import SwiftData
import SwiftUI

/// ホーム画面です。レポート・これから出ていくお金・費目一覧をまとめて出します。
///
/// **1ファイルが500行を超えたため、責務ごとに分けました（2026-08-08）。**
/// ここには状態と `body` だけを置き、残りは同名の extension ファイルにあります：
/// `+Collections`（並べる材料）／`+Rows`（一覧の行）／`+Menus`（追加と絞り込み）／`+Actions`（保存を伴う操作）。
///
/// **保存プロパティの `private` は外しています。**
/// Swiftのextensionはファイルをまたぐと `private` を参照できないためです
/// （`LoanFormView` と同じ理由・同じ扱いです）。
struct DashboardView: View {
    /// 停止・再開のあとで通知を組み直すのに使います。
    /// **既定値で `reconcile` を呼ぶと、利用者が選んだ「何日前」が無視されます。**
    @Environment(LoanNotificationSettings.self) var loanNotificationSettings
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Subscription.renewalDate) var subscriptions: [Subscription]
    @Query(sort: \Loan.createdAt) var loans: [Loan]
    @State var query = ""
    @State var filter: SubscriptionFilter = .all
    @State var costTypeFilter: CostTypeFilter = .all
    @State var editor: SubscriptionEditor?
    @State var loanEditor: LoanEditor?
    @State var operationError: String?
    @State var pendingDeletion: Subscription?

    var body: some View {
        // **1回の描画で一度だけ求めます。**
        // computed property のまま複数箇所から読むと、そのたびに
        // `DashboardListBuilder` の絞り込みと並べ替えが走り、借入ごとに
        // `LoanSummary` まで作り直されます（2026-08-08のレビュー指摘）。
        let searching = isSearching
        // 検索中は時間軸を出さないので、組み立てる必要もありません。
        let upcoming = searching ? [] : upcomingItems
        let visible = visibleItems

        return NavigationStack {
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
                    // **検索中は一覧より上をすべて畳みます（2026-08-09）。**
                    // 一覧はこの画面のいちばん下にあるため、絞り込んでも結果は画面の外にあり、
                    // 探し当てるたびに手でスクロールする必要がありました。
                    // 上を消せば、結果はそのまま検索欄の下に出ます。
                    if !searching {
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

                        if !upcoming.isEmpty {
                            // 費目の更新も借入の返済も「次に出ていくお金」なので、見出しをまとめています。
                            Section("これから出ていく") {
                                UpcomingTimeline(items: upcoming)
                                    .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }

                        // **検索中は隠します。** 状態の絞り込みは検索中に外れるため
                        // （`effectiveStateFilter`）、出したままだと効いていない選択が残ります。
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
                    }

                    Section(listSectionTitle) {
                        if visible.isEmpty {
                            ContentUnavailableView(
                                searching ? "見つかりませんでした" : filter.emptyStateTitle,
                                systemImage: searching
                                    ? "magnifyingglass"
                                    : "line.3.horizontal.decrease.circle",
                                description: Text(emptyStateDescription)
                            )
                            .glassListRow()
                        } else {
                            ForEach(visible) { item in
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
            .navigationTitle("つきねこ")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .automatic,
                prompt: "費目名・カテゴリ・メモ"
            )
            .modifier(MinimizableSearchToolbarModifier())
            // **`searchCompletion` で確定させます（2026-08-09）。**
            // 以前は `query = item.name` のあと `dismissSearch()` を呼んでいましたが、
            // `dismissSearch` は「検索フィールドの文字を消す」と規定されています。
            // 入れた直後に消していたため、**候補を選んでも一覧が絞り込まれませんでした**。
            .searchSuggestions {
                ForEach(searchSuggestions) { item in
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
                    .searchCompletion(item.name)
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
}

/// 編集シートに渡す費目です。`nil` なら新規追加です。
///
/// **`private` にできません。** 追加メニューと一覧の行が別ファイルにあり、
/// そちらからも生成するためです。
struct SubscriptionEditor: Identifiable {
    let id = UUID()
    let subscription: Subscription?
}

/// 編集シートに渡す借入です。`nil` なら新規追加です。
struct LoanEditor: Identifiable {
    let id = UUID()
    let loan: Loan?
}
