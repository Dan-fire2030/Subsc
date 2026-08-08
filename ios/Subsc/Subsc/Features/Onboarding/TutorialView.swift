import SwiftUI

/// 初回起動時に出す全画面のチュートリアルです。
///
/// **どのページからでもスキップできます。** 飛ばせない案内は、
/// 早く使い始めたい人にとって邪魔でしかありません。
///
/// **高さを固定して中身を切り落とすことはしません。** レポートカードで同じことをして
/// 枠が切れる不具合を出しています（`.spec/KNOWLEDGE.md`）。
/// 文字を大きくしている利用者のために、ページの中はスクロールさせます。
///
/// **ページ送りは `TabView(.page)` を使いません。** あれは内部が `UIPageViewController` で、
/// **自分の枠を越えて中身を描きます**。文字を最大にすると本文がスキップ行と下のボタンに
/// 重なり、`clipped()` でも地を敷いても描画順を変えても直りませんでした。
/// 横スクロールのページングなら `ScrollView` が自分の枠で正しく断ちます。
struct TutorialView: View {
    /// 最後まで見終わったときに呼ばれます。
    let onFinish: () -> Void
    /// 途中で切り上げたときに呼ばれます。**扱いは完走と同じです。**
    let onSkip: () -> Void

    /// いま表示しているページです。`nil` はスクロール位置が未確定の状態です。
    @State private var scrolledPage: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var pages: [TutorialPage] { TutorialPage.all }
    private var selection: Int { scrolledPage ?? 0 }
    private var isLastPage: Bool { selection == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            skipButton

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages) { page in
                        TutorialPageView(
                            page: page,
                            // **猫は1ページ目にだけ座らせます。** 全ページに出すと、
                            // 猫が説明役として喋っているように読めてしまいます。
                            showsCat: page.id == 0
                        )
                        .containerRelativeFrame(.horizontal)
                        .id(page.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledPage)
            .scrollIndicators(.hidden)

            pageIndicator
            primaryButton
        }
        .background(BlackCatPalette.background)
        .interactiveDismissDisabled()
    }

    private var skipButton: some View {
        HStack {
            Spacer()
            Button("スキップ", action: onSkip)
                .font(BlackCatType.label)
                .foregroundStyle(BlackCatPalette.textMuted)
                // 見た目が小さくても、触れる大きさは指のサイズを守ります。
                .frame(minWidth: 44, minHeight: 44)
                .padding(.trailing, BlackCatSpacing.s)
        }
        .padding(.top, BlackCatSpacing.s)
        .frame(maxWidth: .infinity)
    }

    /// 現在位置です。**点だけで示します。** 「4分の2」と数字で出すと、
    /// 残りの枚数のほうが気になって内容が読まれません。
    private var pageIndicator: some View {
        HStack(spacing: BlackCatSpacing.s) {
            ForEach(pages) { page in
                Capsule()
                    .fill(
                        page.id == selection
                            ? BlackCatPalette.accent
                            : BlackCatPalette.chartTrack
                    )
                    .frame(width: page.id == selection ? 20 : 8, height: 8)
            }
        }
        .padding(.top, BlackCatSpacing.m)
        .padding(.bottom, BlackCatSpacing.l)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("\(pages.count)ページ中\(selection + 1)ページ目")
    }

    private var primaryButton: some View {
        Button {
            if isLastPage {
                onFinish()
            } else {
                withAnimation(reduceMotion ? nil : .easeInOut) {
                    scrolledPage = selection + 1
                }
            }
        } label: {
            Text(isLastPage ? "はじめる" : "次へ")
                .font(BlackCatType.body)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(BlackCatPalette.accent)
        .padding(.horizontal, BlackCatSpacing.xl)
        .padding(.bottom, BlackCatSpacing.xl)
    }
}

/// チュートリアルの1ページです。
private struct TutorialPageView: View {
    let page: TutorialPage
    let showsCat: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 絵の大きさです。文字を大きくしている利用者の画面では、
    /// **絵より文字に場所を譲ります。**
    private var artworkSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 96 : 160
    }

    var body: some View {
        // **`ScrollView` の中で `Spacer` は伸びません**（中身の高さで畳まれるため）。
        // 画面の高さを測って下限に与え、通常の文字サイズでは中央に、
        // 収まらないときだけスクロールさせます。
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: BlackCatSpacing.xl) {
                    artwork
                        .frame(width: artworkSize, height: artworkSize)

                    VStack(spacing: BlackCatSpacing.m) {
                        Text(page.title)
                            .font(BlackCatType.title)
                            .foregroundStyle(BlackCatPalette.text)

                        Text(page.body)
                            .font(.body)
                            .foregroundStyle(BlackCatPalette.textMuted)
                            .lineSpacing(4)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BlackCatSpacing.xl)
                    // 見出しと本文はひと続きで読ませます。分けると、
                    // 見出しだけ読んで本文が飛ばされます。
                    .accessibilityElement(children: .combine)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, BlackCatSpacing.xl)
                // **中身が画面より低いときだけ中央へ寄せます。**
                // 高いときは下限が効かず、そのままスクロールできます。
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if showsCat {
            // 案内の姿です。**この状態は既にあります**（費目0件のときと同じ姿勢）。
            CatCompanionView(mood: .guiding)
        } else {
            Image(systemName: page.systemImage)
                .resizable()
                .scaledToFit()
                .fontWeight(.light)
                .foregroundStyle(BlackCatPalette.accent)
                .padding(BlackCatSpacing.xl)
                .accessibilityHidden(true)
        }
    }
}

#Preview("ライト") {
    TutorialView(onFinish: {}, onSkip: {})
        .environment(\.colorScheme, .light)
}

#Preview("ダーク") {
    TutorialView(onFinish: {}, onSkip: {})
        .environment(\.colorScheme, .dark)
}
