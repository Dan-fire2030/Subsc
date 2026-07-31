import Foundation

/// ローカル通知の識別子の名前空間です。
///
/// 更新日通知と月末リマインドは、それぞれ独立に予約し直されます。
/// 再スケジュールは「自分の名前空間の予約のうち、計画に無いものを消す」形で行うため、
/// **名前空間が混ざると片方がもう片方を全部消します。**
enum NotificationNamespace: String, CaseIterable {
    case renewal
    case reminder

    var prefix: String {
        switch self {
        case .renewal: "subsc-"
        case .reminder: "subsc-remind-"
        }
    }

    /// その識別子がこの名前空間のものかを返します。
    ///
    /// リマインドの接頭辞は更新日通知の接頭辞から始まるため、
    /// 更新日通知側では明示的に除外しないと巻き込んでしまいます。
    /// 更新日通知の接頭辞は**配布済みのビルドが予約した通知と一致させる必要がある**ので変えられません。
    func contains(_ identifier: String) -> Bool {
        switch self {
        case .renewal:
            identifier.hasPrefix(prefix)
                && !identifier.hasPrefix(NotificationNamespace.reminder.prefix)
        case .reminder:
            identifier.hasPrefix(prefix)
        }
    }
}

enum NotificationIdentifier {
    /// 更新日通知の識別子です。**書式は配布済みのビルドと同じに保ちます。**
    static func renewal(clientID: String, cycleKey: String, suffix: String) -> String {
        "\(NotificationNamespace.renewal.prefix)\(clientID)-\(cycleKey)-\(suffix)"
    }

    /// 月末リマインドの識別子です。1つの費目・1つの年月につき1件になります。
    static func reminder(clientID: String, periodKey: Int) -> String {
        "\(NotificationNamespace.reminder.prefix)\(clientID)-\(periodKey)"
    }

    /// その名前空間で、もう予約しておく必要がなくなった識別子を返します。
    static func obsolete(
        pending: [String],
        desired: Set<String>,
        in namespace: NotificationNamespace
    ) -> [String] {
        pending.filter { namespace.contains($0) && !desired.contains($0) }
    }

    /// 1つの費目に紐づく識別子を、名前空間をまたいで集めます。
    /// 費目を削除したときに、更新日通知とリマインドの両方を取り消すために使います。
    static func all(pending: [String], clientID: String) -> [String] {
        let prefixes = [
            "\(NotificationNamespace.renewal.prefix)\(clientID)-",
            "\(NotificationNamespace.reminder.prefix)\(clientID)-"
        ]
        return pending.filter { identifier in
            prefixes.contains { identifier.hasPrefix($0) }
        }
    }
}
