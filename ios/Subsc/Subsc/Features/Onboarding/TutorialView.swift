import SwiftUI

/// 初回起動時に出す全画面のチュートリアルです。
///
/// **どのページからでもスキップできます。** 飛ばせない案内は、
/// 早く使い始めたい人にとって邪魔でしかありません。
///
/// ## ページ送りに使う部品について（2026-08-08の失敗の記録）
///
/// **`ScrollView(.horizontal)` + `LazyHStack` + `containerRelativeFrame`
/// + `.scrollTargetBehavior(.paging)` の組み合わせを使ってはいけません。**
/// レイアウトが毎フレーム回り続け、**CPUが100%に張り付いて操作を受け付けなくなりました**。
/// 画面は最後のフレームを描いたままなので、見た目には固まったと分かりません。
/// ページの中身を最小構成にしても、`scrollPosition` を外しても再現しました。
///
/// `TabView(.page)` は固まりません。ただし**内部が `UIPageViewController` で、
/// 自分の枠を越えて中身を描きます**。そのため操作部（スキップ・ドット・ボタン）を
/// `VStack` で並べると、文字を大きくしたときに本文が重なって読めなくなります。
/// **`overlay` に載せると必ず上に描かれる**ので、不透明な地を敷けば確実に隠れます。
struct TutorialView: View {
    /// 最後まで見終わったときに呼ばれます。
    let onFinish: () -> Void
    /// 途中で切り上げたときに呼ばれます。**扱いは完走と同じです。**
    let onSkip: () -> Void

    @State private var selection = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pages: [TutorialPage] { TutorialPage.all }
    private var isLastPage: Bool { selection == pages.count - 1 }

    /// 操作部が隠す高さです。ページの中身にこのぶん余白を空け、
    /// 文字を大きくしても最後の行が操作部の下に埋もれたままにしません。
    private enum Inset {
        static let top: CGFloat = 56
        static let bottom: CGFloat = 140
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(pages) { page in
                TutorialPageView(
                    page: page,
                    // **猫は1ページ目にだけ座らせます。** 全ページに出すと、
                    // 猫が説明役として喋っているように読めてしまいます。
                    showsCat: page.id == 0,
                    topInset: Inset.top,
                    bottomInset: Inset.bottom
                )
                .tag(page.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // `reduceMotion` のときはページ送りを animate しません。
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
        .background(BlackCatPalette.background)
        .overlay(alignment: .top) { skipButton }
        .overlay(alignment: .bottom) { pageControls }
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
        // 帯を文字の高さぴったりにすると、スクロールした見出しがすぐ下に迫って
        // 窮屈に見えます。**少し厚みを持たせて間を作ります。**
        .padding(.bottom, BlackCatSpacing.m)
        .frame(maxWidth: .infinity)
        // 下を透かすと、スクロールした本文がこの行に重なって読めなくなります。
        .background(BlackCatPalette.background)
    }

    private var pageControls: some View {
        VStack(spacing: 0) {
            pageIndicator
            primaryButton
        }
        .frame(maxWidth: .infinity)
        .background(BlackCatPalette.background)
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
        .accessibilityElement()
        .accessibilityLabel("\(pages.count)ページ中\(selection + 1)ページ目")
    }

    private var primaryButton: some View {
        Button {
            if isLastPage {
                onFinish()
            } else {
                withAnimation(reduceMotion ? nil : .easeInOut) {
                    selection += 1
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
    /// 上下の操作部が隠す高さです。ここを余白として空けます。
    let topInset: CGFloat
    let bottomInset: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 絵の大きさです。文字を大きくしている利用者の画面では、
    /// **絵より文字に場所を譲ります。**
    private var artworkSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 96 : 160
    }

    var body: some View {
        // **高さを測って返す作りにしません**（`GeometryReader` で測った値を
        // `minHeight` へ戻すと、レイアウトが循環しうる）。
        // 素直に上から積み、収まらないぶんはスクロールで読ませます。
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
                // 見出しと本文はひと続きで読ませます。分けると、
                // 見出しだけ読んで本文が飛ばされます。
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, BlackCatSpacing.xl)
            .padding(.top, topInset + BlackCatSpacing.xxl)
            .padding(.bottom, bottomInset)
        }
        // 中身が収まっているときに跳ねると、スクロールできると誤解させます。
        .scrollBounceBehavior(.basedOnSize)
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
