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

            // **アーカイブは確認を出しません（2026-08-11）。** 30日は戻せるためです。
            // 代わりに「復元」で戻せる知らせをその場に出します。
            if ArchivePolicy.isArchived(subscription.archivedAt) {
                Button {
                    restore(subscription)
                } label: {
                    Label("復元", systemImage: "arrow.uturn.backward")
                }
                .tint(.blue)
            } else {
                Button {
                    archive(subscription)
                } label: {
                    Label("アーカイブ", systemImage: "archivebox")
                }
                .tint(.gray)
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

    /// アーカイブ欄の1行です。
    ///
    /// **残り日数を必ず出します。** いつ消えるか分からないと、復元するかどうかを判断できません。
    /// 期限が近いものは色を変えて、見落とさないようにします。
    @ViewBuilder
    func archivedRow(_ item: DashboardListItem) -> some View {
        let archivedAt = item.archivedAt
        let remaining = ArchivePolicy.remainingDays(archivedAt: archivedAt)
        let isSoon = ArchivePolicy.isExpiringSoon(archivedAt: archivedAt)

        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(suggestionColor(for: item))
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(BlackCatType.body)
                    .foregroundStyle(BlackCatPalette.text)

                Text(remainingDescription(remaining))
                    .font(BlackCatType.label)
                    .foregroundStyle(isSoon ? BlackCatPalette.caution : BlackCatPalette.textMuted)
            }

            Spacer(minLength: 8)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingArchiveDeletion = item
            } label: {
                Label("削除", systemImage: "trash")
            }

            Button {
                restoreItem(item)
            } label: {
                Label("復元", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
        .deleteConfirmation(
            isPresented: Binding(
                get: { pendingArchiveDeletion?.id == item.id },
                set: { if !$0 { pendingArchiveDeletion = nil } }
            ),
            title: "完全に削除しますか？",
            message: "「\(item.name)」を削除します。この操作は取り消せません。"
        ) {
            confirmArchiveDeletion()
        }
        .glassListRow()
    }

    /// 残り日数の言い方です。**0日を「あと0日」と書きません。**
    /// 「今日中に消える」ことが伝わる言葉にします。
    func remainingDescription(_ remaining: Int?) -> String {
        guard let remaining else { return "" }
        return remaining == 0 ? "まもなく削除されます" : "あと\(remaining)日で削除"
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
        // **借入もアーカイブできます。** 削除と違い返済の記録は消えないので、
        // スワイプに置いても取り返しがつかなくなりません。
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if ArchivePolicy.isArchived(loan.archivedAt) {
                Button {
                    restore(loan)
                } label: {
                    Label("復元", systemImage: "arrow.uturn.backward")
                }
                .tint(.blue)
            } else {
                Button {
                    archive(loan)
                } label: {
                    Label("アーカイブ", systemImage: "archivebox")
                }
                .tint(.gray)
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
