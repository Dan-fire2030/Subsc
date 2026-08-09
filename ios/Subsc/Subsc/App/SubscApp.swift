import SwiftData
import SwiftUI
import UserNotifications

enum CloudSyncConfiguration {
    static let containerIdentifier = "iCloud.com.tonaria.subsc"
}

/// アプリ自身についての情報です。
enum AppInfo {
    /// 端末上の表示名です。
    ///
    /// **画面の文言へアプリ名を直接書きません。** 同じ取りこぼしを2度やっているためです。
    /// 「Subsc」→「つきねこ」の変更で、2026-08-08にホーム画面のタイトル・設定画面のヘッダー・
    /// 起動失敗時の案内の3箇所を、2026-08-09に通知設定を開けなかったときの案内の1箇所を
    /// 取り残しました。**4箇所目はビルド12として出荷済みです。**
    ///
    /// 出どころを `Info.plist` の `CFBundleDisplayName` ただ1つに縛れば、
    /// 名前を変えたときに書き換えるのはビルド設定だけで済みます。
    static let displayName: String = {
        // `CFBundleDisplayName` が無いビルド設定でも空文字を出さないよう、名前へ順に落とします。
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let name = Bundle.main.object(forInfoDictionaryKey: key) as? String,
               !name.isEmpty {
                return name
            }
        }
        return "つきねこ"
    }()
}

@main
struct SubscApp: App {
    private let modelContainer: ModelContainer
    private let startupError: String?
    @State private var theme = ThemeStore()
    @State private var loanNotificationSettings = LoanNotificationSettings()
    /// チュートリアルを出すかどうかです。`UserDefaults` に閉じており、
    /// **CloudKitのスキーマには影響しません。**
    @State private var onboarding = OnboardingStore()
    /// 通知の受け口です。**強参照で持ち続けないと、`delegate` が解放されて応答が届きません。**
    @State private var notificationResponder: LoanNotificationResponder?

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
            .environment(loanNotificationSettings)
            .environment(onboarding)
            .task {
                // **予約より先にカテゴリを登録しないと、通知にボタンが出ません。**
                NotificationService.registerCategories()
                let responder = LoanNotificationResponder(modelContainer: modelContainer)
                notificationResponder = responder
                UNUserNotificationCenter.current().delegate = responder
            }
        }
    }
}

private struct StartupFailureView: View {
    let errorDescription: String

    var body: some View {
        ContentUnavailableView {
            Label("データを開けませんでした", systemImage: "exclamationmark.icloud.fill")
        } description: {
            Text("iCloudの状態を確認して、\(AppInfo.displayName)を再起動してください。データが削除されることはありません。")
        } actions: {
            Text(errorDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
