import XCTest
@testable import Subsc

/// 該当が1件も無いときの案内文のテストです。
///
/// **「別の絞り込みを選択してください」では何も分かりません。**
/// 実際に「履歴に何も出ないが壊れているのか」と受け取られたため、
/// どの絞り込みにも「何を入れればここに出るのか」を必ず書くことをここで縛ります。
final class SubscriptionFilterEmptyStateTests: XCTestCase {
    func testEveryFilterHasItsOwnTitleAndDescription() {
        let titles = SubscriptionFilter.allCases.map(\.emptyStateTitle)
        let descriptions = SubscriptionFilter.allCases.map(\.emptyStateDescription)

        XCTAssertEqual(Set(titles).count, SubscriptionFilter.allCases.count, "見出しが重複しています。")
        XCTAssertEqual(
            Set(descriptions).count,
            SubscriptionFilter.allCases.count,
            "説明が重複しています。絞り込みごとに条件が違うので、使い回してはいけません。"
        )
        for description in descriptions {
            XCTAssertFalse(description.isEmpty)
        }
    }

    /// **履歴は条件を2つ持ちます。** どちらか片方しか書かないと、もう片方が永遠に分かりません。
    func testHistoryDescribesBothConditions() {
        let description = SubscriptionFilter.history.emptyStateDescription

        XCTAssertTrue(description.contains("終了日"), "費目側の条件が書かれていません：\(description)")
        XCTAssertTrue(description.contains("完済"), "借入側の条件が書かれていません：\(description)")
    }

    /// 停止は借入に無い概念なので、そのことに触れます。触れないと設定箇所を探させてしまいます。
    func testPausedDescriptionMentionsThatLoansCannotBePaused() {
        let description = SubscriptionFilter.paused.emptyStateDescription

        XCTAssertTrue(description.contains("借入"), "借入に停止が無いことが書かれていません：\(description)")
    }

    /// 何も登録が無い状態では、追加の入口を案内します。
    func testAllDescriptionPointsAtTheAddButton() {
        let description = SubscriptionFilter.all.emptyStateDescription

        XCTAssertTrue(description.contains("＋"), "追加の入口が案内されていません：\(description)")
    }
}
