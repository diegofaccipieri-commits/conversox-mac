# ConversoxMac Implementation Plan

Plano para completar a paridade do ConversoxMac com o Conversox web, mantendo app nativo SwiftUI, contratos HTTP tipados, release assinado e milestones testaveis.

## Objetivo

Completar o app macOS com:

- rede tipada e segura;
- auth via `X-API-Key` scoped;
- sidebar, filtros e polling robustos;
- mensagens, midia, composer completo e acoes;
- contatos, notes, quick replies, stickers, schedule, agenda;
- Welcome, AI, FAQ, agent inbox e deeplinks;
- paridade visual com a spec web;
- release assinado e zip compartilhavel.

## 1. Base Tecnica

Criar `ConversoxAPI` actor como unica camada de rede.

Responsabilidades:

- resolver paths por tenant;
- injetar `X-API-Key`;
- injetar `X-Conversox-Auth-Source`;
- suportar JSON GET/POST;
- suportar multipart upload;
- suportar download binario;
- expor headers de resposta quando necessario;
- aplicar timeouts por endpoint;
- mapear erros literais do backend.

Path resolver:

```text
imigrando -> /Conversox/api
welcome   -> /Welcome/Conversox/api
/api/me.php fica fora do prefixo Conversox
```

Criar `ConversoxError`:

```text
httpStatus
backendError
rawBody
userMessage
recommendedAction
```

Mapear obrigatoriamente:

- `not_authenticated`
- `not_authorized`
- `access_denied_connection`
- `forbidden_connection`
- `forbidden_not_assigned`
- `csrf_token_invalid`
- `file_too_large`
- `file_too_large_for_php`
- `media_expired_not_cached`
- `send_failed`
- `ai_service_unreachable`

## 2. Modelos Swift

Expandir os modelos para cobrir `docs/endpoint-contracts.md`.

Modelos principais:

- `Chat`
- `Message`
- `QuotedMessage`
- `Reaction`
- `MediaAsset`
- `Contact`
- `QuickReply`
- `Sticker`
- `Schedule`
- `AgendaPerson`
- `UserProfile`
- `PollResponse`

Campos obrigatorios em `Message`:

```text
id
keyID
type
body
fromMe
timestamp
status
senderName
quoted
mediaURL
thumbnail
fileName
mimeType
ptt
duration
isDeleted
transcription
transcriptionStatus
sharedContacts
reactions
connectionID
```

Regras:

- Decoding deve aceitar campos legados e novos.
- Datas podem vir como Unix seconds ou ISO-8601, dependendo do endpoint.
- `transcription` standalone nao deve virar mensagem duplicada.

## 3. Stores

Separar estado por responsabilidade:

- `SessionStore`: login, logout, restore, `/api/me.php`.
- `ChatStore`: lista, filtros, selected chat, unread total, polling merge.
- `MessageStore`: mensagens por chat, paginacao, dedup, reactions.
- `ComposerStore`: draft, reply target, anexos, note mode, signature.
- `MediaStore`: avatar, midia, cache, fetch media.
- `ToastStore`: success, error, info, retry.

Regras:

- Stores devem ser testaveis sem UI.
- UI nao deve chamar `HTTPClient` direto.
- `ChatStore` e `MessageStore` devem deduplicar por `id` e `keyID`.

## 4. Sidebar E Realtime

Completar filtros:

- `Inbox`: nao-low-priority e nao-arquivados.
- `Unread`: `unread > 0`.
- `Low`: `is_low_priority = true`.
- `Todos`: tudo.

Completar channel filters:

- `TD`
- `WA`
- `IG`
- `TG`
- `EM`
- `SM`

Regra:

- `WA` ativo de fato.
- Outros canais ficam como placeholders/desabilitados ate backend ter dados.

Tabs:

- `Chats`
- `Contatos`
- `Fila` para admin/superadmin.

Polling:

```text
GET poll.php?since_ts=<server_ts>&active_jid=...&active_connection_id=...
```

Regras:

- intervalo base: 3s;
- cursor: `since_ts = ultimo server_ts`;
- backoff para `403/429/503`: `15s -> 30s -> 60s -> 120s`;
- reset de backoff no primeiro `200`;
- merge de `changed_chats`;
- merge de `inline_messages`;
- merge de `inline_reactions`;
- dedup por `id/keyID`.

Notificacoes:

- atualizar Dock badge com unread total;
- notificar se app estiver em background;
- notificar se chat ativo for diferente;
- nao notificar se o chat ativo ja estiver aberto;
- tocar som via `notification_sound.php`.

## 5. Mensagens E Historico

Usar:

```text
GET messages.php?jid=...&connection_id=...&limit=50
GET messages.php?jid=...&connection_id=...&before_ts=...
GET messages.php?jid=...&connection_id=...&after_ts=...
GET messages.php?jid=...&connection_id=...&cache_sort_ts=...
```

Implementar:

- paginacao reversa;
- preservacao de posicao no scroll;
- date separators;
- auto-scroll quando perto do bottom;
- botao de voltar ao bottom com contador;
- highlight ao clicar em quote.

Renderizar tipos:

- `text`
- `image`
- `video`
- `gif`
- `audio`
- `ptt`
- `document`
- `sticker`
- `contact`
- `location`
- `system`
- `note`

Estados:

- `pending`
- `sent`
- `delivered`
- `read`
- `failed`
- `deleted`
- `edited`
- `forwarded`

Reactions:

- renderizar cluster abaixo da bubble;
- aplicar updates vindos de `inline_reactions`;
- permitir adicionar/remover via `actions.php?action=react`.

## 6. Midia, Avatar E Cache

Implementar `MediaStore`.

Avatar:

- usar `avatar.php?jid=...&conn=...`;
- cache local 24h;
- fallback para iniciais.

Midia:

- usar `media.php`;
- cache local 7d;
- suportar streaming/range quando aplicavel;
- fallback para `actions.php?action=fetch_media` quando `media_url = "fetch:enc"`.

UX:

- `410 media_expired_not_cached`: mostrar "midia expirada".
- `502 media_download_failed`: permitir retry.
- mostrar placeholder durante download.

Audio player:

- estados `idle`, `loading`, `playing`, `paused`, `ended`, `error`;
- velocidade `1x`, `1.5x`, `2x`;
- mostrar duracao;
- mostrar transcricao quando disponivel.

## 7. Composer E Envio

Substituir input atual por composer completo.

Funcionalidades:

- autosize;
- `Enter` envia;
- `Shift+Enter` quebra linha;
- draft salvo por chat;
- signature por chat;
- reply preview;
- note mode;
- attach via `NSOpenPanel`;
- paste de imagem;
- drag and drop;
- upload multipart;
- limite 16MB;
- retry em falha.

Enviar:

```text
POST send.php
Content-Type: application/json ou multipart/form-data
```

Payloads:

- texto simples;
- anexo;
- reply;
- mention;
- signature;
- note.

Erros com UX especifica:

- `413 file_too_large`
- `413 file_too_large_for_php`
- `403 forbidden_not_assigned`
- `403 forbidden_connection`
- `502 send_failed`

## 8. Acoes Do Header E Context Menu

Header actions:

- copy link;
- group invite;
- transfer chat;
- low priority;
- AI assistant;
- internal notes;
- schedule;
- book meeting;
- register Welcome;
- mark read;
- mark unread.

Context menu de mensagem:

- reply;
- forward;
- react;
- edit;
- delete for me;
- delete for everyone;
- retry failed;
- save sticker.

Criacao:

- create contact;
- create group;
- fetch group invite.

## 9. Contatos, Notes, Quick Replies, Stickers E Schedule

Contatos:

- `contacts_directory.php`
- `contact_search.php`
- `contacts_directory_refresh.php`
- `contacts.php`
- `profile.php`

Notes:

- `notes.php` GET/POST/DELETE;
- bubble amarela;
- autor da nota;
- composer em modo note.

Quick replies:

- `quick_replies.php` GET/POST/DELETE;
- CRUD;
- popup;
- busca;
- expansao por `/atalho`.

Stickers:

- `stickers.php`;
- `sticker_upload.php`;
- packs;
- favoritos;
- envio;
- upload;
- salvar sticker recebido;
- deletar custom.

Schedule:

- `schedule.php` list/create/cancel;
- modal com data, hora, timezone e mensagem.

Agenda:

- `agenda.php` list/search/find/by_chat;
- set_primary;
- link;
- set_name;
- hide;
- rebuild.

## 10. Welcome, AI, FAQ, Agent Inbox E Deeplinks

Welcome:

- `register_welcome_lead`;
- visivel apenas no tenant `welcome`;
- tratar `welcome_only`, `individual_chat_required`, `lead_code_required`, `lead_not_found`.

AI:

- `ai_assistant.php`;
- resumo;
- sugestao de resposta;
- historico por chat;
- fallback quando servico offline.

FAQ:

- `faq_search.php`;
- `faq_feedback.php`;
- `faq_feedback_summary.php`;
- `unread_faq_review.php`;
- chips de sugestao acima do composer;
- fila de review.

Agent inbox:

- `agent_inbox.php`;
- visivel para admin/superadmin;
- modes default, history e search.

Deeplinks:

- registrar `conversox://chat/<code>`;
- manter compatibilidade temporaria com `conversoxmac://`;
- resolver via `chat_code.php`.

## 11. Paridade Visual

Completar conforme `docs/visual-design-system.md`.

Itens pendentes:

- tokens light/dark completos;
- wallpaper/pattern;
- skeleton loading;
- toasts;
- drop overlay;
- top progress bar;
- modais;
- popovers;
- AI panel;
- estados hover/active/disabled;
- bubble tails;
- visual de midia;
- visual de audio;
- visual de documento;
- visual de sticker;
- visual de notes;
- badge `ConversoxMac vX.Y.Z` vindo do bundle.

## 12. Ordem Recomendada

1. Base tecnica: `ConversoxAPI`, error mapper, tenant router.
2. Modelos e stores.
3. Integracao com `/api/me.php` e API key scoped.
4. Sidebar, filtros e polling robusto.
5. Mensagens, midia e historico.
6. Composer e envio completo.
7. Header actions e context menu.
8. Contacts, notes, quick replies, stickers, schedule.
9. Welcome, AI, FAQ, agent inbox e deeplinks.
10. Visual parity final.
11. Release, bump, assinatura e commit.

## 13. Test Plan

Unit tests:

- decoding dos modelos principais;
- `TenantRouter`;
- `ConversoxError`;
- query/body generation;
- poll merge;
- dedup;
- filtros;
- backoff.

Integration tests com `URLProtocol` mock:

- `200`;
- `400`;
- `401`;
- `403`;
- `404`;
- `410`;
- `413`;
- `422`;
- `429`;
- `500`;
- `502`;
- `503`.

Smoke real:

- login com chave scoped;
- carregar `/api/me.php`;
- carregar chats;
- abrir conversa;
- enviar texto;
- enviar anexo;
- receber poll;
- mark read;
- carregar midia;
- reproduzir audio;
- usar quick reply;
- enviar sticker;
- criar note;
- criar schedule.

## 14. Release Gate Por Milestone

Para cada milestone:

```bash
swift build
swift test
```

Se mudou app:

```bash
./scripts/release.sh <nova-versao>
open /Applications/ConversoxMac.app
```

Tambem:

- atualizar `docs/spec-coverage.md`;
- fazer commit separado;
- criar tag se for release compartilhavel.

## Criterios De Aceite

- Login com chave scoped funciona.
- `/api/me.php` carrega usuario, role, tenant e connections.
- Lista de chats carrega e filtra corretamente.
- Polling recebe novas mensagens sem duplicar.
- Abrir chat carrega historico e pagina historico antigo.
- Envio de texto, anexo e reply funciona.
- Mark read/unread funciona.
- Midia, avatar e audio funcionam com cache.
- Notificacoes nativas funcionam.
- Notes, quick replies, stickers e schedule funcionam.
- Tenant `welcome` funciona sem quebrar `imigrando`.
- App assinado abre em `/Applications`.
- `swift build`, `swift test` e release script passam.
