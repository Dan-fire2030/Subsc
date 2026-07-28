import Foundation

struct ReportEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Double
    let colorHex: String
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
               startDate > periodEnd(period, cursor: cursor, calendar: calendar) {
                return false
            }
            if let endDate = subscription.endDate,
               endDate < periodStart(period, cursor: cursor, calendar: calendar) {
                return false
            }
            return true
        }

        let entries = active.map { subscription in
            ReportEntry(
                id: subscription.clientID,
                name: subscription.name,
                amount: period == .month
                    ? subscription.monthlyYen
                    : annualAmount(subscription, cursor: cursor, calendar: calendar),
                colorHex: subscription.colorHex
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

    private static func annualAmount(
        _ subscription: Subscription,
        cursor: Date,
        calendar: Calendar
    ) -> Double {
        let year = calendar.component(.year, from: cursor)
        let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? cursor
        let nextYear = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? cursor
        let activeStart = max(subscription.startDate ?? yearStart, yearStart)
        let endDateExclusive = subscription.endDate.flatMap {
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))
        } ?? nextYear
        let activeEnd = min(endDateExclusive, nextYear)
        guard activeStart < activeEnd else { return 0 }

        guard var monthCursor = calendar.date(
            from: calendar.dateComponents([.year, .month], from: activeStart)
        ) else {
            return 0
        }

        var months = 0
        while monthCursor < activeEnd {
            months += 1
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor) else {
                break
            }
            monthCursor = nextMonth
        }

        return subscription.monthlyYen * Double(months)
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
