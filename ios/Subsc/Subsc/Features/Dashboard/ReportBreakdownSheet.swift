import SwiftUI

/// 費目別料金の詳細を全件表示するシートです。
/// カード上のグラフは上位数件しか出さないため、残りをここで確認できるようにしています。
struct ReportBreakdownSheet: View {
    let entries: [ReportEntry]
    @Environment(\.dismiss) private var dismiss

    private var total: Double {
        entries.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.34, blue: 0.82),
                        Color(red: 0.25, green: 0.15, blue: 0.68),
                        Color(red: 0.03, green: 0.52, blue: 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("合計")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.72))
                            Text(
                                total,
                                format: .currency(code: "JPY").precision(.fractionLength(0))
                            )
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.38), lineWidth: 0.8)
                        }

                        ForEach(entries) { entry in
                            BreakdownRow(
                                entry: entry,
                                total: total
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("費目別料金")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .adaptiveNavigationBar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct BreakdownRow: View {
    let entry: ReportEntry
    let total: Double

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return entry.amount / total
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorHex.color(from: entry.colorHex),
                            ColorHex.color(from: entry.colorHex).opacity(0.55),
                            .white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.48), lineWidth: 0.7)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if entry.isEstimated {
                        // 実績が未入力で、直近の実績から見込んだ額であることを示します。
                        Text("見込み")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.white.opacity(0.22), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }

                Text(
                    ratio,
                    format: .percent.precision(.fractionLength(1))
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 8)

            Text(
                entry.amount,
                format: .currency(code: "JPY").precision(.fractionLength(0))
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .monospacedDigit()
        }
        .padding(13)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
    }
}
