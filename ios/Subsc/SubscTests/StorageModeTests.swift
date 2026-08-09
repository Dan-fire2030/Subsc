import XCTest
@testable import Subsc

final class StorageModeTests: XCTestCase {
    func testNormalLaunchSyncsThroughCloudKit() {
        let mode = StorageMode.resolve(
            arguments: ["/path/to/Subsc"],
            environmentKeys: ["HOME", "TMPDIR"]
        )

        XCTAssertEqual(mode, .cloudKitSynced)
    }

    func testUITestingArgumentKeepsDataInMemory() {
        let mode = StorageMode.resolve(
            arguments: ["/path/to/Subsc", StorageMode.uiTestingArgument],
            environmentKeys: ["HOME"]
        )

        XCTAssertEqual(mode, .inMemory)
    }

    func testXCTestEnvironmentKeepsDataInMemory() {
        let mode = StorageMode.resolve(
            arguments: ["/path/to/Subsc"],
            environmentKeys: ["HOME", "XCTestConfigurationFilePath"]
        )

        XCTAssertEqual(mode, .inMemory)
    }

    func testAnyXCTestPrefixedVariableKeepsDataInMemory() {
        let mode = StorageMode.resolve(
            arguments: ["/path/to/Subsc"],
            environmentKeys: ["XCTestSessionIdentifier"]
        )

        XCTAssertEqual(mode, .inMemory)
    }

    /// テストホスト自身がCloudKitを要求していないことを確かめます。
    /// 署名なしビルドではiCloud entitlementが無く、CloudKitコンテナを
    /// 要求した時点でテストホストが起動に失敗するためです。
    func testHostProcessRunningTheseTestsKeepsDataInMemory() {
        XCTAssertEqual(StorageMode.resolve(), .inMemory)
    }
}

/// 画面に出すアプリ名のテストです。
///
/// **同じ取りこぼしを2度やっています。** 「Subsc」→「つきねこ」の変更で、
/// 2026-08-08にホーム画面のタイトル・設定画面のヘッダー・起動失敗時の案内の3箇所を、
/// 2026-08-09に通知設定を開けなかったときの案内の1箇所を取り残しました。
/// **4箇所目はビルド12として出荷済みです。**
/// 名前を文言へ直接書くのをやめ、出どころを1つに縛ります。
final class AppInfoTests: XCTestCase {
    /// `Info.plist` の `CFBundleDisplayName` から読めていること。
    /// **読めずに控えの値へ落ちていないこと**を、キーの存在ごと確かめます。
    func testDisplayNameComesFromTheBundle() throws {
        let fromBundle = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            "CFBundleDisplayName が読めません。ビルド設定を確認してください。"
        )

        XCTAssertEqual(AppInfo.displayName, fromBundle)
        XCTAssertEqual(
            fromBundle,
            "つきねこ",
            "表示名を変えたら、掲載文言（AppStore/Metadata-ja.md）とプライバシーポリシーも同じコミットで直すこと。"
        )
    }

    /// 旧名が残っていないこと。**利用者は「Subsc」というアプリを持っていません。**
    func testDisplayNameIsNotTheOldName() {
        XCTAssertFalse(
            AppInfo.displayName.localizedCaseInsensitiveContains("Subsc"),
            "旧アプリ名が残っています：\(AppInfo.displayName)"
        )
    }
}
