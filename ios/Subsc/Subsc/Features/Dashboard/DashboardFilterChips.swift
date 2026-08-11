import SwiftUI

/// 一覧の状態の絞り込みを、**横に流れるチップの列**で出します。
///
/// **セグメントをやめた理由（2026-08-11）。** 「アーカイブ」を足して5段になった時点で、
/// 1段あたり約75ptしか無く**「アーカ…」と省略されました**。段が増えるたびに同じことが起きます。
/// チップなら6つ・7つに増えても壊れません。
///
/// ## 横スクロールの構成について
///
/// **`LazyHStack` + `containerRelativeFrame` + `.scrollTargetBehavior(.paging)` の
/// 組み合わせは使っていません。** その組み合わせはレイアウトが毎フレーム回り続け、
/// CPUが100%に張り付きます（2026-08-08にチュートリアルで踏んだ。`.spec/KNOWLEDGE.md`）。
/// ここは**素の `HStack` を5個並べるだけ**で、遅延読み込みもページ送りも使いません。
struct DashboardFilterChips: View {
    @Binding var selection: SubscriptionFilter

    /// 右端で溶かす幅の割合です。**溶け始めが早すぎると、選択中のチップまで薄く見えます。**
    private let fadeStart = 0.88

    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    /// **実際に画面からはみ出しているか。**
    ///
    /// 既定の文字サイズでは5つが幅に収まり、**スクロールしません**。
    /// それでもフェードを出すと「先がある」と嘘をつくことになるため、
    /// **はみ出しているときだけ**溶かします。文字を大きくしたときや段が増えたときに効きます。
    private var overflows: Bool { contentWidth > viewportWidth + 1 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BlackCatSpacing.s) {
                    ForEach(SubscriptionFilter.allCases) { filter in
                        chip(filter).id(filter)
                    }
                }
                .padding(.vertical, 2)
                .background(widthReader { contentWidth = $0 })
            }
            .background(widthReader { viewportWidth = $0 })
            // **右端を背景へ溶かして「まだ先がある」ことを示します。**
            // 動きで伝える案（開いた瞬間に少し弾む）は採りませんでした。
            // 見ていない瞬間に終わると、その回は何も伝わらないためです。
            // 溶けているだけなら、**止まっている状態でも伝わり続けます。**
            .mask {
                if overflows {
                    fadeMask
                } else {
                    Rectangle()
                }
            }
            .onChange(of: selection) { _, newValue in
                // 選んだチップが端で見切れたままにならないよう、中央へ寄せます。
                withAnimation(.snappy(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    /// 幅を測って伝えます。`GeometryReader` を背景へ敷き、レイアウトに影響させません。
    private func widthReader(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { onChange(proxy.size.width) }
                .onChange(of: proxy.size.width) { _, newValue in onChange(newValue) }
        }
    }

    private func chip(_ filter: SubscriptionFilter) -> some View {
        let isSelected = filter == selection

        return Button {
            selection = filter
        } label: {
            Text(filter.rawValue)
                .font(BlackCatType.label)
                .foregroundStyle(isSelected ? BlackCatPalette.text : BlackCatPalette.textMuted)
                .padding(.horizontal, BlackCatSpacing.m)
                .padding(.vertical, BlackCatSpacing.s)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                                ? BlackCatPalette.accent.opacity(0.18)
                                : BlackCatPalette.surface
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            isSelected ? BlackCatPalette.accent : BlackCatPalette.border,
                            lineWidth: isSelected ? 1.2 : 0.7
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    /// 右端だけを透過させる覆いです。左端は溶かしません（**先頭が欠けて見えるため**）。
    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: fadeStart),
                .init(color: .black.opacity(0), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
