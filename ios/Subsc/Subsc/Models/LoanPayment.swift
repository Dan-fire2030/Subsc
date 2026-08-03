import Foundation
import SwiftData

/// 各回の返済がどうなったかです。
enum LoanPaymentStatus: String, CaseIterable, Identifiable {
    /// これから返す回です。**何もしなければ予定どおり返済されたものとして扱います。**
    case scheduled
    case paid
    /// 滞納。その月の返済額は0になり、以降の予定が後ろへずれます。
    case missed
    /// 繰上返済。上乗せぶんは全額が元金へ充当されます。
    case prepaid
    /// 一時停止で飛ばした月です。**滞納と違い、利息は発生しません**（SPEC A-2）。
    ///
    /// 繰り延べをここに記録するのは、予定表が常に計算結果で、実績だけが入力だからです。
    /// `LoanPayment.dueOn` を直接書き換えても、次の `synchronize` で作り直されて消えます。
    case deferred

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scheduled: "予定"
        case .paid: "返済済み"
        case .missed: "滞納"
        case .prepaid: "繰上返済"
        case .deferred: "停止中"
        }
    }
}

/// 1回分の返済です。契約から作った予定表を保存し、実績で上書きします。
///
/// CloudKitミラーリングの制約に合わせ、**すべての保存プロパティに既定値かOptionalを持たせ、
/// 一意制約は使っていません**。同じ回が2件できないことは、保存時に既存を探して
/// 上書きすることで保ちます（`AmountEntry` と同じ方針）。
@Model
final class LoanPayment {
    var clientID: String = UUID().uuidString
    var year: Int = 0
    var month: Int = 0
    /// 1回目の返済日から数えて何ヶ月目かです。**滞納した月も1つ消費します。**
    var period: Int = 0
    var dueOn: Date?
    /// 予定額（元金＋利息）です。
    var scheduledAmount: Double = 0
    /// 実際に支払った額です。**nil なら予定どおり**という意味で、0円とは区別します。
    var actualAmount: Double?
    var principalPortion: Double = 0
    var interestPortion: Double = 0
    var balanceAfter: Double = 0
    var statusRaw: String = LoanPaymentStatus.scheduled.rawValue
    var recordedAt: Date?
    /// 逆リレーション。CloudKitミラーリングはリレーションを非Optionalにできないため Optional です。
    var loan: Loan?

    init(
        clientID: String = UUID().uuidString,
        year: Int,
        month: Int,
        period: Int,
        dueOn: Date? = nil,
        scheduledAmount: Double = 0,
        actualAmount: Double? = nil,
        principalPortion: Double = 0,
        interestPortion: Double = 0,
        balanceAfter: Double = 0,
        status: LoanPaymentStatus = .scheduled,
        recordedAt: Date? = nil
    ) {
        self.clientID = clientID
        self.year = year
        self.month = month
        self.period = period
        self.dueOn = dueOn
        self.scheduledAmount = scheduledAmount
        self.actualAmount = actualAmount
        self.principalPortion = principalPortion
        self.interestPortion = interestPortion
        self.balanceAfter = balanceAfter
        self.statusRaw = status.rawValue
        self.recordedAt = recordedAt
    }

    var status: LoanPaymentStatus {
        get { LoanPaymentStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    /// レポートへ計上する金額です。
    /// **滞納した月と停止中の月は0**、実績があればその額、無ければ予定額です。
    var effectiveAmount: Double {
        if status == .missed || status == .deferred { return 0 }
        return actualAmount ?? scheduledAmount
    }

    /// 並べ替えと比較に使う、年月を1つの整数にした値です（例：2026年7月 → 202607）。
    var periodKey: Int { year * 100 + month }
}
