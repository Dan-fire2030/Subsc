import SwiftUI

/// 費目別料金の棒グラフです。カード内は高さが限られるため上位数件だけを出し、
/// 残りは「ほかN件」から `ReportBreakdownSheet` で確認してもらいます。
struct GlassBarChart: View {
    let entries: [ReportEntry]
    let reduceMotion: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsAllEntries = false

    private var maximumAmount: Double {
        max(entries.map(\.amount).max() ?? 1, 1)
    }

    private var visibleEntryCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : 2
    }

    private var hiddenEntryCount: Int {
        max(0, entries.count - visibleEntryCount)
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(entries.prefix(visibleEntryCount)) { entry in
                GlassBarRow(
                    entry: entry,
                    maximumAmount: maximumAmount
                )
            }

            if hiddenEntryCount > 0 {
                Button {
                    showsAllEntries = true
                } label: {
                    HStack(spacing: 4) {
                        Text("ほか\(hiddenEntryCount)件")
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .modifier(CompactGlassCapsuleModifier())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("ほか\(hiddenEntryCount)件をすべて見る")
                .accessibilityHint("費目別料金の詳細を開きます")
            } else {
                Spacer(minLength: 0)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.38), value: entries)
        .sheet(isPresented: $showsAllEntries) {
            ReportBreakdownSheet(entries: entries)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .adaptiveSheetBackground()
        }
    }
}

private struct GlassBarRow: View {
    let entry: ReportEntry
    let maximumAmount: Double
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var fraction: Double {
        max(0.06, min(1, entry.amount / maximumAmount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))

            layout {
                Text(entry.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 6)
                }

                Text(
                    entry.amount,
                    format: .currency(code: "JPY").precision(.fractionLength(0))
                )
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.92))
                .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.11))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 0.6)
                        }

                    // 塗りだけは横方向のままにします。**伸びていく向きに意味がある**ためで、
                    // 縦のグラデーションにすると、どこまで伸びているかが読み取りにくくなります。
                    // 縁と光沢は他のスタイルと共通の素材を使います。
                    ReportChartGlassShape(
                        shape: Capsule(style: .continuous),
                        color: ColorHex.color(from: entry.colorHex),
                        glossHeight: 2,
                        glossInsetRatio: 0.06,
                        fillOverride: LinearGradient(
                            colors: [
                                ColorHex.color(from: entry.colorHex).opacity(0.96),
                                ColorHex.color(from: entry.colorHex).opacity(0.62),
                                .white.opacity(0.72)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                        .frame(width: proxy.size.width * fraction)
                        .shadow(
                            color: ReportChartGlass.shadowColor(
                                ColorHex.color(from: entry.colorHex)
                            ),
                            radius: 6,
                            y: 2
                        )
                }
            }
            .frame(height: 12)
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
    }
}
