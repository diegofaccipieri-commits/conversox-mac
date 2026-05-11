#!/bin/bash
# Usage: ./scripts/release.sh 0.2.6 [--no-publish]
# Builds, signs, zips, installs ConversoxMac locally and (by default) publishes
# the new version as a GitHub release + updates docs/appcast.xml so Sparkle picks
# it up via OTA.

set -euo pipefail

VERSION=${1:?Usage: ./scripts/release.sh VERSION [--no-publish]}
PUBLISH=1
if [[ "${2:-}" == "--no-publish" ]]; then
    PUBLISH=0
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ConversoxMac"
SIGNING_IDENTITY="34A488E1BA65A57C8D37EC51E342923ACA9D891C"
ZIP_NAME="${APP_NAME}_v${VERSION}.zip"
INFO_PLIST="${PROJECT_DIR}/${APP_NAME}/Info.plist"
BUILD_DIR="${PROJECT_DIR}/build"
APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
APPCAST_PATH="${PROJECT_DIR}/docs/appcast.xml"
SIGN_UPDATE="${PROJECT_DIR}/tools/sparkle/sign_update"
FEED_URL="https://diegofaccipieri-commits.github.io/conversox-mac/appcast.xml"
RELEASE_DOWNLOAD_URL="https://github.com/diegofaccipieri-commits/conversox-mac/releases/download/v${VERSION}/${ZIP_NAME}"

echo "==> Building ${APP_NAME} v${VERSION}..."

echo "==> Generating Xcode project..."
xcodegen generate --spec "${PROJECT_DIR}/project.yml" --project "${PROJECT_DIR}" >/dev/null

echo "==> Updating bundle version..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION//./}" "${INFO_PLIST}"

echo "==> Running Release build..."
xcodebuild -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
    > /dev/null

echo "==> Signing with local certificate..."
codesign -f -s "${SIGNING_IDENTITY}" --deep "${APP_PATH}"

echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

echo "==> Zipping signed app..."
rm -f "${PROJECT_DIR}/${ZIP_NAME}"
cd "${BUILD_DIR}/Build/Products/Release"
zip -qr "${PROJECT_DIR}/${ZIP_NAME}" "${APP_NAME}.app"
cd "${PROJECT_DIR}"

echo "==> Installing locally to /Applications..."
rm -rf "/Applications/${APP_NAME}.app"
cp -R "${APP_PATH}" "/Applications/${APP_NAME}.app"

if [[ "${PUBLISH}" -eq 0 ]]; then
    echo ""
    echo "Released ${APP_NAME} v${VERSION} (local only, OTA not published)"
    echo "App: /Applications/${APP_NAME}.app"
    echo "Zip: ${PROJECT_DIR}/${ZIP_NAME}"
    exit 0
fi

echo "==> Signing zip with Sparkle EdDSA key..."
SIGN_OUTPUT=$("${SIGN_UPDATE}" "${PROJECT_DIR}/${ZIP_NAME}")
# sign_update prints something like: sparkle:edSignature="..." length="..."
ED_SIGNATURE=$(echo "${SIGN_OUTPUT}" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
ED_LENGTH=$(echo "${SIGN_OUTPUT}" | sed -n 's/.*length="\([^"]*\)".*/\1/p')

if [[ -z "${ED_SIGNATURE}" || -z "${ED_LENGTH}" ]]; then
    echo "ERROR: sign_update did not produce signature+length"
    echo "Output was: ${SIGN_OUTPUT}"
    exit 1
fi

PUBDATE=$(LC_ALL=en_US.UTF-8 date -u "+%a, %d %b %Y %H:%M:%S +0000")

echo "==> Updating docs/appcast.xml..."
mkdir -p "${PROJECT_DIR}/docs"
if [[ ! -f "${APPCAST_PATH}" ]]; then
    cat > "${APPCAST_PATH}" <<'HEADER'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
<channel>
    <title>ConversoxMac</title>
    <link>https://diegofaccipieri-commits.github.io/conversox-mac/appcast.xml</link>
    <description>OTA updates for ConversoxMac</description>
    <language>pt-br</language>
</channel>
</rss>
HEADER
fi

NEW_ITEM=$(cat <<ITEM
    <item>
        <title>v${VERSION}</title>
        <pubDate>${PUBDATE}</pubDate>
        <sparkle:version>${VERSION//./}</sparkle:version>
        <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
        <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        <enclosure url="${RELEASE_DOWNLOAD_URL}" length="${ED_LENGTH}" type="application/octet-stream" sparkle:edSignature="${ED_SIGNATURE}"/>
    </item>
ITEM
)

# Insert NEW_ITEM right after <channel>...metadata block (before </channel>)
python3 - "${APPCAST_PATH}" "${NEW_ITEM}" <<'PY'
import sys, re, pathlib
path = pathlib.Path(sys.argv[1])
new_item = sys.argv[2]
text = path.read_text()
# Insert immediately before </channel>
if "</channel>" not in text:
    raise SystemExit("appcast.xml is missing </channel>")
text = text.replace("</channel>", new_item + "\n</channel>", 1)
path.write_text(text)
PY

echo "==> Creating GitHub release v${VERSION}..."
gh release create "v${VERSION}" "${PROJECT_DIR}/${ZIP_NAME}" \
    --title "v${VERSION}" \
    --notes "ConversoxMac v${VERSION}" \
    --target main >/dev/null

echo "==> Committing appcast + tagging..."
cd "${PROJECT_DIR}"
git add docs/appcast.xml "${APP_NAME}/Info.plist"
if ! git diff --cached --quiet; then
    git commit -m "Release v${VERSION}: update appcast" >/dev/null
    git push origin main >/dev/null
fi

echo ""
echo "Released ${APP_NAME} v${VERSION}"
echo "App: /Applications/${APP_NAME}.app"
echo "Zip: ${PROJECT_DIR}/${ZIP_NAME}"
echo "Release: https://github.com/diegofaccipieri-commits/conversox-mac/releases/tag/v${VERSION}"
echo "Appcast: ${FEED_URL}"
