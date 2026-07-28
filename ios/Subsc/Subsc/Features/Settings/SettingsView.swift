import CloudKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var notificationStatus = "確認中…"
    @State private var iCloudStatus = "確認中…"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "creditcard.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(
                                .blue.gradient,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(.white.opacity(0.58), lineWidth: 0.8)
                            }
                            .shadow(color: .blue.opacity(0.25), radius: 10, y: 5)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Subsc")
                                .font(.headline)
                            Text("SwiftUI ネイティブ版")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .glassListRow()

                Section {
                    LabeledContent("保存先", value: "iCloud")
                    LabeledContent("同期の状態", value: iCloudStatus)
                } header: {
                    Text("データ")
                } footer: {
                    Text("データはこのiPhoneにも保存され、オフラインでも利用できます。iCloud接続時に同じApple IDの端末へ自動同期します。")
                }
                .glassListRow()

                Section("通知") {
                    LabeledContent("通知の状態", value: notificationStatus)
                    Button("通知を許可") {
                        Task {
                            _ = await NotificationService.requestAuthorization()
                            await updateNotificationStatus()
                        }
                    }
                }
                .glassListRow()

                Section("アプリ情報") {
                    NavigationLink("プライバシーについて") {
                        PrivacyPolicyView()
                    }
                    LabeledContent("バージョン", value: appVersion)
                }
                .glassListRow()
            }
            .liquidGlassScreen()
            .navigationTitle("設定")
            .task {
                async let notificationUpdate: Void = updateNotificationStatus()
                async let iCloudUpdate: Void = updateICloudStatus()
                _ = await (notificationUpdate, iCloudUpdate)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "—"
        return "\(version)（\(build)）"
    }

    private func updateNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "許可済み"
        case .denied: "許可されていません"
        case .notDetermined: "未設定"
        @unknown default: "不明"
        }
    }

    private func updateICloudStatus() async {
        do {
            let status = try await CKContainer(
                identifier: CloudSyncConfiguration.containerIdentifier
            ).accountStatus()

            iCloudStatus = switch status {
            case .available: "同期可能"
            case .noAccount: "未サインイン"
            case .restricted: "利用制限中"
            case .couldNotDetermine: "確認できません"
            case .temporarilyUnavailable: "一時的に利用不可"
            @unknown default: "不明"
            }
        } catch {
            iCloudStatus = "確認できません"
        }
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("保存する情報") {
                Text("登録したサービス名、料金、契約日、通知設定、メモなどは、このiPhoneとユーザー自身のiCloudプライベートデータベースに保存されます。開発者がこれらの内容を閲覧する仕組みはありません。")
            }

            Section("外部通信") {
                Text("米ドル料金を円換算する場合に限り、Frankfurter APIへドル円の参考レートを問い合わせます。登録したサブスク名や料金は送信しません。")
            }

            Section("通知") {
                Text("更新予定の通知はiOSのローカル通知として端末内で予約します。通知は設定画面または各サブスクの編集画面から無効にできます。")
            }

            Section("削除") {
                Text("サブスクを削除すると、この端末とiCloudから対象データが削除されます。アプリ全体のデータは、iCloudのストレージ管理から削除できます。")
            }
        }
        .navigationTitle("プライバシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
