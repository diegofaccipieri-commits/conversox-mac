# Server Discovery Pack - Conversox Mac

Preencha este documento com os dados do servidor para concluir integração de produção.

## 1) SSO / OAuth

- Authorize URL:
- Token URL:
- Revoke URL:
- Client ID para desktop:
- Redirect URI permitido:
- Scopes obrigatórios:
- Exemplo de `token response`:

## 2) Sessão e usuário

- Endpoint `GET /me` (path real):
- Payload de resposta:
- Regras de tenant/empresa/role:

## 3) Chats

- Endpoint listagem de chats:
- Query params (cursor, filtros, limite):
- Exemplo de resposta:

## 4) Mensagens

- Endpoint histórico de mensagens por chat:
- Endpoint envio de texto:
- Endpoint upload/anexo:
- Limites de tamanho e MIME:
- Status suportados (sent/delivered/read):

## 5) Realtime

- URL WebSocket/SSE:
- Método de autenticação no realtime:
- Formato dos eventos:
- Tipos de eventos suportados:
- Política de reconnect recomendada:

## 6) Push / Badge

- Fonte da verdade de unread count:
- Regras de badge:
- Regras de notificação silenciosa:

## 7) Segurança e observabilidade

- Rate limits por endpoint:
- Correlation ID header:
- Requisitos de auditoria:
- Ambientes disponíveis (dev/stage/prod):
