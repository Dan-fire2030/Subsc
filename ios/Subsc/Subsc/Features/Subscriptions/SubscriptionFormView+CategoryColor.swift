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

    /// カタログで選ばれたサービスをフォームへ流し込みます。
    ///
    /// **入れるのは名前・カテゴリ・色・種別だけです。** 金額と更新日は契約ごとに違うため、
    /// カタログは持たず、利用者に入れてもらいます（`ServiceCatalog` の説明を参照）。
    /// **保存もしません。** ここまでは下書きで、すべてこのあと編集できます。
    func apply(_ service: CatalogService) {
        name = service.name
        category = service.category
        colorHex = service.colorHex
        costType = service.costType
        categoryError = nil
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
