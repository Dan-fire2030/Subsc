import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subscription.renewalDate) private var subscriptions: [Subscription]
    @State private var query = ""
    @State private var filter: SubscriptionFilter = .all
    @State private var costTypeFilter: CostTypeFilter = .all
    @State private var editor: SubscriptionEditor?
    @State private var operationError: String?
    @State private var pendingDeletion: Subscription?

    /// 種別で絞り込んだ費目です。レポートと一覧の両方がここを起点にします。
    private var subscriptionsInSelectedTypes: [Subscription] {
        subscriptions.filter { costTypeFilter.matches($0) }
    }

    private var visibleSubscriptions: [Subscription] {
        subscriptionsInSelectedTypes.filter { subscription in
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
                        ReportCard(
                            subscriptions: subscriptionsInSelectedTypes,
                            costTypeTitle: costTypeFilter.isNarrowed ? costTypeFilter.title : nil
                        )
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

                    Section(listSectionTitle) {
                        if visibleSubscriptions.isEmpty {
                            ContentUnavailableView(
                                query.isEmpty ? "対象の費目はありません" : "見つかりませんでした",
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
                if !subscriptions.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        costTypeFilterMenu
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editor = SubscriptionEditor(subscription: nil)
                    } label: {
                        Label("費目を追加", systemImage: "plus")
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
                "この費目を削除しますか？",
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

    /// 一覧の見出しです。種別で絞り込んでいるときは、何を見ているかを見出しで示します。
    private var listSectionTitle: String {
        costTypeFilter.isNarrowed ? costTypeFilter.title : "費目一覧"
    }

    /// 種別の絞り込みです。段の数が多く、セグメントに並べると読めなくなるためメニューにしています。
    private var costTypeFilterMenu: some View {
        Menu {
            Picker("種別", selection: $costTypeFilter) {
                ForEach(CostTypeFilter.allCases) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            Label(
                "種別で絞り込む",
                systemImage: costTypeFilter.isNarrowed
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityIdentifier("cost-type-filter-menu")
        .accessibilityValue(costTypeFilter.title)
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
            operationError = "費目を削除できませんでした。"
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

private struct SubscriptionEditor: Identifiable {
    let id = UUID()
    let subscription: Subscription?
}
