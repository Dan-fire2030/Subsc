import SwiftData
import SwiftUI

/// 一覧から遷移する借入1件の詳細です。予定表・履歴への入口と、編集・削除も兼ねます。
struct LoanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// 停止・再開のあとで通知を組み直すのに使います。
    /// **既定値で `reconcile` を呼ぶと、利用者が選んだ「何日前」が無視されます。**
    @Environment(LoanNotificationSettings.self) private var loanNotificationSettings
    /// 通知の再計画は全件を見て行います。1件だけ消すと、再開したときに予約し直せません。
    @Query private var allSubscriptions: [Subscription]
    @Query private var allLoans: [Loan]
    let loan: Loan
    @State private var isEditing = false
    @State private var showsDeleteConfirmation = false
    @State private var operationError: String?

    /// 表示のたびに数え直します。履歴を編集して戻ったときに、古い残高が残らないようにするためです。
    private var summary: LoanSummary {
        LoanSummary.make(for: loan)
    }

    private var accentColor: Color {
        ColorHex.color(from: CostType.loan.colorHex)
    }

    var body: some View {
        List {
            headerSection
            balanceSection
            termsSection
            navigationSection
            simulationSection
            pauseSection

            if !loan.note.isEmpty {
                Section("メモ") {
                    Text(loan.note)
                }
                .glassListRow()
            }

            Section {
                Button("借入を削除", role: .destructive) {
                    showsDeleteConfirmation = true
                }
            }
            .glassListRow()
        }
        .liquidGlassScreen()
        .navigationTitle("借入の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("編集") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) {
            LoanFormView(loan: loan)
        }
        .confirmationDialog(
            "\(loan.name)を削除しますか？",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { delete() }
        } message: {
            Text("返済の記録もまとめて消えます。この操作は取り消せません。")
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

    /// 返済の一時停止です。
    ///
    /// **完済した借入には出しません。** 止める返済が残っていないためで、
    /// 一覧のスワイプでも同じ条件にしています。
    @ViewBuilder
    private var pauseSection: some View {
        if !summary.isCompleted {
            Section {
                Button {
                    togglePause()
                } label: {
                    Label(
                        loan.isPaused ? "返済を再開する" : "返済を一時停止する",
                        systemImage: loan.isPaused ? "play.fill" : "pause.fill"
                    )
                }
            } header: {
                Text("返済の停止")
            } footer: {
                // **何が起きるかを止める前に伝えます。** 完済日がずれるのは戻せない話ではないものの、
                // 黙ってずらすと「勝手に予定が変わった」と受け取られます。
                if loan.isPaused, let pausedOn = loan.pausedOn {
                    Text("\(pausedOn.formatted(.dateTime.year().month().day()))から停止しています。停止しているあいだの返済日は飛ばされ、完済予定はそのぶん後ろへずれます。利息は増えません。")
                } else {
                    Text("停止しているあいだの返済日は飛ばされ、完済予定はそのぶん後ろへずれます。利息は増えず、残高も変わりません。")
                }
            }
            .glassListRow()
        }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                Capsule(style: .continuous)
                    .fill(accentColor)
                    .frame(width: 6, height: 46)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.name)
                        .font(.title3.bold())
                    HStack(spacing: 6) {
                        Label(CostType.loan.title, systemImage: CostType.loan.systemImage)
                            .font(.caption.weight(.medium))
                        Text("・")
                        Text(loan.method.title)
                    }
                    .foregroundStyle(BlackCatPalette.textMuted)
                }
            }
            .padding(.vertical, 6)
        }
        .glassListRow()
    }

    private var balanceSection: some View {
        Section("残高") {
            LabeledContent("残っている元金") {
                Text(
                    summary.currentBalance,
                    format: .currency(code: "JPY").precision(.fractionLength(0))
                )
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: summary.progress)
                    .tint(accentColor)
                Text(progressDescription)
                    .font(.caption)
                    .foregroundStyle(BlackCatPalette.textMuted)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)

            if let nextDueDate = summary.nextDueDate {
                LabeledContent("次の返済") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(
                            summary.nextAmount,
                            format: .currency(code: "JPY").precision(.fractionLength(0))
                        )
                        .monospacedDigit()
                        Text(nextDueDate, format: .dateTime.year().month().day())
                            .font(.caption)
                            .foregroundStyle(BlackCatPalette.textMuted)
                    }
                }
            }

            if let completionDate = summary.completionDate {
                LabeledContent("完済予定") {
                    Text(completionDate, format: .dateTime.year().month())
                }
            }
            LabeledContent("残り回数", value: "\(summary.remainingCount)回")
            if summary.missedCount > 0 {
                LabeledContent("滞納した回数", value: "\(summary.missedCount)回")
            }
        }
        .glassListRow()
    }

    private var termsSection: some View {
        Section("条件") {
            LabeledContent("返済方式", value: loan.method.title)
            LabeledContent("金利", value: loan.interestType.title)
            LabeledContent(
                "年利",
                value: "\(loan.annualRatePercent.formatted(.number.precision(.fractionLength(0...3))))％"
            )
            LabeledContent("返済日", value: "毎月\(loan.paymentDay)日")
            LabeledContent("登録方法", value: loan.origin.title)
            if let borrowedOn = loan.borrowedOn {
                LabeledContent("借入日") {
                    Text(borrowedOn, format: .dateTime.year().month().day())
                }
            }
            if loan.bonusAmount > 0 {
                LabeledContent("ボーナス返済") {
                    Text(
                        "\(loan.bonusMonths.map { "\($0)月" }.joined(separator: "・"))　\(loan.bonusAmount.formatted(.currency(code: "JPY").precision(.fractionLength(0))))"
                    )
                }
            }
            LabeledContent("利息の合計") {
                Text(
                    summary.totalInterest,
                    format: .currency(code: "JPY").precision(.fractionLength(0))
                )
                .monospacedDigit()
            }
        }
        .glassListRow()
    }

    private var navigationSection: some View {
        Section {
            NavigationLink {
                LoanScheduleView(loan: loan)
            } label: {
                Label("返済予定表", systemImage: "list.bullet.rectangle")
            }
            NavigationLink {
                LoanHistoryView(loan: loan)
            } label: {
                Label("返済履歴", systemImage: "clock.arrow.circlepath")
            }
        }
        .glassListRow()
    }

    /// 試算への入口です。**記録は残りません。** 実際の繰上返済は返済履歴から記録します。
    private var simulationSection: some View {
        Section {
            LoanSimulationLink(
                title: "繰上返済の試算",
                systemImage: "arrow.down.right.circle"
            ) {
                LoanPrepaymentSimulationView(loan: loan)
            }
            LoanSimulationLink(
                title: "利率変更の影響",
                systemImage: "percent"
            ) {
                LoanRateChangeSimulationView(loan: loan)
            }
        } header: {
            Text("試算")
        } footer: {
            Text("「もしこうしたら」を見るだけの機能です。記録には残りません。")
        }
        .glassListRow()
    }

    private var progressDescription: String {
        let percent = (summary.progress * 100).rounded()
        let repaid = summary.repaidPrincipal
            .formatted(.currency(code: "JPY").precision(.fractionLength(0)))
        return "元金の\(percent.formatted(.number.precision(.fractionLength(0))))％（\(repaid)）を返済しました"
    }

    /// 返済を止める・再開します。
    ///
    /// 再開では予定表を組み直すため失敗しうります。**失敗したら停止フラグごと巻き戻します。**
    /// 中途半端に止まったままにしません。
    private func togglePause() {
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
        // 再開したぶんはここで予約し直されます。
        Task {
            await NotificationService.reconcile(
                subscriptions: allSubscriptions,
                loans: allLoans,
                loanLead: loanNotificationSettings.lead,
                loanHour: loanNotificationSettings.hour
            )
        }
    }

    private func delete() {
        let clientID = loan.clientID
        modelContext.delete(loan)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError = "借入を削除できませんでした。"
            return
        }
        Task {
            await NotificationService.cancel(clientID: clientID)
        }
        dismiss()
    }
}
