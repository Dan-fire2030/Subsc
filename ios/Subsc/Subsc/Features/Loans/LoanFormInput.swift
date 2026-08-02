import Foundation

/// 借入フォームに固有の入力エラーです。**利用者にそのまま見せられる日本語**にします。
///
/// 元金・回数・利率・リボの帯といった計算の前提は `LoanTermsError` が持っています。
/// ここに置くのは、計算まで届かない「フォームの決まりごと」だけです。
enum LoanFormError: LocalizedError, Equatable {
    case nameRequired
    case paymentDayOutOfRange
    case negativeBonusAmount

    var errorDescription: String? {
        switch self {
        case .nameRequired:
            return "借入の名前を入力してください。"
        case .paymentDayOutOfRange:
            return "返済日は1〜31で指定してください。"
        case .negativeBonusAmount:
            return "ボーナス返済額にマイナスの値は入力できません。"
        }
    }
}

/// 借入フォームが扱う入力一式です。
///
/// **ビューから切り離した値**にしています。保存前に「この設定で予定表を作れるか」を
/// 確かめる必要があり、その判定をビューに書くとテストできなくなるためです。
/// 未保存判定（`Equatable`）にもそのまま使います。
struct LoanFormInput: Equatable {
    var name: String
    var note: String
    var method: RepaymentMethod
    var interestType: InterestType
    var origin: LoanOrigin
    var annualRatePercent: Double
    var rateHistory: [LoanRateChange]
    var slidingTiers: [RevolvingTier]
    /// 「借りたときの条件から」で使う当初元本です。
    var originalPrincipal: Double
    var borrowedOn: Date
    var totalInstallments: Int
    /// 「今の残高から」で使う開始残高です。
    var startingBalance: Double
    var startingInstallments: Int
    var startedTrackingOn: Date
    var paymentDay: Int
    var bonusMonths: [Int]
    var bonusAmount: Double

    /// 新規登録の初期値です。金額と回数は空欄相当の0にして、利用者に入れてもらいます。
    static func initial(now: Date = .now) -> LoanFormInput {
        LoanFormInput(
            name: "",
            note: "",
            method: .equalPayment,
            interestType: .fixed,
            origin: .fromOrigin,
            annualRatePercent: 0,
            rateHistory: [],
            slidingTiers: [],
            originalPrincipal: 0,
            borrowedOn: now,
            totalInstallments: 0,
            startingBalance: 0,
            startingInstallments: 0,
            startedTrackingOn: now,
            paymentDay: 27,
            bonusMonths: [],
            bonusAmount: 0
        )
    }

    /// 保存済みの契約から復元します。
    static func make(from loan: Loan, now: Date = .now) -> LoanFormInput {
        LoanFormInput(
            name: loan.name,
            note: loan.note,
            method: loan.method,
            interestType: loan.interestType,
            origin: loan.origin,
            annualRatePercent: loan.annualRatePercent,
            rateHistory: loan.rateHistory,
            slidingTiers: loan.slidingTiers,
            originalPrincipal: loan.originalPrincipal,
            borrowedOn: loan.borrowedOn ?? now,
            totalInstallments: loan.totalInstallments,
            startingBalance: loan.startingBalance,
            startingInstallments: loan.startingInstallments,
            startedTrackingOn: loan.startedTrackingOn ?? now,
            paymentDay: loan.paymentDay,
            bonusMonths: loan.bonusMonths,
            bonusAmount: loan.bonusAmount
        )
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 検証

    /// 保存できる入力かを確かめます。
    ///
    /// **実際に予定表を1本作ってみます。** 元金が減らないリボの帯や、終わらない設定は
    /// 個別のルールでは拾いきれず、作ってみるのが最も確実だからです。
    /// 投げるのは `LoanFormError` か `LoanTermsError` で、どちらも日本語の説明を持ちます。
    func validate(calendar: Calendar = .current) throws {
        guard !trimmedName.isEmpty else { throw LoanFormError.nameRequired }
        guard (1...31).contains(paymentDay) else { throw LoanFormError.paymentDayOutOfRange }
        guard bonusAmount >= 0 else { throw LoanFormError.negativeBonusAmount }

        let probe = Loan(name: trimmedName)
        apply(to: probe)
        let firstDueDate = try LoanPaymentStore.firstDueDate(for: probe, calendar: calendar)
        _ = try LoanScheduleCalculator(calendar: calendar)
            .schedule(for: probe.terms(nextDueDate: firstDueDate))
    }

    // MARK: - 契約への書き戻し

    /// 契約へ書き戻します。**使わない項目は持ち込みません。**
    ///
    /// 固定金利なのに利率履歴が残っていたり、元利均等なのにリボの帯が残っていたりすると、
    /// 方式を切り替えたときに古い設定が黙って効きます。
    func apply(to loan: Loan) {
        loan.name = trimmedName
        loan.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        loan.method = method
        loan.interestType = interestType
        loan.origin = origin
        loan.annualRatePercent = annualRatePercent
        loan.rateHistory = interestType == .variable ? rateHistory : []
        loan.slidingTiers = method == .revolving ? slidingTiers : []
        loan.paymentDay = paymentDay
        loan.bonusMonths = bonusMonths
        loan.bonusAmount = bonusAmount

        switch origin {
        case .fromOrigin:
            loan.originalPrincipal = originalPrincipal
            loan.borrowedOn = borrowedOn
            loan.totalInstallments = totalInstallments
            loan.startingBalance = 0
            loan.startingInstallments = 0
            loan.startedTrackingOn = nil
        case .fromCurrentBalance:
            loan.startingBalance = startingBalance
            loan.startedTrackingOn = startedTrackingOn
            loan.startingInstallments = startingInstallments
            loan.originalPrincipal = 0
            loan.borrowedOn = nil
            loan.totalInstallments = 0
        }
        loan.updatedAt = .now
    }
}
