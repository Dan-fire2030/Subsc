import UserNotifications

/// 通知許可の状態です。`UNAuthorizationStatus` を、設定画面で出し分けたい単位に畳んでいます。
enum NotificationPermission: String {
    /// 問い合わせ中。まだ状態が分からない間だけ使います。
    case checking
    case notDetermined
    case authorized
    case denied
    /// 将来 iOS が値を増やした場合の受け皿です。
    case unknown

    init(status: UNAuthorizationStatus) {
        self = switch status {
        case .notDetermined: .notDetermined
        case .authorized, .provisional, .ephemeral: .authorized
        case .denied: .denied
        @unknown default: .unknown
        }
    }

    var title: String {
        switch self {
        case .checking: "確認中…"
        case .notDetermined: "未設定"
        case .authorized: "許可済み"
        case .denied: "許可されていません"
        case .unknown: "不明"
        }
    }

    /// この状態で利用者が取れる操作です。取れる操作が無い場合は `nil` を返します。
    ///
    /// iOSが通知の許可ダイアログを出すのは `notDetermined` のときだけです。
    /// 一度許可・拒否したあとに `requestAuthorization` を呼んでも画面には何も起きないため、
    /// その場合は設定アプリへ誘導します。
    var action: NotificationPermissionAction? {
        switch self {
        case .checking: nil
        case .notDetermined: .requestAuthorization
        case .authorized, .denied, .unknown: .openSystemSettings
        }
    }
}

/// 通知の状態に応じて設定画面に出すボタンです。
enum NotificationPermissionAction: String {
    case requestAuthorization
    case openSystemSettings

    var title: String {
        switch self {
        case .requestAuthorization: "通知を許可"
        case .openSystemSettings: "iOSの設定を開く"
        }
    }
}
