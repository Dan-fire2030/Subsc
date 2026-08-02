import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subscription.renewalDate) private var subscriptions: [Subscription]
    @Query(sort: \Loan.createdAt) private var loans: [Loan]
    @State private var query = ""
    @State private var filter: SubscriptionFilter = .all
    @State private var costTypeFilter: CostTypeFilter = .all
    @State private var editor: SubscriptionEditor?
    @State private var loanEditor: LoanEditor?
    @State private var operationError: String?
    @State private var pendingDeletion: Subscription?

    /// 種別で絞り込んだ費目です。レポートと一覧の両方がここを起点にします。
    private var subscriptionsInSelectedTypes: [Subscription] {
        subscriptions.filter { costTypeFilter.matches($0) }
    }

    /// 種別で絞り込んだ借入です。借入の種別は常に `.loan` なので、丸ごと通すか外すかの二択です。
    private var loansInSelectedTypes: [Loan] {
        costTypeFilter.matches(.loan) ? loans : []
    }

    /// 一覧に並べる要素です。**費目と借入を「次の期日」で1本に混ぜます。**
    /// 並び順と絞り込みの条件は `DashboardListBuilder` に閉じています。
    private var visibleItems: [DashboardListItem] {
        DashboardListBuilder.items(
            subscriptions: subscriptions,
            loans: loans,
            stateFilter: filter,
            costTypeFilter: costTypeFilter,
            query: query
        )
    }

    /// 登録が1件も無いか。空の案内を出すかどうかの判断に使います。
    private var hasNoRegistrations: Bool {
        subscriptions.isEmpty && loans.isEmpty
    }

    private var searchSuggestions: [Subscription] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }
        return subscriptionsInSelectedTypes.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery) ||
                $0.category.localizedCaseInsensitiveContains(normalizedQuery) ||
                $0.notes.localizedCaseInsensitiveContains(normalizedQuery)
        }
        .prefix(6)
        .map { $0 }
    }

    private var nextRenewal: Subscription? {
        subscriptionsInSelectedTypes
            .filter { $0.state == .active && $0.renewalDate >= Calendar.current.startOfDay(for: .now) }
            .min { $0.renewalDate < $1.renewalDate }
    }

    /// 為替レートの更新は表示上の種別絞り込みと無関係なため、全費目の米ドル契約を監視します。
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
                if hasNoRegistrations {
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
                            loans: loansInSelectedTypes,
                            costTypeFilter: costTypeFilter
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
                                            theme.cardBaseColor.gradient,
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
                        if visibleItems.isEmpty {
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
                            ForEach(visibleItems) { item in
                                switch item {
                                case .subscription(let subscription):
                                    subscriptionRow(subscription)
                                case .loan(let loan, let summary):
                                    loanRow(loan, summary: summary)
                                }
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
                prompt: "費目名・カテゴリ・メモ"
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
                if !hasNoRegistrations {
                    ToolbarItem(placement: .topBarLeading) {
                        costTypeFilterMenu
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
            .sheet(item: $editor) { editor in
                SubscriptionFormView(subscription: editor.subscription)
            }
            .sheet(item: $loanEditor) { editor in
                LoanFormView(loan: editor.loan)
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

    /// 費目の1行です。スワイプでの削除・停止と、長押しでの編集を持ちます。
    private func subscriptionRow(_ subscription: Subscription) -> some View {
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

    /// 借入の1行です。
    ///
    /// **スワイプでの削除は付けていません。** 返済の記録がまとめて消えるため、
    /// 確認を挟める詳細画面からだけ消せるようにしています。
    private func loanRow(_ loan: Loan, summary: LoanSummary) -> some View {
        NavigationLink {
            LoanDetailView(loan: loan)
        } label: {
            LoanRow(loan: loan, summary: summary)
        }
        .contextMenu {
            Button {
                loanEditor = LoanEditor(loan: loan)
            } label: {
                Label("編集", systemImage: "pencil")
            }
        }
        .glassListRow()
    }

    /// 追加の入口です。費目と借入は別のモデルなので、押した時点でどちらかを選んでもらいます。
    private var addMenu: some View {
        Menu {
            Button {
                editor = SubscriptionEditor(subscription: nil)
            } label: {
                Label("費目を追加", systemImage: CostType.subscription.systemImage)
            }
            .accessibilityIdentifier("add-subscription-button")

            Button {
                loanEditor = LoanEditor(loan: nil)
            } label: {
                Label("借入・ローンを追加", systemImage: CostType.loan.systemImage)
            }
            .accessibilityIdentifier("add-loan-button")
        } label: {
            Label("追加", systemImage: "plus")
        }
        .accessibilityIdentifier("add-menu")
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

    /// 非表示の費目も次に表示した時点で正しい換算額にするため、全費目の為替レートを更新します。
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

private struct LoanEditor: Identifiable {
    let id = UUID()
    let loan: Loan?
}
