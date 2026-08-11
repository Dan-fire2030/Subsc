import SwiftData
import SwiftUI

/// 一覧から遷移するサブスク1件の詳細画面です。編集と削除の入口も兼ねます。
struct SubscriptionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let subscription: Subscription
    @State private var isEditing = false
    @State private var showsDeleteConfirmation = false
    @State private var operationError: String?
    /// 記録画面で編集する年月。`nil` のあいだは画面を出しません。
    @State private var editingPeriod: EditingPeriod?

    /// `sheet(item:)` は `Identifiable` を要求するため、年月を包んで渡します。
    private struct EditingPeriod: Identifiable {
        let periodKey: Int
        var id: Int { periodKey }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    // 一覧と同じ細い色の印にします。頭文字は名前のすぐ隣にある繰り返しです。
                    Capsule(style: .continuous)
                        .fill(subscription.color)
                        .frame(width: 6, height: 46)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscription.name)
                            .font(.title3.bold())
                        HStack(spacing: 6) {
                            Label(
                                subscription.costType.title,
                                systemImage: subscription.costType.systemImage
                            )
                            .font(.caption.weight(.medium))
                            Text("・")
                            Text(subscription.category)
                        }
                        .foregroundStyle(BlackCatPalette.textMuted)
                    }
                }
                .padding(.vertical, 6)
            }
            .glassListRow()

            Section("支払い") {
                if subscription.currency == .usd {
                    LabeledContent("ドル料金") {
                        Text(
                            subscription.originalAmount,
                            format: .currency(code: "USD").precision(.fractionLength(2))
                        )
                        .monospacedDigit()
                    }
                    LabeledContent("換算レート") {
                        Text("1 USD = \(subscription.exchangeRate.formatted(.currency(code: "JPY").precision(.fractionLength(2))))")
                            .monospacedDigit()
                    }
                }
                LabeledContent("今月の金額") {
                    HStack(spacing: 6) {
                        // **年払いで請求の無い月は「¥0」だけだと誤解を招きます。**
                        // 無料になったのではなく、更新月ではないだけなので、そう書きます。
                        if isYearlyWithoutChargeThisMonth {
                            Text("今月は請求なし")
                                .foregroundStyle(BlackCatPalette.textMuted)
                        }
                        if thisMonth.source == .estimated {
                            Text("見込み")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(BlackCatPalette.accent.opacity(0.18), in: Capsule())
                                .foregroundStyle(BlackCatPalette.accent)
                        }
                        if !isYearlyWithoutChargeThisMonth {
                            Text(
                                thisMonth.amount,
                                format: .currency(code: "JPY").precision(.fractionLength(0))
                            )
                            .monospacedDigit()
                        }
                    }
                }
                if !subscription.hasVariableAmount {
                    LabeledContent("支払い周期", value: subscription.billingCycle.title)
                }
                LabeledContent("支払い方法", value: paymentMethodDescription)
                LabeledContent("次の更新") {
                    Text(subscription.renewalDate, format: .dateTime.year().month().day())
                }
            }
            .glassListRow()

            if subscription.hasVariableAmount {
                AmountHistorySection(subscription: subscription) { periodKey in
                    editingPeriod = EditingPeriod(periodKey: periodKey)
                }
            }

            Section("契約") {
                LabeledContent("利用状況", value: subscription.state.title)
                if let startDate = subscription.startDate {
                    LabeledContent("開始日") {
                        Text(startDate, format: .dateTime.year().month().day())
                    }
                }
                if let endDate = subscription.endDate {
                    LabeledContent("終了日") {
                        Text(endDate, format: .dateTime.year().month().day())
                    }
                }
            }
            .glassListRow()

            if !subscription.notes.isEmpty {
                Section("メモ") {
                    Text(subscription.notes)
                }
                .glassListRow()
            }

            if let website = normalizedWebsiteURL {
                Section {
                    Link(destination: website) {
                        Label("公式サイトを開く", systemImage: "safari")
                    }
                }
                .glassListRow()
            }

            Section {
                Button("費目を削除", role: .destructive) {
                    showsDeleteConfirmation = true
                }
                // **確認は押したボタンを元にして出します（2026-08-11）。**
                .deleteConfirmation(
                    isPresented: $showsDeleteConfirmation,
                    title: "\(subscription.name)を削除しますか？",
                    message: "登録情報が消えます。この操作は取り消せません。"
                ) {
                    deleteSubscription()
                }
            }
            .glassListRow()
        }
        .liquidGlassScreen()
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("編集") {
                isEditing = true
            }
        }
        .sheet(isPresented: $isEditing) {
            SubscriptionFormView(subscription: subscription)
        }
        .sheet(item: $editingPeriod) { period in
            AmountEntryEditorView(subscription: subscription, periodKey: period.periodKey)
        }
        .alert(
            "操作を完了できませんでした",
            isPresented: Binding(
                get: { operationError != nil },
                set: { if !$0 { operationError = nil } }
            )
        ) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(operationError ?? "")
        }
    }

    /// 今月かかる額です。変動費は実績、無ければ直近の実績からの見込みになります。
    private var thisMonth: MonthlyAmount {
        subscription.monthlyAmount(forPeriodKey: AmountEntry.periodKey(for: .now))
    }

    /// 年払いで、今月が更新月ではない状態です。金額そのものは0ですが、意味が違います。
    private var isYearlyWithoutChargeThisMonth: Bool {
        !subscription.hasVariableAmount
            && subscription.billingCycle == .yearly
            && thisMonth.amount == 0
    }

    /// 支払い方法と、その補足メモをつないだ表示です。
    private var paymentMethodDescription: String {
        let note = subscription.paymentMethodNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !note.isEmpty else { return subscription.paymentMethod.title }
        if subscription.paymentMethod == .unspecified { return note }
        return "\(subscription.paymentMethod.title)（\(note)）"
    }

    /// スキームのないURL（`example.com` など）にも `https://` を補ってリンクを開けるようにします。
    private var normalizedWebsiteURL: URL? {
        let value = subscription.websiteURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !value.isEmpty else { return nil }
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(value)")
    }

    /// 費目を削除します。
    ///
    /// **予約済みの通知も取り消します。** 費目が消えても通知だけ残ると、
    /// 存在しないものの更新日が届きます。
    /// 保存に失敗したら巻き戻し、何が起きたかを日本語で伝えます。
    private func deleteSubscription() {
        let clientID = subscription.clientID
        modelContext.delete(subscription)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError = "費目を削除できませんでした。"
            return
        }
        Task {
            await NotificationService.cancel(clientID: clientID)
        }
        dismiss()
    }
}
