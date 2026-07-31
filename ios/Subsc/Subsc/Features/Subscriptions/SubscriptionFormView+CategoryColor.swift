import SwiftUI

/// カテゴリとカラーの選択肢まわりです。どちらも「選択中の値を必ず選択肢に含める」制約を持ちます。
extension SubscriptionFormView {
    /// プリセットと、登録済みサブスクが使っているカテゴリを合わせた選択肢です。
    var categoryOptions: [String] {
        CategoryCatalog.options(
            usedCategories: registeredSubscriptions.map(\.category),
            selected: category
        )
    }

    /// プリセット5色に、プリセット外の現在色を加えた選択肢です。
    /// 選択中の値が選択肢に無いとPickerが空欄になるため、必ず含めます。
    var colorOptions: [String] {
        let current = ColorHex.canonical(colorHex)
        return colorPresets.contains(current) ? colorPresets : colorPresets + [current]
    }

    /// `ColorPicker` は `Color` を扱うため、保存形式の16進数と相互変換します。
    var customColor: Binding<Color> {
        Binding(
            get: { ColorHex.color(from: colorHex) },
            set: { colorHex = ColorHex.string(from: $0) }
        )
    }

    func addCategory() {
        switch CategoryCatalog.validate(newCategoryName, existing: categoryOptions) {
        case .accepted(let name):
            category = name
            categoryError = nil
        case .failure(let message):
            categoryError = message
        }
        newCategoryName = ""
    }

    func colorName(_ hex: String) -> String {
        switch ColorHex.canonical(hex) {
        case "#007AFF": "ブルー"
        case "#34C759": "グリーン"
        case "#FF375F": "ピンク"
        case "#AF52DE": "パープル"
        case "#FF9F0A": "オレンジ"
        default: "カスタム"
        }
    }
}
