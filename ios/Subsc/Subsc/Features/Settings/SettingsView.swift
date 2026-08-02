import CloudKit
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(LoanNotificationSettings.self) private var loanNotificationSettings
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notificationPermission = NotificationPermission.checking
    @State private var iCloudStatus = "確認中…"
    @State private var notificationError: String?
    @State private var showsThemeResetConfirmation = false

    /// 返済日通知の設定です。
    ///
    /// **契約ごとではなくアプリ全体の設定にしています。** `Loan` へ項目を足すと
    /// CloudKitのフィールドが増え、Productionへの不可逆な反映がもう一度必要になるためです。
    private var loanNotificationSection: some View {
        @Bindable var settings = loanNotificationSettings

        return Section {
            Picker("知らせるタイミング", selection: $settings.lead) {
                ForEach(LoanNotificationLead.allCases) { lead in
                    Text(lead.title).tag(lead)
                }
            }
            .accessibilityIdentifier("loan-notification-lead-picker")

            Picker("知らせる時刻", selection: $settings.hour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text("\(hour)時").tag(hour)
                }
            }
        } header: {
            Text("借入・ローンの返済日")
        } footer: {
            Text(
                settings.lead == .sameDay
                    ? "返済日の当日に知らせます。口座への入金が要る場合は、何日か前に寄せておくと間に合います。"
                    : "返済日の\(settings.lead.title)に知らせます。"
            )
        }
        .glassListRow()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        // ホーム画面と同じアイコンを出します。別の絵を描くと、
                        // どのアプリの設定なのかが一目で結びつかなくなります。
                        Image("AppIconPreview")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(.primary.opacity(0.12), lineWidth: 0.8)
                            }
                            .accessibilityHidden(true)
                        Text("Subsc")
                            .font(.headline)
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

                loanNotificationSection

                Section("テーマ") {
                    NavigationLink {
                        ThemeColorPickerView.buttonColor()
                    } label: {
                        ThemeColorSettingLabel(
                            title: "ボタンの色",
                            color: theme.buttonColor,
                            colorName: theme.buttonColorName
                        )
                    }

                    NavigationLink {
                        ThemeColorPickerView.cardColor()
                    } label: {
                        ThemeColorSettingLabel(
                            title: "カードの色",
                            color: theme.cardBaseColor,
                            colorName: theme.cardColorName
                        )
                    }

                    NavigationLink {
                        ReportChartStylePickerView()
                    } label: {
                        LabeledContent("グラフの表示") {
                            Text(theme.chartStyle.title)
                        }
                    }

                    if !theme.isDefault {
                        Button("既定に戻す", role: .destructive) {
                            showsThemeResetConfirmation = true
                        }
                    }
                }
                .glassListRow()

                // 借入シミュレーターは**登録していなくても試せる**ため、
                // 契約の詳細画面ではなくここに置いています。
                Section {
                    LoanSimulationLink(
                        title: "借入シミュレーター",
                        systemImage: CostType.loan.systemImage
                    ) {
                        LoanBorrowingSimulatorView()
                    }
                } header: {
                    Text("ツール")
                } footer: {
                    Text("借入額・年利・返済回数から毎月の返済額を試算します。登録は要りません。")
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
            // 設定画面はテーマ色に追従させません。色を選んでいる最中に
            // 画面自身の色まで動くと、何を変えているのか分かりにくくなるためです。
            .tint(ThemeStore.fixedButtonColor)
            .alert("テーマを既定に戻しますか？", isPresented: $showsThemeResetConfirmation) {
                Button("戻す", role: .destructive) {
                    theme.resetToDefaults()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("ボタンとカードの色、グラフの表示が、すべて既定に戻ります。")
            }
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

private struct ThemeColorSettingLabel: View {
    private enum Layout {
        static let colorCircleSize: CGFloat = 12
        static let borderWidth: CGFloat = 0.8
        static let colorNameSpacing: CGFloat = 7
    }

    let title: String
    let color: Color
    let colorName: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: Layout.colorNameSpacing) {
                Circle()
                    .fill(color)
                    .frame(width: Layout.colorCircleSize, height: Layout.colorCircleSize)
                    .overlay {
                        Circle()
                            .stroke(.primary.opacity(0.18), lineWidth: Layout.borderWidth)
                    }
                    .accessibilityHidden(true)
                Text(colorName)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("保存する情報") {
                Text("登録した費目名、料金、契約日、通知設定、メモと、借入の条件・返済の記録は、このiPhoneとユーザー自身のiCloudプライベートデータベースに保存されます。開発者がこれらの内容を閲覧する仕組みはありません。")
            }

            Section("外部通信") {
                Text("米ドル料金を円換算する場合に限り、Frankfurter APIへドル円の参考レートを問い合わせます。登録した費目名や料金、借入の情報は送信しません。返済額や利息の計算はすべて端末内で行います。")
            }

            Section("通知") {
                Text("更新予定の通知と借入の返済日の通知は、いずれもiOSのローカル通知として端末内で予約します。通知は設定画面または各費目の編集画面から無効にできます。")
            }

            Section("削除") {
                Text("費目を削除すると、この端末とiCloudから対象データが削除されます。借入を削除すると、返済の記録もあわせて削除されます。アプリ全体のデータは、iCloudのストレージ管理から削除できます。")
            }
        }
        .navigationTitle("プライバシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
