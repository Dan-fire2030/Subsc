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
