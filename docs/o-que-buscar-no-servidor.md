# O que buscar no servidor para conectar o ConversoxMac

Este documento lista as informações que precisamos coletar no servidor para ligar o app macOS `ConversoxMac` ao sistema/Conversox real.

Nao envie senhas, chaves privadas, secrets ou tokens reais de producao. Quando precisar mostrar payloads, substitua valores sensiveis por `REDACTED`.

## 1. Informacoes gerais do servidor

Preencher:

```text
URL producao:
URL homologacao/dev, se existir:
Sistema operacional/stack:
Local do codigo do Conversox:
Local do codigo de login/autenticacao:
Como o front web atual acessa o Conversox:
```

Buscar no servidor:

```bash
pwd
ls -la
find . -maxdepth 3 -type f \( -name "*.php" -o -name "*.js" -o -name "*.ts" -o -name "*.env*" -o -name "*.conf" -o -name "*.nginx" \) | head -200
```

Se houver repositorio git:

```bash
git remote -v
git branch --show-current
git status --short
```

## 2. Autenticacao e SSO

Precisamos saber como o usuario autenticado no sistema ganha acesso ao Conversox.

Preencher:

```text
O sistema usa OAuth/OIDC/SAML/session cookie/JWT/proprio?
Endpoint de login atual:
Endpoint de logout atual:
Existe refresh token?
Tempo de expiracao da sessao/token:
Como validar usuario logado:
Como obter dados do usuario logado:
```

Se ja existir OAuth/OIDC, preencher:

```text
Authorize URL:
Token URL:
Refresh URL:
Revoke/logout URL:
Client ID para desktop:
Redirect URI permitido para o app: conversoxmac://oauth/callback
Scopes necessarios:
Token request usa JSON ou application/x-www-form-urlencoded?
```

Exemplo de resposta esperada, com valores sanitizados:

```json
{
  "access_token": "REDACTED",
  "refresh_token": "REDACTED",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

Buscar no codigo:

```bash
rg -n "oauth|authorize|token|refresh|revoke|logout|login|session|jwt|cookie|OIDC|SAML" .
rg -n "Authorization|Bearer|X-API-Key|setcookie|session_start|access_token|refresh_token" .
```

## 3. Endpoint do usuario logado

O app precisa de um endpoint tipo `GET /me`.

Preencher:

```text
Endpoint real:
Metodo:
Headers obrigatorios:
Formato de autenticacao:
Roles/permissoes retornadas:
Tenant/empresa retornado:
```

Exemplo de resposta sanitizada:

```json
{
  "id": "123",
  "name": "Nome Usuario",
  "email": "usuario@example.com",
  "tenant": "imigrando",
  "roles": ["admin"]
}
```

Buscar no codigo:

```bash
rg -n "current_user|me|profile|user_id|usuario|permiss|role|tenant|empresa" .
```

## 4. APIs de chats/conversas

Precisamos mapear como listar conversas no Conversox.

Preencher:

```text
Endpoint para listar chats:
Metodo:
Headers:
Query params:
Paginacao:
Filtro por empresa/instancia:
Campo de ID da conversa:
Campo de titulo/nome:
Campo de contador de nao lidas:
Campo de ultima mensagem:
Campo de data de atualizacao:
```

Exemplo de resposta sanitizada:

```json
{
  "chats": [
    {
      "id": "chat_123",
      "title": "Cliente Exemplo",
      "unread_count": 2,
      "last_message_preview": "Ola",
      "updated_at": "2026-05-07T20:00:00Z"
    }
  ],
  "next_cursor": "REDACTED"
}
```

Buscar no codigo:

```bash
rg -n "chat|conversation|conversa|inbox|unread|nao_lid|last_message|messages.php|agent_inbox" .
```

## 5. APIs de mensagens

Precisamos mapear historico, envio, anexos e leitura.

Preencher:

```text
Endpoint para listar mensagens de um chat:
Endpoint para enviar texto:
Endpoint para upload/enviar anexo:
Endpoint para marcar como lida:
Metodo de cada endpoint:
Headers obrigatorios:
Campos obrigatorios no body:
Formato de data:
Limite de tamanho de arquivo:
Tipos de arquivo permitidos:
```

Exemplo de mensagem sanitizada:

```json
{
  "id": "msg_123",
  "chat_id": "chat_123",
  "sender_name": "Cliente Exemplo",
  "text": "Ola",
  "sent_at": "2026-05-07T20:00:00Z",
  "direction": "inbound",
  "status": "delivered"
}
```

Exemplo de envio esperado:

```json
{
  "text": "Mensagem enviada pelo app Mac"
}
```

Buscar no codigo:

```bash
rg -n "send|message|mensagem|upload|attachment|anexo|media|read|delivered|jid|chat_code|instance" .
```

## 6. Realtime: WebSocket, SSE ou polling

Para funcionar como WhatsApp/Telegram, precisamos receber eventos novos sem depender apenas de refresh manual.

Preencher:

```text
Existe WebSocket/SSE hoje?
URL do realtime:
Metodo de autenticacao:
Formato dos eventos:
Eventos de nova mensagem:
Eventos de contador nao lido:
Eventos de typing/presenca, se existirem:
Politica recomendada de reconnect:
Fallback se realtime cair:
```

Exemplo de evento sanitizado:

```json
{
  "type": "message.new",
  "payload": {
    "message": {
      "id": "msg_123",
      "chat_id": "chat_123",
      "sender_name": "Cliente Exemplo",
      "text": "Ola",
      "sent_at": "2026-05-07T20:00:00Z"
    }
  }
}
```

Buscar no codigo:

```bash
rg -n "websocket|ws://|wss://|EventSource|SSE|poll|longpoll|socket|pusher|redis|pubsub|typing|presence" .
```

## 7. Instancias, empresas e permissoes

Hoje existem instancias/escopos como Imigrando e Welcome. Precisamos saber como isso e representado no servidor.

Preencher:

```text
Lista de instancias/empresas:
Como o usuario e vinculado a uma instancia:
Como o chat e vinculado a uma instancia:
Campo usado para instance/scope:
Usuarios podem ver mais de uma instancia?
O app Mac deve iniciar em qual instancia por padrao?
```

Buscar no codigo:

```bash
rg -n "instance|scope|tenant|empresa|company|welcome|imigrando|welcomeca|main" .
```

## 8. Headers, CORS e rate limit

Preencher:

```text
Header de autenticacao usado:
Headers obrigatorios adicionais:
Rate limit por usuario/IP:
Timeout recomendado:
CORS atual, se relevante:
```

Buscar no codigo/config:

```bash
rg -n "CORS|Access-Control|rate|limit|timeout|Authorization|X-API-Key|headers" .
```

## 9. Ambiente de teste

Precisamos de uma conta segura para validar o app sem afetar cliente real.

Preencher:

```text
Ambiente para teste:
Usuario de teste:
Tenant/empresa de teste:
Chat de teste:
Pode enviar mensagem real nesse chat? sim/nao
Pode testar anexo? sim/nao
```

Nao colocar senha neste arquivo. A senha/token deve ser entregue por canal seguro.

## 10. Se nao existir API pronta para desktop

Se o servidor nao tiver esses endpoints, criar/adaptar esta API minima:

```text
GET  /oauth/authorize
POST /oauth/token
POST /oauth/refresh
POST /oauth/revoke
GET  /me
GET  /chats
GET  /chats/{id}/messages
POST /chats/{id}/messages
POST /chats/{id}/attachments
PATCH /chats/{id}/read
GET  /realtime ou WSS /ws
```

Formato minimo esperado pelo app hoje:

```json
{
  "chats": [
    {
      "id": "chat_123",
      "title": "Cliente Exemplo",
      "unread_count": 0,
      "last_message_preview": "Ultima mensagem",
      "updated_at": "2026-05-07T20:00:00Z"
    }
  ],
  "next_cursor": null
}
```

```json
{
  "messages": [
    {
      "id": "msg_123",
      "chat_id": "chat_123",
      "sender_name": "Cliente Exemplo",
      "text": "Ola",
      "sent_at": "2026-05-07T20:00:00Z"
    }
  ],
  "next_cursor": null
}
```

## 11. Arquivos finais para me devolver

Depois de coletar no servidor, me entregue:

```text
1. Este arquivo preenchido.
2. Exemplos sanitizados de requests/responses.
3. Caminhos dos arquivos do servidor onde ficam login, Conversox, envio de mensagem e realtime.
4. Confirmacao se existe OAuth/SSO ou se precisamos criar.
5. URL de homologacao ou ambiente seguro de teste.
```
