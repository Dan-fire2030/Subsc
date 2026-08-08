import Observation
import Foundation

/// チュートリアルを出すかどうかを保持します。
///
/// 端末ごとの「もう見たか」なので、CloudKitへは同期せず `UserDefaults` に閉じます
/// （`ThemeStore` と同じ理由です）。**スキーマを増やさないので、
/// CloudKit Productionへの反映と無関係に変更できます。**
///
/// 2台目の端末では再び出ますが、新しい端末で一度案内が出ることは不自然ではありません。
/// 案内のためだけに `@Model` を増やすと、**削除できないRecord Typeが1つ増える**ほうが重いと判断しました。
@Observable
final class OnboardingStore {
    private enum Keys {
        static let hasSeenTutorial = "onboarding.hasSeenTutorial"
    }

    /// テスト時に本物の `UserDefaults` を汚さないよう、既定値つきで注入します。
    private let defaults: UserDefaults

    /// 一度でも最後まで見たか、スキップしたか。
    ///
    /// **スキップも「見た」に含めます。** 飛ばしたいという意思を、次の起動で無視しないためです。
    private var hasSeenTutorial: Bool

    /// いま画面に出しているか。設定からの見直しもここを立てます。
    var isPresentingTutorial: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // **`bool(forKey:)` を使いません。** 壊れた文字列が入っていると `false` を返し、
        // 「見た」ことになってしまいます。値の有無で判定し、読めなければ未読へ倒します。
        let saved = defaults.object(forKey: Keys.hasSeenTutorial) as? Bool
        self.hasSeenTutorial = saved ?? false
        self.isPresentingTutorial = !(saved ?? false)
    }

    /// 起動時に出すべきか。**保存値だけで決まります**（画面の状態に依存しません）。
    var shouldPresentTutorial: Bool {
        !hasSeenTutorial
    }

    /// 最後まで見終わったときに呼びます。
    func markTutorialFinished() {
        recordAsSeen()
    }

    /// 途中でスキップされたときに呼びます。**完走と同じ扱いです。**
    func markTutorialSkipped() {
        recordAsSeen()
    }

    /// 設定画面から見直すときに呼びます。
    ///
    /// **「見た」記録は消しません。** 消すと、見直した次の起動で勝手に出てきます。
    func replayTutorial() {
        isPresentingTutorial = true
    }

    private func recordAsSeen() {
        hasSeenTutorial = true
        isPresentingTutorial = false
        defaults.set(true, forKey: Keys.hasSeenTutorial)
    }
}
