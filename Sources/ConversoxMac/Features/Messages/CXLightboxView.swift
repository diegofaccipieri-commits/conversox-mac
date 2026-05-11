import SwiftUI
import AppKit

struct CXLightboxView: View {
    let url: URL
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            AuthedImage(
                url: url,
                contentMode: .fit,
                placeholder: {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                },
                fallback: {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                        Text("Não foi possível carregar a imagem.")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
            )
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(1, min(6, lastScale * value))
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= 1.02 {
                            withAnimation(.easeOut(duration: 0.18)) {
                                scale = 1
                                offset = .zero
                                lastOffset = .zero
                            }
                            lastScale = 1
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard scale > 1 else { return }
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    if scale > 1 {
                        scale = 1
                        offset = .zero
                        lastOffset = .zero
                        lastScale = 1
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                    .padding(.trailing, 14)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        copyToPasteboard()
                    } label: {
                        lightboxToolbarButton(symbol: "doc.on.doc", label: "Copiar")
                    }
                    .buttonStyle(.plain)

                    Button {
                        revealInFinder()
                    } label: {
                        lightboxToolbarButton(symbol: "arrow.down.circle", label: "Salvar")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 22)
            }
        }
        .focusable()
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .transition(.opacity)
    }

    private func lightboxToolbarButton(symbol: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
    }

    private func copyToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.absoluteString, forType: .string)
    }

    private func revealInFinder() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent.isEmpty ? "image.jpg" : url.lastPathComponent
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            Task {
                if let data = try? await URLSession.shared.data(from: url).0 {
                    try? data.write(to: dest, options: .atomic)
                }
            }
        }
    }
}
