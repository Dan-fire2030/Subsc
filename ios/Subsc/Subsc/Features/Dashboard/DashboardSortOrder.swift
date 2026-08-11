import Foundation

/// 一覧の並び順です。
///
/// **向き（昇順・降順）は別に持ちます。** 「金額の大きい順」「金額の小さい順」を
/// 別の選択肢として並べると、増えるたびに選択肢が2倍になるためです。
enum DashboardSortOrder: String, CaseIterable, Identifiable, Sendable {
    /// 次の期日が近い順。従来の並びです。
    case dueDate
    case amount
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dueDate: "期日順"
        case .amount: "金額順"
        case .name: "名前順"
        }
    }

    var systemImage: String {
        switch self {
        case .dueDate: "calendar"
        case .amount: "yensign.circle"
        case .name: "textformat.abc"
        }
    }

    /// この並びを選んだ直後の向きです。
    ///
    /// **金額だけ降順から始めます。** 金額を選ぶ人が見たいのは、たいてい高いほうだからです。
    /// 期日と名前は昇順が自然な向きです。
    var startsDescending: Bool { self == .amount }

    /// 向きに添える言葉です。並びによって「大きい／小さい」「早い／遅い」と読み替えます。
    func directionTitle(isDescending: Bool) -> String {
        switch self {
        case .dueDate: isDescending ? "遠い順" : "近い順"
        case .amount: isDescending ? "大きい順" : "小さい順"
        case .name: isDescending ? "降順" : "昇順"
        }
    }
}

/// 一覧のセクションの種類です。
///
/// **借入を月払い・年払いへ混ぜません。** 借入には支払い周期の概念が無く、
/// どちらに入れても嘘になるためです。
enum DashboardSectionKind: String, CaseIterable, Identifiable, Sendable {
    case loan
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loan: "返済"
        case .monthly: "月払い"
        case .yearly: "年払い"
        }
    }
}

/// 見出しと、その下に並ぶ行の組です。
struct DashboardListSection: Identifiable {
    /// **`nil` は「見出しを出さない」印**です。検索中はこの形になります。
    let kind: DashboardSectionKind?
    let items: [DashboardListItem]

    var id: String { kind?.rawValue ?? "all" }

    var count: Int { items.count }

    /// 見出しに出す合計です。
    ///
    /// **その下に並ぶ行の金額をそのまま足します。** レポートの集計を持ってくると、
    /// 停止中や履歴を含む絞り込みのときに**見出しがすぐ下の行と食い違います**。
    /// 見出しは、その下にあるものについての要約でなければなりません。
    var total: Double {
        items.reduce(0) { $0 + $1.listedAmount }
    }
}
