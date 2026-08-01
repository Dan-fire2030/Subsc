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
        ChartStyleThumbnail(style: style, colors: theme.cardGradientColors)
            .frame(height: Layout.previewHeight)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: Layout.previewCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: theme.cardGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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

    private enum Sample {
        static let fractions: [Double] = [0.46, 0.26, 0.18, 0.10]
        static let colorHexes = CostType.allCases.map(\.colorHex)
    }

    private var sampleColors: [Color] {
        Sample.colorHexes.map(ColorHex.color(from:))
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
                ForEach(Array(Sample.fractions.enumerated()), id: \.offset) { index, fraction in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(sampleColors[index])
                        .frame(width: proxy.size.width * fraction - 2)
                }
            }
            .frame(height: 22)
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private var ring: some View {
        ZStack {
            ForEach(Array(Sample.fractions.enumerated()), id: \.offset) { index, fraction in
                let inset = CGFloat(index) * 9
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(sampleColors[index], style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
            }
        }
        .frame(width: 50, height: 50)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var bubble: some View {
        ZStack {
            Circle().fill(sampleColors[0]).frame(width: 40, height: 40).offset(x: -26)
            Circle().fill(sampleColors[1]).frame(width: 28, height: 28).offset(x: 10, y: -10)
            Circle().fill(sampleColors[2]).frame(width: 20, height: 20).offset(x: 32, y: 14)
            Circle().fill(sampleColors[3]).frame(width: 13, height: 13).offset(x: 6, y: 20)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var column: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(Sample.fractions.enumerated()), id: \.offset) { index, fraction in
                Capsule(style: .continuous)
                    .fill(sampleColors[index])
                    .frame(width: 12, height: 46 * fraction + 8)
            }
            Capsule(style: .continuous)
                .fill(.white.opacity(0.35))
                .frame(width: 12, height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
