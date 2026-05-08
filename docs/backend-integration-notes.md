# Backend integration notes

O ConversoxMac agora usa o backend real descoberto em `/var/www/imigrando`.

## Auth

- Header principal: `X-API-Key`
- Tenant/header: `X-Conversox-Auth-Source: imigrando | welcome`
- OAuth/OIDC nao e usado.
- O app tenta `GET /api/me.php` ao entrar. Se o endpoint ainda nao existir e retornar 404, valida a chave com `GET /Conversox/api/chats.php`.

## Endpoints consumidos pelo app

```text
GET  /api/me.php                         futuro, recomendado
GET  /Conversox/api/chats.php
GET  /Conversox/api/messages.php
POST /Conversox/api/send.php
POST /Conversox/api/actions.php
GET  /Conversox/api/poll.php
```

## Gaps de servidor para MVP seguro

1. Criar `GET /api/me.php` retornando usuario, role, tenant e connections.
2. Criar API key escopada por usuario, herdando a ACL de `connection_acl.json`.
3. Criar usuario/instancia Evolution de teste para evitar envio real em cliente.
4. Manter push/APNs para pos-MVP; o app usa polling de 3s hoje.

## Payload minimo de /api/me.php

```json
{
  "ok": true,
  "user": {
    "id": 7,
    "email": "user@example.com",
    "name": "User Name",
    "role": "admin",
    "company_id": "1",
    "auth_source": "imigrando",
    "session_remaining_seconds": 14400
  },
  "conversox": {
    "restricted": false,
    "connections": ["evolution:main", "evolution:canada"]
  }
}
```
