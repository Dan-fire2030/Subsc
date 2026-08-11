import Foundation

/// アーカイブの期限についての判断をまとめます。
///
/// **「あと何日か」と「もう消してよいか」は3箇所から必要になります**
/// （アーカイブ欄の行・自動削除・起動時の掃除）。写すと必ず食い違うため、ここに閉じます。
///
/// **アーカイブしたかどうかは日時1つ（`archivedAt`）で表します。**
/// 状態を別に持つと、日時と状態が食い違いえます。`nil` がアーカイブしていない状態です。
enum ArchivePolicy {
    /// アーカイブを保つ日数です。**設定で変えられるようにはしません。**
    static let retentionDays = 30

    /// 行の色を変える境目です。
    static let expiringSoonDays = 7

    static func isArchived(_ archivedAt: Date?) -> Bool {
        archivedAt != nil
    }

    /// 自動削除までの残り日数です。アーカイブしていなければ `nil` を返します。
    ///
    /// **日付の境目で数えます。** 時刻で比べると、同じ日なのに「あと30日」と「あと29日」が
    /// 混ざります。アーカイブした時刻が23時でも0時でも、同じ日なら同じ日数になります。
    ///
    /// 期限を過ぎたあとは0で止めます。**負の数を画面へ出さないため**です。
    static func remainingDays(
        archivedAt: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int? {
        guard let elapsed = elapsedDays(archivedAt: archivedAt, now: now, calendar: calendar) else {
            return nil
        }
        return max(0, retentionDays - elapsed)
    }

    /// 消してよいか。**30日ちょうどの日はまだ残し、31日目で消します。**
    static func isExpired(
        archivedAt: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard let elapsed = elapsedDays(archivedAt: archivedAt, now: now, calendar: calendar) else {
            return false
        }
        return elapsed > retentionDays
    }

    /// 期限が近いか。行の色を変える鍵に使います。
    static func isExpiringSoon(
        archivedAt: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard let remaining = remainingDays(archivedAt: archivedAt, now: now, calendar: calendar),
              !isExpired(archivedAt: archivedAt, now: now, calendar: calendar) else {
            return false
        }
        return remaining <= expiringSoonDays
    }

    /// アーカイブしてから何日経ったか。**日付の境目で数えます。**
    private static func elapsedDays(
        archivedAt: Date?,
        now: Date,
        calendar: Calendar
    ) -> Int? {
        guard let archivedAt else { return nil }
        let from = calendar.startOfDay(for: archivedAt)
        let to = calendar.startOfDay(for: now)
        guard let days = calendar.dateComponents([.day], from: from, to: to).day else { return nil }
        // 端末の時計が巻き戻った場合に負の日数を通さないよう、0で止めます。
        return max(0, days)
    }
}
