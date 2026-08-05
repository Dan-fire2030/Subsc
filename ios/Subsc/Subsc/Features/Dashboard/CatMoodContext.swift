import Foundation

/// 保存されている費目・借入から、猫の状態を決める材料を組み立てます。
///
/// **判定そのものは `CatMood.decide` に置いてあります。** ここは材料集めに徹し、
/// 「どの条件を優先するか」の判断を二重に持たないようにします。
enum CatMoodContext {
    /// 平均を取る過去の月数です。
    ///
    /// **3ヶ月にしているのは、年払いの偏りを均しつつ、季節の変化には追随できる長さだから**です。
    /// 短すぎると先月の年払い1件で基準が跳ね、長すぎると去年の暮らしと今を比べることになります。
    static let averagedMonths = 3

    static func mood(
        subscriptions: [Subscription],
        loans: [Loan],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CatMood {
        CatMood.decide(
            registrationCount: subscriptions.count + loans.count,
            monthlyTotal: total(subscriptions: subscriptions, loans: loans, cursor: now, now: now, calendar: calendar),
            recentAverage: recentAverage(
                subscriptions: subscriptions,
                loans: loans,
                now: now,
                calendar: calendar
            ),
            hasUpcomingLargeCharge: !UpcomingLargeCharge.notices(
                subscriptions: subscriptions,
                now: now,
                calendar: calendar
            ).isEmpty,
            hasUnenteredVariableCost: hasUnenteredVariableCost(
                subscriptions: subscriptions,
                now: now,
                calendar: calendar
            ),
            now: now,
            calendar: calendar
        )
    }

    /// 過去 `averagedMonths` ヶ月の平均です。**今月は含めません**（比較の相手なので）。
    ///
    /// 1ヶ月も遡れない場合は `nil` を返し、増減を語らせません。
    private static func recentAverage(
        subscriptions: [Subscription],
        loans: [Loan],
        now: Date,
        calendar: Calendar
    ) -> Double? {
        let totals = (1...averagedMonths).compactMap { offset -> Double? in
            guard let cursor = calendar.date(byAdding: .month, value: -offset, to: now) else {
                return nil
            }
            return total(
                subscriptions: subscriptions,
                loans: loans,
                cursor: cursor,
                now: now,
                calendar: calendar
            )
        }
        guard !totals.isEmpty else { return nil }
        return totals.reduce(0, +) / Double(totals.count)
    }

    private static func total(
        subscriptions: [Subscription],
        loans: [Loan],
        cursor: Date,
        now: Date,
        calendar: Calendar
    ) -> Double {
        ReportCalculator.report(
            subscriptions: subscriptions,
            loans: loans,
            period: .month,
            cursor: cursor,
            now: now,
            calendar: calendar
        ).total
    }

    /// 今月ぶんの金額をまだ入れていない変動費があるかどうかです。
    ///
    /// **見込み（直近の実績からの推定）は「入っていない」として扱います。**
    /// 見込みのまま月を終えると、その月の合計は実際に払った額と違ったまま残るためです。
    /// 停止中・終了済みの費目は入力を求めません。
    private static func hasUnenteredVariableCost(
        subscriptions: [Subscription],
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let periodKey = AmountEntry.periodKey(for: now, calendar: calendar)
        return subscriptions.contains { subscription in
            guard subscription.hasVariableAmount, subscription.state == .active else { return false }
            return subscription.monthlyAmount(forPeriodKey: periodKey, calendar: calendar).source != .recorded
        }
    }
}
