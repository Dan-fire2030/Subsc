import Foundation

/// これから来る「大きな支払い」の1ヶ月ぶんです。
struct UpcomingChargeNotice: Identifiable, Equatable {
    var id: Int { periodKey }
    /// 年月のキーです（例：2026年10月 → 202610）。
    let periodKey: Int
    /// その月に立つ年払いの合計です。
    let total: Double
    /// 費目名です。金額の大きい順に並びます。
    let names: [String]

    var year: Int { periodKey / 100 }
    var month: Int { periodKey % 100 }
}

/// 年払いが集中する月を先に知らせるための計算です。
///
/// **年払いは更新月にだけ全額が立ちます**（`Subscription.monthlyAmount(forPeriodKey:)`）。
/// そのぶん月次レポートの合計は月によって跳ねます。実際の支出どおりではありますが、
/// 月をめくって初めて気づくと不意打ちになるため、先に出しておきます。
///
/// **月払いは対象にしません。** 毎月同じ額なので跳ねず、知らせる意味がありません。
enum UpcomingLargeCharge {
    /// 何ヶ月先まで知らせるかです。遠すぎる先は行動につながりません。
    static let horizonMonths = 3

    /// 来月から `horizonMonths` ヶ月先までのあいだに年払いが来る月を、月の早い順に返します。
    ///
    /// **今月は含めません。** すでに払ったか、これから数日で払うだけで、
    /// 表示中のレポートの合計にも出ています。
    static func notices(
        subscriptions: [Subscription],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [UpcomingChargeNotice] {
        let targets = subscriptions.filter { $0.state == .active && $0.billingCycle == .yearly }
        guard !targets.isEmpty else { return [] }

        return (1...horizonMonths).compactMap { offset in
            notice(for: offset, targets: targets, now: now, calendar: calendar)
        }
    }

    private static func notice(
        for offset: Int,
        targets: [Subscription],
        now: Date,
        calendar: Calendar
    ) -> UpcomingChargeNotice? {
        guard let monthStart = monthStart(offset: offset, from: now, calendar: calendar),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return nil
        }
        let periodKey = AmountEntry.periodKey(for: monthStart, calendar: calendar)

        let charged = targets.filter { subscription in
            guard isContracted(subscription, from: monthStart, to: monthEnd, calendar: calendar) else {
                return false
            }
            return subscription.monthlyAmount(forPeriodKey: periodKey, calendar: calendar).amount > 0
        }
        guard !charged.isEmpty else { return nil }

        let sorted = charged.sorted { $0.yenAmount > $1.yenAmount }
        return UpcomingChargeNotice(
            periodKey: periodKey,
            total: sorted.reduce(0) { $0 + $1.yenAmount },
            names: sorted.map(\.name)
        )
    }

    /// その月に契約が生きているかどうかです。集計（`ReportCalculator`）と同じ規則で判断します。
    private static func isContracted(
        _ subscription: Subscription,
        from monthStart: Date,
        to monthEnd: Date,
        calendar: Calendar
    ) -> Bool {
        if let startDate = subscription.startDate, startDate >= monthEnd { return false }
        if let endDate = subscription.endDate, endDate < monthStart { return false }
        return true
    }

    /// 今月の初日から `offset` ヶ月先の初日です。年をまたいでも `Calendar` が繰り上げます。
    private static func monthStart(offset: Int, from now: Date, calendar: Calendar) -> Date? {
        guard let thisMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) else {
            return nil
        }
        return calendar.date(byAdding: .month, value: offset, to: thisMonth)
    }
}
