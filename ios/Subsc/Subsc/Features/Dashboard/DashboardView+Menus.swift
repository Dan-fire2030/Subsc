import SwiftUI

/// `DashboardView` のツールバーと、該当が無いときの文言です。
extension DashboardView {
    /// 追加の入口です。費目と借入は別のモデルなので、押した時点でどちらかを選んでもらいます。
    var addMenu: some View {
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

    /// 種別の絞り込みと並び替えです。
    ///
    /// 段の数が多く、セグメントに並べると読めなくなるためメニューにしています。
    /// **並び替えもここへ入れます（2026-08-11）。** ツールバーに入口を増やすと、
    /// 一覧に関わる操作が2箇所へ散らばります。
    var costTypeFilterMenu: some View {
        Menu {
            Picker("種別", selection: $costTypeFilter) {
                ForEach(CostTypeFilter.allCases) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option)
                }
            }

            Section("並び替え") {
                ForEach(DashboardSortOrder.allCases) { order in
                    Button {
                        sortStore.select(order)
                    } label: {
                        // **選ばれている並びには印と向きを添えます。**
                        // どちらの向きなのかが分からないと、押しても何が起きたか読めません。
                        if sortStore.order == order {
                            Label(
                                "\(order.title)（\(order.directionTitle(isDescending: sortStore.isDescending))）",
                                systemImage: sortStore.isDescending ? "chevron.down" : "chevron.up"
                            )
                        } else {
                            Label(order.title, systemImage: order.systemImage)
                        }
                    }
                }
            }
        } label: {
            Label(
                "絞り込みと並び替え",
                systemImage: costTypeFilter.isNarrowed
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityIdentifier("cost-type-filter-menu")
        .accessibilityValue("\(costTypeFilter.title)・\(sortStore.order.title)")
    }

    /// 一覧のセクションの見出しです。**件数と合計を添えます。**
    ///
    /// 合計はそのセクションに並んでいる行の金額の合計です。
    /// レポートの集計を持ってくると、停止中や履歴を含む絞り込みのときに
    /// **見出しがすぐ下の行と食い違います**。
    @ViewBuilder
    func sectionHeader(for section: DashboardListSection) -> some View {
        if let kind = section.kind {
            HStack(spacing: 6) {
                Text(kind.title)
                Spacer(minLength: 8)
                Text("\(section.count)件")
                Text(section.total, format: .currency(code: "JPY").precision(.fractionLength(0)))
            }
            .accessibilityElement(children: .combine)
        } else {
            Text(listSectionTitle)
        }
    }

    /// 該当が無いときの説明です。
    ///
    /// 検索中は検索の話を優先します。**種別で絞り込んでいることを見落として
    /// 「無くなった」と思われる**ことがあるため、絞り込み中はその旨を必ず添えます。
    var emptyStateDescription: String {
        let base = isSearching
            ? "検索条件を変えてみてください。"
            : filter.emptyStateDescription
        guard costTypeFilter.isNarrowed else { return base }
        return "\(base)\nいまは「\(costTypeFilter.title)」で絞り込んでいます。"
    }

    /// 一覧の見出しです。検索中と、種別で絞り込んでいるときに何を見ているかを示します。
    var listSectionTitle: String {
        DashboardListHeading.title(costTypeFilter: costTypeFilter, isSearching: isSearching)
    }
}
