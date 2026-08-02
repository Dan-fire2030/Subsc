import SwiftUI

/// 一覧の絞り込み条件です。表示名をそのまま rawValue にしてピッカーへ流し込みます。
enum SubscriptionFilter: String, CaseIterable, Identifiable {
    case all = "すべて"
    case active = "利用中"
    case paused = "停止中"
    case history = "履歴"

    var id: String { rawValue }
}

/// 種別での絞り込み条件です。
///
/// 一覧とレポートの**両方に効く1つの条件**として使います。同じ絞り込みを画面内に
/// 2つ置くと、どちらが効いているのか分からなくなるためです。
enum CostTypeFilter: Hashable, Identifiable, CaseIterable {
    case all
    case only(CostType)

    static var allCases: [CostTypeFilter] {
        [.all] + CostType.allCases.map(CostTypeFilter.only)
    }

    var id: String {
        switch self {
        case .all: "all"
        case .only(let type): type.rawValue
        }
    }

    var title: String {
        switch self {
        case .all: "すべての種別"
        case .only(let type): type.title
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .only(let type): type.systemImage
        }
    }

    /// 絞り込みが効いているか。ツールバーのアイコンを塗り分けるのに使います。
    var isNarrowed: Bool { self != .all }

    func matches(_ subscription: Subscription) -> Bool {
        matches(subscription.costType)
    }

    /// 種別だけで判定します。借入（`Loan`）は `Subscription` ではないため、
    /// **モデルではなく種別を受け取る口**が要ります。
    func matches(_ costType: CostType) -> Bool {
        switch self {
        case .all: true
        case .only(let type): costType == type
        }
    }
}

/// iOS 26 でのみ検索バーの最小化を有効にします。
///
/// `searchToolbarBehavior` は iOS 26 で追加された API のため、
/// iOS 17〜25 では何もせずそのまま返してフォールバックさせています。
struct MinimizableSearchToolbarModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.searchToolbarBehavior(.minimize)
        } else {
            content
        }
    }
}
