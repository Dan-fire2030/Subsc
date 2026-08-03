import Foundation
import SwiftData

/// 借入をどこから記録し始めるかです。
///
/// **大半の利用者は途中から登録します。** 契約書が手元に無くても始められるよう、
/// 現在の残高だけで登録する道を用意しています。
enum LoanOrigin: String, CaseIterable, Identifiable {
    /// 当初元本と借入日から、これまでの経過を逆算します。
    case fromOrigin
    /// 現在の残高と残り回数から、今日以降だけを組み立てます。
    case fromCurrentBalance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fromOrigin: "借りたときの条件から"
        case .fromCurrentBalance: "今の残高から"
        }
    }
}

/// 借金・ローンの契約です。
///
/// CloudKitミラーリングの制約に合わせ、**すべての保存プロパティに既定値かOptionalを持たせ、
/// 一意制約は使っていません**。配列は `AmountEntry` と同じくCSV文字列で保存し、
/// computed property で出し入れします。
/// 一時停止の操作が成り立たない場合です。
enum LoanPauseError: LocalizedError, Equatable {
    /// 完済したローンは止められません。止める返済が残っていないためです。
    case loanIsClosed

    var errorDescription: String? {
        switch self {
        case .loanIsClosed:
            return "完済した借入は一時停止できません。"
        }
    }
}

@Model
final class Loan {
    var clientID: String = UUID().uuidString
    /// 借入先や名称です（例：住宅ローン、奨学金、A社カードローン）。
    var name: String = ""
    var note: String = ""
    var repaymentMethodRaw: String = RepaymentMethod.equalPayment.rawValue
    var interestTypeRaw: String = InterestType.fixed.rawValue
    var originRaw: String = LoanOrigin.fromOrigin.rawValue
    /// 現在の年利（％）です。`rateHistoryCSV` に該当がない期間はこの値を使います。
    var annualRatePercent: Double = 0
    /// 変動金利の見直し履歴です。`2026-04-01:1.2,2026-10-01:1.5` の形式で保存します。
    ///
    /// **配列を直接保存するとCloudKitミラーリングが壊れます。** `leadDaysCSV` と同じ方針です。
    var rateHistoryCSV: String = ""
    /// リボ払いの残高スライドです。`300000:10000,500000:15000` の形式で保存します。
    var slidingTiersCSV: String = ""
    var originalPrincipal: Double = 0
    var borrowedOn: Date?
    var totalInstallments: Int = 0
    /// 「今の残高から」登録した場合の開始残高です。
    var startingBalance: Double = 0
    var startingInstallments: Int = 0
    var startedTrackingOn: Date?
    /// 毎月の返済日です。月末に寄せたい場合も、まずは日付で持ちます。
    var paymentDay: Int = 27
    /// ボーナス返済月です。`6,12` の形式で保存します。
    var bonusMonthsCSV: String = ""
    var bonusAmount: Double = 0
    var isClosed: Bool = false
    /// 返済を一時的に止めているかどうかです。
    ///
    /// **滞納とは別物です。** 滞納はその月の利息が残高へ繰り入れられて総利息が増えますが、
    /// 一時停止は利息を発生させず、**期日を後ろへずらすだけ**です（SPEC A-2）。
    var isPaused: Bool = false
    /// いつ停止したかです。再開時に、繰り延べる月数をここから数えます。
    ///
    /// **`isPaused` が真のときは必ず値が入ります。** 停止・再開では両方を同時に書き換えます。
    var pausedOn: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// 各回の返済です。契約を消したら返済記録も消えるよう `.cascade` にしています。
    /// CloudKitミラーリングの制約でOptionalの配列にする必要があります。
    @Relationship(deleteRule: .cascade, inverse: \LoanPayment.loan)
    var payments: [LoanPayment]?

    init(
        clientID: String = UUID().uuidString,
        name: String,
        note: String = "",
        method: RepaymentMethod = .equalPayment,
        interestType: InterestType = .fixed,
        origin: LoanOrigin = .fromOrigin,
        annualRatePercent: Double = 0,
        rateHistory: [LoanRateChange] = [],
        slidingTiers: [RevolvingTier] = [],
        originalPrincipal: Double = 0,
        borrowedOn: Date? = nil,
        totalInstallments: Int = 0,
        startingBalance: Double = 0,
        startingInstallments: Int = 0,
        startedTrackingOn: Date? = nil,
        paymentDay: Int = 27,
        bonusMonths: [Int] = [],
        bonusAmount: Double = 0
    ) {
        self.clientID = clientID
        self.name = name
        self.note = note
        self.repaymentMethodRaw = method.rawValue
        self.interestTypeRaw = interestType.rawValue
        self.originRaw = origin.rawValue
        self.annualRatePercent = annualRatePercent
        self.rateHistoryCSV = Self.encodeRateHistory(rateHistory)
        self.slidingTiersCSV = Self.encodeSlidingTiers(slidingTiers)
        self.originalPrincipal = originalPrincipal
        self.borrowedOn = borrowedOn
        self.totalInstallments = totalInstallments
        self.startingBalance = startingBalance
        self.startingInstallments = startingInstallments
        self.startedTrackingOn = startedTrackingOn
        self.paymentDay = paymentDay
        self.bonusMonthsCSV = bonusMonths.sorted().map(String.init).joined(separator: ",")
        self.bonusAmount = bonusAmount
        self.createdAt = .now
        self.updatedAt = .now
    }

    // MARK: - 型付きの値

    var method: RepaymentMethod {
        get { RepaymentMethod(rawValue: repaymentMethodRaw) ?? .equalPayment }
        set { repaymentMethodRaw = newValue.rawValue }
    }

    var interestType: InterestType {
        get { InterestType(rawValue: interestTypeRaw) ?? .fixed }
        set { interestTypeRaw = newValue.rawValue }
    }

    var origin: LoanOrigin {
        get { LoanOrigin(rawValue: originRaw) ?? .fromOrigin }
        set { originRaw = newValue.rawValue }
    }

    var bonusMonths: [Int] {
        get {
            bonusMonthsCSV
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        set { bonusMonthsCSV = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    var rateHistory: [LoanRateChange] {
        get { Self.decodeRateHistory(rateHistoryCSV) }
        set { rateHistoryCSV = Self.encodeRateHistory(newValue) }
    }

    var slidingTiers: [RevolvingTier] {
        get { Self.decodeSlidingTiers(slidingTiersCSV) }
        set { slidingTiersCSV = Self.encodeSlidingTiers(newValue) }
    }

    // MARK: - 計算への詰め替え

    /// 返済予定表を作るための入力へ詰め替えます。
    ///
    /// 「今の残高から」登録した場合は残高と残り回数を、そうでなければ当初元本と総回数を使います。
    /// **計算側は登録方式を知りません。** どちらも「元本・回数・次回返済日」に均されます。
    func terms(nextDueDate: Date) -> LoanTerms {
        let usesCurrentBalance = origin == .fromCurrentBalance
        return LoanTerms(
            principal: usesCurrentBalance ? startingBalance : originalPrincipal,
            annualRatePercent: annualRatePercent,
            interestType: interestType,
            rateChanges: rateHistory,
            installmentCount: usesCurrentBalance ? startingInstallments : totalInstallments,
            method: method,
            firstDueDate: nextDueDate,
            paymentDay: paymentDay,
            bonusMonths: bonusMonths,
            bonusAmount: bonusAmount,
            revolvingTiers: slidingTiers
        )
    }
}

// MARK: - CSVの符号化

extension Loan {
    /// `2026-04-01:1.2` を並べた形式です。日付は年月日だけを持ち、時刻は含めません。
    static func encodeRateHistory(_ changes: [LoanRateChange]) -> String {
        changes
            .sorted { $0.effectiveFrom < $1.effectiveFrom }
            .map { "\(csvDateFormatter.string(from: $0.effectiveFrom)):\($0.annualRatePercent)" }
            .joined(separator: ",")
    }

    static func decodeRateHistory(_ csv: String) -> [LoanRateChange] {
        csv
            .split(separator: ",")
            .compactMap { element -> LoanRateChange? in
                let parts = element.split(separator: ":")
                guard
                    parts.count == 2,
                    let date = csvDateFormatter.date(from: String(parts[0])),
                    let rate = Double(parts[1])
                else { return nil }
                return LoanRateChange(effectiveFrom: date, annualRatePercent: rate)
            }
            .sorted { $0.effectiveFrom < $1.effectiveFrom }
    }

    /// `300000:10000` を並べた形式です。「この残高以下ならこの定額」を表します。
    static func encodeSlidingTiers(_ tiers: [RevolvingTier]) -> String {
        tiers
            .sorted { $0.upperBalance < $1.upperBalance }
            .map { "\($0.upperBalance):\($0.monthlyPayment)" }
            .joined(separator: ",")
    }

    static func decodeSlidingTiers(_ csv: String) -> [RevolvingTier] {
        csv
            .split(separator: ",")
            .compactMap { element -> RevolvingTier? in
                let parts = element.split(separator: ":")
                guard
                    parts.count == 2,
                    let upper = Double(parts[0]),
                    let payment = Double(parts[1])
                else { return nil }
                return RevolvingTier(upperBalance: upper, monthlyPayment: payment)
            }
            .sorted { $0.upperBalance < $1.upperBalance }
    }

    /// CSVの日付だけに使う書式です。**表示には使いません。**
    /// 端末の暦や地域で保存内容が変わらないよう、固定のロケールとカレンダーを与えています。
    private static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
