import SwiftUI

/// `DashboardView` の一覧に並ぶ行です。`body` から切り出しただけで、操作は元のまま保っています。
extension DashboardView {
    /// 検索候補の色です。費目は利用者が選んだ色、借入は種別の色を使います。
    func suggestionColor(for item: DashboardListItem) -> Color {
        switch item {
        case .subscription(let subscription): subscription.color
        case .loan: ColorHex.color(from: CostType.loan.colorHex)
        }
    }

    /// 費目の1行です。スワイプでの削除・停止と、長押しでの編集を持ちます。
    func subscriptionRow(_ subscription: Subscription) -> some View {
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
        // **確認の吹き出しは、消そうとしている行そのものを元にして出します（2026-08-11）。**
        // 画面に1つだけ置くと、どの行に対する確認なのかが読み取れませんでした。
        .deleteConfirmation(
            isPresented: Binding(
                get: { pendingDeletion?.clientID == subscription.clientID },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            title: "この費目を削除しますか？",
            message: "「\(subscription.name)」の登録情報を削除します。この操作は取り消せません。"
        ) {
            confirmDeletion()
        }
        .glassListRow()
    }

    /// 借入の1行です。
    ///
    /// **スワイプでの削除は付けていません。** 返済の記録がまとめて消えるため、
    /// 確認を挟める詳細画面からだけ消せるようにしています。
    func loanRow(_ loan: Loan, summary: LoanSummary) -> some View {
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
}
