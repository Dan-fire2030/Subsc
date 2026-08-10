import Foundation

/// 月のマスを組み立てます。
///
/// **「その月に計上するか」を自前で判断しません。** `ReportCalculator.includes` を通し、
/// 金額も `Subscription.monthlyAmount` を使います。判断を写すと、同じ月を見ているのに
/// レポートとカレンダーで数字が食い違います。ここが足すのは**「月のどの日か」だけ**です。
enum CalendarMonthBuilder {
    /// 並べる週の数です。**月によらず6週で固定します。**
    /// 週数が5と6で変わると、月を送るたびにカレンダーの高さが動き、
    /// 同じ月を見ている感覚が切れます。
    static let weeksPerPage = 6

    static func days(
        inMonthOf cursor: Date,
        subscriptions: [Subscription],
        loans: [Loan],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [CalendarDay] {
        guard let monthStart = startOfMonth(cursor, calendar: calendar),
              let gridStart = startOfGrid(monthStart, calendar: calendar) else {
            return []
        }

        let itemsByDay = itemsByDay(
            inMonthOf: monthStart,
            subscriptions: subscriptions,
            loans: loans,
            now: now,
            calendar: calendar
        )
        let today = calendar.startOfDay(for: now)
        let displayedMonth = calendar.dateComponents([.year, .month], from: monthStart)

        return (0..<(weeksPerPage * 7)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            let components = calendar.dateComponents([.year, .month], from: date)
            return CalendarDay(
                date: date,
                isInDisplayedMonth: components.year == displayedMonth.year
                    && components.month == displayedMonth.month,
                isToday: date == today,
                isPast: date < today,
                items: itemsByDay[date] ?? []
            )
        }
    }

    // MARK: - 材料

    /// その月に出ていくものを、日ごとにまとめます。
    private static func itemsByDay(
        inMonthOf monthStart: Date,
        subscriptions: [Subscription],
        loans: [Loan],
        now: Date,
        calendar: Calendar
    ) -> [Date: [CalendarDayItem]] {
        var result: [Date: [CalendarDayItem]] = [:]

        for subscription in subscriptions {
            guard ReportCalculator.includes(
                subscription,
                period: .month,
                cursor: monthStart,
                now: now,
                calendar: calendar
            ) else { continue }

            let resolved = subscription.monthlyAmount(
                forPeriodKey: AmountEntry.periodKey(for: monthStart, calendar: calendar),
                calendar: calendar
            )
            // **定額で「その月に無い」ものは置きません。** 年払いの更新月以外がこれに当たります。
            // 変動費は額が分からないだけで請求は来るため、未入力として残します。
            if !subscription.hasVariableAmount, resolved.source == .unavailable {
                continue
            }
            guard let date = chargeDate(
                for: subscription,
                inMonthOf: monthStart,
                calendar: calendar
            ) else { continue }

            let isUnentered = subscription.hasVariableAmount && resolved.source != .recorded
            result[date, default: []].append(
                CalendarDayItem(
                    id: "subscription-\(subscription.clientID)",
                    name: subscription.name,
                    subtitle: subscription.category,
                    colorHex: subscription.colorHex,
                    kind: .subscription,
                    amount: resolved.amount,
                    isUnentered: isUnentered,
                    isEstimated: resolved.source == .estimated,
                    isPaused: subscription.state == .paused,
                    subscriptionClientID: subscription.clientID
                )
            )
        }

        let periodKey = AmountEntry.periodKey(for: monthStart, calendar: calendar)
        for loan in loans {
            guard ReportCalculator.includes(
                loan,
                period: .month,
                cursor: monthStart,
                now: now,
                calendar: calendar
            ) else { continue }

            for payment in LoanPaymentStore.sortedPayments(on: loan)
            where payment.periodKey == periodKey {
                guard let dueOn = payment.dueOn else { continue }
                let date = calendar.startOfDay(for: dueOn)
                result[date, default: []].append(
                    CalendarDayItem(
                        // 費目と `clientID` が衝突しても別物として扱えるよう接頭辞を付けます。
                        id: "loan-\(loan.clientID)-\(payment.periodKey)",
                        name: loan.name,
                        subtitle: loan.method.title,
                        colorHex: CostType.loan.colorHex,
                        kind: .loan,
                        amount: payment.effectiveAmount,
                        isUnentered: false,
                        // **返済額は予定表から確定的に決まります。** 見込みにしません。
                        isEstimated: false,
                        isPaused: loan.isPaused,
                        subscriptionClientID: nil
                    )
                )
            }
        }

        return result.mapValues { $0.sorted(by: CalendarDayItem.isOrderedBefore) }
    }

    /// その月で、費目の請求が立つ日です。
    ///
    /// **月末の日付を丸めます。** 31日更新の費目は、30日までの月では30日、
    /// 2月では28日（うるう年は29日）に立ちます。丸めないとその月だけ消えます。
    static func chargeDate(
        for subscription: Subscription,
        inMonthOf monthStart: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
        let renewalDay = calendar.component(.day, from: subscription.renewalDate)
        var components = calendar.dateComponents([.year, .month], from: monthStart)
        components.day = min(renewalDay, range.upperBound - 1)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    // MARK: - 枠

    private static func startOfMonth(_ cursor: Date, calendar: Calendar) -> Date? {
        calendar.date(from: calendar.dateComponents([.year, .month], from: cursor))
    }

    /// 6週ぶんの枠の始まりです。
    ///
    /// **週の始まりは端末の設定に従います**（`calendar.firstWeekday`）。
    /// 自前で日曜と決め打つと、月曜始まりにしている利用者の他アプリと食い違います。
    private static func startOfGrid(_ monthStart: Date, calendar: Calendar) -> Date? {
        let weekday = calendar.component(.weekday, from: monthStart)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: monthStart)
            .map { calendar.startOfDay(for: $0) }
    }
}
