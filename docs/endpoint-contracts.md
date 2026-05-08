# Conversox Endpoint Contracts

Fonte: Parte II da spec funcional. Este arquivo e o contrato HTTP engineer-ready para o cliente macOS.

## Conventions

- Auth comum: `Conversox/api/_boot.php`.
- Auth aceita sessao web ou `X-API-Key`.
- API key pode ser `system` (legado/superadmin) ou `scoped` (herda usuario + restringe por `scope_connections`).
- Em chave scoped, `user_connections = intersection(ACL do usuario, scope_connections da key)`.
- Restricted users so enxergam conversas atribuidas.
- POST por sessao pode exigir CSRF; POST com `X-API-Key` ignora CSRF.
- Envelope usual: `{"ok": true, ...}` ou `{"ok": false, "error": "..."}`.
- Erros ACL relevantes: `forbidden_connection`, `access_denied_connection`, `forbidden_not_assigned`.
- Timestamps: unix seconds para polling/cursor; ISO-8601 para agenda/mensagens persistidas.

## Cache and Data Files

- Sidebar cache: `data/omnichannel/conversox4_chats_cache.json`
- Hub state: `data/omnichannel/hub_state.json`
- Realtime post-its: `data/omnichannel/chats_pending.jsonl`
- Caderninhos: `data/omnichannel/chats/<md5(connection|jid)>.jsonl`
- Media cache: `data/omnichannel/media_cache/*`
- Chat codes: `data/omnichannel/chat_codes.json`
- Manual renames: `data/omnichannel/renamed_names.json`
- ACL and low priority: `Conversox/data/connection_acl.json`
- LID mapping: `data/omnichannel/lid_to_phone.json`

## Tenant Scope

`imigrando|welcome` affects URL prefix, connection filtering, Welcome-only actions and UI labels.

- Imigrando API prefix: `/Conversox/api`
- Welcome API prefix: `/Welcome/Conversox/api`

## `GET /Conversox/api/chats.php`

Purpose: sidebar chat list.

Auth: session or API key. CSRF: none. Time limit: 5s.

Request: no required query params.

Server sequence:

- Reads `conversox4_chats_cache.json`.
- If cache missing/invalid, returns fast with empty list and cache headers.
- Merges LID/phone chats.
- Applies manual renames.
- Applies unread overlay from hub state.
- Backfills hub stubs and groups.
- Applies connection ACL and restricted assignment filtering.
- Marks `is_low_priority`.
- Deduplicates groups.
- Rewrites avatar prefix for tenant.

Response:

```json
{
  "ok": true,
  "chats": [
    {
      "jid": "5511999999999@s.whatsapp.net",
      "connection_id": "evolution:canada",
      "instance": "canada",
      "name": "Nome",
      "push_name": "Push",
      "name_source": "renamed|cache|hub",
      "avatar": "/Conversox/api/avatar.php?...",
      "is_group": false,
      "unread": 3,
      "last_message": "...",
      "last_message_at": "2026-05-08T02:47:00Z",
      "last_from_me": false,
      "last_message_type": "text",
      "last_message_duration": 0,
      "badge": "CA",
      "chat_code": "09abcc35e50d",
      "_sort_ts": 1773514000,
      "is_low_priority": false
    }
  ],
  "cached": true,
  "cache_age_s": 12
}
```

Headers:

- `X-Conversox-Cache-Age-S`
- `X-Conversox-Cache-Status: missing`
- `X-Conversox-Cache-Stale: 1`

Errors:

- `401 not_authenticated`
- `403 not_authorized`

Client behavior:

- Initial sidebar load.
- Refresh after poll events.
- Preserve `_sort_ts` for gap detection.

## `GET /Conversox/api/messages.php`

Purpose: chat thread history.

Auth: session or API key. CSRF: none. Time limit: 15s.

Request:

- `jid` required.
- `connection_id` required.
- `limit` optional, clamped `1..50`, default 20.
- `before_ts`, `after_ts`, `cache_sort_ts` optional.

Errors:

- `400 jid_required`
- `400 connection_id_required`
- `403 forbidden_connection`
- `403 forbidden_not_assigned`

Server sequence:

- Resolves caderninho candidates, aliases LID/phone and group cross-connection files.
- Reads tails and parses JSONL.
- Dedups by external id/key.
- Merges reactions.
- Rehydrates transcription state.
- Filters empty/protocol messages and standalone `transcription`.
- Adjusts media URLs/thumbnails for tenant.
- Paginates and returns `has_older` + `oldest_ts`.

Normalized message keys:

```text
id, key_id, type, body, from_me, timestamp, status, sender_name,
quoted, media_url, thumbnail, file_name, mime_type, ptt, duration,
is_deleted, transcription, transcription_status, shared_contacts, reactions
```

Response:

```json
{"ok": true, "messages": [], "has_older": true, "oldest_ts": 1773511000}
```

Client behavior:

- Open chat.
- Reverse pagination.
- Gap reload via `cache_sort_ts`.

## `GET /Conversox/api/poll.php`

Purpose: short polling / realtime.

Auth: session or API key. CSRF: none. Time limit: 10s.

Request:

- `since_ts` required and `> 0`.
- `active_jid` optional.
- `active_connection_id` optional.
- `newest_ts` optional.

Errors:

- `400 since_ts_required`

Server sequence:

- Fast return if no post-its and cache unchanged.
- Reads `chats_pending.jsonl` and aggregates latest by chat.
- Reads shared cache for daemon-consumed changes.
- Applies hub unread overlay.
- Reads inline tail for active conversation.
- Expands LID/phone aliases and group/cross-connection lookup.
- Collects `inline_reactions`.
- Ignores standalone `message_type=transcription`.
- Marks `is_low_priority`.

Response:

```json
{
  "ok": true,
  "changed_chats": [],
  "new_messages": 0,
  "inline_messages": [],
  "inline_reactions": [
    {"target_id": "ABCD", "emoji": "👍", "from_me": false}
  ],
  "server_ts": 1773514200
}
```

Client behavior:

- Poll loop.
- Keep cursor `since_ts = last server_ts`.
- Dedup inline messages by `id`/`key_id`.
- Backoff on 403/429/503.

## `POST /Conversox/api/send.php`

Purpose: send text/media/note via proxy to `api/conversox3/send.php`.

Auth: session or API key. CSRF: required for session, ignored for API key.

Content-Type:

- `application/json`
- `multipart/form-data`

Fields:

- `instance` conditional if no `chat_code`/`connection_id`.
- `connection_id` conditional.
- `jid` conditional if no `chat_code`.
- `chat_code` conditional.
- `text` conditional if no file/media_url.
- `file` optional multipart, max 16MB.
- `media_url`/`file_url` optional.
- `reply_to` optional.
- `mentioned_jids[]` optional.
- `signature_name` optional.
- `csrf_token` conditional for session.

Errors:

- `405 method_not_allowed`
- `413 file_too_large_for_php (max ...)`
- `403 csrf_token_invalid`
- `404 chat_code_not_found`
- `400 instance_required (use chat_code or instance+jid or connection_id)`
- `400 jid_required (use chat_code or instance+jid)`
- `400 text_or_file_required`
- `413 file_too_large`
- `403 forbidden_connection`
- `403 forbidden_not_assigned`
- `502 send_failed` or provider error

Important routing:

- Group in `main` may force `canada`.
- Auth by `api_key` currently may force `canada` in legacy path.
- Signature only for session text without attachment.

Response:

```json
{
  "ok": true,
  "message_id": "3EB0...",
  "timestamp": "2026-05-08T03:10:00+00:00",
  "error": null
}
```

Client behavior:

- Text send.
- Attachments.
- Reply/mention send.
- Show provider failure distinctly from validation failure.

## `POST /Conversox/api/actions.php`

Dispatcher for chat and message actions.

### `mark_read`

Fields: `action`, `jid`, `connection_id`, optional `read_messages`.

Side effects:

- Updates hub state.
- Tries Evolution `markMessageAsRead`.
- Fallback to `readMessages`.
- Returns success even if provider fails, with provider metadata.

Response:

```json
{
  "ok": true,
  "action": "mark_read",
  "updated": true,
  "provider": {"attempted": true, "ok": true, "http_code": 200}
}
```

### `mark_unread`

Side effects:

- Updates hub only.
- Sets `manual_unread_count=1`.
- Clears/removes `last_read_at`.
- Does not call Evolution.

Response:

```json
{"ok": true, "action": "mark_unread", "set_unread": true}
```

Common errors:

- `400 connection_id_required`
- `403 access_denied_connection`
- `400 jid_required`

### `delete`

Fields: `message_id`, `jid`, `connection_id`, `delete_scope=for_me|for_everyone`.

Errors:

- `message_id_required`
- `evolution_not_configured`

Side effects:

- Tries Evolution delete fallback chain.
- Writes tombstone/local state.
- Emits cache/post-it asynchronously.

### `edit`

Fields: `message_id`, `text`, `jid`, `connection_id`.

Errors:

- `message_id_and_text_required`
- `evolution_not_configured`

Side effects:

- `POST /chat/updateMessage/{instance}`.
- Rewrites history with same external id.

### `react`

Fields: `message_id`, `emoji`, `jid`, `connection_id`.

Errors:

- `message_id_required`
- `evolution_not_configured`

Side effects:

- `POST /message/sendReaction/{instance}`.
- Empty emoji removes reaction.
- Emits synthetic local reaction id.

### `set_low_priority`

Fields: `jid`, `connection_id`, `set`.

Side effect:

- Persists in `Conversox/data/connection_acl.json` under `low_priority_conversations[email]`.

Errors:

- `500 failed_to_set_low_priority`

### `transfer_conversation`

Fields: `jid`, `connection_id`, `target_user_id`.

Errors:

- `400 target_user_id_required`
- `404 target_user_not_found`
- `500 could_not_transfer_conversation`

Side effects:

- Resolves target agent by company.
- Updates hub assignment.
- Appends system message.
- Enqueues post-it.

### `create_contact`

Fields: `jid`, `connection_id`, optional `name`.

Side effects:

- Registers chat code.
- Persists manual name.
- May auto-assign for restricted user.
- No Evolution call.

### `create_group`

Fields: `connection_id`, `group_name`, `participants[]`, optional `photo_base64`.

Errors:

- `group_name_required`
- `participants_required`
- `instance_required`
- `no_valid_participants`
- `group_creation_failed`

Side effects:

- Normalizes participants.
- Calls Evolution group create.
- Persists group name.
- Registers chat code.
- Optionally updates group picture.

### `fetch_group_invite`

Fields: `connection_id`, `jid` or `group_jid`.

Errors:

- `group_jid_required`
- `group_invite_fetch_failed`

Response:

```json
{
  "ok": true,
  "group_jid": "1203...@g.us",
  "invite_code": "AbCdEf",
  "invite_url": "https://chat.whatsapp.com/AbCdEf"
}
```

### `fetch_media`

Fields: `message_id`, `jid`, `connection_id`, optional `mime_type`.

Errors:

- `message_id_required`
- `instance_required`
- `410 media_expired_not_cached`
- `502 media_download_failed: ...`

Side effects:

- Checks local media cache.
- Calls Evolution `getBase64FromMediaMessage`.
- Saves local cache file.

Response:

```json
{
  "ok": true,
  "media_url": "/Conversox/api/media.php?path=...",
  "cached_url": "/Conversox/api/media.php?path=...",
  "mime_type": "audio/ogg"
}
```

### `register_welcome_lead`

Fields: `lead_code`, `chat_code`, `jid`, `connection_id`.

Errors:

- `403 welcome_only`
- `422 individual_chat_required`
- `422 lead_code_required`
- `422 chat_code_required`
- `404 lead_not_found`

Side effects:

- Links chat to `wlc_leads`.
- Updates lead whatsapp/chat code if empty.

## `GET /api/conversox3/notification_sound.php`

Purpose: notification sound.

Auth: conversox3 session. Response type: `audio/mpeg`.

Response:

- `200 audio/mpeg`
- `304` when ETag matches.
- `404 sound_not_found`
- `500 sound_open_failed`

Headers:

- `Cache-Control: private, max-age=86400`
- `ETag`
- `Last-Modified`
- `Accept-Ranges: bytes`

## Audio Playback Contract

Audio URL sources:

- `messages.php` can return direct `media_url`.
- `fetch:enc` or missing URL triggers `actions.php?action=fetch_media`.
- `media.php?path=...` supports Range (`206`) for audio playback.

Relevant fields:

- `type=audio|ptt`
- `ptt`
- `duration`
- `waveform`
- `media_url`

Mac player states:

```text
idle -> loading -> playing -> paused -> ended
error -> retry
```

## Stickers

Endpoints:

- `GET /Conversox/api/stickers.php?action=packs`
- `GET /Conversox/api/stickers.php?action=stickers&pack_id=...&q=...`
- `GET /Conversox/api/stickers.php?action=favorites`
- `GET /Conversox/api/stickers.php?action=asset&sticker_id=...`
- `POST /Conversox/api/stickers.php?action=favorite`
- `POST /Conversox/api/stickers.php?action=send`
- `POST /Conversox/api/stickers.php?action=save`
- `POST /Conversox/api/stickers.php?action=delete`
- `POST /Conversox/api/sticker_upload.php`

Important errors:

- `pack_id_required`
- `pack_not_found`
- `sticker_not_found`
- `sticker_file_missing`
- `sticker_id_required`
- `favorite_save_failed`
- `jid_and_connection_id_required`
- `access_denied_connection`
- `invalid_connection_instance`
- `invalid_jid`
- `sticker_id_or_sticker_url_required`
- `send_sticker_failed`
- `media_url_required`
- `download_failed`
- `invalid_image_type`
- `image_decode_failed`
- `webp_encode_failed`
- `sticker_too_large`
- `can_only_delete_uploaded_stickers`
- `multipart_required`
- `file_required`
- `file_too_large_max_5mb`
- `unsupported_type`

## Notes

Endpoint: `/Conversox/api/notes.php`

GET fields: `jid`, `connection_id`, optional `jids[]`.

POST fields: `jid`, `connection_id`, `text`.

Errors:

- `method_not_allowed`
- `jid_and_connection_id_required`
- `text_required`
- `forbidden_connection`

Storage: `data/omnichannel/notes/<md5(conn|jid)>.json`.

## Schedule

Endpoint: `/api/conversox3/schedule.php`

GET by `jid` or `chat_code`.

POST `action=create`:

- `jid`
- `message`
- `date` as `YYYY-MM-DD`
- `time` as `HH:MM`
- optional `timezone`, `connection_id`, `instance`

POST `action=cancel`:

- `id`

Errors:

- `jid is required`
- `message is required`
- `date and time are required`
- `invalid date format (expected YYYY-MM-DD)`
- `invalid time format (expected HH:MM)`
- `id is required`
- `schedule not found`

Storage: `data/omnichannel/scheduled_messages.json`.

## Quick Replies

Endpoint: `/api/conversox3/quick_replies.php`

GET returns `quick_replies`, `scope`, `company_label`.

POST actions: `create`, `update`, `delete`.

Errors:

- `method_not_allowed`
- `missing_action`
- `unknown_action`
- `shortcut_and_body_required`
- `invalid_shortcut_format`
- `shortcut_already_exists`
- `missing_id`
- `not_found`

Shortcut format: `^/[a-z0-9_]+$`.

## Agenda

Endpoint: `/Conversox/api/agenda.php`

GET actions:

- `list`
- `search`
- `find`
- `by_chat`

POST actions:

- `set_primary`
- `link`
- `set_name`
- `hide`
- `rebuild`

Errors:

- `missing_params: chat_id, connection_id`
- `missing_params: person_id, chat_id, connection_id`
- `missing_params: display_name, chats[]`
- `missing_params: person_id`
- `unknown_action: <action>`
- `method_not_allowed`

Storage: `data/omnichannel/contact_agenda.json`.

## AI Assistant

Endpoint: `POST /Conversox/api/ai_assistant.php`

Fields:

- `prompt` required.
- `messages` optional.
- `context` optional.
- `ai_thread` optional.

Errors:

- `405 method_not_allowed`
- `prompt_required`
- `502 ai_service_unreachable: ...`
- `502 ai_service_invalid_response`

Side effects:

- Proxy to `http://127.0.0.1:7700/aa-sidebar`.
- Logs markdown usage in `logs/conversox_ai_usage/*`.

## Media Proxy

Endpoint: `GET /Conversox/api/media.php`

Modes:

- Cache path: `?path=<basename>`
- Provider fetch: `?message_id=...&jid=...&instance=...`
- Optional `stream=1`

Errors:

- `method_not_allowed`
- `invalid_path`
- `not_found`
- `missing_params: path= or message_id=&jid=&instance=`
- `media_fetch_failed: ...`
- `media_decode_failed`

Behavior:

- Serves cached files with Range support.
- Fetch mode calls Evolution and writes cache.

## Avatar

Endpoint: `GET /Conversox/api/avatar.php`

Contract:

- Always returns renderable image: cached JPG, remote fetch or fallback SVG initials.

Resolution chain:

- local avatar cache
- LID to phone fallback
- `evolution_contacts_cache.json`
- Evolution `fetchProfilePictureUrl`
- SVG fallback

## Contacts and Profile

### `/Conversox/api/contacts.php`

POST `action=set_name`:

- `jid` required.
- `name` required.

POST `action=remove_name`.

Errors:

- `method_not_allowed`
- `invalid_action`
- `jid_required`
- `name_required`

Side effects:

- Updates `renamed_names.json`.
- Invalidates temporary chat cache.

### `/api/conversox3/contact_search.php`

Fields:

- `connection_id` required.
- `q` required, minimum 2 chars.
- `limit` optional `1..20`.

Errors:

- `connection_id_required`
- `access_denied_connection`

### `/api/conversox3/contacts_directory.php`

Fields:

- `q`
- `limit` `1..200`
- `offset`
- `connection_id`

Errors:

- `access_denied_connection`

### `/api/conversox3/contacts_directory_refresh.php`

Fields:

- `action=status|start`
- optional `stale_only=1`

Errors:

- `invalid_action`

### `/api/conversox3/profile.php`

GET fields:

- `jid`
- `connection_id`
- optional `force=1`

Errors:

- `jid_required`
- `connection_id_required`
- `access_denied_connection`

POST `action=rename` fields:

- `jid`
- `name`

Errors:

- `jid_required`
- `name_required`
- `save_failed`
- `invalid_action`

## Chat Code

Endpoint: `GET /Conversox/api/chat_code.php`

Modes:

- Resolve: `?code=<12hex>`
- Generate/lookup: `?jid=...&connection_id=...`

Errors:

- `method_not_allowed`
- `invalid_code_format`
- `code_not_found`
- `missing_params: provide code= or jid=&connection_id=`

## Group Participants

Endpoint: `GET /Conversox/api/group_participants.php`

Fields:

- `jid` required and must end with `@g.us`.
- `connection_id` required.

Errors:

- `401 unauthorized`
- `400 jid_must_be_group`
- `502` provider error.

## Agent Inbox

Endpoint: `GET /Conversox/api/agent_inbox.php`

Modes:

- default inbound queue since `since_ts`.
- `mode=history`.
- `search=<term>`.

Fields:

- `since_ts` optional, default now-300.
- `limit` optional `1..50`.
- `jid`, `connection_id` conditional.
- `scope` optional.

Errors:

- `jid_required`
- `connection_id_required`
- `forbidden_connection`

## FAQ Review

Endpoint: `GET /Conversox/api/unread_faq_review.php`

Fields:

- `limit` `1..100`
- `message_limit` `1..40`
- `top_n` `1..10`
- `include_groups`
- `include_faq`
- `skip_faq`
- `scope`
- `acting_email`
- `filter_jid`
- `filter_connection_id`
- `exclude_low_priority`

Modes:

- `mode=direct`: PHP reads caderninhos directly.
- `mode=faq`: proxy to `127.0.0.1:7700/aa-unread-faq-review`.

Errors:

- `acting_email_without_acl`
- `unread_review_service_unreachable: ...`
- `unread_review_service_invalid_response`

## `/api/me.php`

Purpose: app bootstrap.

Auth: session or API key.

Response:

```json
{
  "ok": true,
  "user": {
    "id": 123,
    "email": "user@imigrando.com",
    "name": "User",
    "role": "admin",
    "company_id": 1,
    "auth_source": "imigrando",
    "session_remaining_seconds": 21000,
    "auth_via": "session|api_key"
  },
  "conversox": {
    "is_master_superadmin": false,
    "restricted": false,
    "connections": ["evolution:canada"],
    "csrf_token": "..."
  },
  "server_time": "2026-05-08T03:20:00Z"
}
```

Errors:

- `401 not_authenticated`
- `403 not_authorized`

## Error Handling Cheat Sheet

| HTTP | error literal | Client action |
|---:|---|---|
| 401 | `not_authenticated` / `unauthorized` | reauth |
| 403 | `access_denied_connection` | refresh `/api/me.php`, update UI |
| 403 | `forbidden_not_assigned` | show blocked state + refresh sidebar |
| 403 | `csrf_token_invalid` | renew token and retry when using session |
| 404 | `code_not_found` | invalidate deeplink |
| 404 | `lead_not_found` | ask for another code |
| 410 | `media_expired_not_cached` | render expired media state |
| 422 | `individual_chat_required` | contextual warning |
| 422 | `lead_code_required` / `chat_code_required` | form validation |
| 500 | `evolution_not_configured` | alert support / retry fallback |
| 500 | `failed_to_set_low_priority` | rollback visual state |
| 502 | `media_download_failed: ...` | retry with backoff |
| 502 | `ai_service_unreachable: ...` | manual fallback |
| 502 | `unread_review_service_unreachable: ...` | degrade to direct mode |

## Client Implementation Checklist

- Bootstrap: `/api/me.php`, persist `connections[]`, `restricted`, `auth_via`.
- Networking: endpoint timeout, `X-API-Key`, CSRF when session, literal error mapper.
- Sidebar/poll: `chats.php`, `poll.php`, merge `changed_chats`, `is_low_priority`, cache headers.
- Messages: `messages.php`, `before_ts`, dedup, per-type rendering, transcription inline only.
- Composer/send: text, attachment, reply, mention, multipart 413 UX, `forbidden_not_assigned` UX.
- Actions: mark read/unread, edit, delete, react, transfer, low priority, create contact/group/invite, register welcome.
- Media/audio/avatar: `media_url`, `fetch_media`, Range audio player, local cache, expired placeholders.
- Stickers/notes/schedule/quick replies: picker, notes, schedule create/cancel/list, shortcut validation.
- Contacts/agenda/profile: contact search, directory pagination, agenda linking, profile rename.
- Agent/FAQ/AI: agent inbox, unread FAQ review, AI panel with fallback.
- Observability: status code + error string logs, latency by endpoint class, backoff telemetry.
- Release gate: smoke normal/restricted user, imigrando/welcome, visual parity checklist.
