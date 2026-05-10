# Send Auth Diagnostic

Date: 2026-05-10

## Summary

The current app session is valid for read endpoints, but `send.php` rejects the same `X-API-Key`.

Observed behavior with the exact key restored from the macOS app keychain:

- `GET /Conversox/api/chats.php` -> `200`
- `POST /Conversox/api/actions.php` -> request passes auth and fails only on missing payload
- `POST /Conversox/api/send.php` -> `401 {"ok":false,"error":"unauthorized"}`

This means the failure is not a generic "session missing" issue in the app.
It is a backend authorization inconsistency specific to `send.php`.

## Reproduction

Headers used by the app:

```text
X-API-Key: <restored from keychain>
X-Conversox-Auth-Source: imigrando
```

Successful read probe:

```bash
curl -sS \
  -H "X-API-Key: $CONVERSOX_API_KEY" \
  -H "X-Conversox-Auth-Source: imigrando" \
  "https://app.imigrando.com/Conversox/api/chats.php?_t=$(date +%s)"
```

Observed result:

```json
{"status":200}
```

Successful auth pass on `actions.php`:

```bash
curl -sS \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $CONVERSOX_API_KEY" \
  -H "X-Conversox-Auth-Source: imigrando" \
  -d '{"action":"mark_unread"}' \
  https://app.imigrando.com/Conversox/api/actions.php
```

Observed result:

```json
{"status":400,"body":"{\"ok\":false,\"error\":\"connection_id_required\"}"}
```

Failing send probe:

```bash
curl -sS \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $CONVERSOX_API_KEY" \
  -H "X-Conversox-Auth-Source: imigrando" \
  -d '{}' \
  https://app.imigrando.com/Conversox/api/send.php
```

Observed result:

```json
{"status":401,"body":"{\"ok\":false,\"error\":\"unauthorized\"}"}
```

## Expected backend behavior

`send.php` must resolve auth using the same `_boot.php` logic already accepted by:

- `chats.php`
- `messages.php`
- `poll.php`
- `actions.php`

For the same API key, `send.php` should not return `401 unauthorized` if read/action endpoints already accept it.

Expected outcomes for the same identity:

- `400` validation errors for missing `jid`, `connection_id`, `text`
- `403 forbidden_connection`
- `403 forbidden_not_assigned`
- `502 send_failed`

But not `401 unauthorized` once the key has already authenticated elsewhere.

## Likely root cause

One of these is probably happening in backend:

- `send.php` is not using the same auth bootstrap path as other Conversox endpoints.
- `send.php` still treats some `X-API-Key` flow as legacy/unsupported.
- `send.php` applies a stricter or divergent identity resolution branch.
- scoped/system key handling is inconsistent between read endpoints and send endpoint.

This aligns with existing project notes in:

- `docs/server-implementation-plan.md`
- `docs/endpoint-contracts.md`
- `docs/spec-coverage.md`

## Action required on server

1. Make `send.php` use the same resolved identity contract as `chats.php` and `actions.php`.
2. Ensure `X-API-Key` + `X-Conversox-Auth-Source` reaches the same `_boot.php` auth path.
3. Return validation or ACL errors after auth succeeds, instead of `401 unauthorized`.
4. Re-run smoke tests with the same key against:
   - `chats.php`
   - `messages.php`
   - `poll.php`
   - `send.php`
   - `actions.php`

## App-side mitigation already added

The macOS app now:

- detects when the key can read chats but cannot send
- shows a clear session notice for this condition
- maps `unauthorized` to a send-permission error instead of a generic "not authenticated"
