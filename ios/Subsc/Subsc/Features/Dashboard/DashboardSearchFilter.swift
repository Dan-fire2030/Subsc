import SwiftUI

/// 一覧の絞り込み条件です。表示名をそのまま rawValue にしてピッカーへ流し込みます。
enum SubscriptionFilter: String, CaseIterable, Identifiable {
    case all = "すべて"
    case active = "利用中"
    case paused = "停止中"
    case history = "履歴"

    var id: String { rawValue }
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
