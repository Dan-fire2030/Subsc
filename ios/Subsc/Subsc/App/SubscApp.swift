import SwiftData
import SwiftUI

enum CloudSyncConfiguration {
    static let containerIdentifier = "iCloud.com.tonaria.subsc"
}

@main
struct SubscApp: App {
    private let modelContainer: ModelContainer
    private let startupError: String?

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let configuration = if isUITesting {
            ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            ModelConfiguration(
                cloudKitDatabase: .private(CloudSyncConfiguration.containerIdentifier)
            )
        }

        do {
            modelContainer = try ModelContainer(
                for: Subscription.self,
                configurations: configuration
            )
            startupError = nil
        } catch {
            do {
                let recoveryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(
                    for: Subscription.self,
                    configurations: recoveryConfiguration
                )
                startupError = error.localizedDescription
            } catch {
                fatalError("復旧用データ領域の初期化に失敗しました: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let startupError {
                    StartupFailureView(errorDescription: startupError)
                } else {
                    RootView()
                }
            }
            .modelContainer(modelContainer)
        }
    }
}

private struct StartupFailureView: View {
    let errorDescription: String

    var body: some View {
        ContentUnavailableView {
            Label("データを開けませんでした", systemImage: "exclamationmark.icloud.fill")
        } description: {
            Text("iCloudの状態を確認して、Subscを再起動してください。データが削除されることはありません。")
        } actions: {
            Text(errorDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
