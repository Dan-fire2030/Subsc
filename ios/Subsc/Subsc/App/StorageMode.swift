import Foundation
import SwiftData

/// アプリ起動時に選ぶデータ保存方式です。
///
/// テスト実行中はCloudKitへミラーリングしません。テストホストは署名なしで
/// 起動されることがあり、iCloud entitlementを持たない状態でCloudKitコンテナを
/// 要求するとCore Dataが起動処理の途中で停止します。併せて、テストが実行者本人の
/// iCloudプライベートデータベースへ書き込むことも防ぎます。
enum StorageMode: Equatable {
    /// CloudKitのプライベートデータベースへミラーリングする通常起動です。
    case cloudKitSynced
    /// 端末内の一時領域だけを使う起動です。テスト専用です。
    case inMemory
}

extension StorageMode {
    /// UIテストがアプリへ渡す起動引数です。
    static let uiTestingArgument = "-ui-testing"

    /// XCTestがテストホストのプロセス環境へ加える変数の接頭辞です。
    /// `XCTestConfigurationFilePath`や`XCTestSessionIdentifier`が該当します。
    private static let xcTestEnvironmentPrefix = "XCTest"

    static func resolve(processInfo: ProcessInfo = .processInfo) -> StorageMode {
        resolve(
            arguments: processInfo.arguments,
            environmentKeys: Set(processInfo.environment.keys)
        )
    }

    static func resolve(arguments: [String], environmentKeys: Set<String>) -> StorageMode {
        let isUITesting = arguments.contains(uiTestingArgument)
        let isUnitTesting = environmentKeys.contains { $0.hasPrefix(xcTestEnvironmentPrefix) }
        return isUITesting || isUnitTesting ? .inMemory : .cloudKitSynced
    }

    func modelConfiguration(cloudKitContainerIdentifier: String) -> ModelConfiguration {
        switch self {
        case .cloudKitSynced:
            ModelConfiguration(cloudKitDatabase: .private(cloudKitContainerIdentifier))
        case .inMemory:
            ModelConfiguration(isStoredInMemoryOnly: true)
        }
    }
}
