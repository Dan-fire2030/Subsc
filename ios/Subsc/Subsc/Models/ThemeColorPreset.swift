/// テーマと費目の色選択で共用できるプリセットです。
///
/// 保存形式の16進文字列をrawValueにすることで、UI側に色と表示名の
/// 対応表を重複させず、将来の差し替え時に同じ定義を利用できるようにします。
///
/// **2026-08-05に黒猫のパレットへ入れ替えました。** iOSの標準色（`#007AFF` など）は
/// 彩度が高く、墨と金目の画面では浮きます。ここにあるのは
/// `BlackCatPalette.Category` と同じ、**黒地でも白磁の上でも沈まない明度**に揃えた色です。
///
/// **入れ替え前の色で保存された費目は、そのままの色で表示され続けます**
/// （選択画面では「カスタム」と呼ばれます）。保存値には触れません。
enum ThemeColorPreset: String, CaseIterable {
    case gold = "#D9A43C"
    case indigo = "#7FB3D5"
    case violet = "#9B8FD9"
    case moss = "#7FC8A9"
    case amber = "#E0A66B"
    case blossom = "#D98FA6"
    case steel = "#8FA8C4"

    var title: String {
        switch self {
        case .gold: "金目"
        case .indigo: "藍"
        case .violet: "菫"
        case .moss: "若草"
        case .amber: "琥珀"
        case .blossom: "撫子"
        case .steel: "鈍色"
        }
    }

    /// 大文字小文字や `#` の有無に左右されず、保存値に対応するプリセットを返します。
    static func preset(for hex: String) -> ThemeColorPreset? {
        ThemeColorPreset(rawValue: ColorHex.canonical(hex))
    }

    /// プリセット外の自由選択色も、既存UIと同じ「カスタム」と表示できるようにします。
    static func title(for hex: String) -> String {
        preset(for: hex)?.title ?? "カスタム"
    }
}
