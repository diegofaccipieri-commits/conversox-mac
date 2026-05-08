# Functional Specs Needed

Status: the full functional spec is now loaded in `docs/functional-spec.md`.

Keep this file as a gap checklist for follow-up discovery or implementation decisions.

## Still needs exact server confirmation

- Exact `/api/me.php` final payload once implemented.
- Exact scoped API key schema and provisioning flow.
- Exact response shape for multipart attachments through `send.php`.
- Exact `actions.php` payloads for each action: mark_read, set_low_priority, transfer_conversation, fetch_media, react, edit, delete, create_contact, create_group, fetch_group_invite, register_welcome_lead.
- Exact `poll.php` response shape in production, because discovery showed top-level fields while the functional spec also mentions a nested `data` variant.
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
