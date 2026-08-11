import Foundation
import Observation

/// 一覧の並び順の選択を覚えておきます。
///
/// **`UserDefaults` に置きます。** 表示の好みであって記録ではないため、
/// `@Model` には入れません（＝CloudKitへも同期しません）。
/// `CalendarDisplayStore` と同じ流儀です。
@Observable
final class DashboardSortStore {
    private enum Key {
        static let order = "dashboard.sortOrder"
        static let isDescending = "dashboard.sortIsDescending"
    }

    /// **既定は金額の大きい順**です（2026-08-11・harutoさんの決定）。
    private enum Default {
        static let order = DashboardSortOrder.amount
        static let isDescending = true
    }

    private let defaults: UserDefaults

    var order: DashboardSortOrder {
        didSet {
            guard order != oldValue else { return }
            defaults.set(order.rawValue, forKey: Key.order)
        }
    }

    var isDescending: Bool {
        didSet {
            guard isDescending != oldValue else { return }
            defaults.set(isDescending, forKey: Key.isDescending)
        }
    }

    /// テストから差し替えられるよう、既定値付きの引数で受け取ります。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedOrder = defaults.string(forKey: Key.order)
            .flatMap(DashboardSortOrder.init(rawValue:))
        order = storedOrder ?? Default.order

        // **`object(forKey:)` で有無を見ます。** `bool(forKey:)` は未設定でも `false` を返すため、
        // 「まだ選んでいない」と「小さい順を選んだ」を区別できません。
        if defaults.object(forKey: Key.isDescending) == nil {
            isDescending = Default.isDescending
        } else {
            isDescending = defaults.bool(forKey: Key.isDescending)
        }
    }

    /// 並び順を選び直します。
    ///
    /// **別の並びへ移るときは、その並びの自然な向きから始めます。**
    /// 金額へ移った瞬間に「小さい順」で出ると、たいていの人が見たいものと逆になります。
    /// **同じ並びをもう一度選んだときは向きを反転**します。
    func select(_ newOrder: DashboardSortOrder) {
        if order == newOrder {
            isDescending.toggle()
        } else {
            order = newOrder
            isDescending = newOrder.startsDescending
        }
    }
}
