import SwiftUI

/// 利用コストのレポート画面です。ホームの合計カードから開きます。
///
/// **2026-10-15にホームから分けました。** これまでホームの先頭にあったレポート（期間の切り替え・
/// グラフ・内訳）と、先の予定（この先の大きな支払い・これから出ていく）をここへまとめます。
/// ホームは「いくら・次は何か」だけを一目で見せる画面にし、詳しく見たいときだけここへ来ます。
///
/// **種別の絞り込みはホームと共有します。** 片方だけ絞り込まれていると、合計カードの額と
/// レポートの額が食い違って見えるためです。
struct ReportScreen: View {
    let subscriptions: [Subscription]
    let loans: [Loan]
    @Binding var costTypeFilter: CostTypeFilter

    private var subscriptionsInSelectedTypes: [Subscription] {
        subscriptions.filter { costTypeFilter.matches($0) }
    }

    private var loansInSelectedTypes: [Loan] {
        costTypeFilter.matches(.loan) ? loans : []
    }

    var body: some View {
        let upcoming = DashboardListBuilder.upcomingItems(
            subscriptions: subscriptions,
            loans: loans,
            costTypeFilter: costTypeFilter
        )

        List {
            Section {
                CostTypeChips(selection: $costTypeFilter)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .glassListRow()
            }

            Section {
                ReportCard(
                    subscriptions: subscriptionsInSelectedTypes,
                    loans: loansInSelectedTypes,
                    costTypeFilter: costTypeFilter,
                    catMood: CatMoodContext.mood(
                        subscriptions: subscriptionsInSelectedTypes,
                        loans: loansInSelectedTypes
                    )
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            UpcomingChargeSection(notices: UpcomingLargeCharge.notices(subscriptions: subscriptionsInSelectedTypes))

            if !upcoming.isEmpty {
                // 費目の更新も借入の返済も「次に出ていくお金」なので、見出しをまとめています。
                Section("これから出ていく") {
                    UpcomingTimeline(items: upcoming)
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .liquidGlassScreen()
        .navigationTitle("レポート")
        .navigationBarTitleDisplayMode(.large)
    }
}

/// 種別の絞り込みを、横に並ぶチップで選びます。
///
/// ホームではメニューに畳んでいますが、レポートでは**絞り込みそのものが見たいもの**なので、
/// 選択肢を開いたまま並べます。
private struct CostTypeChips: View {
    @Binding var selection: CostTypeFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SubscSpacing.s) {
                ForEach(CostTypeFilter.allCases) { option in
                    let isSelected = option == selection
                    Button {
                        selection = option
                    } label: {
                        Text(option == .all ? "すべて" : option.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? SubscPalette.background : SubscPalette.text)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(
                                isSelected ? SubscPalette.text : SubscPalette.surfaceElevated,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("種別で絞り込む")
    }
}
