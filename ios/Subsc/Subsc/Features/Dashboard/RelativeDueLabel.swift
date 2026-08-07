import Foundation

/// 期日までの近さを、日付ではなく「あと何日か」で表します。
///
/// **ビューから切り出してあります（2026-08-08）。** もとは `UpcomingTimelineRow` の中で
/// `Calendar.current` と `.now` を直接読んでおり、境目が実行日で変わるのにテストできませんでした。
///
/// 行動に効くのは何月何日かではなく、あと何日かなので、日付そのものは出しません。
enum RelativeDueLabel {
    /// 期日が無いときは空文字を返し、行に余計な語を足しません。
    static func text(for dueDate: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let dueDate else { return "" }

        // **時刻ではなく日付の差で数えます。** 23時に見る「明日の0時」は1時間後ですが、
        // 利用者にとっては「あと1日」です。両端を日の始まりへ揃えてから引きます。
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0

        if days == 0 { return "今日" }
        if days < 0 { return "期日超過" }
        return "あと\(days)日"
    }
}
