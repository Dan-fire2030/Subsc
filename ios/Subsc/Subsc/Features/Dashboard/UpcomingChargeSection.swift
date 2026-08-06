import SwiftUI

/// 先の月に来る大きな支払いを予告する行です。
///
/// 年払いは更新月にだけ全額が立つため、その月の合計だけ跳ね上がります。
/// **月をめくって初めて気づく状態にしないため**、ここで先に出しておきます。
/// 該当が無ければ何も描きません（通常の月は静かなままにします）。
struct UpcomingChargeSection: View {
    let notices: [UpcomingChargeNotice]

    var body: some View {
        if !notices.isEmpty {
            Section("この先の大きな支払い") {
                ForEach(notices) { notice in
                    row(for: notice)
                }
            }
        }
    }

    private func row(for notice: UpcomingChargeNotice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(BlackCatPalette.accent)
                .frame(width: 36, height: 36)
                .background(
                    BlackCatPalette.accent.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(notice.month)月に年払いが\(notice.names.count)件")
                    .font(.subheadline.weight(.semibold))
                // 名前を並べます。多いときは先頭2件だけにして、行の高さを保ちます。
                Text(summary(for: notice))
                    .font(.caption)
                    .foregroundStyle(BlackCatPalette.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(notice.total, format: .currency(code: "JPY").precision(.fractionLength(0)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private func summary(for notice: UpcomingChargeNotice) -> String {
        let shown = notice.names.prefix(2).joined(separator: "、")
        let rest = notice.names.count - min(2, notice.names.count)
        return rest > 0 ? "\(shown) ほか\(rest)件" : shown
    }
}
