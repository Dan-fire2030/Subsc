import Foundation

struct ReportEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Double
    let colorHex: String
    let costType: CostType
    /// 実績ではなく直近の実績から見込んだ額かどうか。画面で実績と区別するために使います。
    let isEstimated: Bool
}

struct PaymentReport: Equatable {
    let total: Double
    let entries: [ReportEntry]
}

enum ReportPeriod: String, CaseIterable, Identifiable {
    case month = "月額換算"
    case year = "年間換算"

    var id: String { rawValue }
}

enum ReportCalculator {
    static func report(
        subscriptions: [Subscription],
        period: ReportPeriod,
        cursor: Date,
        calendar: Calendar = .current
    ) -> PaymentReport {
        let active = subscriptions.filter { subscription in
            guard subscription.state == .active else { return false }
            if let startDate = subscription.startDate,
               startDate >= periodEnd(period, cursor: cursor, calendar: calendar) {
                return false
            }
            if let endDate = subscription.endDate,
               endDate < periodStart(period, cursor: cursor, calendar: calendar) {
                return false
            }
            return true
        }

        let entries = active.map { subscription in
            let resolved = amount(
                for: subscription,
                period: period,
                cursor: cursor,
                calendar: calendar
            )
            return ReportEntry(
                id: subscription.clientID,
                name: subscription.name,
                amount: resolved.amount,
                colorHex: subscription.colorHex,
                costType: subscription.costType,
                isEstimated: resolved.source == .estimated
            )
        }
        .filter { $0.amount > 0 }
        .sorted { $0.amount > $1.amount }

        return PaymentReport(
            total: entries.reduce(0) { $0 + $1.amount },
            entries: entries
        )
    }

    static func shifted(_ cursor: Date, period: ReportPeriod, by value: Int) -> Date {
        Calendar.current.date(
            byAdding: period == .month ? .month : .year,
            value: value,
            to: cursor
        ) ?? cursor
    }

    /// 表示中の期間が今日を含む期間かどうかを返します。
    static func isCurrentPeriod(
        _ cursor: Date,
        period: ReportPeriod,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(
            cursor,
            equalTo: reference,
            toGranularity: period == .month ? .month : .year
        )
    }

    /// 表示中の期間について、その費目がいくらかを解決します。
    private static func amount(
        for subscription: Subscription,
        period: ReportPeriod,
        cursor: Date,
        calendar: Calendar
    ) -> MonthlyAmount {
        if period == .month {
            return subscription.monthlyAmount(
                forPeriodKey: AmountEntry.periodKey(for: cursor, calendar: calendar)
            )
        }
        return annualAmount(subscription, cursor: cursor, calendar: calendar)
    }

    /// 年間の合計です。**月ごとに解決した額を足し上げます。**
    /// 変動費は月によって額が違うため、1ヶ月ぶんを12倍する方法では合いません。
    private static func annualAmount(
        _ subscription: Subscription,
        cursor: Date,
        calendar: Calendar
    ) -> MonthlyAmount {
        let year = calendar.component(.year, from: cursor)
        let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? cursor
        let nextYear = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? cursor
        let activeStart = max(subscription.startDate ?? yearStart, yearStart)
        let endDateExclusive = subscription.endDate.flatMap {
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))
        } ?? nextYear
        let activeEnd = min(endDateExclusive, nextYear)
        guard activeStart < activeEnd else { return .unavailable }

        guard var monthCursor = calendar.date(
            from: calendar.dateComponents([.year, .month], from: activeStart)
        ) else {
            return .unavailable
        }

        var total: Double = 0
        var hasEstimatedMonth = false
        var hasKnownMonth = false
        while monthCursor < activeEnd {
            let monthly = subscription.monthlyAmount(
                forPeriodKey: AmountEntry.periodKey(for: monthCursor, calendar: calendar)
            )
            total += monthly.amount
            switch monthly.source {
            case .estimated: hasEstimatedMonth = true
            case .recorded: hasKnownMonth = true
            case .unavailable: break
            }
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor) else {
                break
            }
            monthCursor = nextMonth
        }

        guard hasEstimatedMonth || hasKnownMonth else { return .unavailable }
        return MonthlyAmount(
            amount: total,
            source: hasEstimatedMonth ? .estimated : .recorded
        )
    }

    private static func periodStart(
        _ period: ReportPeriod,
        cursor: Date,
        calendar: Calendar
    ) -> Date {
        if period == .month {
            return calendar.date(
                from: calendar.dateComponents([.year, .month], from: cursor)
            ) ?? cursor
        }
        return calendar.date(
            from: DateComponents(year: calendar.component(.year, from: cursor), month: 1, day: 1)
        ) ?? cursor
    }

    private static func periodEnd(
        _ period: ReportPeriod,
        cursor: Date,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            byAdding: period == .month ? .month : .year,
            value: 1,
            to: periodStart(period, cursor: cursor, calendar: calendar)
        ) ?? cursor
    }
}
