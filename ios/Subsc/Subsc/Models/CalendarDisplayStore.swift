import Foundation
import Observation

/// カレンダーのマスに金額と件数を出すかどうかを保持します。
///
/// 端末ごとの見た目の好みなので、CloudKitへは同期せず `UserDefaults` に閉じます
/// （`ThemeStore` / `OnboardingStore` と同じ理由）。**スキーマを増やしません。**
///
/// **既定は「出さない」です。** 色の点だけのほうが月全体の形を掴みやすく、
/// 金額は必要なときに足すもの、という位置づけにしています。
@Observable
final class CalendarDisplayStore {
    private enum Keys {
        static let showsAmounts = "calendar.showsAmounts"
    }

    /// テスト時に本物の `UserDefaults` を汚さないよう、既定値つきで注入します。
    private let defaults: UserDefaults

    /// 金額の合計と件数のバッジを出すか。**2つをまとめて1つの状態で持ちます。**
    /// 別々にすると、片方だけ出ている中途半端な見え方が生まれます。
    var showsAmounts: Bool {
        didSet { defaults.set(showsAmounts, forKey: Keys.showsAmounts) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // **`bool(forKey:)` を使いません。** 値が無いときも `false` を返すため、
        // 「保存されていない」と「出さないを選んだ」を区別できません。
        // いまは既定が `false` なので結果は同じですが、既定を変えたときに壊れます。
        self.showsAmounts = (defaults.object(forKey: Keys.showsAmounts) as? Bool) ?? false
    }
}
