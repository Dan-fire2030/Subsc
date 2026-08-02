import SwiftData
import SwiftUI

/// 借入の追加・編集フォームです。
///
/// 扱う項目が多く1ファイルに収まらないため、各セクションと保存処理を
/// `LoanFormView+*.swift` へ分割しています。別ファイルのextensionから参照するため、
/// 保存プロパティの `private` は外しています
/// （Swiftのextensionはファイルをまたぐと `private` を参照できないため）。
///
/// 入力の中身は `LoanFormInput` が持ちます。**検証と契約への書き戻しはビューの外**で、
/// ここは入力を集めて見せることに徹します。
struct LoanFormView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    let loan: Loan?

    @State var input: LoanFormInput
    @State var validationMessage: String?
    @State var isSaving = false
    @AccessibilityFocusState var isValidationFocused: Bool

    let initialInput: LoanFormInput

    /// ボーナス返済月の選択肢です。1〜12月から複数選べます。
    let bonusMonthOptions = Array(1...12)

    init(loan: Loan?) {
        self.loan = loan
        let initial = loan.map { LoanFormInput.make(from: $0) } ?? LoanFormInput.initial()
        initialInput = initial
        _input = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                originSection
                interestSection
                if input.method == .revolving {
                    revolvingSection
                }
                scheduleSection
                bonusSection
                previewSection
                validationSection
            }
            .liquidGlassScreen()
            .navigationTitle(loan == nil ? "借入・ローンを追加" : "借入の内容を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                    .accessibilityIdentifier("loan-save-button")
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
        }
    }

    var hasUnsavedChanges: Bool {
        input != initialInput
    }

    /// 入力の途中経過から試算した予定表です。
    ///
    /// **入力しながら「毎月いくらか」が見えるようにする**ためのもので、失敗しても
    /// エラーは出しません。まだ入れ終わっていないだけの状態で赤字を出しても意味がないためです。
    var previewSchedule: LoanSchedule? {
        guard (try? input.validate()) != nil else { return nil }
        let probe = Loan(name: input.trimmedName)
        input.apply(to: probe)
        guard let firstDueDate = try? LoanPaymentStore.firstDueDate(for: probe) else { return nil }
        return try? LoanScheduleCalculator().schedule(for: probe.terms(nextDueDate: firstDueDate))
    }
}
