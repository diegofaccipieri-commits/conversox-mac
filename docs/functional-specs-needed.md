# Functional Specs Needed

Status: the full functional spec is now loaded in `docs/functional-spec.md`.

Keep this file as a gap checklist for follow-up discovery or implementation decisions.

## Still needs exact server confirmation

- Exact `/api/me.php` final payload once implemented.
- Exact scoped API key schema and provisioning flow.
- Exact response shape for multipart attachments through `send.php`.
- Exact production confirmation for `actions.php` variants documented in `docs/endpoint-contracts.md`.
- Exact `poll.php` response shape in production, because older docs mentioned a nested `data` variant while current endpoint contract uses top-level fields.
- Exact media proxy URLs and cache headers for `avatar.php` and `media.php`.
- Exact role matrix for viewer/editor/admin/superadmin in the Mac app.
- Exact tenant routing for Welcome paths when using `X-API-Key`.

## Implementation gaps in the Mac app

- Visual parity components from `docs/visual-design-system.md`.
- Full `ConversoxAPI` actor and typed endpoint layer.
- Chat filters/search/channel filters.
- Message rendering beyond basic text.
- Attachments, media cache and previews.
- Reply/quote.
- Polling backoff and recovery.
- Header actions.
- Contacts tab.
- Internal notes.
- Quick replies.
- Native notification click routing.
- Deep links.
