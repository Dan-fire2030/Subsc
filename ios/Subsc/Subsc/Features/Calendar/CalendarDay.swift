import Foundation

/// カレンダーのマス1つぶんです。
struct CalendarDay: Identifiable, Equatable {
    /// マスに並べる点の上限です。**これを超えたぶんは残数で示します。**
    /// iPhoneのマスは狭く、点を増やすほど1つ1つの色が読めなくなります。
    static let maximumDots = 3

    /// その日の始まりです。**`startOfDay` に正規化して持ちます。**
    /// 時刻が混じると、同じ日なのに別のマスとして扱われます。
    let date: Date
    /// 表示中の月の日か。前後の月の日は淡く描きます。
    let isInDisplayedMonth: Bool
    let isToday: Bool
    /// 過ぎた日か。**今日は含めません**（今日はまだ出ていく可能性があります）。
    let isPast: Bool
    let items: [CalendarDayItem]

    var id: Date { date }

    /// その日に出ていく額です。
    ///
    /// **見込みも足します。** レポートの月合計と揃えるためで、
    /// 片方だけが見込みを外すと、同じ月を見て数字が食い違います。
    var total: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    /// マスに並べる点です。
    var visibleItems: [CalendarDayItem] {
        Array(items.prefix(Self.maximumDots))
    }

    /// 点を並べきれなかった件数です。0なら残数を出しません。
    var hiddenItemCount: Int {
        max(0, items.count - Self.maximumDots)
    }

    /// 件数のバッジを出すか。
    ///
    /// **1件のときは出しません。** 金額がそのまま件数の意味を兼ねており、
    /// 「1件」と書くと同じことを二度言うことになります。
    var showsCountBadge: Bool {
        items.count >= 2
    }
}
