import SwiftUI

struct DetailPanelView: View {
    let chat: Chat
    var avatarURL: URL? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                statsGrid
                tagsSection
                assignedSection
                notesSection
                filesSection
                timelineSection
            }
        }
        .frame(width: 320)
        .background(CXColor.surface)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 0) {
            CXAvatarView(title: chat.title, size: 72, imageURL: avatarURL, online: true)
                .padding(.top, 24)

            Text(chat.title)
                .font(.system(size: 17, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(CXColor.text)
                .padding(.top, 12)
                .multilineTextAlignment(.center)

            if let secondary = phoneLabel ?? identifierLabel {
                Text(secondary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(CXColor.textMute)
                    .padding(.top, 3)
            }

            HStack(spacing: 6) {
                actionPill(icon: "phone.fill", label: "Ligar", style: .accent)
                actionPill(icon: "note.text", label: "Nota", style: .neutral)
                actionPill(icon: "ellipsis", label: nil, style: .neutral)
            }
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { divider }
    }

    private enum PillStyle { case accent, neutral }

    private func actionPill(icon: String, label: String?, style: PillStyle) -> some View {
        let bg: Color = style == .accent ? CXColor.accentBg : CXColor.surface2
        let fg: Color = style == .accent ? CXColor.accent : CXColor.text
        return HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            if let label {
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold))
            }
        }
        .foregroundStyle(fg)
        .padding(.horizontal, label == nil ? 10 : 12)
        .frame(height: 28)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: CXRadius.sm, style: .continuous))
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        HStack(spacing: 0) {
            statBox(title: "Valor", trailing: false) {
                Text("R$ 0")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(CXColor.text)
            }
            statBox(title: "Estágio", trailing: true) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(CXColor.accent)
                        .frame(width: 7, height: 7)
                    Text(stageLabel)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(CXColor.accent)
                }
            }
        }
        .overlay(alignment: .bottom) { divider }
    }

    private func statBox<Content: View>(title: String, trailing: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            microLabel(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .trailing) {
            if !trailing {
                Rectangle().fill(CXColor.borderLight).frame(width: 1)
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        section(title: "Tags", action: "Gerenciar") {
            FlowLayout(spacing: 6) {
                if let badge = chat.badge?.trimmingCharacters(in: .whitespacesAndNewlines), !badge.isEmpty {
                    CXTagPill(label: badge.capitalized)
                }
                CXTagPill(label: chat.resolvedChannel.rawValue.uppercased())
                addTagButton
            }
        }
    }

    private var addTagButton: some View {
        Text("+ adicionar")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(CXColor.textMute)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .overlay(
                Capsule().strokeBorder(CXColor.border, style: StrokeStyle(lineWidth: 1, dash: [3]))
            )
    }

    // MARK: - Assigned

    private var assignedSection: some View {
        section(title: "Atribuído a", action: "Trocar") {
            HStack(spacing: 10) {
                CXAvatarView(title: assigneeLabel, size: 32, ring: CXColor.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(assigneeLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CXColor.text)
                    Text("equipe " + (chat.instance ?? "Conversox"))
                        .font(.system(size: 11))
                        .foregroundStyle(CXColor.textMute)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        section(title: "Notas internas", action: "+ Nova") {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(CXColor.warning)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nenhuma nota interna ainda. Adicione um lembrete sobre este atendimento.")
                        .font(.system(size: 12))
                        .lineSpacing(2)
                        .foregroundStyle(CXColor.text)
                    HStack(spacing: 5) {
                        CXAvatarView(title: assigneeLabel, size: 14)
                        Text(assigneeLabel + " · agora")
                            .font(.system(size: 10.5))
                            .foregroundStyle(CXColor.textMute)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                Spacer(minLength: 0)
            }
            .background(CXColor.noteCardBg)
            .overlay(
                RoundedRectangle(cornerRadius: CXRadius.sm, style: .continuous)
                    .stroke(CXColor.noteCardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CXRadius.sm, style: .continuous))
        }
    }

    // MARK: - Files

    private var filesSection: some View {
        section(title: "Arquivos", action: "Ver tudo") {
            VStack(spacing: 0) {
                Text("Sem arquivos anexados.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(CXColor.textMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        section(title: "Timeline", action: nil) {
            VStack(alignment: .leading, spacing: 0) {
                timelineRow(label: "Conversa atualizada", time: relativeTime(chat.updatedAt), color: CXColor.accent, isLast: false)
                timelineRow(label: "Canal " + chat.resolvedChannel.rawValue.uppercased(), time: nil, color: Color.cxChannel(forConnectionID: chat.connectionID), isLast: true)
            }
        }
    }

    private func timelineRow(label: String, time: String?, color: Color, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack(alignment: .top) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(CXColor.borderLight)
                        .frame(width: 1)
                        .padding(.top, 14)
                }
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(CXColor.text)
                if let time {
                    Text(time)
                        .font(.system(size: 10.5))
                        .foregroundStyle(CXColor.textMute)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Section helper

    @ViewBuilder
    private func section<Content: View>(title: String, action: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                microLabel(title)
                Spacer()
                if let action {
                    Button(action: {}) {
                        Text(action)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CXColor.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { divider }
    }

    private func microLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(CXColor.textMute)
    }

    private var divider: some View {
        Rectangle()
            .fill(CXColor.borderLight)
            .frame(height: 1)
    }

    // MARK: - Helpers

    private var phoneLabel: String? {
        let digits = chat.jid.split(separator: "@").first.map(String.init) ?? ""
        guard digits.count >= 10, digits.allSatisfy(\.isNumber) else { return nil }
        let dd = digits.prefix(2)
        let rest = digits.dropFirst(2)
        if rest.count == 9 {
            let mid = rest.prefix(5)
            let tail = rest.dropFirst(5)
            return "+\(dd) \(mid)-\(tail)"
        }
        return "+\(digits)"
    }

    private var identifierLabel: String? {
        chat.jid.isEmpty ? nil : chat.jid
    }

    private var stageLabel: String {
        if chat.isLowPriority { return "Baixa prioridade" }
        if chat.unreadCount > 0 { return "Não lido" }
        return "Em atendimento"
    }

    private var assigneeLabel: String {
        let raw = chat.connectionID
            .replacingOccurrences(of: "evolution:", with: "")
            .replacingOccurrences(of: "telegram:", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "Atendente" }
        return raw.split(separator: " ").first.map { $0.capitalized } ?? "Atendente"
    }

    private func relativeTime(_ date: Date) -> String {
        guard date != .distantPast else { return "" }
        if Calendar.current.isDateInToday(date) {
            return "hoje " + date.formatted(.dateTime.hour().minute())
        }
        if Calendar.current.isDateInYesterday(date) {
            return "ontem"
        }
        return date.formatted(.dateTime.day().month())
    }
}

// MARK: - Flow layout for tag wrap

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > width, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth - spacing)
        return CGSize(width: min(maxRowWidth, width), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + width, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
