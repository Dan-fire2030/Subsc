import SwiftUI
import UIKit

/// アプリの色です（2026-10-15に黒猫の配色からパステルへ入れ替えました）。
///
/// **ライトが主役で、ダークにも応じます。** 端末の設定に従い、明るい場所では白に近い地に、
/// 暗い場所では紫がかった墨の地に、同じパステルの費目が並びます。
///
/// **パステルは面（カード・グラフ・印）に使い、文字には使いません。** 淡い色は文字にすると
/// 白地で読めなくなるためです。文字の色は `text` / `textMuted` か、各色の濃い版を使います。
///
/// ボタン・ツールバー・検索といった操作部品はiOSのLiquid Glassを素のまま使い、
/// 色を指定しません（自作すると「押せるもの」の手がかりが弱まり、OSの更新にも追従できなくなります）。
enum SubscPalette {
    // MARK: - 地とカード

    /// 画面の地です。真っ白にせず、ほんの少し青みを入れてカードの白を浮かせます。
    static let background = dynamic(light: "#F8F7FC", dark: "#15131B")
    /// カードの面です。地から**わずかに浮いた**面。
    ///
    /// 境目は線ではなく明度の差と淡い影で作ります。
    static let surface = dynamic(light: "#FFFFFF", dark: "#221F2B")
    /// カードの中で**沈む**面です（帯の下地など）。
    ///
    /// 浮いた面より暗くします。入れ子を「さらに浮かせる」と階層が増えて騒がしくなるため、
    /// **内側は沈める**と決めています。
    static let surfaceElevated = dynamic(light: "#F1EEF9", dark: "#1B1822")
    /// 境界線です。フォームの入力欄など、線が意味を持つ場所にだけ使います。
    static let border = dynamic(light: "#ECE8F6", dark: "#2E2A3A")
    /// グラフの下地です。**金額が小さい費目を消さない**ために必ず敷きます。
    static let chartTrack = dynamic(light: "#F1EEF9", dark: "#2E2A3A")

    // MARK: - 文字

    static let text = dynamic(light: "#2A2733", dark: "#F3F1F8")
    /// 補足の文字です。**沈む面（`surfaceElevated`）の上でも 4.5:1 を保つ**濃さにしています。
    static let textMuted = dynamic(light: "#6E6879", dark: "#A39DB0")

    // MARK: - アクセント

    /// 予告や現在地（今日・選択中）といった**一点にだけ**使う色です。
    ///
    /// 金額そのものをこの色にしません。数字の読み取りが装飾に負けるためです。
    static let accent = dynamic(light: "#6A4FC9", dark: "#C9BAFF")

    /// テーマ色で塗ったボタンの上の文字です。
    ///
    /// **ダークでは濃い文字にします。** ダークのテーマ色は同じ色相の明るい版
    /// （`ThemeColor.darkButtonTint`）なので、白い文字のままだと沈みます（2026-10-15）。
    static let onTint = dynamic(light: "#FFFFFF", dark: "#1B1530")

    // MARK: - 増減の符号

    /// 減って嬉しい額（試算で減る利息など）の色です。
    /// **カテゴリ色とは別に持ちます。** カテゴリ色は費目の識別子なので、
    /// 意味を持たせて流用すると「ミントの費目」と「良い結果」が同じ色になります。
    /// 金額に当てる色なので、装飾ではなく**数字が読めること**を優先します。
    static let positive = dynamic(light: "#2E7D5B", dark: "#8FDDB8")
    /// 増えて注意したい額（試算で増える利息など）の色です。
    static let caution = dynamic(light: "#A85424", dark: "#FFB696")

    // MARK: - 曜日

    /// 日曜の見出しです。**費目のローズを流用しません。** パステルのままだと白地で読めません。
    static let sunday = dynamic(light: "#B0461F", dark: "#FF9F80")
    /// 土曜の見出しです。理由は日曜と同じです。
    static let saturday = dynamic(light: "#2F6FB8", dark: "#8FBFFF")

    // MARK: - 猫

    /// 猫の体です。ラベンダーのパステルを、**白いカードの上で図形として見分けられる濃さ（3:1以上）**まで
    /// 一段沈めています。淡いままだとカードに溶けます。ダークでは明るい版にして暗い地から浮かせます。
    static let catBody = dynamic(light: "#9585D6", dark: "#C9BAFF")
    /// 目・眉・口元です。体の上で表情が読める濃さにします。
    static let catFace = dynamic(light: "#2A2733", dark: "#15131B")
    /// 耳の内側です。飾りなので、体と見分けられればよい色にしています。
    static let catEarInner = ColorHex.color(from: "#FFC9DA")
    static let catNose = ColorHex.color(from: "#E07A93")
    /// 頬です。体の上に半透明で重ねます（`CatCompanionView` 側で透明度を掛けます）。
    /// **ピーチではなくピンク寄りにしています。** ピーチをラベンダーに重ねると茶色く濁りました（2026-10-15）。
    static let catCheek = ColorHex.color(from: "#FF9FBA")
    /// 猫に添える符号（「！」・きらめき・案内の点）です。**アクセントと同じ色**にして、
    /// 「ここを見て」という一点の意味を揃えます。
    static let catAccent = accent
    /// 汗です。飾りで、意味は読み上げの状態名が担います。
    static let catSweat = ColorHex.color(from: "#9CC8FF")

    // MARK: - 費目カテゴリ

    /// カテゴリのパステル7色です。**両モードで同じ色**を使います。
    ///
    /// 色そのものが費目の識別子なので、モードで色が変わると同じ費目が別物に見えます。
    enum Category {
        static let mint = ColorHex.color(from: "#8FDDB8")
        static let peach = ColorHex.color(from: "#FFB696")
        static let lavender = ColorHex.color(from: "#B9A6FF")
        static let sky = ColorHex.color(from: "#9CC8FF")
        static let butter = ColorHex.color(from: "#FFD966")
        static let rose = ColorHex.color(from: "#F7A8C4")
        /// ミストです。借入の色で、無彩色や壊れた保存値の逃げ場も兼ねます。
        static let mist = ColorHex.color(from: "#B9B4C9")

        /// 色を指定していない費目へ順に割り当てる並びです。
        static let fallbackOrder: [Color] = [sky, lavender, mint, peach, rose, butter, mist]
    }

    /// ライトとダークで出し分ける色を作ります。
    ///
    /// アセットカタログではなくコードで持つのは、**この配色が仕様の一部**で、
    /// 値の意図（なぜその明度か）をコメントとして同じ場所に残したいためです。
    private static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(ColorHex.color(from: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

extension SubscPalette {
    /// 色相で寄せられない色の行き先（ミスト）です。無彩色や壊れた保存値がここへ来ます。
    static let harmonizedFallbackHex = "#B9B4C9"

    /// これ未満の彩度は「色が無い」とみなします。灰色を無理に色相で寄せると、
    /// 端数の誤差でどのカテゴリ色にもなり得てしまい、再現性がありません。
    private static let minimumSaturation: CGFloat = 0.12

    /// これまでの選択肢で保存された色の寄せ先です。**色相の近さに任せず、意味で対応させます。**
    ///
    /// たとえばオレンジ（`#FF9F0A`）は色相だけならバターに近く、利用者が「オレンジ」と
    /// 選んだ費目が黄色で出てしまいます。過去に選択肢として出した色は、ここで名指しします。
    private static let legacyCounterparts: [String: String] = [
        // iOS標準色の旧プリセット（2026-08-05まで）
        "#007AFF": "#9CC8FF",  // ブルー → スカイ
        "#34C759": "#8FDDB8",  // グリーン → ミント
        "#FF375F": "#F7A8C4",  // ピンク → ローズ
        "#AF52DE": "#B9A6FF",  // パープル → ラベンダー
        "#FF9F0A": "#FFB696",  // オレンジ → ピーチ
        // 黒猫のパレット（2026-08-05〜2026-10-15）
        "#7FB3D5": "#9CC8FF",  // 藍 → スカイ
        "#9B8FD9": "#B9A6FF",  // 菫 → ラベンダー
        "#7FC8A9": "#8FDDB8",  // 若草 → ミント
        "#E0A66B": "#FFB696",  // 琥珀 → ピーチ
        "#D98FA6": "#F7A8C4",  // 撫子 → ローズ
        "#C4B37F": "#FFD966",  // 黄土 → バター
        "#8FA8C4": "#B9B4C9",  // 鈍色 → ミスト
        "#D9A43C": "#FFD966"   // 金目 → バター
    ]

    /// 保存済みの費目色を、**表示のときだけ**パステルの7色へ寄せます。
    ///
    /// **保存値は書き換えません。** 利用者が選んだ色はその人のデータであり、
    /// デザインの都合で上書きするものではないためです。表示だけ揃えることで、
    /// 配色を元に戻したくなったときもこの関数を外すだけで済みます。
    ///
    /// 順番は「パステルそのもの → 過去の選択肢の対応表 → 色相の近さ → ミスト」です。
    static func harmonizedHex(from hex: String) -> String {
        let canonical = ColorHex.canonical(hex)
        if Category.hexes.contains(canonical) { return canonical }
        if let counterpart = legacyCounterparts[canonical] { return counterpart }

        guard let source = hsb(of: canonical), source.saturation >= minimumSaturation else {
            return harmonizedFallbackHex
        }

        let nearest = Category.hueTargets.min { lhs, rhs in
            hueDistance(source.hue, hsb(of: lhs)?.hue ?? 0)
                < hueDistance(source.hue, hsb(of: rhs)?.hue ?? 0)
        }
        return nearest ?? harmonizedFallbackHex
    }

    /// 寄せたあとの色です。画面はこちらを使います。
    static func harmonized(from hex: String) -> Color {
        ColorHex.color(from: harmonizedHex(from: hex))
    }

    /// 色相環は一周するので、0度と359度は1度差として扱います。
    private static func hueDistance(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
        let raw = abs(lhs - rhs)
        return min(raw, 1 - raw)
    }

    private static func hsb(of hex: String) -> (hue: CGFloat, saturation: CGFloat)? {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(ColorHex.color(from: hex))
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return nil
        }
        return (hue, saturation)
    }
}

extension SubscPalette.Category {
    /// カテゴリ色の一覧です（ミント・ピーチ・ラベンダー・スカイ・バター・ローズ・ミスト）。
    static let hexes = ["#8FDDB8", "#FFB696", "#B9A6FF", "#9CC8FF", "#FFD966", "#F7A8C4", "#B9B4C9"]

    /// 色相で寄せる先です。**ミスト（`#B9B4C9`）を外しています。**
    ///
    /// ミストは借入・ローンの色です。色のある費目がミストへ寄ると、
    /// **一覧で費目と借入を見分けられなくなります**。ミストは無彩色の逃げ場としてだけ使います。
    static let hueTargets = hexes.filter { $0 != SubscPalette.harmonizedFallbackHex }
}
