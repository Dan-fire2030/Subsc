import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(ThemeStore.self) private var theme
    /// 停止・再開のあとで通知を組み直すのに使います。
    /// **既定値で `reconcile` を呼ぶと、利用者が選んだ「何日前」が無視されます。**
    @Environment(LoanNotificationSettings.self) private var loanNotificationSettings
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

    /// 検索候補です。**費目と借入の両方**が出ます。
    private var searchSuggestions: [DashboardListItem] {
        DashboardListBuilder.suggestions(
            subscriptions: subscriptions,
            loans: loans,
            costTypeFilter: costTypeFilter,
            query: query
        )
    }

    /// 次に支払いが来る1件です。**費目の更新日と借入の返済日を同じ土俵で比べます。**
    private var nextDue: DashboardListItem? {
        DashboardListBuilder.nextDue(
            subscriptions: subscriptions,
            loans: loans,
            costTypeFilter: costTypeFilter
        )
    }

    /// 時間軸に並べる、これから期日が来るものです。
    ///
    /// **期日を持たないもの（完済した借入など）は外します。** 軸の上に置けないためです。
    private var upcomingItems: [DashboardListItem] {
        DashboardListBuilder.items(
            subscriptions: subscriptions,
            loans: loans,
            stateFilter: .active,
            costTypeFilter: costTypeFilter,
            query: ""
        )
        .filter { $0.nextDueDate != nil }
    }

    /// 相棒の黒猫がいまどの姿で座るかです。
    ///
    /// **種別の絞り込みを掛けた母集団で判断します。** レポートと違う材料で表情を決めると、
    /// 画面に出ている金額と猫の様子が食い違って見えます。
    private var catMood: CatMood {
        CatMoodContext.mood(
            subscriptions: subscriptionsInSelectedTypes,
            loans: loansInSelectedTypes
        )
    }

    /// この先の月に来る、年払いのまとまった支払いです。
    /// **種別の絞り込みに従います。** レポートと違う母集団を出すと、金額が合わなく見えます。
    private var upcomingCharges: [UpcomingChargeNotice] {
        UpcomingLargeCharge.notices(subscriptions: subscriptionsInSelectedTypes)
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
                            costTypeFilter: costTypeFilter,
                            catMood: catMood
                        )
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    UpcomingChargeSection(notices: upcomingCharges)

                    if !upcomingItems.isEmpty {
                        // 費目の更新も借入の返済も「次に出ていくお金」なので、見出しをまとめています。
                        Section("これから出ていく") {
                            UpcomingTimeline(items: upcomingItems)
                                .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
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
                                query.isEmpty ? filter.emptyStateTitle : "見つかりませんでした",
                                systemImage: query.isEmpty
                                    ? "line.3.horizontal.decrease.circle"
                                    : "magnifyingglass",
                                description: Text(emptyStateDescription)
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
                ForEach(searchSuggestions) { item in
                    Button {
                        query = item.name
                        dismissSearch()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                Text(item.searchSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Circle()
                                .fill(suggestionColor(for: item))
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

    /// 「次の支払い」のアイコンです。更新なのか返済なのかを一目で分けます。
    private func nextDueSymbol(for item: DashboardListItem) -> String {
        switch item {
        case .subscription: "calendar.badge.clock"
        case .loan: CostType.loan.systemImage
        }
    }

    /// 検索候補の色です。費目は利用者が選んだ色、借入は種別の色を使います。
    private func suggestionColor(for item: DashboardListItem) -> Color {
        switch item {
        case .subscription(let subscription): subscription.color
        case .loan: ColorHex.color(from: CostType.loan.colorHex)
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
        // **leading に置きます。** 費目の行と操作方向を揃えるためで、
        // ローンの行に削除スワイプは無いので、どちらとも取り違えません。
        // 完済した借入には止める返済が残っていないので出しません。
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !loan.isClosed {
                Button {
                    togglePause(of: loan)
                } label: {
                    Label(
                        loan.isPaused ? "再開" : "停止",
                        systemImage: loan.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .tint(loan.isPaused ? .green : .orange)
            }
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

    /// 該当が無いときの説明です。
    ///
    /// 検索中は検索の話を優先します。**種別で絞り込んでいることを見落として
    /// 「無くなった」と思われる**ことがあるため、絞り込み中はその旨を必ず添えます。
    private var emptyStateDescription: String {
        let base = query.isEmpty
            ? filter.emptyStateDescription
            : "検索条件を変えてみてください。"
        guard costTypeFilter.isNarrowed else { return base }
        return "\(base)\nいまは「\(costTypeFilter.title)」で絞り込んでいます。"
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

    /// 借入の返済を止める・再開します。
    ///
    /// 再開では予定表を組み直すため失敗しうります。**失敗したら状態も戻します**
    /// （`rollback` が停止フラグごと巻き戻します）。中途半端に止まったままにしません。
    private func togglePause(of loan: Loan) {
        do {
            if loan.isPaused {
                let result = try LoanPaymentStore.resume(loan: loan)
                for removed in result.removed {
                    modelContext.delete(removed)
                }
            } else {
                try LoanPaymentStore.pause(loan: loan)
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError = (error as? LocalizedError)?.errorDescription
                ?? "返済の停止状態を保存できませんでした。"
            return
        }
        // 停止したぶんの予約は、計画から消えることで `reconcile` が取り消します。
        Task {
            await NotificationService.reconcile(
                subscriptions: subscriptions,
                loans: loans,
                loanLead: loanNotificationSettings.lead,
                loanHour: loanNotificationSettings.hour
            )
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
