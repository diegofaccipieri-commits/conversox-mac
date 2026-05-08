# ConversoxMac Spec Coverage

This file tracks whether the loaded specs are active in the project and how much is implemented in the Mac app.

## Spec Loading Status

| Spec | File | Status |
|---|---|---|
| Server discovery/auth integration | `docs/backend-integration-notes.md` | Loaded |
| Visual design system | `docs/visual-design-system.md` | Loaded |
| Functional feature spec | `docs/functional-spec.md` | Loaded |
| Engineer-ready endpoint contracts | `docs/endpoint-contracts.md` | Loaded |
| Remaining gaps | `docs/functional-specs-needed.md` | Loaded |

## Implementation Coverage

| Area | Status | Notes |
|---|---|---|
| Signed macOS app bundle | Implemented | Release script builds, signs and installs app. |
| X-API-Key auth | Partial | App stores key and validates via `/api/me.php` or `chats.php` fallback. Scoped key server work still pending. |
| Tenant switcher | Partial | Login has `imigrando|welcome`; endpoint path routing still needs full Welcome prefix handling. |
| `/api/me.php` | Partial | App calls it; server stub exists; production endpoint still pending. |
| Chat list | Partial | Loads `chats.php`, sorts locally, basic search/filter UI. Low-priority and channel logic still incomplete. |
| Chat row visual parity | Partial | Dark-first row, badges and dense layout implemented. Avatar image proxy not implemented yet. |
| Message history | Partial | Loads `messages.php`, basic text body mapping. Reverse pagination and media types pending. |
| Send text | Partial | Sends basic JSON text through `send.php`. Attachments/reply/mentions/signature pending. |
| Mark read | Partial | Called after loading messages. Manual unread and provider metadata handling pending. |
| Polling | Partial | 3s polling implemented. Backoff/recovery/dedup/inline reactions pending. |
| Notifications | Partial | Permission/local notification shell exists. Click routing, silence rules and sound pending. |
| Visual shell | Partial | Dark shell/tokens/sidebar/header/bubbles/composer implemented. Wallpaper pattern, toasts, drop overlay pending. |
| Contacts tab | Not started | Needs `contacts_directory.php` and related endpoints. |
| Header actions | Mostly not started | Buttons are visual placeholders except mark read side effect on chat load. |
| Media/audio/avatar cache | Not started | Needs cache layer and proxy integration. |
| Attachments | Not started | Needs `NSOpenPanel`, multipart upload and drag/drop. |
| Reply/quote | Not started | Needs state + send payload. |
| Notes | Not started | Needs `notes.php`. |
| Quick replies | Not started | Needs `quick_replies.php`. |
| Stickers | Not started | Needs stickers endpoints and picker. |
| Schedule/agenda/Welcome | Not started | Needs forms and action endpoints. |
| AI/FAQ/agent inbox | Not started | Post-MVP/nice-to-have. |
| Deep links | Not started | Current Info.plist has `conversoxmac://`; spec recommends future `conversox://chat/<code>`. |

## Next Implementation Gate

Before adding more UI surface, implement:

1. `ConversoxAPI` typed actor for all endpoint calls.
2. Error mapper using literal backend `error` strings from `docs/endpoint-contracts.md`.
3. Polling backoff and dedup.
4. Full chat filters/search/channel filters.
5. Message model expansion for media/status/reply/reactions.
