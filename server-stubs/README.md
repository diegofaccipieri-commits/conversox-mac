# Server stubs

Estes arquivos nao devem ser copiados cegamente para producao. Eles sao pontos de partida para implementar os gaps levantados no discovery.

## `api/me.php`

Objetivo:

- Retornar usuario logado para o app Mac.
- Aceitar sessao PHP existente ou `X-API-Key`.
- Retornar ACL efetiva do Conversox.

Pendencia principal:

- Resolver `X-API-Key` para um usuario real e aplicar a ACL desse usuario, em vez de promover toda chave a `superadmin`.
