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

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Text(subscription.name.prefix(1).uppercased())
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(subscription.color, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscription.name)
                            .font(.title3.bold())
                        Text(subscription.category)
                            .foregroundStyle(.secondary)
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
                LabeledContent("月額換算") {
                    Text(subscription.monthlyYen, format: .currency(code: "JPY").precision(.fractionLength(0)))
                }
                LabeledContent("支払い周期", value: subscription.billingCycle.title)
                LabeledContent("次の更新") {
                    Text(subscription.renewalDate, format: .dateTime.year().month().day())
                }
            }
            .glassListRow()

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
                Button("サブスクを削除", role: .destructive) {
                    showsDeleteConfirmation = true
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
        .confirmationDialog(
            "\(subscription.name)を削除しますか？",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                let clientID = subscription.clientID
                modelContext.delete(subscription)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    operationError = "サブスクを削除できませんでした。"
                    return
                }
                Task {
                    await NotificationService.cancel(clientID: clientID)
                }
                dismiss()
            }
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
}
