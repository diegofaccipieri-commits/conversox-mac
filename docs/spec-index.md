# ConversoxMac Spec Index

Specs carregadas:

- `docs/o-que-buscar-no-servidor.md`: checklist usado para discovery no servidor.
- `docs/backend-integration-notes.md`: contratos reais ja adotados pelo app.
- `docs/visual-design-system.md`: referencia visual web -> macOS.
- `docs/functional-spec.md`: spec funcional completa web -> macOS.
- `docs/functional-specs-needed.md`: gaps ainda pendentes ou que precisam de confirmacao exata.

Status atual:

- Backend MVP: parcialmente implementado no app via `X-API-Key`, `chats.php`, `messages.php`, `send.php`, `actions.php`, `poll.php`.
- Visual parity: ainda nao implementada; existe apenas referencia.
- Functional parity: especificada; implementacao ainda parcial.

Proximo marco recomendado:

1. Implementar tokens visuais e primeiros componentes (`CXChatRowView`, `CXMessageBubbleView`, `CXComposerView`).
2. Criar `ConversoxAPI` actor tipado e mover os endpoints atuais para essa camada.
3. Implementar chat filters/search + polling com backoff antes de portar funcionalidades secundarias.
