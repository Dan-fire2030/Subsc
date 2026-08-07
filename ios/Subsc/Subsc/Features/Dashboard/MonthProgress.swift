import Foundation
import SwiftUI

/// 月のどこまで進んだかです。
///
/// **合計だけでは、多いか少ないかを判断できません。** 月初の ¥88,586 と月末の ¥88,586 は
/// 意味が違うためで、合計の下に「どこまで進んだ月なのか」を添えます。
enum MonthProgress {
    /// 進み具合（0...1）と、今日を含めない残り日数を返します。
    ///
    /// **月の長さは月ごとに違う**ので、30日で決め打ちせずカレンダーへ問い合わせます。
    static func current(now: Date = .now, calendar: Calendar = .current) -> (fraction: Double, remainingDays: Int)? {
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return nil }
        let lastDay = range.upperBound - 1
        let today = calendar.component(.day, from: now)
        guard lastDay > 0 else { return nil }
        return (Double(today) / Double(lastDay), max(0, lastDay - today))
    }
}

/// 月の進み具合を示す細い線です。
///
/// **目盛りを持ちません。** 正確な日付は「これから出ていく」の並びで分かるので、
/// ここは「月のどのあたりか」だけを伝えれば足ります。
struct MonthProgressLine: View {
    let progress: Double
    let remainingDays: Int
    /// 線の下に出す日付です。
    ///
    /// **`Date.now` を直接読みません（2026-08-08に修正）。** 進み具合は
    /// `MonthProgress.current(now:)` が注入された時刻から出しているのに、
    /// ここだけ実時刻を読むと、線の位置と日付が別々の瞬間を指しえます。
    let date: Date

    private let height: CGFloat = 3

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(BlackCatPalette.chartTrack)
                    Capsule()
                        .fill(BlackCatPalette.textMuted.opacity(0.55))
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: height)

            HStack {
                Text(date, format: .dateTime.month().day())
                Spacer()
                Text("残り\(remainingDays)日")
                    .monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(BlackCatPalette.textMuted)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今月は残り\(remainingDays)日です")
    }
}
