import XCTest
@testable import Subsc

/// 月のマスを組み立てる部分のテストです。
///
/// **ビューではなくここを縛ります。** 日付の丸めと「その月に計上するか」の判断が
/// カレンダーの正しさのほぼ全部で、画面は並べるだけだからです。
/// 実行日に依存させないため、`now` と `calendar` は必ず注入します。
final class CalendarMonthBuilderTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        calendar.firstWeekday = 1 // 日曜始まり。端末設定に依らず固定して判定する
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, year: y, month: m, day: d).date ?? .distantPast
    }

    private func day(_ days: [CalendarDay], _ y: Int, _ m: Int, _ d: Int) -> CalendarDay? {
        days.first { $0.date == date(y, m, d) }
    }

    // MARK: - 枠

    /// **月によらず6週42マス。** 週数が変わると月を送るたびに高さが動きます。
    func testGridIsAlwaysSixWeeks() {
        for month in 1...12 {
            let days = CalendarMonthBuilder.days(
                inMonthOf: date(2026, month, 1),
                subscriptions: [],
                loans: [],
                now: date(2026, 8, 9),
                calendar: calendar
            )
            XCTAssertEqual(days.count, 42, "\(month)月のマス数が42ではありません。")
        }
    }

    /// 前後の月の日が枠に入り、当月の日と区別されること。
    func testGridIncludesAdjacentMonthDays() {
        let days = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 8, 1),
            subscriptions: [],
            loans: [],
            now: date(2026, 8, 9),
            calendar: calendar
        )

        XCTAssertEqual(days.first?.date, date(2026, 7, 26), "週の始まりまで遡れていません。")
        XCTAssertEqual(day(days, 2026, 8, 1)?.isInDisplayedMonth, true)
        XCTAssertEqual(day(days, 2026, 7, 26)?.isInDisplayedMonth, false)
    }

    /// 今日と過去の判定。**今日は過去に入れません**（まだ出ていく可能性があります）。
    func testTodayIsNotPast() {
        let days = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 8, 1),
            subscriptions: [],
            loans: [],
            now: date(2026, 8, 9),
            calendar: calendar
        )

        XCTAssertEqual(day(days, 2026, 8, 9)?.isToday, true)
        XCTAssertEqual(day(days, 2026, 8, 9)?.isPast, false)
        XCTAssertEqual(day(days, 2026, 8, 8)?.isPast, true)
        XCTAssertEqual(day(days, 2026, 8, 10)?.isPast, false)
    }

    // MARK: - 日付の丸め

    /// **31日更新の費目は、短い月では末日に立ちます。** 丸めないとその月だけ消えます。
    func testRenewalDayIsClampedToShortMonths() {
        let subscription = makeSubscription(name: "月末", renewalOn: date(2026, 1, 31))

        let april = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 4, 1),
            subscriptions: [subscription],
            loans: [],
            now: date(2026, 1, 1),
            calendar: calendar
        )
        XCTAssertEqual(day(april, 2026, 4, 30)?.items.count, 1, "30日までの月で末日に立っていません。")
    }

    /// うるう年の2月は29日、平年は28日に立つこと。
    func testLeapYearFebruary() {
        let subscription = makeSubscription(name: "月末", renewalOn: date(2024, 1, 31))

        let leap = CalendarMonthBuilder.days(
            inMonthOf: date(2024, 2, 1),
            subscriptions: [subscription],
            loans: [],
            now: date(2024, 1, 1),
            calendar: calendar
        )
        let common = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 2, 1),
            subscriptions: [subscription],
            loans: [],
            now: date(2024, 1, 1),
            calendar: calendar
        )

        XCTAssertEqual(day(leap, 2024, 2, 29)?.items.count, 1, "うるう年の29日に立っていません。")
        XCTAssertEqual(day(common, 2026, 2, 28)?.items.count, 1, "平年の28日に立っていません。")
    }

    // MARK: - 何を置くか

    func testSubscriptionAndLoanLandOnTheirOwnDays() throws {
        let subscription = makeSubscription(name: "動画", renewalOn: date(2026, 8, 10))
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let days = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 8, 1),
            subscriptions: [subscription],
            loans: [loan],
            now: date(2026, 8, 1),
            calendar: calendar
        )

        XCTAssertEqual(day(days, 2026, 8, 10)?.items.map(\.name), ["動画"])
        // 返済日は毎月27日で作っている
        XCTAssertEqual(day(days, 2026, 8, 27)?.items.map(\.name), ["自動車ローン"])
        XCTAssertEqual(day(days, 2026, 8, 27)?.items.first?.kind, .loan)
    }

    /// **停止中の費目はレポートと同じ規則で扱います。**
    /// 過ぎ去った月には残し、今月・未来の月からは消えます。
    func testPausedSubscriptionFollowsTheReportRule() {
        let paused = makeSubscription(name: "止めたやつ", renewalOn: date(2026, 5, 10))
        paused.state = .paused

        let past = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 5, 1),
            subscriptions: [paused],
            loans: [],
            now: date(2026, 8, 9),
            calendar: calendar
        )
        let future = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 9, 1),
            subscriptions: [paused],
            loans: [],
            now: date(2026, 8, 9),
            calendar: calendar
        )

        XCTAssertEqual(day(past, 2026, 5, 10)?.items.count, 1, "過ぎた月から消えています。")
        XCTAssertEqual(day(past, 2026, 5, 10)?.items.first?.isPaused, true)
        XCTAssertEqual(day(future, 2026, 9, 10)?.items.count, 0, "未来の月に残っています。")
    }

    /// **年払いは更新月だけに、年額そのままで立ちます。** 1/12へならしません。
    func testYearlySubscriptionAppearsOnlyInItsRenewalMonth() {
        let yearly = Subscription(
            name: "年払い",
            originalAmount: 28_776,
            billingCycle: .yearly,
            renewalDate: date(2026, 8, 20)
        )

        let renewalMonth = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 8, 1),
            subscriptions: [yearly],
            loans: [],
            now: date(2026, 8, 1),
            calendar: calendar
        )
        let otherMonth = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 9, 1),
            subscriptions: [yearly],
            loans: [],
            now: date(2026, 8, 1),
            calendar: calendar
        )

        XCTAssertEqual(day(renewalMonth, 2026, 8, 20)?.items.first?.amount, 28_776)
        XCTAssertEqual(otherMonth.reduce(0) { $0 + $1.items.count }, 0, "更新月以外に出ています。")
    }

    /// **変動費の未入力は、その月の更新日のマスに輪で立ちます。**
    func testUnenteredVariableCostIsMarkedOnItsRenewalDay() {
        let variable = makeSubscription(name: "電気代", renewalOn: date(2026, 8, 15))
        variable.hasVariableAmount = true

        let days = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 8, 1),
            subscriptions: [variable],
            loans: [],
            now: date(2026, 8, 1),
            calendar: calendar
        )

        let item = day(days, 2026, 8, 15)?.items.first
        XCTAssertEqual(item?.name, "電気代")
        XCTAssertEqual(item?.isUnentered, true, "未入力の印が立っていません。")
    }

    // MARK: - 点の打ち切りと並び順

    func testDotsAreCappedAndRemainderIsCounted() {
        let subscriptions = (1...5).map {
            makeSubscription(name: "費目\($0)", renewalOn: date(2026, 8, 10))
        }

        let days = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 8, 1),
            subscriptions: subscriptions,
            loans: [],
            now: date(2026, 8, 1),
            calendar: calendar
        )
        let target = try? XCTUnwrap(day(days, 2026, 8, 10))

        XCTAssertEqual(target?.visibleItems.count, 3)
        XCTAssertEqual(target?.hiddenItemCount, 2)
        XCTAssertEqual(target?.showsCountBadge, true)
    }

    /// 1件のときは件数バッジを出しません。金額が件数の意味を兼ねます。
    func testSingleItemHasNoCountBadge() {
        let subscription = makeSubscription(name: "動画", renewalOn: date(2026, 8, 10))

        let days = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 8, 1),
            subscriptions: [subscription],
            loans: [],
            now: date(2026, 8, 1),
            calendar: calendar
        )

        XCTAssertEqual(day(days, 2026, 8, 10)?.showsCountBadge, false)
    }

    /// **並び順は借入 → 費目、金額の大きい順、同額なら名前順。**
    /// 同額の順序が実行のたびに変わると、点と一覧が入れ替わって見えます。
    func testOrderIsStableAndDeterministic() throws {
        let cheap = makeSubscription(name: "あ費目", renewalOn: date(2026, 8, 27), amount: 500)
        let same = makeSubscription(name: "い費目", renewalOn: date(2026, 8, 27), amount: 500)
        let rich = makeSubscription(name: "う費目", renewalOn: date(2026, 8, 27), amount: 9_000)
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let names = (0..<5).map { _ -> [String] in
            let days = CalendarMonthBuilder.days(
                inMonthOf: date(2026, 8, 1),
                subscriptions: [cheap, same, rich],
                loans: [loan],
                now: date(2026, 8, 1),
                calendar: calendar
            )
            return day(days, 2026, 8, 27)?.items.map(\.name) ?? []
        }

        XCTAssertEqual(names[0], ["自動車ローン", "う費目", "あ費目", "い費目"])
        XCTAssertEqual(Set(names.map { $0.joined(separator: ",") }).count, 1, "順序が揺れています。")
    }

    // MARK: - レポートとの一致（いちばん大事な不変条件）

    /// **月内の日合計の総和が、レポートの月合計と一致すること。**
    ///
    /// ここが崩れると、同じ月を見ているのに画面によって数字が違うことになります。
    /// 「その月に計上するか」の判断を `ReportCalculator` へ寄せた理由そのものです。
    func testMonthTotalMatchesTheReport() throws {
        let fixed = makeSubscription(name: "動画", renewalOn: date(2026, 8, 10), amount: 1_980)
        let yearly = Subscription(
            name: "年払い",
            originalAmount: 28_776,
            billingCycle: .yearly,
            renewalDate: date(2026, 8, 20)
        )
        let paused = makeSubscription(name: "止めたやつ", renewalOn: date(2026, 8, 5))
        paused.state = .paused
        let loan = try makeSynchronizedLoan(name: "自動車ローン")

        let subscriptions = [fixed, yearly, paused]
        let now = date(2026, 8, 1)

        let days = CalendarMonthBuilder.days(
            inMonthOf: date(2026, 8, 1),
            subscriptions: subscriptions,
            loans: [loan],
            now: now,
            calendar: calendar
        )
        let calendarTotal = days
            .filter(\.isInDisplayedMonth)
            .reduce(0) { $0 + $1.total }

        let report = ReportCalculator.report(
            subscriptions: subscriptions,
            loans: [loan],
            period: .month,
            cursor: date(2026, 8, 1),
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(
            calendarTotal,
            report.total,
            accuracy: 0.01,
            "カレンダーの合計 \(calendarTotal) とレポートの合計 \(report.total) が食い違っています。"
        )
    }

    // MARK: - 補助

    private func makeSubscription(
        name: String,
        renewalOn renewalDate: Date,
        amount: Double = 1_000
    ) -> Subscription {
        Subscription(name: name, originalAmount: amount, renewalDate: renewalDate)
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
        try LoanPaymentStore.synchronize(loan: loan, calendar: calendar)
        return loan
    }
}
