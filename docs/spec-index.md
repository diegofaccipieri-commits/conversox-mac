# ConversoxMac Spec Index

Specs carregadas:

- `docs/o-que-buscar-no-servidor.md`: checklist usado para discovery no servidor.
- `docs/backend-integration-notes.md`: contratos reais ja adotados pelo app.
- `docs/visual-design-system.md`: referencia visual web -> macOS.
- `docs/functional-spec.md`: spec funcional completa web -> macOS.
- `docs/endpoint-contracts.md`: contratos HTTP detalhados por endpoint.
- `docs/spec-coverage.md`: cobertura atual da implementacao contra as specs.
- `docs/functional-specs-needed.md`: gaps ainda pendentes ou que precisam de confirmacao exata.

Status atual:

- Backend MVP: parcialmente implementado no app via `X-API-Key`, `chats.php`, `messages.php`, `send.php`, `actions.php`, `poll.php`.
- Visual parity: parcialmente implementada na shell/sidebar/bubbles/composer.
- Functional parity: especificada; implementacao ainda parcial.

Proximo marco recomendado:

1. Criar `ConversoxAPI` actor tipado e mover os endpoints atuais para essa camada.
2. Implementar error mapper literal usando `docs/endpoint-contracts.md`.
3. Implementar polling com backoff/dedup antes de portar funcionalidades secundarias.
