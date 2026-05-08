import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var apiKey = ""
    @State private var authSource = AppConfig.shared.defaultAuthSource

    var body: some View {
        ZStack {
            CXColor.bg.ignoresSafeArea()
            RadialGradient(colors: [CXColor.accentBg.opacity(0.5), .clear], center: .topLeading, startRadius: 40, endRadius: 520)
                .ignoresSafeArea()
            RadialGradient(colors: [CXColor.waGreen.opacity(0.12), .clear], center: .topTrailing, startRadius: 40, endRadius: 520)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: CXSize.s4) {
                Text("ConversoxMac")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(CXColor.text)

                Text("Conecte usando a X-API-Key do Conversox")
                    .font(.system(size: 13))
                    .foregroundStyle(CXColor.textMute)

                VStack(alignment: .leading, spacing: CXSize.s2) {
                    Text("X-API-Key")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CXColor.textSoft)

                    SecureField("Cole a chave de acesso", text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(CXColor.text)
                        .padding(.horizontal, CXSize.s3)
                        .frame(height: 38)
                        .background(CXColor.input)
                        .clipShape(RoundedRectangle(cornerRadius: CXSize.rMd, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: CXSize.rMd, style: .continuous).stroke(CXColor.borderLight, lineWidth: 1))
                }

                Picker("Tenant", selection: $authSource) {
                    Text("Imigrando").tag("imigrando")
                    Text("Welcome").tag("welcome")
                }
                .pickerStyle(.segmented)
                .tint(CXColor.accent)

                Button {
                    Task { await sessionStore.signIn(apiKey: apiKey, authSource: authSource) }
                } label: {
                    HStack {
                        Spacer()
                        Text("Entrar")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .frame(height: 38)
                    .background(
                        LinearGradient(colors: [CXColor.accent, CXColor.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let lastError = sessionStore.lastError {
                    Text(lastError)
                        .foregroundStyle(CXColor.danger)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(CXSize.s6)
            .frame(width: 440)
            .cxShellPanel()
        }
        .preferredColorScheme(.dark)
    }
}
