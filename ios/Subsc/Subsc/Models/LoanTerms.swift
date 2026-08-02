import Foundation

/// 返済方式です。元金均等は対象外にしています（SPEC 9節）。
enum RepaymentMethod: String, CaseIterable, Identifiable {
    /// 毎月の返済額が一定。住宅ローン・カーローン・奨学金第二種など、日本で最も一般的です。
    case equalPayment
    /// 利息なしで元本を均等に返します。奨学金第一種や分割払いがこれにあたります。
    case interestFree
    /// リボ払い（残高スライド定額）。残高の帯に応じて毎月の返済額が段階的に変わります。
    case revolving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .equalPayment: "元利均等"
        case .interestFree: "無利息"
        case .revolving: "リボ払い"
        }
    }
}

/// 金利の種別です。変動は「現在の利率で試算し、変更時に手入力」で扱います（SPEC 2節）。
enum InterestType: String, CaseIterable, Identifiable {
    case fixed
    case variable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixed: "固定金利"
        case .variable: "変動金利"
        }
    }
}

/// 変動金利の見直し履歴です。`effectiveFrom` 以降の返済に、この年利を使います。
struct LoanRateChange: Equatable, Hashable {
    let effectiveFrom: Date
    let annualRatePercent: Double

    init(effectiveFrom: Date, annualRatePercent: Double) {
        self.effectiveFrom = effectiveFrom
        self.annualRatePercent = annualRatePercent
    }
}

/// リボ払いの残高スライドの1段です。**残高が `upperBalance` 以下ならこの定額**を返します。
struct RevolvingTier: Equatable, Hashable {
    let upperBalance: Double
    let monthlyPayment: Double

    init(upperBalance: Double, monthlyPayment: Double) {
        self.upperBalance = upperBalance
        self.monthlyPayment = monthlyPayment
    }
}

/// 返済予定表を作るための入力です。
///
/// **`@Model` から切り離した純粋な値**にしています。計算をビューにも永続化にも依存させないためで、
/// `ReportCalculator` と同じ方針です。`Loan` からこの型へ詰め替えて計算します。
struct LoanTerms: Equatable {
    /// 計算を始める時点の元本です。「現在の残高から」登録した場合はその残高が入ります。
    var principal: Double
    /// 現在の年利（％）。`rateChanges` に該当がない期間はこの値を使います。
    var annualRatePercent: Double
    var interestType: InterestType
    var rateChanges: [LoanRateChange]
    /// 残りの返済回数です。リボ払いでは使いません（残高が尽きるまで続きます）。
    var installmentCount: Int
    var method: RepaymentMethod
    /// 次回の返済日です。ここを1回目として月ごとに進めます。
    var firstDueDate: Date
    /// 毎月の返済日（1〜31）です。
    ///
    /// **`firstDueDate` を月ごとに進めるだけでは足りません。** 起点が短い月に丸められていると
    /// （31日指定で2月起点なら28日）、以降ずっとその日で固定されてしまいます。
    /// 各回でこの日へ丸め直すために、意図した日を別に持ちます。
    /// 試算のように日付そのものに意味がない場合は nil で構いません。
    var paymentDay: Int?
    /// ボーナス返済月（1〜12）。該当月は `bonusAmount` を上乗せし、**全額を元金へ充当**します。
    var bonusMonths: [Int]
    var bonusAmount: Double
    var revolvingTiers: [RevolvingTier]

    init(
        principal: Double,
        annualRatePercent: Double,
        interestType: InterestType = .fixed,
        rateChanges: [LoanRateChange] = [],
        installmentCount: Int,
        method: RepaymentMethod = .equalPayment,
        firstDueDate: Date,
        paymentDay: Int? = nil,
        bonusMonths: [Int] = [],
        bonusAmount: Double = 0,
        revolvingTiers: [RevolvingTier] = []
    ) {
        self.principal = principal
        self.annualRatePercent = annualRatePercent
        self.interestType = interestType
        self.rateChanges = rateChanges
        self.installmentCount = installmentCount
        self.method = method
        self.firstDueDate = firstDueDate
        self.paymentDay = paymentDay
        self.bonusMonths = bonusMonths
        self.bonusAmount = bonusAmount
        self.revolvingTiers = revolvingTiers
    }
}

extension Calendar {
    /// その月の指定日です。**月末が短い月は末日へ丸めます。**
    ///
    /// `date(from:)` は存在しない日付を翌月へ送ります（2026年2月31日 → 3月3日）。
    /// そのまま使うと、返済日を31日にした契約の日付が3日へずれ、以降ずっとそのままになります。
    /// 日本のローンの実務でも、短い月は末日に寄せます。
    func dueDate(inMonthOf base: Date, day: Int) -> Date? {
        var components = dateComponents([.year, .month], from: base)
        components.day = 1
        guard
            let monthStart = date(from: components),
            let range = range(of: .day, in: .month, for: monthStart)
        else {
            return nil
        }
        components.day = min(max(day, 1), range.count)
        return date(from: components)
    }
}

/// 入力が返済予定表を作れない場合の理由です。**利用者にそのまま見せられる日本語**にします。
enum LoanTermsError: LocalizedError, Equatable {
    case principalMustBePositive
    case installmentCountMustBePositive
    case negativeInterestRate
    case revolvingTiersMissing
    /// リボ払いで、利息が定額を食い尽くして元金が減らない帯があります。
    case revolvingPaymentDoesNotReducePrincipal(balance: Double)
    case bonusMonthOutOfRange(Int)
    /// 返済が終わらないまま上限回数に達しました。設定の取り違えを疑います。
    case scheduleDoesNotTerminate

    var errorDescription: String? {
        switch self {
        case .principalMustBePositive:
            return "借入額は0より大きい金額を入力してください。"
        case .installmentCountMustBePositive:
            return "返済回数は1回以上を入力してください。"
        case .negativeInterestRate:
            return "金利にマイナスの値は入力できません。"
        case .revolvingTiersMissing:
            return "リボ払いでは、残高に応じた毎月の返済額を1つ以上設定してください。"
        case let .revolvingPaymentDoesNotReducePrincipal(balance):
            let amount = balance.formatted(.currency(code: "JPY").precision(.fractionLength(0)))
            return "残高\(amount)のときの返済額が利息を下回っており、残高が減りません。返済額を上げてください。"
        case let .bonusMonthOutOfRange(month):
            return "ボーナス返済月は1〜12で指定してください（\(month)が指定されています）。"
        case .scheduleDoesNotTerminate:
            return "この設定では返済が終わりません。金利と返済額を確認してください。"
        }
    }
}
