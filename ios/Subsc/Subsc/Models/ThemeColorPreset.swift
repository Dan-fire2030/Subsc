/// テーマと費目の色選択で共用できるプリセットです。
///
/// 保存形式の16進文字列をrawValueにすることで、UI側に色と表示名の
/// 対応表を重複させず、将来の差し替え時に同じ定義を利用できるようにします。
enum ThemeColorPreset: String, CaseIterable {
    case blue = "#007AFF"
    case green = "#34C759"
    case pink = "#FF375F"
    case purple = "#AF52DE"
    case orange = "#FF9F0A"

    var title: String {
        switch self {
        case .blue: "ブルー"
        case .green: "グリーン"
        case .pink: "ピンク"
        case .purple: "パープル"
        case .orange: "オレンジ"
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
