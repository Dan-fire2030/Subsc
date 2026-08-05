import SwiftUI
import UIKit

/// 黒猫のデザイン言語で使う色です。
///
/// **ライトとダークの両方に応じます。** 端末の設定に従い、暗い場所では墨（ink）の地に、
/// 明るい場所では白磁（porcelain）の地に、同じ猫が座ります。
///
/// **ここにあるのは「地・カード・文字・グラフ・猫」のための色だけです。**
/// ボタン・ツールバー・検索といった操作部品はiOSのLiquid Glassを素のまま使い、
/// 色を指定しません（自作すると「押せるもの」の手がかりが弱まり、OSの更新にも追従できなくなります）。
enum BlackCatPalette {
    // MARK: - 地とカード

    /// 画面の地です。
    static let background = dynamic(light: "#FAF8F4", dark: "#0B0B0F")
    /// カードの面です。
    static let surface = dynamic(light: "#FFFFFF", dark: "#14141A")
    /// カードの中でもう一段沈める面です（帯の下地など）。
    static let surfaceElevated = dynamic(light: "#F2EEE7", dark: "#1C1C24")
    /// 境界線です。面の差だけでは弱い場所に引きます。
    static let border = dynamic(light: "#E4DED3", dark: "#262630")
    /// グラフの下地です。**金額が小さい費目を消さない**ために必ず敷きます。
    static let chartTrack = dynamic(light: "#EAE4DA", dark: "#1F1F28")

    // MARK: - 文字

    static let text = dynamic(light: "#16151A", dark: "#F5F3EF")
    static let textMuted = dynamic(light: "#6B6672", dark: "#9A94A2")

    // MARK: - 金目（アクセント）

    /// 金目です。**予告や現在地といった一点にだけ**使います。
    ///
    /// 金額そのものを金色にしません。数字の読み取りが装飾に負けるためです。
    /// ライトでは白地でのコントラストを確保するため、一段暗い金を使います。
    static let accent = dynamic(light: "#C8901F", dark: "#E8B44A")

    // MARK: - 猫

    /// 猫の体です。地に対する影として置くので、地より必ず暗くします。
    static let cat = dynamic(light: "#16151A", dark: "#05050A")
    /// 猫の目と、猫に添える符号（汗・きらめき・「！」・案内の点）です。
    static let catEye = dynamic(light: "#C8901F", dark: "#F2C96B")

    // MARK: - 費目カテゴリ

    /// カテゴリの色です。**黒地でも白磁の上でも沈まない明度**に揃えています。
    ///
    /// 両モードで同じ色を使うのは、色そのものが費目の識別子だからです。
    /// モードで色が変わると、同じ費目が別物に見えます。
    enum Category {
        static let watch = ColorHex.color(from: "#7FB3D5")
        static let listen = ColorHex.color(from: "#9B8FD9")
        static let read = ColorHex.color(from: "#7FC8A9")
        static let work = ColorHex.color(from: "#E0A66B")
        static let living = ColorHex.color(from: "#D98FA6")
        static let network = ColorHex.color(from: "#C4B37F")
        static let loan = ColorHex.color(from: "#8FA8C4")

        /// 色を指定していない費目へ順に割り当てる並びです。
        static let fallbackOrder: [Color] = [watch, listen, read, work, living, network, loan]
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

extension BlackCatPalette {
    /// 色相で寄せられない色の行き先です。無彩色や壊れた保存値がここへ来ます。
    static let harmonizedFallbackHex = "#8FA8C4"

    /// これ未満の彩度は「色が無い」とみなします。灰色を無理に色相で寄せると、
    /// 端数の誤差でどのカテゴリ色にもなり得てしまい、再現性がありません。
    private static let minimumSaturation: CGFloat = 0.12

    /// 保存済みの費目色を、**表示のときだけ**黒猫のパレットへ寄せます。
    ///
    /// **保存値は書き換えません。** 利用者が選んだ色はその人のデータであり、
    /// デザインの都合で上書きするものではないためです。表示だけ揃えることで、
    /// 配色を元に戻したくなったときもこの関数を外すだけで済みます。
    ///
    /// **金目（アクセント）へは寄せません。** 金は予告や現在地といった一点のための色で、
    /// 費目に配ると「大事な一点」の意味が薄れます。寄せ先はカテゴリの7色だけです。
    static func harmonizedHex(from hex: String) -> String {
        let canonical = ColorHex.canonical(hex)
        if Category.hexes.contains(canonical) { return canonical }

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

extension BlackCatPalette.Category {
    /// カテゴリ色の一覧です。**金目（アクセント）は含みません。**
    static let hexes = ["#7FB3D5", "#9B8FD9", "#7FC8A9", "#E0A66B", "#D98FA6", "#C4B37F", "#8FA8C4"]

    /// 色相で寄せる先です。**鈍色（`#8FA8C4`）を外しています。**
    ///
    /// 鈍色は借入・ローンの色で、色相が青（`#007AFF`）とほとんど同じです。
    /// 残したままにすると、青で保存された費目が借入と同じ色で並び、
    /// **一覧で費目と借入を見分けられなくなります**。鈍色は無彩色の逃げ場としてだけ使います。
    static let hueTargets = hexes.filter { $0 != BlackCatPalette.harmonizedFallbackHex }
}
