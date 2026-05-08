# Conversox Server Implementation Plan

Plano para preparar o backend Conversox para o ConversoxMac com autenticacao segura por API key escopada, bootstrap de usuario, ACL correta por usuario e suporte multi-tenant.

## Objetivo

Entregar a parte de servidor necessaria para o app macOS operar com seguranca e sem escalar privilegios:

- `GET /api/me.php` funcional.
- API keys escopadas por usuario.
- `_boot.php` diferenciando chave `system` de chave `scoped`.
- ACL/restricted users aplicados a todos os endpoints Conversox.
- Tenant `imigrando|welcome` respeitado via header.
- Smoke tests/cURL para validar os fluxos do app Mac.

## 1. Criar `GET /api/me.php`

Implementar endpoint em producao:

```text
GET /api/me.php
Auth: PHP session ou X-API-Key
CSRF: n/a
```

Resposta esperada:

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

Erros obrigatorios:

- `401 not_authenticated`: sem sessao/chave valida.
- `403 not_authorized`: usuario autenticado sem permissao para Conversox.

Regras:

- Com sessao, usar usuario real da sessao PHP.
- Com `X-API-Key` scoped, usar usuario real vinculado a chave.
- Com `X-API-Key` system, preservar compatibilidade legada, mas identificar `auth_via = "api_key"`.
- Retornar `connections` ja filtradas pela ACL final usada pelos endpoints Conversox.

## 2. Implementar API Key Escopada Por Usuario

Manter compatibilidade com chaves existentes, mas adicionar suporte a chaves scoped.

Campos necessarios na tabela/camada de API keys:

```text
id
user_id
key_name
api_key_hash
scope
scope_connections
is_active
expires_at
last_used_at
revoked_at
created_at
updated_at
```

Semantica:

- `scope = "system"`: comportamento legado/superadmin controlado.
- `scope = "scoped"`: herda usuario real e limita connections.
- `scope_connections`: lista JSON de `connection_id`s permitidas por aquela chave.
- `api_key_hash`: SHA-256 da chave em texto puro.
- `revoked_at != null` ou `is_active = 0`: chave invalida.
- `expires_at < now`: chave invalida.

Regra de permissao para chave scoped:

```text
effective_connections = intersection(
  conversox_acl_user_connections(user.email),
  api_key.scope_connections
)
```

Regras de seguranca:

- Chave scoped nunca pode virar superadmin automaticamente.
- Chave scoped sem usuario valido deve retornar `401 not_authenticated`.
- Chave scoped sem connections efetivas deve autenticar o usuario, mas deixar endpoints Conversox retornarem vazio ou `403`, conforme endpoint.
- Atualizar `last_used_at` apenas depois da chave ser validada.

## 3. Ajustar `Conversox/api/_boot.php`

Centralizar a identidade resolvida para todos os endpoints Conversox.

Campos internos esperados:

```text
auth_via = session | api_key
api_key_type = system | scoped | null
current_user
current_user_email
current_user_role
current_company_id
auth_source = imigrando | welcome
isMasterSuperadmin
userConnections
userRestricted
```

Comportamento:

- Sessao: manter comportamento atual.
- API key system: preservar comportamento legado, incluindo acesso amplo quando ja previsto.
- API key scoped: carregar usuario real, role real, company real e aplicar ACL final.
- Restricted users continuam limitados a conversas atribuidas.
- Todos os endpoints devem consumir a mesma identidade resolvida pelo boot.

Erros literais a preservar:

- `forbidden_connection`
- `access_denied_connection`
- `forbidden_not_assigned`
- `not_authenticated`
- `not_authorized`

## 4. Multi-Tenant

Aceitar header:

```text
X-Conversox-Auth-Source: imigrando | welcome
```

Regras:

- Default: `imigrando`.
- Validar apenas `imigrando` ou `welcome`; valor invalido cai para default ou retorna erro padronizado.
- `imigrando` usa `/Conversox/api`.
- `welcome` usa `/Welcome/Conversox/api`.
- ACL, permissions, avatar paths e actions Welcome-only devem respeitar o tenant.
- `register_welcome_lead` fora de `welcome` deve retornar `403 welcome_only`.

## 5. ACL e Restricted Users

Fonte de verdade:

```text
conversox_acl_user_connections(email)
Conversox/data/connection_acl.json
v4_load_assigned_conversations(email)
```

Regras:

- Usuario sem ACL nao ve nenhuma connection.
- Master superadmin continua vendo todas, apenas quando definido pelo servidor.
- Usuario restricted so ve conversas atribuidas.
- Chave scoped nao pode ignorar restricted assignment.
- `chats.php`, `messages.php`, `poll.php`, `send.php`, `actions.php`, `media.php` e `avatar.php` devem aplicar a mesma decisao de permissao.

## 6. Validar Endpoints Criticos Para O Mac

Validar com chave scoped:

- `GET /api/me.php`
- `GET /Conversox/api/chats.php`
- `GET /Conversox/api/messages.php`
- `GET /Conversox/api/poll.php`
- `POST /Conversox/api/send.php`
- `POST /Conversox/api/actions.php?action=mark_read`
- `POST /Conversox/api/actions.php?action=mark_unread`
- `POST /Conversox/api/actions.php?action=fetch_media`
- `GET /Conversox/api/avatar.php`
- `GET /Conversox/api/media.php`

Validar tambem os mesmos endpoints no prefixo Welcome quando aplicavel:

- `/Welcome/Conversox/api/...`

## 7. Smoke Tests / cURL

Criar comandos ou script de smoke cobrindo:

- chave scoped normal;
- chave scoped restricted;
- chave system;
- tenant `imigrando`;
- tenant `welcome`;
- usuario sem ACL;
- connection proibida;
- `/api/me.php`;
- listar chats;
- abrir mensagens;
- enviar texto para chat de teste;
- mark read;
- polling com `since_ts`;
- fetch media.

Exemplo base:

```bash
curl -sS \
  -H "X-API-Key: $CONVERSOX_API_KEY" \
  -H "X-Conversox-Auth-Source: imigrando" \
  https://app.imigrando.com/api/me.php
```

## 8. Rollout

Sequencia recomendada:

1. Criar migracao/alteracao da tabela de API keys sem remover comportamento existente.
2. Implementar validacao scoped em caminho paralelo.
3. Implementar `/api/me.php`.
4. Atualizar `_boot.php` para usar identidade resolvida.
5. Rodar smoke tests com chave system para garantir compatibilidade.
6. Criar chave scoped para usuario de teste.
7. Rodar smoke tests com usuario normal e restricted.
8. Validar tenant Welcome.
9. Liberar chave scoped para o app Mac.

## Criterios De Aceite

- `/api/me.php` funciona com sessao e API key.
- API key scoped herda permissoes reais do usuario.
- API key scoped nao escala privilegio.
- Chave system existente continua funcionando.
- Endpoints principais do Mac funcionam com `X-API-Key`.
- Tenant Welcome funciona sem quebrar Imigrando.
- Erros literais batem com `docs/endpoint-contracts.md`.
- Usuario restricted nao consegue acessar conversa nao atribuida.
- Smoke tests documentados passam em producao ou ambiente de teste.
