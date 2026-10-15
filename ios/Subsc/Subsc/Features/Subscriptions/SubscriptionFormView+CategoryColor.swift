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

    /// パステルの6色に、選択肢外の現在色を加えた選択肢です。
    var colorOptions: [String] {
        CategoryColorChoice.options(selected: colorHex)
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
        // **ブランド色そのままではなく、寄せたパステルで入れます（2026-10-15）。**
        // 表示はどのみちパステルへ寄せるので、色見本の選択もその色に揃えます。
        colorHex = SubscPalette.harmonizedHex(from: service.colorHex)
        costType = service.costType
        categoryError = nil
    }

    func colorName(_ hex: String) -> String {
        CategoryColorChoice.name(for: hex)
    }
}

/// 費目の色の選択肢です（2026-10-15にiOS標準の5色からパステルの6色へ替えました）。
///
/// **ミストは入れません。** ミストは借入の色で、費目に使うと一覧で借入と見分けられなくなります。
/// 以前の選択肢で保存された費目の色は書き換えず、名前もそのまま呼びます。
enum CategoryColorChoice {
    static let presets = SubscPalette.Category.hueTargets
    /// 新しく登録する費目の色です。
    static let defaultHex = "#9CC8FF"

    private static let names: [String: String] = [
        "#8FDDB8": "ミント",
        "#FFB696": "ピーチ",
        "#B9A6FF": "ラベンダー",
        "#9CC8FF": "スカイ",
        "#FFD966": "バター",
        "#F7A8C4": "ローズ",
        // 以前の選択肢（iOS標準色）。保存済みの費目のために名前だけ残します。
        "#007AFF": "ブルー",
        "#34C759": "グリーン",
        "#FF375F": "ピンク",
        "#AF52DE": "パープル",
        "#FF9F0A": "オレンジ"
    ]

    static func name(for hex: String) -> String {
        names[ColorHex.canonical(hex)] ?? "カスタム"
    }

    /// 選択中の値が選択肢に無いと、どれも選ばれていない見た目になるため、末尾に足します。
    static func options(selected hex: String) -> [String] {
        let current = ColorHex.canonical(hex)
        return presets.contains(current) ? presets : presets + [current]
    }
}
