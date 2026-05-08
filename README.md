# ConversoxMac

App macOS nativo (SwiftUI) para Conversox com autenticação via `X-API-Key`, inbox de chats, envio de mensagens e long-polling em `poll.php`.

## Rodar local

```bash
cd /Users/diegofaccipieri/conversox-mac
swift run ConversoxMac
```

## Gerar app assinado

O release segue o mesmo padrão local do DictationApp: gera o projeto Xcode, faz build Release, assina com o certificado `DictationApp Dev`, cria o zip e instala em `/Applications`.

```bash
cd /Users/diegofaccipieri/conversox-mac
./scripts/release.sh 0.1.0
```

Artefatos gerados:

- `/Applications/ConversoxMac.app`
- `/Users/diegofaccipieri/conversox-mac/ConversoxMac_v0.1.0.zip`

## Variáveis de ambiente

- `CONVERSOX_SERVER_BASE_URL` (default: `https://app.imigrando.com`)
- `CONVERSOX_AUTH_SOURCE` (default: `imigrando`; use `welcome` para o tenant Welcome)

## Status

Este projeto usa diretamente os endpoints atuais do servidor:

- `GET /Conversox/api/chats.php`
- `GET /Conversox/api/messages.php`
- `POST /Conversox/api/send.php`
- `POST /Conversox/api/actions.php`
- `GET /Conversox/api/poll.php`

Ainda falta no servidor criar `GET /api/me.php` e API keys escopadas por usuario. Enquanto `/api/me.php` nao existe, o app valida a chave carregando `chats.php` e usa perfil local `api@system`.

Checklist detalhado para coletar no servidor: `docs/o-que-buscar-no-servidor.md`.

Indice das specs do projeto: `docs/spec-index.md`.

Spec funcional completa: `docs/functional-spec.md`.

Contratos HTTP detalhados: `docs/endpoint-contracts.md`.

Cobertura atual contra as specs: `docs/spec-coverage.md`.
