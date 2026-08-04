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
    /// 表示中の期間のレポートです。
    ///
    /// 借入（`loans`）は既定で空にしています。**呼び出し側が渡さなければ従来どおり**動き、
    /// 費目だけの集計を期待している既存の呼び出しを壊しません。
    static func report(
        subscriptions: [Subscription],
        loans: [Loan] = [],
        period: ReportPeriod,
        cursor: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PaymentReport {
        let active = subscriptions.filter { subscription in
            // **停止は「今」の状態であって、過去の事実ではありません。**
            // 過ぎ去った期間からも消すと、その月に実際に払っていた記録まで
            // 無かったことになり、あとから見返した合計が変わってしまいます。
            // いつ停止したかは記録していないため、期間が過去かどうかだけで判断します。
            if subscription.state != .active,
               !isPastPeriod(period, cursor: cursor, now: now, calendar: calendar) {
                return false
            }
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

        // 停止中の借入も費目と同じ規則で扱います。**過ぎ去った期間には効かせません。**
        // 見え方を費目と揃えるため、判定の仕方も上の `active` に合わせています
        // （`pausedOn` は繰り延べの計算に使い、ここでは使いません）。
        let payingLoans = loans.filter { loan in
            guard loan.isPaused else { return true }
            return isPastPeriod(period, cursor: cursor, now: now, calendar: calendar)
        }

        let loanEntries = payingLoans.compactMap {
            loanEntry(for: $0, period: period, cursor: cursor, calendar: calendar)
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

        let combined = (entries + loanEntries)
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }

        return PaymentReport(
            total: combined.reduce(0) { $0 + $1.amount },
            entries: combined
        )
    }

    /// その期間に返済する額（元金＋利息）を1件のレポート項目にします。
    ///
    /// **滞納した月は0**になり、金額0の項目として落ちます。繰上返済した月は実績の額で計上されます。
    /// 借入には利用者が選ぶ色が無いため、種別の色をそのまま使います。
    private static func loanEntry(
        for loan: Loan,
        period: ReportPeriod,
        cursor: Date,
        calendar: Calendar
    ) -> ReportEntry? {
        let components = calendar.dateComponents([.year, .month], from: cursor)
        let year = components.year ?? 0
        let periodKey = year * 100 + (components.month ?? 0)

        let matching = LoanPaymentStore.sortedPayments(on: loan).filter { payment in
            period == .month ? payment.periodKey == periodKey : payment.year == year
        }
        guard !matching.isEmpty else { return nil }

        return ReportEntry(
            // 費目と `clientID` が衝突しても別項目として扱えるよう、接頭辞を付けます。
            id: "loan-\(loan.clientID)",
            name: loan.name,
            amount: matching.reduce(0) { $0 + $1.effectiveAmount },
            colorHex: CostType.loan.colorHex,
            costType: .loan,
            // **見込み扱いにしません。** 返済額は予定表から確定的に決まります（SPEC 7節）。
            isEstimated: false
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
                forPeriodKey: AmountEntry.periodKey(for: cursor, calendar: calendar),
                calendar: calendar
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
                forPeriodKey: AmountEntry.periodKey(for: monthCursor, calendar: calendar),
                calendar: calendar
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

    /// その期間が丸ごと過ぎ去っているかどうかです。
    ///
    /// 期間の終わり（次の期間の始まり）が今日以前なら過去とみなします。
    /// **今日を含む期間は過去に入れません。** 停止した当月まで計上すると、
    /// もう払っていない額が「今月の支出」に残ります。
    private static func isPastPeriod(
        _ period: ReportPeriod,
        cursor: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        periodEnd(period, cursor: cursor, calendar: calendar) <= calendar.startOfDay(for: now)
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
