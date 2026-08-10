import Foundation

/// カレンダーの1日に並ぶ1件です。
///
/// **モデルを持たせず、表示に要る値だけを写し取ります。** 並べ替えや合計のたびに
/// 保存領域へ触れないようにするためで、`DashboardListItem` がモデルを持つのとは
/// 事情が違います（あちらは行から詳細画面へ渡す必要があります）。
struct CalendarDayItem: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case subscription
        case loan
    }

    /// **種別ごとに接頭辞を付けます。** 費目と借入で `clientID` が偶然衝突しても、
    /// `ForEach` が同じ行だと誤認しないようにするためです（一覧と同じ扱い）。
    let id: String
    let name: String
    /// 名前の下に出す補足です。費目はカテゴリ、借入は返済方式を指します。
    let subtitle: String
    let colorHex: String
    let kind: Kind
    /// その日に出ていく額です。**合計はこれを足し上げます。**
    let amount: Double
    /// 変動費で、その月の実績がまだ記録されていない状態です。
    /// **点を塗らずに輪で描きます。** 色（どの費目か）の意味は保ったまま、質感だけで区別します。
    let isUnentered: Bool
    /// 額が実績ではなく見込みであることです。**断定しないために添えます。**
    let isEstimated: Bool
    /// 停止中の費目です。過ぎ去った月では計上に残るため、印だけ添えます。
    let isPaused: Bool
    /// 実績入力の画面へ渡すための識別子です。借入では `nil` です。
    let subscriptionClientID: String?
}

extension CalendarDayItem {
    /// 並び順です。**借入 → 費目**、同じ種別の中は**金額の大きい順**、同額なら名前順。
    ///
    /// **最後は必ず名前で決めます。** 金額が同じ項目の順序が実行のたびに変わると、
    /// 再描画でカレンダーの点と一覧の行が入れ替わって見えます。
    static func isOrderedBefore(_ lhs: CalendarDayItem, _ rhs: CalendarDayItem) -> Bool {
        if lhs.kind != rhs.kind {
            return lhs.kind == .loan
        }
        if lhs.amount != rhs.amount {
            return lhs.amount > rhs.amount
        }
        return lhs.name.localizedCompare(rhs.name) == .orderedAscending
    }
}
