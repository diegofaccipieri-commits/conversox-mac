# ConversoxMac Functional Spec

Fonte: spec funcional do Conversox web (`Conversox/v6.php`, backend PHP em `Conversox/api/`, discovery do servidor e spec visual).

Este documento define a paridade funcional esperada para o ConversoxMac. A implementacao atual cobre apenas o nucleo: auth via `X-API-Key`, listagem de chats, leitura/envio de texto e polling.

## 1. Arquitetura

- Frontend web fonte: SPA single-file `Conversox/v6.php`, com JS inline e CSS externo `assets/conversox/v5/conversox-v5.css`.
- Backend: endpoints PHP em `Conversox/api/`.
- Cache de chats: `data/omnichannel/conversox4_chats_cache.json`.
- Historico por conversa: caderninhos append-only em `data/omnichannel/chats/<connection>/<jid>.jsonl`.
- Incrementais/polling: `data/omnichannel/chats_pending.jsonl` alimenta `poll.php`.
- Daemon: `cron/conversox4_daemon.php` atualiza cache full e incrementais.
- Provider: Evolution API para 5 instancias WhatsApp.
- Hub state: `omnichannel_hub.php` e autoritativo para unread, last_read_at e manual_unread_count.

Fluxo principal:

```text
Evolution webhook -> hub/post-it -> chats_pending.jsonl -> poll.php -> app
Daemon -> full Evolution fetch + caderninho merge -> conversox4_chats_cache.json
App -> chats.php/messages.php/send.php/actions.php/poll.php
```

## 2. Auth, tenant e ACL

- Auth principal no Mac: `X-API-Key`.
- Tenant: `X-Conversox-Auth-Source: imigrando | welcome`.
- Sessao web tambem existe via `IMIGRANDO_SESSION`, mas o Mac nao deve depender de cookie/CSRF.
- POST com sessao requer CSRF; POST com API key ignora CSRF.
- ACL por usuario: `conversox_acl_user_connections($email)`.
- Restricted users so veem conversas explicitamente atribuidas.
- Master superadmin ve todas as connections.

Endpoint planejado para boot:

```text
GET /api/me.php
```

Deve retornar user, role, tenant, connections, restricted, csrf_token quando aplicavel e server_time.

## 3. Multi-tenant

Tenant `imigrando`:

- API base: `/Conversox/api`.
- Company label: `Imigrando`.
- Permissions: `/config/permissions.php`.
- Avatar prefix: `/Conversox/api/`.

Tenant `welcome`:

- API base: `/Welcome/Conversox/api`.
- Company label: `Welcome Education`.
- Permissions: `/Welcome/config/permissions.php`.
- Avatar prefix: `/Welcome/Conversox/api/`.
- Exibe fluxo `register_welcome_lead`.

No Mac:

- Tela de entrada deve permitir escolher tenant.
- Persistir tenant em Keychain/UserDefaults junto da API key.
- Ajustar base path dos endpoints conforme tenant.

## 4. Sidebar

Top row:

- Version badge: `ConversoxMac vX.Y.Z`.
- Search input: busca live em name, push_name, jid, last_message e agenda.
- New chat button: abre fluxo nova conversa.
- Notifications toggle: persiste preferencia local.
- Dark mode toggle: dark/light/system.

Filtros:

- Inbox: chats nao low-priority e nao arquivados.
- Unread: `unread > 0`.
- Low: `is_low_priority == true`.
- Todos: sem filtro.

Tabs:

- Chats: `GET chats.php`.
- Contatos: `GET contacts_directory.php`.
- Fila: `GET agent_inbox.php`, visivel para admin/superadmin quando habilitado.

Channel filters:

- TD, WA, IG, TG, EM, SM.
- MVP: WA funcional, demais placeholders.

Nova conversa:

- Escolher connection permitida.
- Informar numero ou buscar contato salvo.
- `POST actions.php?action=create_contact`.

## 5. Chat list

Cada item deve exibir:

- Avatar via `avatar.php?jid&conn`.
- Nome resolvido: renamed > cache/caderninho > pushName > JID.
- Tempo relativo da ultima mensagem.
- Preview da ultima mensagem.
- Sub-linha de connection origin.
- Badge unread.
- Status icon para outgoing last message.

Estados:

- Active.
- Has unread.
- Draft local.
- Draft-line/digitando por outro agente, se existir no hub.
- Low priority.
- Disconnected/connecting por connection status.

Ordenacao:

- Decrescente por `_sort_ts`.

Paginacao:

- Web nao pagina; `chats.php` retorna lista completa.
- Mac MVP pode manter lista completa.

Backfill:

- Contatos criados sem mensagem devem aparecer via hub state.

Dedup:

- Grupos podem ser deduplicados por subject+participants.

## 6. Chat header

Identidade:

- Avatar 40pt.
- Nome + rename manual.
- Badge de telefone da instancia.
- Badge de connection/instance.
- Status: online, digitando, visto por ultimo, offline.

Acoes:

```text
copy-link
group-invite
transfer-chat
low-priority
ai-assistant
internal-notes
schedule
book-meeting
register-welcome
mark-read
```

Visibilidade:

- `group-invite` apenas grupos.
- `register-welcome` apenas tenant Welcome.
- Acoes administrativas conforme role/ACL.

## 7. Mensagens

Tipos suportados:

```text
text
image
video
gif
audio
ptt
document
sticker
contact
location
system
transcription
note
```

Estados:

```text
pending
sent
delivered
read
failed
deleted
edited
forwarded
replied/quoted
note
```

Comportamentos:

- URLs auto-linkadas.
- Mentions com pill.
- Emoji-only sizing.
- Quote clicavel com scroll/highlight.
- Sender label em grupos.
- Date separators por dia.
- Auto-scroll se usuario estiver ate 80px do bottom.
- Botao scroll-bottom se usuario estiver afastado.
- History loader com `before_ts`/limite.

Media:

- `media.php?id&type` para proxy/descriptografia.
- `avatar.php?jid&conn` para foto de perfil.
- Lazy load para imagens/videos.
- `fetch:enc` deve disparar `actions.php?action=fetch_media`.

## 8. Composer

Layout funcional:

```text
reply-preview
recording-indicator
signature-name-btn
attach + textarea + quick replies + emoji + sticker + audio + send
```

Texto:

- Auto-resize, min 24px, max 180px.
- Enter envia.
- Shift+Enter quebra linha.
- Draft local por chat.

Acoes:

- Attach: multi-upload, tipos image/video/audio/pdf/doc/xls/txt.
- Quick replies: popup/CRUD.
- Emoji picker.
- Sticker picker.
- Audio record/PTT.
- Send habilitado quando houver texto ou anexo.
- Drag & drop de arquivo.
- Paste de imagem.
- Signature prepend opcional por chat.

Payload de envio conceitual:

```json
{
  "connection_id": "evolution:canada",
  "conversation_id": "5511999999999@s.whatsapp.net",
  "message": "ola",
  "type": "text",
  "quoted_msg_id": null,
  "note": false,
  "signature": "Diego",
  "attachments": []
}
```

## 9. Polling e sincronizacao

Endpoint:

```text
GET poll.php?since_ts=<unix_float>&active_jid=<jid>&active_connection_id=<connection_id>
```

Resposta:

- `changed_chats`.
- `new_messages`.
- `inline_messages`.
- `inline_notes`.
- `inline_reactions`.
- `server_ts`.
- `server_seq`.

Loop:

- Poll interval: 3s.
- Backoff em 403/429/503: 15s -> 30s -> 60s -> 120s.
- Reset ao primeiro 200.
- Fallback: refresh manual de `chats.php`.

Unread:

- Hub state e autoritativo.
- Manual unread pode vencer Evolution.
- Se `last_read_at >= last_message_at`, unread vira 0.

## 10. Notificacoes

MVP:

- Notificacao local macOS quando polling detectar mensagem nova e janela/chat nao estiver ativo.
- Badge dock com soma de unread.
- Clique em notificacao deve abrir/focar conversa.

Pos-MVP:

- APNs via proxy usando `CONVERSOX_FORWARDER_*`.
- Regras de silencio por usuario/tenant/chat.

## 11. Contatos

Endpoints:

```text
GET contacts_directory.php
POST contacts_directory_refresh.php
GET contact_search.php
POST actions.php?action=create_contact
POST contacts.php
```

Features:

- Aba contatos.
- Busca por nome/telefone.
- Click abre conversa ou cria contato.
- Rename manual persiste em `renamed_names.json`.
- Profile preview com foto, telefone, CRM/tickets quando houver.

## 12. Grupos

Deteccao:

- JID terminado em `@g.us`.

Features:

- Sender labels.
- Avatar do remetente.
- Mention autocomplete via `group_participants.php`.
- Group invite via `actions.php?action=fetch_group_invite`.
- Create group via `actions.php?action=create_group`.
- Subject/avatar cacheados pela Evolution.

## 13. Notas internas

Trigger:

- `internal-notes-btn`.

Comportamento:

- Composer entra em modo nota.
- Envio vira `note=true`.
- Nao vai para Evolution.
- Persiste no caderninho/cache.
- Render com bubble amarela, autor e lock.

Endpoint:

```text
GET/POST/DELETE notes.php
```

## 14. AI assistant e FAQ

AI panel:

- Resumir conversa.
- Sugerir resposta.
- Free prompt.
- Acoes sugeridas clicaveis.
- Historico por chat.

Endpoint:

```text
POST ai_assistant.php
```

FAQ:

```text
GET faq_search.php?q=...
POST faq_feedback.php
GET faq_feedback_summary.php
GET unread_faq_review.php
```

## 15. Quick replies, stickers e forwarding

Quick replies:

- `GET/POST/DELETE quick_replies.php`.
- Popup no composer.
- Atalho `/atalho` expande texto.

Stickers:

- `GET stickers.php`.
- `POST sticker_upload.php`.
- Recentes, favoritos, packs, busca.

Forward:

- Context menu de mensagem.
- Modal com busca/lista de chats.
- `POST send.php` com `forwarded=true`.

## 16. Schedule, agenda e Welcome

Schedule:

- `GET/POST/DELETE schedule.php`.
- Body: `connection_id`, `conversation_id`, `message`, `scheduled_at`, `timezone`.

Agenda/book meeting:

- `POST agenda.php`.
- Cria booking e envia confirmacao via WhatsApp.

Welcome lead:

- `POST actions.php?action=register_welcome_lead`.
- Visivel apenas tenant Welcome.

## 17. Deep links

Web:

```text
GET chat_code.php?code=ABC123
https://app.imigrando.com/Conversox/v6.php?code=ABC123
```

Mac futuro:

```text
conversox://chat/<code>
```

Info.plist atual registra `conversoxmac://` para compatibilidade inicial, mas a spec funcional recomenda `conversox://`.

## 18. Permissoes

Roles:

```text
viewer
editor
admin
superadmin
system
```

Regras:

- Viewer le.
- Editor atende/envia.
- Admin transfere/fila/operacoes ampliadas.
- Superadmin ve tudo.
- System para automacoes/API.

O Mac precisa aplicar visibilidade de acoes com base no retorno de `/api/me.php`.

## 19. Errors e status codes

```text
200 OK
400 validacao
401 nao autenticado
403 sem permissao
404 recurso nao encontrado
429 rate limit
500 erro interno
503 Evolution/backend indisponivel
```

Padrao:

```json
{"ok": true, "data": {}}
{"ok": false, "error": "missing_params", "details": {}}
```

## 20. API reference

```text
chats.php                         GET
messages.php                      GET
send.php                          POST
poll.php                          GET
actions.php                       POST
notes.php                         GET/POST/DELETE
contacts.php                      POST
contact_search.php                GET
contacts_directory.php            GET
contacts_directory_refresh.php    POST
agenda.php                        POST
agent_inbox.php                   GET
chat_code.php                     GET
avatar.php                        GET
media.php                         GET
group_participants.php            GET
profile.php                       GET
quick_replies.php                 GET/POST/DELETE
schedule.php                      GET/POST/DELETE
ai_assistant.php                  POST
faq_search.php                    GET
faq_feedback.php                  POST
faq_feedback_summary.php          GET
unread_faq_review.php             GET
stickers.php                      GET
sticker_upload.php                POST
notification_sound.php            GET
shared_prompt_doc.php             GET
```

## 21. Data models

Chat:

```ts
{
  jid: string,
  connection_id: string,
  instance: string,
  name: string,
  push_name: string,
  name_source: "renamed" | "evolution" | "hub" | "jid",
  avatar: string | null,
  is_group: boolean,
  unread: number,
  last_message: string,
  last_message_at: string,
  last_from_me: boolean,
  last_message_type: string,
  last_message_duration: number,
  badge: string,
  chat_code: string,
  is_low_priority: boolean,
  _sort_ts: number,
  _updated_at: number
}
```

Message:

```ts
{
  msg_id: string,
  conversation_id: string,
  connection_id: string,
  direction: "inbound" | "outbound",
  from_me: boolean,
  sender_jid: string,
  sender_name: string,
  occurred_at: string,
  stored_at: string,
  message_type: string,
  message_text: string,
  media_url: string | null,
  media_mime: string | null,
  media_size: number | null,
  duration: number | null,
  transcription: string | null,
  quoted_msg_id: string | null,
  quoted_text: string | null,
  forwarded: boolean,
  edited_at: string | null,
  deleted_at: string | null,
  reactions: [{ emoji: string, jid: string, name: string }],
  status: "pending" | "sent" | "delivered" | "read" | "failed",
  note_author: string | null
}
```

Poll response:

```ts
{
  ok: true,
  changed_chats: [],
  new_messages: number,
  inline_messages: [],
  inline_notes: [],
  inline_reactions: [],
  server_ts: number,
  server_seq: number
}
```

## 22. MVP checklist

- Auth via scoped `X-API-Key`.
- `GET /api/me.php` on boot.
- Chat list with sort/filter/search.
- Inbox/Unread/Low/Todos and WA channel filter.
- Open chat and load history.
- Render text, image, video, audio/PTT, document, sticker, contact, location, system.
- Read receipts.
- Composer text, attach, emoji, audio record, send.
- Reply/quote.
- Drag and drop.
- Polling with backoff.
- Native macOS notifications.
- Mark as read.
- Global search.
- Dark mode.
- Multi-tenant.

## 23. Nice-to-have after MVP

- Internal notes.
- Quick replies.
- Forward.
- Transfer chat.
- Low priority toggle.
- Schedule message.
- Edit/delete/react.
- Mention autocomplete.
- Sticker picker.
- Group invite.
- Contact rename.
- Contacts tab.
- FAQ suggestions.
- AI panel.

## 24. Post-MVP

- Book meeting.
- Register Welcome lead.
- Agent inbox.
- FAQ feedback/review.
- Quick reply shortcuts.
- Custom sticker upload.
- Profile preview.
- Deeplinks.
- APNs push.

## 25. Implementation order

1. `ConversoxAPI` actor with X-API-Key, tenant routing and error mapping.
2. Polling task with cancellation and backoff.
3. Expand Codable models from the data models above.
4. `ChatStore` with filters/search/sort.
5. `MessageStore` per chat with lazy history and reverse pagination.
6. `MediaCache` for avatars/media.
7. Composer with text, attach and drag/drop.
8. Notifications and dock badge.
9. Visual parity components from `visual-design-system.md`.
