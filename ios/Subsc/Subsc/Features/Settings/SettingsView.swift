import CloudKit
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationPermission = NotificationPermission.checking
    @State private var iCloudStatus = "確認中…"
    @State private var notificationError: String?

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

                Section {
                    LabeledContent("通知の状態", value: notificationPermission.title)
                    if let action = notificationPermission.action {
                        Button(action.title) { perform(action) }
                    }
                    if let notificationError {
                        Text(notificationError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("通知")
                } footer: {
                    if notificationPermission == .denied {
                        Text("通知は一度断ると、アプリからは再度お願いできません。iOSの設定アプリから許可してください。")
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
            // 設定アプリで許可を変えて戻ってきたときにも状態を取り直します。
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
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

    /// 通知の状態に応じた操作を実行します。
    private func perform(_ action: NotificationPermissionAction) {
        switch action {
        case .requestAuthorization:
            Task {
                _ = await NotificationService.requestAuthorization()
                await updateNotificationStatus()
            }
        case .openSystemSettings:
            openSystemSettings()
        }
    }

    /// 設定アプリのSubscのページを開きます。
    /// iOSは一度許可を断られると再度ダイアログを出さないため、ここからしか許可を戻せません。
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            notificationError = settingsAppFailureMessage
            return
        }
        notificationError = nil
        openURL(url) { accepted in
            if !accepted {
                notificationError = settingsAppFailureMessage
            }
        }
    }

    private var settingsAppFailureMessage: String {
        "設定アプリを開けませんでした。ホーム画面の「設定」からSubscを選んでください。"
    }

    private func updateNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationPermission = NotificationPermission(status: settings.authorizationStatus)
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
                Text("米ドル料金を円換算する場合に限り、Frankfurter APIへドル円の参考レートを問い合わせます。登録した費目名や料金は送信しません。")
            }

            Section("通知") {
                Text("更新予定の通知はiOSのローカル通知として端末内で予約します。通知は設定画面または各費目の編集画面から無効にできます。")
            }

            Section("削除") {
                Text("費目を削除すると、この端末とiCloudから対象データが削除されます。アプリ全体のデータは、iCloudのストレージ管理から削除できます。")
            }
        }
        .navigationTitle("プライバシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
