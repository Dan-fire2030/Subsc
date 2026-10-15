/// テーマ色（タブ・リンクの色）の選択肢です。
///
/// 保存形式の16進文字列をrawValueにすることで、UI側に色と表示名の
/// 対応表を重複させず、将来の差し替え時に同じ定義を利用できるようにします。
///
/// **2026-10-15にパステルの配色へ入れ替えました。** テーマ色はリンクやタブの**文字**に使うため、
/// 費目のパステルそのものではなく、**同じ色相を白地で文字として読める濃さ（4.5:1以上）にした色**です。
/// ダークでは `ThemeColor.darkButtonTint` で同じ色相の明るい版に切り替えます。
///
/// **入れ替え前の色を選んでいた利用者の色は、そのまま残ります**
/// （選択画面では「カスタム」と呼ばれます）。保存値には触れません。
enum ThemeColorPreset: String, CaseIterable {
    case lavender = "#6A4FC9"
    case sky = "#2F6FB8"
    case mint = "#2E7D5B"
    case peach = "#B4532A"
    case rose = "#B8456F"
    case butter = "#8A6D00"
    case mist = "#6E6879"

    var title: String {
        switch self {
        case .lavender: "ラベンダー"
        case .sky: "スカイ"
        case .mint: "ミント"
        case .peach: "ピーチ"
        case .rose: "ローズ"
        case .butter: "バター"
        case .mist: "ミスト"
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
