import SwiftUI
import UIKit

/// 費目の色から、一覧のカードの面とアイコンの色を作ります（2026-10-15）。
///
/// 一覧の行は費目の色のパステルで塗ったカードです。**もとの色をそのまま面にすると濃すぎて**
/// 文字が読めないため、ライトでは白へ、ダークでは地へ寄せて薄めます。
/// 寄せる割合は、7色すべてで本文と補足の文字が 4.5:1 を保つように決めています（`PastelTintTests`）。
///
/// 入出力は16進文字列にして、色の計算を画面から切り離してテストできるようにしています。
enum PastelTint {
    private enum Mix {
        /// ライトのカードに残すもとの色の割合です。
        static let lightCard = 0.32
        /// ダークのカードに残すもとの色の割合です。無彩色の黒へ大きく寄せて沈めます。
        static let darkCard = 0.18
        /// ライトのアイコンに残すもとの色の割合です。文字色へ寄せて、白い丸の上で読める濃さにします。
        static let iconInk = 0.45
        static let white = "#FFFFFF"
        /// **画面の地（紫がかった墨）ではなく無彩色の黒へ寄せます（2026-10-15）。**
        /// 地の紫へ寄せると、ピーチとローズが同じ紫がかった灰色になって見分けられませんでした。
        static let darkGround = "#121212"
        static let ink = "#2A2733"
    }

    static func lightCardHex(for hex: String) -> String {
        mix(SubscPalette.harmonizedHex(from: hex), with: Mix.white, keeping: Mix.lightCard)
    }

    static func darkCardHex(for hex: String) -> String {
        mix(SubscPalette.harmonizedHex(from: hex), with: Mix.darkGround, keeping: Mix.darkCard)
    }

    /// ライトでアイコンの記号に使う色です。ダークでは丸をパステルで塗り、記号は顔の色で描きます。
    static func iconInkHex(for hex: String) -> String {
        mix(SubscPalette.harmonizedHex(from: hex), with: Mix.ink, keeping: Mix.iconInk)
    }

    // MARK: - 画面が使う色

    /// カードの面です。端末の外観に追従します。
    static func card(for hex: String) -> Color {
        dynamic(light: lightCardHex(for: hex), dark: darkCardHex(for: hex))
    }

    /// アイコンの丸です。ライトは白を透かし、ダークはもとのパステルで塗ります。
    static func iconBackground(for hex: String) -> Color {
        dynamic(light: "#FFFFFF", dark: SubscPalette.harmonizedHex(from: hex), lightOpacity: 0.75)
    }

    /// アイコンの記号です。
    static func iconInk(for hex: String) -> Color {
        dynamic(light: iconInkHex(for: hex), dark: "#1A1722")
    }

    // MARK: - 計算

    /// 2色を混ぜます。`keeping` はもとの色を残す割合です。
    private static func mix(_ hex: String, with other: String, keeping amount: Double) -> String {
        let source = rgb(of: hex)
        let base = rgb(of: other)
        func blend(_ lhs: CGFloat, _ rhs: CGFloat) -> CGFloat {
            lhs * CGFloat(amount) + rhs * CGFloat(1 - amount)
        }
        return ColorHex.string(
            red: blend(source.red, base.red),
            green: blend(source.green, base.green),
            blue: blend(source.blue, base.blue)
        )
    }

    private static func rgb(of hex: String) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(ColorHex.color(from: hex)).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue)
    }

    private static func dynamic(light: String, dark: String, lightOpacity: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(ColorHex.color(from: dark))
                : UIColor(ColorHex.color(from: light)).withAlphaComponent(lightOpacity)
        })
    }
}

/// 一覧の行の先頭に置く、費目の色の丸いアイコンです。
///
/// **細い色の印から、色の丸へ戻しました（2026-10-15）。** 行そのものが費目の色のカードになったので、
/// 印だけでは色が面に埋もれます。種別の記号を添えて、色と意味を一緒に示します。
struct PastelRowIcon: View {
    let systemImage: String
    let colorHex: String

    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 44

    /// 文字の拡大に合わせて大きくしますが、**60ptで止めます（2026-10-15）。**
    /// 最大の文字サイズでは140pt近くまで育ち、行の文字を下へ押し出していました。
    /// 印は飾りで、大きく読みたいのは文字のほうです。
    private var size: CGFloat { min(scaledSize, 60) }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(PastelTint.iconInk(for: colorHex))
            .frame(width: size, height: size)
            .background(PastelTint.iconBackground(for: colorHex), in: Circle())
            .accessibilityHidden(true)
    }
}

extension View {
    /// 一覧の行を、費目の色のパステルカードにします。
    ///
    /// 面は `listRowBackground` で敷くので、スワイプ操作や長押しはそのまま効きます。
    /// 上下に隙間を取って、行どうしが1枚ずつのカードに見えるようにします。
    func pastelCardRow(colorHex: String) -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: SubscSpacing.Corner.row, style: .continuous)
                .fill(PastelTint.card(for: colorHex))
                .padding(.vertical, 4)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 16))
    }
}
