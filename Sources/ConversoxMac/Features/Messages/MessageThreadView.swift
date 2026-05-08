import SwiftUI

struct MessageThreadView: View {
    @EnvironmentObject private var vm: ChatsViewModel

    let chatID: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                CXColor.bg
                RadialGradient(colors: [CXColor.accentBg.opacity(0.42), .clear], center: .topLeading, startRadius: 80, endRadius: 520)
                RadialGradient(colors: [CXColor.waGreen.opacity(0.12), .clear], center: .topTrailing, startRadius: 80, endRadius: 520)

                ScrollView {
                    LazyVStack(spacing: CXSize.s2) {
                        dateSeparator("Hoje")

                        ForEach(vm.messagesByChat[chatID] ?? []) { message in
                            CXMessageBubbleView(message: message)
                        }
                    }
                    .padding(CXSize.s4)
                    .padding(.top, CXSize.s2)
                }
            }

            Divider().overlay(CXColor.border)

            composer
        }
        .background(CXColor.bg)
        .task(id: chatID) {
            await vm.loadMessages(for: chatID)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: CXSize.s2) {
            CXIconButton(systemName: "paperclip") {}
            CXIconButton(systemName: "face.smiling") {}

            TextField("Digite uma mensagem", text: $vm.draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(CXColor.text)
                .lineLimit(1...6)
                .padding(.horizontal, CXSize.s3)
                .padding(.vertical, 9)
                .background(CXColor.input)
                .clipShape(RoundedRectangle(cornerRadius: CXSize.rLg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CXSize.rLg, style: .continuous)
                        .stroke(CXColor.borderLight, lineWidth: 1)
                )

            Button {
                Task { await vm.sendMessage() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        LinearGradient(colors: [CXColor.accent, CXColor.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: CXColor.accent.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(vm.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(CXSize.s3)
        .background(CXColor.composer)
    }

    private func dateSeparator(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(CXColor.textMute)
            .padding(.horizontal, CXSize.s3)
            .frame(height: 24)
            .background(CXColor.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(CXColor.borderLight, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
    }
}

struct CXMessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.fromMe { Spacer(minLength: 80) }

            VStack(alignment: .leading, spacing: 5) {
                if !message.fromMe {
                    Text(message.senderName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CXColor.accent)
                }

                Text(message.text.isEmpty ? mediaPlaceholder : message.text)
                    .font(.system(size: 14))
                    .lineSpacing(2)
                    .foregroundStyle(message.fromMe ? CXColor.bubbleOutText : CXColor.bubbleInText)
                    .textSelection(.enabled)

                HStack(spacing: 5) {
                    Spacer(minLength: 4)
                    Text(message.sentAt == .distantPast ? "" : message.sentAt.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle((message.fromMe ? CXColor.bubbleOutText : CXColor.textMute).opacity(0.72))
                    if message.fromMe {
                        Image(systemName: message.status == "read" ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(message.status == "read" ? CXColor.checkRead : CXColor.textMute)
                    }
                }
            }
            .padding(.horizontal, CXSize.s3)
            .padding(.vertical, CXSize.s2)
            .frame(maxWidth: 720, alignment: .leading)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: CXSize.rLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CXSize.rLg, style: .continuous)
                    .stroke(message.fromMe ? CXColor.accent.opacity(0.35) : CXColor.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)

            if !message.fromMe { Spacer(minLength: 80) }
        }
        .frame(maxWidth: .infinity)
    }

    private var bubbleBackground: some View {
        Group {
            if message.fromMe {
                LinearGradient(colors: [CXColor.bubbleOutStart, CXColor.bubbleOutEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                CXColor.bubbleIn
            }
        }
    }

    private var mediaPlaceholder: String {
        switch message.type {
        case "image": return "[imagem]"
        case "audio", "ptt": return "[audio]"
        case "video": return "[video]"
        case "document": return "[documento]"
        case "sticker": return "[sticker]"
        default: return ""
        }
    }
}
