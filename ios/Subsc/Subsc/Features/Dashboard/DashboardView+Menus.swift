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

    /// 種別の絞り込みです。段の数が多く、セグメントに並べると読めなくなるためメニューにしています。
    var costTypeFilterMenu: some View {
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

    /// 該当が無いときの説明です。
    ///
    /// 検索中は検索の話を優先します。**種別で絞り込んでいることを見落として
    /// 「無くなった」と思われる**ことがあるため、絞り込み中はその旨を必ず添えます。
    var emptyStateDescription: String {
        let base = query.isEmpty
            ? filter.emptyStateDescription
            : "検索条件を変えてみてください。"
        guard costTypeFilter.isNarrowed else { return base }
        return "\(base)\nいまは「\(costTypeFilter.title)」で絞り込んでいます。"
    }

    /// 一覧の見出しです。種別で絞り込んでいるときは、何を見ているかを見出しで示します。
    var listSectionTitle: String {
        costTypeFilter.isNarrowed ? costTypeFilter.title : "費目一覧"
    }
}
