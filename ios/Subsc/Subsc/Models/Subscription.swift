import Foundation
import SwiftData
import SwiftUI

enum SubscriptionCurrency: String, CaseIterable, Codable, Identifiable {
    case jpy = "JPY"
    case usd = "USD"

    var id: String { rawValue }
    var title: String { self == .jpy ? "日本円" : "米ドル" }
    var symbol: String { self == .jpy ? "¥" : "$" }
}

enum BillingCycle: String, CaseIterable, Codable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }
    var title: String { self == .monthly ? "月払い" : "年払い" }
}

enum SubscriptionState: String, CaseIterable, Codable, Identifiable {
    case active
    case paused

    var id: String { rawValue }
    var title: String { self == .active ? "利用中" : "停止中" }
}

/// 毎月・毎年かかる費目です。
///
/// **サブスクに限らず、通信費や光熱費などの固定費全般を表します。**
/// 名前が実態より狭いのは、SwiftDataのクラス名がそのままCloudKitのRecord Type名になるためです。
/// 改名すると既存ユーザーのデータが読めなくなるので、名前は変えません。
/// 何の費目かは `costType` で判別します。
@Model
final class Subscription {
    var clientID: String = UUID().uuidString
    var name: String = ""
    var category: String = "エンタメ"
    var costTypeRaw: String = CostType.subscription.rawValue
    /// 金額が毎月変わるかどうか。オンのとき、金額は `amountEntries` の月次実績で管理します。
    ///
    /// 種別では決まりません。通信費でも定額プランはあり、光熱費でも定額契約はあるためです。
    var hasVariableAmount: Bool = false
    var paymentMethodRaw: String = PaymentMethod.unspecified.rawValue
    var paymentMethodNote: String = ""
    var originalAmount: Double = 0
    var exchangeRate: Double = 1
    var currencyRaw: String = SubscriptionCurrency.jpy.rawValue
    var billingCycleRaw: String = BillingCycle.monthly.rawValue
    var stateRaw: String = SubscriptionState.active.rawValue
    var renewalDate: Date = Date.now
    var startDate: Date?
    var endDate: Date?
    var websiteURL: String = ""
    var notes: String = ""
    var colorHex: String = "#007AFF"
    var notificationsEnabled: Bool = true
    var notificationHour: Int = 9
    var notificationMinute: Int = 0
    var leadDaysCSV: String = "1"
    var leadHoursCSV: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// 変動費の月次実績です。費目を消したら実績も消えるよう `.cascade` にしています。
    /// CloudKitミラーリングの制約でOptionalの配列にする必要があります。
    @Relationship(deleteRule: .cascade, inverse: \AmountEntry.subscription)
    var amountEntries: [AmountEntry]?

    init(
        clientID: String = UUID().uuidString,
        name: String,
        category: String = "エンタメ",
        costType: CostType = .subscription,
        hasVariableAmount: Bool = false,
        paymentMethod: PaymentMethod = .unspecified,
        paymentMethodNote: String = "",
        originalAmount: Double,
        exchangeRate: Double = 1,
        currency: SubscriptionCurrency = .jpy,
        billingCycle: BillingCycle = .monthly,
        state: SubscriptionState = .active,
        renewalDate: Date,
        startDate: Date? = nil,
        endDate: Date? = nil,
        websiteURL: String = "",
        notes: String = "",
        colorHex: String = "#007AFF",
        notificationsEnabled: Bool = true,
        notificationHour: Int = 9,
        notificationMinute: Int = 0,
        leadDays: [Int] = [1],
        leadHours: [Int] = []
    ) {
        self.clientID = clientID
        self.name = name
        self.category = category
        self.costTypeRaw = costType.rawValue
        self.hasVariableAmount = hasVariableAmount
        self.paymentMethodRaw = paymentMethod.rawValue
        self.paymentMethodNote = paymentMethodNote
        self.originalAmount = originalAmount
        self.exchangeRate = exchangeRate
        self.currencyRaw = currency.rawValue
        self.billingCycleRaw = billingCycle.rawValue
        self.stateRaw = state.rawValue
        self.renewalDate = renewalDate
        self.startDate = startDate
        self.endDate = endDate
        self.websiteURL = websiteURL
        self.notes = notes
        self.colorHex = colorHex
        self.notificationsEnabled = notificationsEnabled
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.leadDaysCSV = leadDays.map(String.init).joined(separator: ",")
        self.leadHoursCSV = leadHours.map(String.init).joined(separator: ",")
        self.createdAt = .now
        self.updatedAt = .now
    }

    var costType: CostType {
        get { CostType(rawValue: costTypeRaw) ?? .subscription }
        set { costTypeRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRaw) ?? .unspecified }
        set { paymentMethodRaw = newValue.rawValue }
    }

    /// 月次実績を新しい年月の順に並べたものです。
    ///
    /// CloudKit同期で同じ年月が重複した場合は、読み出しと同じ規則で1件に畳みます。
    /// リレーション自体は順序を保証しないため、最後に年月で並べます。
    var sortedAmountEntries: [AmountEntry] {
        Dictionary(grouping: amountEntries ?? [], by: \.periodKey)
            .values
            .compactMap { MonthlyAmountResolver.winner(among: $0) }
            .sorted { $0.periodKey > $1.periodKey }
    }

    var currency: SubscriptionCurrency {
        get { SubscriptionCurrency(rawValue: currencyRaw) ?? .jpy }
        set { currencyRaw = newValue.rawValue }
    }

    var billingCycle: BillingCycle {
        get { BillingCycle(rawValue: billingCycleRaw) ?? .monthly }
        set { billingCycleRaw = newValue.rawValue }
    }

    var state: SubscriptionState {
        get { SubscriptionState(rawValue: stateRaw) ?? .active }
        set { stateRaw = newValue.rawValue }
    }

    var leadDays: [Int] {
        get { Self.parseCSV(leadDaysCSV) }
        set { leadDaysCSV = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    var leadHours: [Int] {
        get { Self.parseCSV(leadHoursCSV) }
        set { leadHoursCSV = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    var yenAmount: Double {
        currency == .usd ? originalAmount * exchangeRate : originalAmount
    }

    var monthlyYen: Double {
        billingCycle == .yearly ? yenAmount / 12 : yenAmount
    }

    /// その年月にいくらかかるかを、円で返します。
    ///
    /// 定額の費目は今までどおり `monthlyYen` を返し、常に実績扱いになります。
    /// 変動費は月次実績から解決します（実績 → 直近の実績で見込み → 0円）。
    ///
    /// **変動費は支払い周期で割りません。** 月ごとの実績はその月に払った額そのものだからです。
    /// そのため変動費の支払い周期は月払いに固定しています（`SubscriptionFormView` の保存時）。
    ///
    /// 換算は実績が持つ記録時のレートで行います。費目側の `exchangeRate` は最新レートで
    /// 上書きされるため、それを使うと支払い済みの月の金額が今日のレートで動いてしまいます。
    func monthlyAmount(forPeriodKey periodKey: Int) -> MonthlyAmount {
        guard hasVariableAmount else {
            return MonthlyAmount(amount: monthlyYen, source: .recorded)
        }

        return MonthlyAmountResolver.resolve(
            entries: amountEntries ?? [],
            periodKey: periodKey
        )
    }

    var color: Color { ColorHex.color(from: colorHex) }

    func nextRenewalDate(
        onOrAfter referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let anchor = calendar.startOfDay(for: renewalDate)
        let reference = calendar.startOfDay(for: referenceDate)
        let end = endDate.map { calendar.startOfDay(for: $0) }

        guard end.map({ anchor <= $0 }) ?? true else { return nil }
        if anchor >= reference {
            return end.map { anchor <= $0 ? anchor : nil } ?? anchor
        }

        let component: Calendar.Component = billingCycle == .monthly ? .month : .year
        let estimatedOffset: Int
        if billingCycle == .monthly {
            estimatedOffset = max(
                0,
                calendar.dateComponents([.month], from: anchor, to: reference).month ?? 0
            )
        } else {
            estimatedOffset = max(
                0,
                calendar.dateComponents([.year], from: anchor, to: reference).year ?? 0
            )
        }

        var offset = estimatedOffset
        var candidate = calendar.date(byAdding: component, value: offset, to: anchor)
        while let date = candidate, date < reference {
            offset += 1
            candidate = calendar.date(byAdding: component, value: offset, to: anchor)
        }

        guard let candidate else { return nil }
        return end.map { candidate <= $0 ? candidate : nil } ?? candidate
    }

    func upcomingRenewalDates(
        onOrAfter referenceDate: Date,
        limit: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard limit > 0,
              let first = nextRenewalDate(onOrAfter: referenceDate, calendar: calendar) else {
            return []
        }

        var dates = [first]

        while dates.count < limit,
              let previous = dates.last,
              let nextReference = calendar.date(byAdding: .day, value: 1, to: previous),
              let candidate = nextRenewalDate(
                onOrAfter: nextReference,
                calendar: calendar
              ) {
            dates.append(candidate)
        }
        return dates
    }

    @discardableResult
    func advanceRenewalDateIfNeeded(
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard let next = nextRenewalDate(onOrAfter: referenceDate, calendar: calendar),
              !calendar.isDate(next, inSameDayAs: renewalDate) else {
            return false
        }
        renewalDate = next
        updatedAt = .now
        return true
    }

    private static func parseCSV(_ value: String) -> [Int] {
        value
            .split(separator: ",")
            .compactMap { Int($0) }
            .sorted()
    }
}
