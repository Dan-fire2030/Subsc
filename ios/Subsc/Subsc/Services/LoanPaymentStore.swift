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
            deferredPeriods: deferredPeriods(in: existing),
            prepayments: prepayments(in: existing)
        )

        var byPeriod = Dictionary(grouping: existing, by: \.period)
        var payments: [LoanPayment] = []
        // **何か1つでも実際に変えたか**を持ち回ります。詳細は末尾の `updatedAt` の項を参照。
        var didChange = false
        var hasNewRows = false

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
                        status: Self.status(for: installment)
                    )
                )
                hasNewRows = true
                continue
            }

            // 同期で重複していた場合も、全件を同じ値へ揃えてどれが選ばれても同じにします。
            for row in rows {
                if apply(installment, components: components, to: row) {
                    didChange = true
                }
            }
            payments.append(contentsOf: rows)
        }

        let removed = byPeriod.values.flatMap { $0 }.sorted { $0.period < $1.period }
        for row in removed {
            row.loan = nil
        }

        // **関係を組み直すのは、顔ぶれが変わったときだけです。**
        // 同じ顔ぶれを入れ直すのも書き込みとして扱われます。
        if hasNewRows || !removed.isEmpty {
            loan.payments = payments
            didChange = true
        }

        // **完済したかどうかをここで確定させます。** 記録を取り消して返済が復活したときは
        // false へ戻ります。
        if updateClosedState(of: loan) {
            didChange = true
        }

        // **変わっていないなら `updatedAt` を進めません（2026-08-08）。**
        // ここを無条件に書いていたため、アプリが無限に回りました。`RootView` は
        // `.task(id:)` の鍵に `Loan.updatedAt` を含めており、そのタスクの中から
        // ここが呼ばれます。毎回書くと鍵が変わってタスクが再発火し、また書く、
        // という循環になります（停止中の借入が1件でもあれば必ず起きます）。
        //
        // 書き込みを減らすためではなく、**`updatedAt` は「変わった」という意味の値**
        // だからです。変わっていないのに進めると、CloudKitへ無意味な同期も流れます。
        if didChange {
            loan.updatedAt = .now
        }
        return SynchronizationResult(payments: payments, removed: removed)
    }

    /// 計算結果を1回ぶんの記録へ写します。**値が違うときだけ書き、書いたかどうかを返します。**
    ///
    /// 同じ値でも代入すればSwiftDataは変更として扱うため、「書かない」ことに意味があります。
    ///
    /// **状態（`status`）は写しません。** 滞納も繰上返済も利用者が記録した事実で、
    /// 計算結果より優先されます。
    private static func apply(
        _ installment: LoanInstallment,
        components: DateComponents,
        to row: LoanPayment
    ) -> Bool {
        // 短絡評価で書き漏らさないよう、**全項目を先に評価してから**まとめます。
        let changes = [
            assign(components.year ?? 0, to: \.year, on: row),
            assign(components.month ?? 0, to: \.month, on: row),
            assign(Optional(installment.dueDate), to: \.dueOn, on: row),
            assign(installment.amount, to: \.scheduledAmount, on: row),
            assign(installment.principal, to: \.principalPortion, on: row),
            assign(installment.interest, to: \.interestPortion, on: row),
            assign(installment.balanceAfter, to: \.balanceAfter, on: row)
        ]
        return changes.contains(true)
    }

    /// 値が違うときだけ書き、書いたかどうかを返します。
    private static func assign<Root: AnyObject, Value: Equatable>(
        _ value: Value,
        to keyPath: ReferenceWritableKeyPath<Root, Value>,
        on object: Root
    ) -> Bool {
        guard object[keyPath: keyPath] != value else { return false }
        object[keyPath: keyPath] = value
        return true
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

    /// その回の記録を取り消し、予定へ戻します。
    ///
    /// **通知のボタンは押し間違えます。** 「滞納」を誤って選ぶと以降の予定が丸ごと後ろへずれるため、
    /// 取り消せる道が要ります。取り消すと予定表は計算しなおされ、ずれも元に戻ります。
    @discardableResult
    static func clearRecord(
        period: Int,
        on loan: Loan,
        calendar: Calendar = .current
    ) throws -> SynchronizationResult {
        for row in sortedPayments(on: loan) where row.period == period {
            row.status = .scheduled
            // nil は「予定どおり」の意味です。0（実績として0円）と混ぜません。
            row.actualAmount = nil
            row.recordedAt = nil
        }
        return try synchronize(loan: loan, calendar: calendar)
    }

    // MARK: - 一時停止

    /// 返済を一時的に止めます。
    ///
    /// **滞納として記録するのではありません。** 停止中の月は利息を発生させず、
    /// 期日を後ろへずらすだけです（SPEC A-2）。実際の繰り延べは、返済日を跨ぐたびに
    /// `deferPastDue` が1回ぶんずつ記録します。
    static func pause(loan: Loan, on date: Date = .now, calendar: Calendar = .current) throws {
        // **完済したローンは止められません。** 止める返済が残っていないためです。
        guard !loan.isClosed else { throw LoanPauseError.loanIsClosed }
        guard !loan.isPaused else { return }

        loan.isPaused = true
        loan.pausedOn = date
        loan.updatedAt = .now
    }

    /// 返済を再開します。
    ///
    /// 停止中に跨いだ返済日を繰り延べとして記録してから、予定表を組み直します。
    /// **順序を逆にしてはいけません。** 先に停止を解除すると、跨いだ月が
    /// `settlePastDue` によって「返済済み」になってしまいます。
    @discardableResult
    static func resume(
        loan: Loan,
        on date: Date = .now,
        calendar: Calendar = .current
    ) throws -> SynchronizationResult {
        let result = try deferPastDue(on: loan, now: date, calendar: calendar)
        // **両方を同時に消します。** 片方だけ残ると「停止中なのに開始日が無い」状態になります。
        loan.isPaused = false
        loan.pausedOn = nil
        loan.updatedAt = .now
        return result
    }

    /// 停止中に返済日を過ぎた回を、繰り延べとして記録します。
    ///
    /// `settlePastDue` の停止中版です。同じ「過ぎた回を処理する」形にすることで、
    /// 停止したまま何ヶ月も放置されても、開くたびに正しい回数ぶんが繰り延べられます。
    ///
    /// **停止した日より前に返済日が来ていた回は対象外です。** 止める前に期限が来ていた返済まで
    /// 遡って繰り延べると、停止が過去へ効いてしまいます。それらは停止していない期間の
    /// 未処理分なので、`settlePastDue` の担当です。
    @discardableResult
    static func deferPastDue(
        on loan: Loan,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> SynchronizationResult {
        guard loan.isPaused, let pausedOn = loan.pausedOn else {
            return try synchronize(loan: loan, calendar: calendar)
        }

        let passed = sortedPayments(on: loan).filter { payment in
            guard payment.status == .scheduled, let dueOn = payment.dueOn else { return false }
            return dueOn >= pausedOn && dueOn <= now
        }
        for payment in passed {
            payment.status = .deferred
            // 予定どおり返したわけではないので、実績は残しません。
            payment.actualAmount = nil
        }
        // 繰り延べた回は元金を返さないため、**予定表の末尾が延びます。** 組み直して反映します。
        return try synchronize(loan: loan, calendar: calendar)
    }

    /// 返済日を過ぎた回を、返済済みとして扱います。
    ///
    /// **何もしなければ予定どおり返済されたものとします。** 毎月の入力を求めると続かないためです。
    /// `actualAmount` は nil のままにし、「実績0円」と区別できる状態を保ちます。
    /// 滞納・繰上返済として記録済みの回には触れません。
    ///
    /// **停止中は何もしません。** 進めてしまうと、止めているあいだに返済済みが積み上がり、
    /// 一時停止が無意味になります。停止中の繰り延べは `deferPastDue` が担います。
    @discardableResult
    static func settlePastDue(on loan: Loan, now: Date = .now) -> [LoanPayment] {
        guard !loan.isPaused else { return [] }

        let settled = sortedPayments(on: loan).filter { payment in
            guard payment.status == .scheduled, let dueOn = payment.dueOn else { return false }
            return dueOn <= now
        }
        for payment in settled {
            payment.status = .paid
        }
        // 最後の回がここで返済済みになることがあります。**予定表を組み直さない経路**なので、
        // 完済の判定もここで更新しないと、`isClosed` が古いまま残ります。
        updateClosedState(of: loan)
        return settled
    }

    /// 予定が1回も残っていなければ完済とみなします。
    ///
    /// **判定はこの1箇所に閉じます。** 完済かどうかを画面ごとに数え直すと、
    /// 記録を取り消したときに戻し忘れが起きます。
    ///
    /// **停止中の回が残っているあいだは完済にしません。** 繰り延べを記録した直後は
    /// 予定を組み直すまで `scheduled` が一時的に0件になり得るため、
    /// これが無いと止めた瞬間に完済扱いへ倒れます。
    /// **値が変わったときだけ書き、書いたかどうかを返します。**
    /// 同じ値でも代入すればSwiftDataは変更として扱い、`synchronize` が
    /// 「変わった」と誤って判断してしまいます。
    @discardableResult
    private static func updateClosedState(of loan: Loan) -> Bool {
        let payments = sortedPayments(on: loan)
        let isClosed = !payments.isEmpty
            && payments.allSatisfy { $0.status != .scheduled && $0.status != .deferred }
        return assign(isClosed, to: \.isClosed, on: loan)
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

        guard let dueDate = calendar.dueDate(inMonthOf: base, day: loan.paymentDay) else {
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

    private static func deferredPeriods(in payments: [LoanPayment]) -> Set<Int> {
        Set(payments.filter { $0.status == .deferred }.map(\.period))
    }

    /// 新しく作る回の状態です。**計算結果から素直に決まる分だけ**を扱います。
    /// 既存の回の状態は上書きしません（利用者が記録した事実が優先されます）。
    private static func status(for installment: LoanInstallment) -> LoanPaymentStatus {
        if installment.isMissed { return .missed }
        if installment.isDeferred { return .deferred }
        return .scheduled
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
