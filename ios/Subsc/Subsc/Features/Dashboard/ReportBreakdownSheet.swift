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
                // **黒猫のパレットで敷きます（2026-08-11）。**
                // ここは青・紫・青緑を直に書いており、**リデザインで唯一取り残されていました**。
                // 段の作り（3色の斜めグラデーション）はそのままに、色の出どころだけを揃えています。
                LinearGradient(
                    colors: [
                        BlackCatPalette.accent.opacity(0.32),
                        BlackCatPalette.background,
                        BlackCatPalette.surfaceElevated
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
                                .foregroundStyle(BlackCatPalette.textMuted)
                            Text(
                                total,
                                format: .currency(code: "JPY").precision(.fractionLength(0))
                            )
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(BlackCatPalette.text)
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
                                .stroke(BlackCatPalette.border, lineWidth: 0.8)
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
                        .foregroundStyle(BlackCatPalette.text)
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
                        // **グラフ本体と同じ寄せ方を通します（2026-08-11）。**
                        // ここだけ保存値で描いていたため、同じ費目がグラフと内訳で
                        // 違う色に見えていました。段の作りは変えていません。
                        colors: ReportChartPalette.breakdownSwatchColors(for: entry.colorHex),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BlackCatPalette.border, lineWidth: 0.7)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(entry.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(BlackCatPalette.text)
                        .lineLimit(1)

                    if entry.isEstimated {
                        // 実績が未入力で、直近の実績から見込んだ額であることを示します。
                        Text("見込み")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(BlackCatPalette.surfaceElevated, in: Capsule())
                            .foregroundStyle(BlackCatPalette.text)
                    }
                }

                Text(
                    ratio,
                    format: .percent.precision(.fractionLength(1))
                )
                .font(.caption)
                .foregroundStyle(BlackCatPalette.textMuted)
            }

            Spacer(minLength: 8)

            Text(
                entry.amount,
                format: .currency(code: "JPY").precision(.fractionLength(0))
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(BlackCatPalette.text)
            .monospacedDigit()
        }
        .padding(13)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BlackCatPalette.border, lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
    }
}
