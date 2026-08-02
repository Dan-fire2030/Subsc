import Observation
import Foundation

/// 返済日の通知を、何日前に出すかです。
///
/// **当日では入金が間に合いません。** 口座へお金を移す必要があるためで、
/// 費目の更新日通知に「何日前」があるのと同じ理由です。
enum LoanNotificationLead: Int, CaseIterable, Identifiable {
    case sameDay = 0
    case oneDay = 1
    case threeDays = 3
    case fiveDays = 5
    case oneWeek = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sameDay: "当日"
        case .oneDay: "1日前"
        case .threeDays: "3日前"
        case .fiveDays: "5日前"
        case .oneWeek: "1週間前"
        }
    }
}

/// 返済日通知の設定です。
///
/// **契約ごとではなく、アプリ全体で1つの設定にしています。**
/// `Loan` へ項目を足すとCloudKitのフィールドが増え、Productionへの不可逆な反映が
/// もう一度必要になるためです。端末ごとの好みでもあるので、`ThemeStore` と同じく
/// `UserDefaults` に閉じます。契約ごとに変えたい要望が出てから作り直します。
@Observable
final class LoanNotificationSettings {
    enum Defaults {
        /// これまでの挙動（返済日当日）を変えないため、既定は当日にします。
        static let lead = LoanNotificationLead.sameDay
        /// **返済日は年月日しか持たないため、時刻を与えないと0時に鳴ります。**
        /// 費目の通知の既定値と揃えています。
        static let hour = 9
    }

    private enum Keys {
        static let lead = "loanNotification.leadDays"
        static let hour = "loanNotification.hour"
    }

    private let defaults: UserDefaults

    /// 何日前に出すか。
    var lead: LoanNotificationLead {
        didSet { defaults.set(lead.rawValue, forKey: Keys.lead) }
    }

    /// 通知を出す時刻（時）です。分は0に固定しています。
    var hour: Int {
        didSet { defaults.set(hour, forKey: Keys.hour) }
    }

    /// テスト時に本物の `UserDefaults` を汚さないよう、既定値つきで注入します。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 未設定と「当日（0）」を区別するため、キーの有無で判定します。
        // `integer(forKey:)` は未設定でも0を返すので、そのままでは見分けられません。
        self.lead = defaults.object(forKey: Keys.lead)
            .flatMap { $0 as? Int }
            .flatMap(LoanNotificationLead.init(rawValue:)) ?? Defaults.lead
        self.hour = defaults.object(forKey: Keys.hour)
            .flatMap { $0 as? Int }
            .flatMap { (0...23).contains($0) ? $0 : nil } ?? Defaults.hour
    }
}
