# ConversoxMac Visual Design System

Fonte: spec visual extraida de `assets/conversox/v5/conversox-v5.css` e `Conversox/v6.php`.

O app Mac deve seguir o visual dark-first do Conversox web, mas usando controles nativos SwiftUI/AppKit onde isso melhorar ergonomia no macOS.

## Decisoes visuais principais

- Aparencia inicial: dark-first, equivalente ao web em `<html class="dark">`.
- Tipografia: SF Pro para UI nativa; Manrope fica opcional para branding/header.
- Layout: split view desktop-first com sidebar, chat principal e futuro painel direito.
- Sidebar: largura alvo 300-380pt, filtros em pills, lista densa de chats.
- Main: header compacto, area de mensagens com wallpaper/tint, composer fixo no rodape.
- Bubbles: incoming alinhado a esquerda, outgoing alinhado a direita, radius 14pt com canto emissor em 4pt quando possivel.
- Accent: azul Conversox (`#3b82f6` dark / `#2563eb` light).
- Semantics: WhatsApp green `#25d366`, success `#10b981`, warning `#f59e0b`, danger `#ef4444`, read check `#38bdf8`.

## Tokens Swift sugeridos

Criar `ConversoxTokens.swift` antes da remodelagem visual:

```swift
enum CXColor {
    static let bg = Color("cx.bg")
    static let surface = Color("cx.surface")
    static let surface2 = Color("cx.surface2")
    static let border = Color("cx.border")
    static let text = Color("cx.text")
    static let textSoft = Color("cx.text.soft")
    static let textMute = Color("cx.text.mute")
    static let accent = Color("cx.accent")
    static let accentBg = Color("cx.accent.bg")
    static let bubbleIn = Color("cx.bubble.in")
    static let bubbleOutStart = Color("cx.bubble.out.start")
    static let bubbleOutEnd = Color("cx.bubble.out.end")
    static let success = Color("cx.success")
    static let warning = Color("cx.warning")
    static let danger = Color("cx.danger")
    static let checkRead = Color("cx.check.read")
}

enum CXSize {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let rMd: CGFloat = 10
    static let rLg: CGFloat = 14
    static let shellRadius: CGFloat = 24
}
```

## Componentes visuais a criar

- `CXAvatarView`: imagem remota + fallback por iniciais.
- `CXBadgeView`: unread, connection, channel e low-priority badges.
- `CXFilterPill`: filtros Inbox/Unread/Low/Todos.
- `CXIconButton`: botoes de header/composer com SF Symbols.
- `CXChatRowView`: linha de chat densa com avatar, nome, tempo, preview, badge e connection.
- `CXMessageBubbleView`: bubble in/out/note/pending/failed/deleted.
- `CXComposerView`: input, attach, emoji/audio/QR e send button em gradiente.
- `CXToastCenter`: toasts bottom-right.

## Primeiro corte visual recomendado

1. Tokens + cores dark/light.
2. Sidebar remodelada com `CXChatRowView`.
3. Bubbles e area de mensagens.
4. Composer.
5. Header actions.
6. Wallpaper/pattern e toasts.

## Fora do primeiro corte

- AI panel completo.
- Sticker picker completo.
- Modais avancados de transfer/register-welcome.
- Audio recorder/waveform.
- Snapshot visual comparativo.
