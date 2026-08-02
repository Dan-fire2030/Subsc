import SwiftData
import SwiftUI

/// 入力の検証と保存です。検証に失敗したら理由を日本語で示し、保存には進みません。
extension LoanFormView {
    func save() async {
        do {
            try input.validate()
        } catch {
            // `LoanFormError` も `LoanTermsError` も日本語の説明を持つため、そのまま見せます。
            showValidation(
                (error as? LocalizedError)?.errorDescription
                    ?? "この内容では返済予定表を作れません。入力を確認してください。"
            )
            return
        }

        isSaving = true
        defer { isSaving = false }

        // 返済日の通知が要るため、保存前に許可を確かめます。
        // 許可されなくても保存自体は続けます。**記録は通知が無くても意味があります。**
        _ = await NotificationService.requestAuthorization()

        let target = loan ?? Loan(name: input.trimmedName)
        if loan == nil {
            modelContext.insert(target)
        }
        input.apply(to: target)

        do {
            // 条件が変われば予定表も変わります。滞納・繰上返済の記録は保たれます。
            let result = try LoanPaymentStore.synchronize(loan: target)
            for removed in result.removed {
                modelContext.delete(removed)
            }
            // 返済日を過ぎた回は、何もしなければ予定どおり返済されたものとして扱います。
            LoanPaymentStore.settlePastDue(on: target)
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            showValidation(
                (error as? LocalizedError)?.errorDescription
                    ?? "保存できませんでした。もう一度お試しください。"
            )
        }
    }

    func showValidation(_ message: String) {
        validationMessage = message
        isValidationFocused = true
    }
}
