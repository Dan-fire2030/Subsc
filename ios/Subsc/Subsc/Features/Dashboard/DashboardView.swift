import SwiftData
import SwiftUI

private enum SubscriptionFilter: String, CaseIterable, Identifiable {
    case all = "すべて"
    case active = "利用中"
    case paused = "停止中"
    case history = "履歴"

    var id: String { rawValue }
}

struct DashboardView: View {
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subscription.renewalDate) private var subscriptions: [Subscription]
    @State private var query = ""
    @State private var filter: SubscriptionFilter = .all
    @State private var editor: SubscriptionEditor?
    @State private var operationError: String?
    @State private var pendingDeletion: Subscription?

    private var visibleSubscriptions: [Subscription] {
        subscriptions.filter { subscription in
            let isHistory = subscription.endDate.map {
                $0 < Calendar.current.startOfDay(for: .now)
            } ?? false
            let matchesFilter = switch filter {
            case .all: true
            case .active: subscription.state == .active && !isHistory
            case .paused: subscription.state == .paused && !isHistory
            case .history: isHistory
            }
            let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = normalizedQuery.isEmpty ||
                subscription.name.localizedCaseInsensitiveContains(normalizedQuery) ||
                subscription.category.localizedCaseInsensitiveContains(normalizedQuery) ||
                subscription.notes.localizedCaseInsensitiveContains(normalizedQuery)
            return matchesFilter && matchesQuery
        }
    }

    private var searchSuggestions: [Subscription] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }
        return subscriptions.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery) ||
                $0.category.localizedCaseInsensitiveContains(normalizedQuery) ||
                $0.notes.localizedCaseInsensitiveContains(normalizedQuery)
        }
        .prefix(6)
        .map { $0 }
    }

    private var nextRenewal: Subscription? {
        subscriptions
            .filter { $0.state == .active && $0.renewalDate >= Calendar.current.startOfDay(for: .now) }
            .min { $0.renewalDate < $1.renewalDate }
    }

    private var usdSubscriptionIDs: String {
        subscriptions
            .filter { $0.currency == .usd }
            .map(\.clientID)
            .sorted()
            .joined(separator: ",")
    }

    var body: some View {
        NavigationStack {
            List {
                if subscriptions.isEmpty {
                    Section {
                        DashboardEmptyState {
                            editor = SubscriptionEditor(subscription: nil)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                        ReportCard(subscriptions: subscriptions)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    if let nextRenewal {
                        Section("次の更新") {
                            NavigationLink {
                                SubscriptionDetailView(subscription: nextRenewal)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            .blue.gradient,
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(.white.opacity(0.55), lineWidth: 0.7)
                                        }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(nextRenewal.name)
                                            .font(.headline)
                                        Text(nextRenewal.renewalDate, format: .dateTime.month().day())
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(relativeDate(nextRenewal.renewalDate))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                }
                            }
                            .glassListRow()
                        }
                    }

                    Section {
                        Picker("表示", selection: $filter) {
                            ForEach(SubscriptionFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowInsets(
                            EdgeInsets(
                                top: 8,
                                leading: 16,
                                bottom: 8,
                                trailing: 16
                            )
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    Section("サブスク一覧") {
                        if visibleSubscriptions.isEmpty {
                            ContentUnavailableView(
                                query.isEmpty ? "対象のサブスクはありません" : "見つかりませんでした",
                                systemImage: query.isEmpty ? "line.3.horizontal.decrease.circle" : "magnifyingglass",
                                description: Text(
                                    query.isEmpty
                                        ? "別の絞り込みを選択してください。"
                                        : "検索条件や絞り込みを変更してください。"
                                )
                            )
                            .glassListRow()
                        } else {
                            ForEach(visibleSubscriptions) { subscription in
                                NavigationLink {
                                    SubscriptionDetailView(subscription: subscription)
                                } label: {
                                    SubscriptionRow(subscription: subscription)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        pendingDeletion = subscription
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        toggleState(of: subscription)
                                    } label: {
                                        Label(
                                            subscription.state == .active ? "停止" : "再開",
                                            systemImage: subscription.state == .active ? "pause.fill" : "play.fill"
                                        )
                                    }
                                    .tint(subscription.state == .active ? .orange : .green)
                                }
                                .contextMenu {
                                    Button {
                                        editor = SubscriptionEditor(subscription: subscription)
                                    } label: {
                                        Label("編集", systemImage: "pencil")
                                    }
                                }
                                .glassListRow()
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .liquidGlassScreen()
            .navigationTitle("Subsc")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .automatic,
                prompt: "サービス名・カテゴリ・メモ"
            )
            .modifier(MinimizableSearchToolbarModifier())
            .searchSuggestions {
                ForEach(searchSuggestions) { subscription in
                    Button {
                        query = subscription.name
                        dismissSearch()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(subscription.name)
                                Text(subscription.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Circle()
                                .fill(subscription.color)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = SubscriptionEditor(subscription: nil)
                    } label: {
                        Label("サブスクを追加", systemImage: "plus")
                    }
                    .accessibilityIdentifier("add-subscription-button")
                }
            }
            .sheet(item: $editor) { editor in
                SubscriptionFormView(subscription: editor.subscription)
            }
            .task(id: usdSubscriptionIDs) {
                await refreshUsdExchangeRate()
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
            .confirmationDialog(
                "このサブスクを削除しますか？",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    confirmDeletion()
                }
                Button("キャンセル", role: .cancel) {
                    pendingDeletion = nil
                }
            } message: {
                if let pendingDeletion {
                    Text("「\(pendingDeletion.name)」の登録情報を削除します。この操作は取り消せません。")
                }
            }
        }
    }

    private func refreshUsdExchangeRate() async {
        let dollarSubscriptions = subscriptions.filter { $0.currency == .usd }
        guard !dollarSubscriptions.isEmpty,
              let quote = try? await ExchangeRateService.usdJpy() else {
            return
        }

        let changedSubscriptions = dollarSubscriptions.filter {
            abs($0.exchangeRate - quote.rate) > 0.000_001
        }
        guard !changedSubscriptions.isEmpty else { return }

        for subscription in changedSubscriptions {
            subscription.exchangeRate = quote.rate
            subscription.updatedAt = .now
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError = "為替レートを保存できませんでした。"
        }
    }

    private func toggleState(of subscription: Subscription) {
        withAnimation {
            subscription.state = subscription.state == .active ? .paused : .active
            subscription.updatedAt = .now
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError = "利用状況を保存できませんでした。"
            return
        }
        Task {
            await NotificationService.reschedule(for: subscription)
        }
    }

    private func delete(_ subscription: Subscription) {
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
    }

    private func confirmDeletion() {
        guard let pendingDeletion else { return }
        self.pendingDeletion = nil
        delete(pendingDeletion)
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        return days == 0 ? "今日" : "あと\(days)日"
    }
}

private struct MinimizableSearchToolbarModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.searchToolbarBehavior(.minimize)
        } else {
            content
        }
    }
}

private struct SubscriptionEditor: Identifiable {
    let id = UUID()
    let subscription: Subscription?
}

private struct DashboardEmptyState: View {
    let addSubscription: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 14 : 18) {
            Image(systemName: "creditcard.and.123")
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(.blue.gradient)
                .frame(
                    width: dynamicTypeSize.isAccessibilitySize ? 60 : 72,
                    height: dynamicTypeSize.isAccessibilitySize ? 60 : 72
                )
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text(
                    dynamicTypeSize.isAccessibilitySize
                        ? "サブスクを管理"
                        : "サブスクをまとめて管理"
                )
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    dynamicTypeSize.isAccessibilitySize
                        ? "料金と更新日を登録して、利用コストと次回更新を確認できます。"
                        : "料金と更新日を登録すると、毎月の利用コストと次回更新をひと目で確認できます。"
                )
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: addSubscription) {
                Label(
                    dynamicTypeSize.isAccessibilitySize
                        ? "サブスクを追加"
                        : "最初のサブスクを追加",
                    systemImage: "plus"
                )
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("empty-state-add-subscription-button")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 16 : 24)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 22 : 30)
        .glassSurface(cornerRadius: 24)
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            Text(subscription.name.prefix(1).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(subscription.color, in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(subscription.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    if subscription.state == .paused {
                        Text("停止中")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Text("\(subscription.category)・\(subscription.renewalDate.formatted(.dateTime.month().day()))更新")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }

            VStack(
                alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
                spacing: 2
            ) {
                Text(subscription.monthlyYen, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(subscription.billingCycle == .yearly ? "月換算" : "月額")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .opacity(subscription.state == .paused ? 0.62 : 1)
        .accessibilityElement(children: .combine)
    }
}

private struct SubscriptionDetailView: View {
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
