#!/bin/bash
# Usage: ./scripts/release.sh 0.1.0
# Builds, signs, zips, and installs ConversoxMac locally.

set -euo pipefail

VERSION=${1:?Usage: ./scripts/release.sh VERSION}

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ConversoxMac"
SIGNING_IDENTITY="34A488E1BA65A57C8D37EC51E342923ACA9D891C"
ZIP_NAME="${APP_NAME}_v${VERSION}.zip"
INFO_PLIST="${PROJECT_DIR}/${APP_NAME}/Info.plist"
BUILD_DIR="${PROJECT_DIR}/build"
APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

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

echo ""
echo "Released ${APP_NAME} v${VERSION}"
echo "App: /Applications/${APP_NAME}.app"
echo "Zip: ${PROJECT_DIR}/${ZIP_NAME}"
