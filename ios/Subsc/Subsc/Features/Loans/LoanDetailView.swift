import SwiftData
import SwiftUI

/// 一覧から遷移する借入1件の詳細です。予定表・履歴への入口と、編集・削除も兼ねます。
struct LoanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: CostType.loan.systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(accentColor, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.name)
                        .font(.title3.bold())
                    HStack(spacing: 6) {
                        Label(CostType.loan.title, systemImage: CostType.loan.systemImage)
                            .font(.caption.weight(.medium))
                        Text("・")
                        Text(loan.method.title)
                    }
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
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

    private var progressDescription: String {
        let percent = (summary.progress * 100).rounded()
        let repaid = summary.repaidPrincipal
            .formatted(.currency(code: "JPY").precision(.fractionLength(0)))
        return "元金の\(percent.formatted(.number.precision(.fractionLength(0))))％（\(repaid)）を返済しました"
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
