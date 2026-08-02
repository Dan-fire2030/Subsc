import Foundation

/// 契約から返済予定表を組み立て、`LoanPayment` として保存します。
///
/// **同じ回が2件できないことを保証するのがこの型の役目です。**
/// CloudKitミラーリングでは `@Attribute(.unique)` を使えないため、
/// 一意性はデータベースではなくここで保つしかありません（`AmountEntryStore` と同じ方針）。
///
/// 滞納と繰上返済は**記録として先に保存され、予定表はそれを織り込んで組み直されます。**
/// つまり予定表は常に計算結果であり、実績が唯一の入力です。
enum LoanPaymentStore {
    struct SynchronizationResult: Equatable {
        /// 組み直したあとの予定表です。`period` の昇順です。
        let payments: [LoanPayment]
        /// 予定が短くなって不要になった回です。
        ///
        /// **呼び出し側が `ModelContext` から削除してください。** ここは文脈を持たないため、
        /// 関係を外すところまでしか行いません。
        let removed: [LoanPayment]

        static func == (lhs: SynchronizationResult, rhs: SynchronizationResult) -> Bool {
            lhs.payments.map(\.period) == rhs.payments.map(\.period)
                && lhs.removed.map(\.period) == rhs.removed.map(\.period)
        }
    }

    /// 返済予定表を組み直します。既存の滞納・繰上返済の記録は保たれます。
    @discardableResult
    static func synchronize(
        loan: Loan,
        calendar: Calendar = .current
    ) throws -> SynchronizationResult {
        let existing = sortedPayments(on: loan)
        let schedule = try LoanScheduleCalculator(calendar: calendar).schedule(
            for: loan.terms(nextDueDate: try firstDueDate(for: loan, calendar: calendar)),
            missedPeriods: missedPeriods(in: existing),
            prepayments: prepayments(in: existing)
        )

        var byPeriod = Dictionary(grouping: existing, by: \.period)
        var payments: [LoanPayment] = []

        for installment in schedule.installments {
            let components = calendar.dateComponents([.year, .month], from: installment.dueDate)
            let rows = byPeriod.removeValue(forKey: installment.period) ?? []

            if rows.isEmpty {
                payments.append(
                    LoanPayment(
                        year: components.year ?? 0,
                        month: components.month ?? 0,
                        period: installment.period,
                        dueOn: installment.dueDate,
                        scheduledAmount: installment.amount,
                        principalPortion: installment.principal,
                        interestPortion: installment.interest,
                        balanceAfter: installment.balanceAfter,
                        status: installment.isMissed ? .missed : .scheduled
                    )
                )
                continue
            }

            // 同期で重複していた場合も、全件を同じ値へ揃えてどれが選ばれても同じにします。
            for row in rows {
                row.year = components.year ?? 0
                row.month = components.month ?? 0
                row.dueOn = installment.dueDate
                row.scheduledAmount = installment.amount
                row.principalPortion = installment.principal
                row.interestPortion = installment.interest
                row.balanceAfter = installment.balanceAfter
                // **状態は上書きしません。** 滞納も繰上返済も利用者が記録した事実で、
                // 計算結果より優先されます。
            }
            payments.append(contentsOf: rows)
        }

        let removed = byPeriod.values.flatMap { $0 }.sorted { $0.period < $1.period }
        for row in removed {
            row.loan = nil
        }

        loan.payments = payments
        loan.updatedAt = .now
        return SynchronizationResult(payments: payments, removed: removed)
    }

    /// その回を滞納として記録します。**返済額は0になり、以降の予定が後ろへずれます。**
    @discardableResult
    static func markMissed(
        period: Int,
        on loan: Loan,
        recordedAt: Date = .now,
        calendar: Calendar = .current
    ) throws -> SynchronizationResult {
        for row in sortedPayments(on: loan) where row.period == period {
            row.status = .missed
            row.actualAmount = 0
            row.recordedAt = recordedAt
        }
        return try synchronize(loan: loan, calendar: calendar)
    }

    /// その回を返済済みとして記録します。
    ///
    /// 予定額より多い場合は**繰上返済**として扱い、上乗せぶんを全額元金へ充当します（期間短縮型）。
    @discardableResult
    static func recordPayment(
        amount: Double,
        period: Int,
        on loan: Loan,
        recordedAt: Date = .now,
        calendar: Calendar = .current
    ) throws -> SynchronizationResult {
        for row in sortedPayments(on: loan) where row.period == period {
            row.actualAmount = amount
            row.status = amount > row.scheduledAmount ? .prepaid : .paid
            row.recordedAt = recordedAt
        }
        return try synchronize(loan: loan, calendar: calendar)
    }

    /// 予定表の1回目の返済日です。
    ///
    /// 「今の残高から」なら記録を始めた月、そうでなければ借入日の翌月を起点にし、
    /// どちらも契約の返済日へ寄せます。
    static func firstDueDate(for loan: Loan, calendar: Calendar = .current) throws -> Date {
        let base: Date
        switch loan.origin {
        case .fromCurrentBalance:
            base = loan.startedTrackingOn ?? loan.createdAt
        case .fromOrigin:
            let borrowed = loan.borrowedOn ?? loan.createdAt
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: borrowed) else {
                throw LoanTermsError.scheduleDoesNotTerminate
            }
            base = nextMonth
        }

        var components = calendar.dateComponents([.year, .month], from: base)
        components.day = loan.paymentDay
        guard let dueDate = calendar.date(from: components) else {
            throw LoanTermsError.scheduleDoesNotTerminate
        }
        return dueDate
    }

    // MARK: - 補助

    static func sortedPayments(on loan: Loan) -> [LoanPayment] {
        (loan.payments ?? []).sorted { $0.period < $1.period }
    }

    private static func missedPeriods(in payments: [LoanPayment]) -> Set<Int> {
        Set(payments.filter { $0.status == .missed }.map(\.period))
    }

    /// 予定額を超えて支払った差額を、繰上返済の上乗せとして取り出します。
    private static func prepayments(in payments: [LoanPayment]) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for row in payments where row.status == .prepaid {
            let extra = (row.actualAmount ?? 0) - row.scheduledAmount
            if extra > 0 {
                result[row.period] = extra
            }
        }
        return result
    }
}
