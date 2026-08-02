import SwiftData
import SwiftUI

enum CloudSyncConfiguration {
    static let containerIdentifier = "iCloud.com.tonaria.subsc"
}

@main
struct SubscApp: App {
    private let modelContainer: ModelContainer
    private let startupError: String?
    @State private var theme = ThemeStore()

    init() {
        let configuration = StorageMode.resolve().modelConfiguration(
            cloudKitContainerIdentifier: CloudSyncConfiguration.containerIdentifier
        )

        do {
            // **モデルはすべて明示します。** リレーション経由で暗黙に引き込まれることに頼ると、
            // 参照を外した瞬間にスキーマから静かに消え、保存できなくなります。
            modelContainer = try ModelContainer(
                for: Subscription.self, AmountEntry.self, Loan.self, LoanPayment.self,
                configurations: configuration
            )
            startupError = nil
        } catch {
            do {
                let recoveryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(
                    for: Subscription.self, AmountEntry.self, Loan.self, LoanPayment.self,
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
            .environment(theme)
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
