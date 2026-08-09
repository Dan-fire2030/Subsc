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

/// チュートリアルに並べる内容のテストです。
///
/// **ページを足す・並べ替えるときに壊れやすい前提**をここで縛ります。
/// `TabView` の選択は `id` をそのまま `tag` に使っているため、
/// 番号が飛ぶと「次へ」で進めないページができます。
final class TutorialPageTests: XCTestCase {
    /// `id` は 0 から連番であること。`selection += 1` で進める作りの前提です。
    func testPageIdentifiersAreSequentialFromZero() {
        XCTAssertEqual(
            TutorialPage.all.map(\.id),
            Array(0..<TutorialPage.all.count),
            "idが連番でないと「次へ」で進めないページができます。"
        )
    }

    /// 見出しと本文が空のページを出さないこと。
    func testEveryPageHasTitleAndBody() {
        for page in TutorialPage.all {
            XCTAssertFalse(page.title.isEmpty, "\(page.id)ページ目の見出しが空です。")
            XCTAssertFalse(page.body.isEmpty, "\(page.id)ページ目の本文が空です。")
        }
    }

    /// **猫の状態を説明するページは、レポートの直後に置きます。**
    /// 猫が示すのは支出の傾向で、レポートで見た集計を姿に置き換えたものだからです。
    func testMoodGuideFollowsTheReportPage() throws {
        let guideIndex = try XCTUnwrap(
            TutorialPage.all.firstIndex { $0.artwork == .catMoodGuide },
            "猫の状態を説明するページがありません。"
        )
        let previous = TutorialPage.all[guideIndex - 1]

        XCTAssertEqual(previous.artwork, .symbol("chart.bar.xaxis"))
    }

    /// **最後は「通知とデータ」で閉じること。** 外へ送らないという前提は、
    /// 使い始める直前に残しておきたい情報です。
    func testTheLastPageIsAboutNotificationsAndData() throws {
        let last = try XCTUnwrap(TutorialPage.all.last)

        XCTAssertEqual(last.artwork, .symbol("bell.badge"))
    }

    /// **猫を1匹だけ座らせるページは1つだけ。** 全ページに出すと、
    /// 猫が説明役として喋っているように読めてしまいます。
    func testOnlyOnePageSeatsASingleCat() {
        let seated = TutorialPage.all.filter { page in
            if case .cat = page.artwork { return true }
            return false
        }

        XCTAssertEqual(seated.count, 1)
    }

    /// 並べる状態が重複していないこと。同じ姿が2つ並ぶと対応が読めません。
    func testFeaturedMoodsAreDistinct() {
        XCTAssertEqual(
            Set(TutorialPage.featuredMoods).count,
            TutorialPage.featuredMoods.count
        )
    }

    /// **名前も重複しないこと。** 姿が違っても同じ名前が並ぶと、
    /// どちらがどの状況か分かりません。名前は `CatMood.title` を使い回しています。
    func testFeaturedMoodNamesAreDistinctAndNotEmpty() {
        let names = TutorialPage.featuredMoods.map(\.title)

        XCTAssertEqual(Set(names).count, names.count, "同じ名前の姿が並んでいます：\(names)")
        for name in names {
            XCTAssertFalse(name.isEmpty)
        }
    }
}
