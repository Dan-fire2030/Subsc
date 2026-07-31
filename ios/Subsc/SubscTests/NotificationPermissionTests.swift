import UserNotifications
import XCTest
@testable import Subsc

final class NotificationPermissionTests: XCTestCase {
    func testNotDeterminedOffersTheSystemPrompt() {
        let permission = NotificationPermission(status: .notDetermined)

        XCTAssertEqual(permission, .notDetermined)
        XCTAssertEqual(permission.title, "未設定")
        XCTAssertEqual(permission.action, .requestAuthorization)
    }

    func testDeniedOffersTheSystemSettingsInsteadOfThePrompt() {
        let permission = NotificationPermission(status: .denied)

        XCTAssertEqual(permission, .denied)
        XCTAssertEqual(permission.title, "許可されていません")
        // 一度拒否されるとiOSは再度ダイアログを出さないため、設定アプリへ誘導する
        XCTAssertEqual(permission.action, .openSystemSettings)
    }

    func testAuthorizedOffersTheSystemSettingsToChangeIt() {
        let permission = NotificationPermission(status: .authorized)

        XCTAssertEqual(permission, .authorized)
        XCTAssertEqual(permission.title, "許可済み")
        XCTAssertEqual(permission.action, .openSystemSettings)
    }

    func testProvisionalAndEphemeralCountAsAuthorized() {
        XCTAssertEqual(NotificationPermission(status: .provisional), .authorized)
        XCTAssertEqual(NotificationPermission(status: .ephemeral), .authorized)
    }

    func testCheckingHasNoActionUntilTheStatusIsKnown() {
        XCTAssertEqual(NotificationPermission.checking.title, "確認中…")
        XCTAssertNil(NotificationPermission.checking.action)
    }

    func testEveryStatusMapsToAKnownPermission() {
        // 将来 iOS が値を増やしても「不明」で落とし込み、確認中のまま固まらせない
        let unknownStatus = UNAuthorizationStatus(rawValue: 999) ?? .notDetermined
        XCTAssertEqual(NotificationPermission(status: unknownStatus), .unknown)
        XCTAssertEqual(NotificationPermission.unknown.title, "不明")
        XCTAssertEqual(NotificationPermission.unknown.action, .openSystemSettings)
    }

    func testActionTitlesAreShownInJapanese() {
        XCTAssertEqual(NotificationPermissionAction.requestAuthorization.title, "通知を許可")
        XCTAssertEqual(NotificationPermissionAction.openSystemSettings.title, "iOSの設定を開く")
    }
}
