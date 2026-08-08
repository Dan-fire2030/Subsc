import XCTest
@testable import Subsc

/// チュートリアルを出すかどうかの判断を確かめます。
///
/// **表示の要否だけを持つ小さなストアですが、間違えると2種類の実害が出ます。**
/// 出すべきときに出なければ初めての人が何も分からないまま放り出され、
/// 出すべきでないときに出れば毎回の起動を邪魔します。
final class OnboardingStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        // 実行者本人の設定を汚さないよう、テストごとに独立したsuiteを使います。
        suiteName = "OnboardingStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testShowsTheTutorialOnTheFirstLaunch() {
        let store = OnboardingStore(defaults: defaults)

        XCTAssertTrue(store.shouldPresentTutorial, "何も保存されていなければ初回とみなす")
    }

    func testFinishingHidesTheTutorialFromThenOn() {
        let store = OnboardingStore(defaults: defaults)
        store.markTutorialFinished()

        XCTAssertFalse(store.shouldPresentTutorial)
        XCTAssertFalse(
            OnboardingStore(defaults: defaults).shouldPresentTutorial,
            "起動し直しても出さない"
        )
    }

    /// **スキップは完走と同じ扱いです。** 「飛ばした人には次も出す」は、
    /// 飛ばしたいという意思を無視することになります。
    func testSkippingCountsTheSameAsFinishing() {
        let store = OnboardingStore(defaults: defaults)
        store.markTutorialSkipped()

        XCTAssertFalse(store.shouldPresentTutorial)
        XCTAssertFalse(OnboardingStore(defaults: defaults).shouldPresentTutorial)
    }

    /// **設定から見直しても「見た」記録は消しません。**
    /// 消すと、見直した次の起動で勝手に出てきて驚かせます。
    func testReplayingFromSettingsDoesNotBringItBackOnLaunch() {
        let store = OnboardingStore(defaults: defaults)
        store.markTutorialFinished()

        store.replayTutorial()
        XCTAssertTrue(store.isPresentingTutorial, "見直しを頼まれたら、その場では出す")

        store.markTutorialFinished()
        XCTAssertFalse(store.isPresentingTutorial)
        XCTAssertFalse(
            OnboardingStore(defaults: defaults).shouldPresentTutorial,
            "見直した後も、次の起動では出さない"
        )
    }

    /// 保存値が壊れていても起動を止めません。**案内のために起動できないのは本末転倒です。**
    func testBrokenSavedValueDoesNotPreventLaunching() {
        defaults.set("こわれた値", forKey: "onboarding.hasSeenTutorial")

        let store = OnboardingStore(defaults: defaults)

        XCTAssertTrue(
            store.shouldPresentTutorial,
            "真偽値として読めない値は「まだ見ていない」に倒す"
        )
    }
}
