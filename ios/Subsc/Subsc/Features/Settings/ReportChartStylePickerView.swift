import SwiftUI

/// レポートカードのグラフの表示方法を選ぶ画面です。
///
/// 文字だけでは違いが伝わらないため、**選択肢そのものを縮小した実物で見せます**。
/// 選んだ瞬間にカードへ反映されるので、保存ボタンは置きません。
struct ReportChartStylePickerView: View {
    @Environment(ThemeStore.self) private var theme

    private enum Layout {
        static let previewHeight: CGFloat = 74
        static let previewCornerRadius: CGFloat = 14
        static let rowSpacing: CGFloat = 10
    }

    var body: some View {
        List {
            ForEach(ReportChartStyle.allCases) { style in
                Section {
                    Button {
                        theme.chartStyle = style
                    } label: {
                        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                            header(for: style)
                            preview(for: style)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(style.title)
                    .accessibilityValue(style.summary)
                    .accessibilityAddTraits(theme.chartStyle == style ? .isSelected : [])
                }
                .glassListRow()
            }
        }
        .liquidGlassScreen()
        .navigationTitle("グラフの表示")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(for style: ReportChartStyle) -> some View {
        HStack(spacing: 8) {
            Image(systemName: style.systemImage)
                .font(.callout)
                .foregroundStyle(ThemeStore.fixedButtonColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(style.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(style.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if theme.chartStyle == style {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(ThemeStore.fixedButtonColor)
                    .accessibilityHidden(true)
            }
        }
    }

    /// カードと同じ下地の上に描き、実際の見え方に近づけます。
    private func preview(for style: ReportChartStyle) -> some View {
        ChartStyleThumbnail(style: style, colors: BlackCatPalette.Category.fallbackOrder)
            .frame(height: Layout.previewHeight)
            .frame(maxWidth: .infinity)
            .background {
                // **本物のグラフと同じ「沈む面」の上に描きます（2026-08-06）。**
                // テーマ色のグラデーションで塗っていた頃は、見本と実物の地の色が違い、
                // 選んだあとに「思っていたのと違う」が起きていました。
                RoundedRectangle(cornerRadius: Layout.previewCornerRadius, style: .continuous)
                    .fill(BlackCatPalette.surfaceElevated)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: Layout.previewCornerRadius, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

/// 実データを使わない見本です。設定画面では「どんな形か」だけ伝われば十分で、
/// 実データを引くとこの画面が費目の有無に左右されてしまいます。
private struct ChartStyleThumbnail: View {
    let style: ReportChartStyle
    let colors: [Color]

    /// 見本の1切れです。**割合と色を1つの値にまとめてあります。**
    ///
    /// 以前は割合の配列（4件）と色の配列（`CostType.allCases` 由来で5件）が別々で、
    /// 割合の添字で色を引いていました。**費目種別を4件未満に減らすと範囲外アクセスで落ちます。**
    /// 一緒に持てば、片方だけ増減させようがありません。
    private struct Slice {
        let fraction: Double
        let color: Color
    }

    private enum Sample {
        /// 色は費目種別ではなくパレットから直に取ります。見本は「どんな形か」を
        /// 伝えるためのもので、特定の費目種別を表しているわけではありません。
        static let slices: [Slice] = [
            Slice(fraction: 0.46, color: BlackCatPalette.Category.watch),
            Slice(fraction: 0.26, color: BlackCatPalette.Category.listen),
            Slice(fraction: 0.18, color: BlackCatPalette.Category.read),
            Slice(fraction: 0.10, color: BlackCatPalette.Category.work)
        ]

        /// バブルだけは大きさと位置を1つずつ決めるので、その並びも一緒に持ちます。
        /// `zip` で組むため、どちらかが短ければ短いほうに合わせて止まります。
        static let bubbleGeometry: [(diameter: CGFloat, x: CGFloat, y: CGFloat)] = [
            (40, -26, 0),
            (28, 10, -10),
            (20, 32, 14),
            (13, 6, 20)
        ]
    }

    var body: some View {
        Group {
            switch style {
            case .bar: bar
            case .ring: ring
            case .bubble: bubble
            case .column: column
            }
        }
        .padding(12)
    }

    private var bar: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(Array(Sample.slices.enumerated()), id: \.offset) { _, slice in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(slice.color)
                        .frame(width: proxy.size.width * slice.fraction - 2)
                }
            }
            .frame(height: 22)
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private var ring: some View {
        ZStack {
            ForEach(Array(Sample.slices.enumerated()), id: \.offset) { index, slice in
                let inset = CGFloat(index) * 9
                Circle()
                    .trim(from: 0, to: slice.fraction)
                    .stroke(slice.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
            }
        }
        .frame(width: 50, height: 50)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var bubble: some View {
        ZStack {
            ForEach(Array(zip(Sample.slices, Sample.bubbleGeometry).enumerated()), id: \.offset) { _, pair in
                let (slice, geometry) = pair
                Circle()
                    .fill(slice.color)
                    .frame(width: geometry.diameter, height: geometry.diameter)
                    .offset(x: geometry.x, y: geometry.y)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var column: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(Sample.slices.enumerated()), id: \.offset) { _, slice in
                Capsule(style: .continuous)
                    .fill(slice.color)
                    .frame(width: 12, height: 46 * slice.fraction + 8)
            }
            Capsule(style: .continuous)
                .fill(BlackCatPalette.chartTrack)
                .frame(width: 12, height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
