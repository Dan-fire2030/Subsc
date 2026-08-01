import SwiftUI

/// レポートカードの外枠です。iOS 26 では `glassEffect` を使い、
/// それ以前は同系色のグラデーション＋縁取りでフォールバックします。
struct ReportCardSurfaceModifier: ViewModifier {
    @Environment(ThemeStore.self) private var theme

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background {
                    LiquidGlassCardBackground()
                        .opacity(0.82)
                }
                .glassEffect(
                    .regular.tint(theme.cardBaseColor.opacity(0.18)),
                    in: .rect(cornerRadius: 24)
                )
                .shadow(color: theme.cardBaseColor.opacity(0.2), radius: 20, y: 9)
        } else {
            content
                .background {
                    LiquidGlassCardBackground()
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.72), .white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                }
                .shadow(color: theme.cardBaseColor.opacity(0.22), radius: 22, y: 10)
        }
    }
}

/// レポートカード内の操作ボタン（前後の期間・今期間へ戻る）の見た目です。
struct ReportControlButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
        } else {
            content
                .buttonStyle(.plain)
                .background(.black.opacity(0.16), in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.32), lineWidth: 0.7)
                }
        }
    }
}

/// 小さめのカプセル背景です。ボタンスタイルではなくラベルへ直接当てるので、
/// 見た目を小さく保ったまま外側で44ptのタップ領域を確保できます。
struct CompactGlassCapsuleModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.black.opacity(0.16), in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.32), lineWidth: 0.7)
                }
        }
    }
}

private struct LiquidGlassCardBackground: View {
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.cardBaseColor,
                    theme.cardHighlightColor,
                    theme.cardAccentColor
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(theme.cardAccentColor.opacity(0.52))
                .frame(width: 190, height: 190)
                .blur(radius: 42)
                .offset(x: 130, y: -145)

            Circle()
                .fill(theme.cardHighlightColor.opacity(0.4))
                .frame(width: 170, height: 170)
                .blur(radius: 46)
                .offset(x: -140, y: 150)

            LinearGradient(
                colors: [.black.opacity(0.02), .black.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
