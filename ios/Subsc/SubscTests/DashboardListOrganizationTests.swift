import XCTest
@testable import Subsc

/// 一覧の**並び替え**と、**月払い・年払いへの分類**のテストです。
///
/// どちらもビューではなく `DashboardListBuilder` に閉じています。
/// ビューに書くと、条件が画面のあちこちへ散らばって食い違います。
final class DashboardListOrganizationTests: XCTestCase {
    private enum Fixture {
        static var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt
            return calendar
        }

        static let now = DateComponents(
            calendar: calendar,
            year: 2026,
            month: 1,
            day: 15
        ).date ?? .distantPast
    }

    // MARK: - 並び替え

    /// 既定は**金額の大きい順**です。
    func testAmountOrderPutsTheLargestFirst() {
        let items = makeItems([
            ("安い", 500, BillingCycle.monthly),
            ("高い", 3_000, .monthly),
            ("中くらい", 1_200, .monthly)
        ], sortOrder: .amount, isDescending: true)

        XCTAssertEqual(items.map(\.name), ["高い", "中くらい", "安い"])
    }

    /// 向きを反転できます。
    func testAmountOrderCanBeReversed() {
        let items = makeItems([
            ("安い", 500, BillingCycle.monthly),
            ("高い", 3_000, .monthly),
            ("中くらい", 1_200, .monthly)
        ], sortOrder: .amount, isDescending: false)

        XCTAssertEqual(items.map(\.name), ["安い", "中くらい", "高い"])
    }

    /// **年払いは年額で比べます。** 行に出している値と同じでないと、
    /// 「大きい順」と言いながら小さいものが上に来ます。
    func testAmountOrderComparesYearlyByItsYearlyAmount() {
        let items = makeItems([
            ("月払い高め", 3_000, BillingCycle.monthly),
            ("年払い", 28_800, .yearly)
        ], sortOrder: .amount, isDescending: true)

        XCTAssertEqual(items.map(\.name), ["年払い", "月払い高め"])
    }

    /// 名前順は**日本語の並び**で比べます。文字コード順だと直感と食い違います。
    func testNameOrderUsesJapaneseCollation() {
        let items = makeItems([
            ("さくら", 100, BillingCycle.monthly),
            ("あさひ", 200, .monthly),
            ("かえで", 300, .monthly)
        ], sortOrder: .name, isDescending: false)

        XCTAssertEqual(items.map(\.name), ["あさひ", "かえで", "さくら"])
    }

    /// **同額でも順序が安定します。** 決まらないと再描画のたびに行が入れ替わります。
    func testEqualAmountsFallBackToTheName() {
        let ascending = makeItems([
            ("びー", 1_000, BillingCycle.monthly),
            ("えー", 1_000, .monthly)
        ], sortOrder: .amount, isDescending: true)

        XCTAssertEqual(ascending.map(\.name), ["えー", "びー"])
    }

    /// 向きを反転しても、**同額のときの並びは名前順のまま**です。
    /// ここまで反転すると、金額が同じ行が向きを変えるたびに入れ替わります。
    func testReversingKeepsTheNameTiebreakStable() {
        let items = makeItems([
            ("びー", 1_000, BillingCycle.monthly),
            ("えー", 1_000, .monthly)
        ], sortOrder: .amount, isDescending: false)

        XCTAssertEqual(items.map(\.name), ["えー", "びー"])
    }

    /// 期日順は従来どおりです。**既存の並びを壊していないこと**を縛ります。
    func testDueDateOrderKeepsTheExistingBehavior() {
        let items = makeItems([
            ("あと", 100, BillingCycle.monthly, date(2026, 3, 1)),
            ("さき", 100, .monthly, date(2026, 2, 1))
        ], sortOrder: .dueDate, isDescending: false)

        XCTAssertEqual(items.map(\.name), ["さき", "あと"])
    }

    // MARK: - 分類

    /// 月払いと年払いが別のセクションに分かれます。
    func testSectionsSplitMonthlyAndYearly() {
        let items = makeItems([
            ("月のもの", 1_000, BillingCycle.monthly),
            ("年のもの", 12_000, .yearly)
        ], sortOrder: .amount, isDescending: true)

        let sections = DashboardListBuilder.sections(from: items, isSearching: false)

        XCTAssertEqual(sections.map(\.kind), [.monthly, .yearly])
        XCTAssertEqual(sections[0].items.map(\.name), ["月のもの"])
        XCTAssertEqual(sections[1].items.map(\.name), ["年のもの"])
    }

    /// **借入は「返済」の独立したセクションで、先頭**に来ます。
    /// 借入には支払い周期が無く、月払い・年払いのどちらにも入れられません。
    func testLoansGoIntoTheirOwnSectionFirst() throws {
        let subscription = makeSubscription("月のもの", 1_000, .monthly, date(2026, 2, 10))
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let items = DashboardListBuilder.items(
            subscriptions: [subscription],
            loans: [loan],
            stateFilter: .all,
            costTypeFilter: .all,
            query: "",
            now: Fixture.now,
            calendar: Fixture.calendar
        )
        let sections = DashboardListBuilder.sections(from: items, isSearching: false)

        XCTAssertEqual(sections.map(\.kind), [.loan, .monthly])
        XCTAssertEqual(sections[0].items.map(\.name), ["自動車ローン"])
    }

    /// 中身が無いセクションは出しません。見出しだけが並ぶのを避けます。
    func testEmptySectionsAreOmitted() {
        let items = makeItems([("月のもの", 1_000, BillingCycle.monthly)])

        let sections = DashboardListBuilder.sections(from: items, isSearching: false)

        XCTAssertEqual(sections.map(\.kind), [.monthly])
    }

    /// 見出しに出す件数と合計です。
    func testSectionCarriesItsCountAndTotal() {
        let items = makeItems([
            ("あ", 1_000, BillingCycle.monthly),
            ("い", 2_500, .monthly)
        ])

        let sections = DashboardListBuilder.sections(from: items, isSearching: false)

        XCTAssertEqual(sections[0].count, 2)
        XCTAssertEqual(sections[0].total, 3_500)
    }

    /// **見出しの合計は、その下に並ぶ行の金額の合計と必ず一致します。**
    /// ここがずれると、見出しがすぐ下の行について嘘をつくことになります。
    func testSectionTotalAlwaysMatchesItsRows() {
        let items = makeItems([
            ("月1", 1_000, BillingCycle.monthly),
            ("月2", 2_500, .monthly),
            ("年1", 36_000, .yearly)
        ])

        let sections = DashboardListBuilder.sections(from: items, isSearching: false)

        for section in sections {
            let sum = section.items.reduce(0) { $0 + $1.listedAmount }
            XCTAssertEqual(section.total, sum, "\(String(describing: section.kind))の合計が行と食い違っています")
        }
    }

    /// **検索中は分類しません。** 探している最中に階層が増えると目的の行が遠くなります。
    /// 見出しを出さない印として `kind` が `nil` の1セクションになります。
    func testSearchingDoesNotGroup() {
        let items = makeItems([
            ("月のもの", 1_000, BillingCycle.monthly),
            ("年のもの", 12_000, .yearly)
        ])

        let sections = DashboardListBuilder.sections(from: items, isSearching: true)

        XCTAssertEqual(sections.count, 1)
        XCTAssertNil(sections[0].kind)
        XCTAssertEqual(sections[0].items.count, 2)
    }

    /// 1件も無ければセクションも作りません。空の案内は呼び出し側が出します。
    func testNoItemsMakeNoSections() {
        XCTAssertTrue(DashboardListBuilder.sections(from: [], isSearching: false).isEmpty)
        XCTAssertTrue(DashboardListBuilder.sections(from: [], isSearching: true).isEmpty)
    }

    // MARK: - 行に出している金額

    /// 月払いは月額、年払いは年額です。**行の表示と同じ値**でなければなりません。
    func testListedAmountMatchesWhatTheRowShows() {
        let monthly = makeSubscription("月", 1_980, .monthly, date(2026, 2, 1))
        let yearly = makeSubscription("年", 28_776, .yearly, date(2026, 2, 1))

        XCTAssertEqual(DashboardListItem.subscription(monthly).listedAmount, 1_980)
        XCTAssertEqual(DashboardListItem.subscription(yearly).listedAmount, 28_776)
    }

    // MARK: - 材料

    private func makeItems(
        _ sources: [(String, Double, BillingCycle)],
        sortOrder: DashboardSortOrder = .amount,
        isDescending: Bool = true
    ) -> [DashboardListItem] {
        makeItems(
            sources.map { ($0.0, $0.1, $0.2, date(2026, 2, 1)) },
            sortOrder: sortOrder,
            isDescending: isDescending
        )
    }

    private func makeItems(
        _ sources: [(String, Double, BillingCycle, Date)],
        sortOrder: DashboardSortOrder = .amount,
        isDescending: Bool = true
    ) -> [DashboardListItem] {
        let subscriptions = sources.map { makeSubscription($0.0, $0.1, $0.2, $0.3) }
        return DashboardListBuilder.items(
            subscriptions: subscriptions,
            loans: [],
            stateFilter: .all,
            costTypeFilter: .all,
            query: "",
            sortOrder: sortOrder,
            isDescending: isDescending,
            now: Fixture.now,
            calendar: Fixture.calendar
        )
    }

    private func makeSubscription(
        _ name: String,
        _ amount: Double,
        _ cycle: BillingCycle,
        _ renewalDate: Date
    ) -> Subscription {
        Subscription(
            name: name,
            originalAmount: amount,
            billingCycle: cycle,
            renewalDate: renewalDate
        )
    }

    private func makeSynchronizedLoan(name: String) throws -> Loan {
        let loan = Loan(
            name: name,
            method: .equalPayment,
            annualRatePercent: 3.0,
            originalPrincipal: 1_000_000,
            borrowedOn: date(2025, 12, 10),
            totalInstallments: 12,
            paymentDay: 27
        )
        try LoanPaymentStore.synchronize(loan: loan, calendar: Fixture.calendar)
        return loan
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: Fixture.calendar, year: year, month: month, day: day).date
            ?? .distantPast
    }
}
