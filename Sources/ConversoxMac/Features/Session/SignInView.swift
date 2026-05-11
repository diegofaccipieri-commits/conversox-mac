import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var theme = CXTheme.shared
    @State private var apiKey = ""
    @State private var authSource = AppConfig.shared.defaultAuthSource
    @State private var showKey = false

    var body: some View {
        ZStack {
            // Body bg: radial sutil como o web
            LinearGradient(
                colors: [CXColor.surface3.opacity(0.6), CXColor.bg, CXColor.accentBg.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(colors: [CXColor.accentBg.opacity(0.45), .clear], center: .topLeading, startRadius: 40, endRadius: 520)
                .ignoresSafeArea()
            RadialGradient(colors: [CXColor.waGreen.opacity(0.10), .clear], center: .topTrailing, startRadius: 40, endRadius: 520)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: CXSize.s4) {
                header

                VStack(alignment: .leading, spacing: 6) {
                    Text("X-API-Key")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CXColor.textSoft)

                    HStack(spacing: 0) {
                        Group {
                            if showKey {
                                TextField("Cole a chave de acesso", text: $apiKey)
                            } else {
                                SecureField("Cole a chave de acesso", text: $apiKey)
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(CXColor.text)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CXColor.textMute)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, CXSize.s3)
                    .frame(height: 38)
                    .background(CXColor.input)
                    .clipShape(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                            .stroke(CXColor.inputBorder, lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tenant")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CXColor.textSoft)

                    Picker("", selection: $authSource) {
                        Text("Imigrando").tag("imigrando")
                        Text("Welcome").tag("welcome")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Button {
                    Task { await sessionStore.signIn(apiKey: apiKey, authSource: authSource) }
                } label: {
                    HStack {
                        Spacer()
                        Text("Entrar")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .frame(height: 40)
                    .background(CXGradient.accentButton)
                    .clipShape(RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let lastError = sessionStore.lastError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(lastError)
                    }
                    .foregroundStyle(CXColor.danger)
                    .font(.system(size: 12, weight: .medium))
                }

                Divider().overlay(CXColor.border).padding(.vertical, 4)

                HStack {
                    Text("Tema")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CXColor.textSoft)
                    Picker("", selection: $theme.mode) {
                        ForEach(CXTheme.Mode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .padding(CXSize.s6)
            .frame(width: 440)
            .background(CXColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CXRadius.shell, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CXRadius.shell, style: .continuous)
                    .stroke(CXColor.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 44, x: 0, y: 24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CXGradient.accentButton)
                        .frame(width: 36, height: 36)
                    Image(systemName: "message.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("ConversoxMac")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(CXColor.text)
            }

            Text("Conecte usando a X-API-Key do Conversox")
                .font(.system(size: 13))
                .foregroundStyle(CXColor.textMute)
        }
    }
}
