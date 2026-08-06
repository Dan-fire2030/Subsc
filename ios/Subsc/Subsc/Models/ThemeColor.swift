import SwiftUI
import UIKit

/// 保存形式のsRGB十六進文字列から、可読性を保ったテーマ色を生成します。
///
/// UIの `Color` ではなく文字列で入出力し、表示層や呼び出し順に依存しない
/// テスト可能な変換として閉じ込めます。
enum ThemeColor {


    /// タブバーなどで色が沈まないよう、色相と彩度を保ちつつ明度だけを底上げします。
    static func buttonTint(from hex: String) -> String {
        let canonical = ColorHex.canonical(hex)
        let hsb = hsb(from: rgb(from: canonical))
        guard hsb.brightness < Constants.minimumButtonBrightness else { return canonical }

        return hexString(from: HSB(
            hue: hsb.hue,
            saturation: hsb.saturation,
            brightness: Constants.quantizedMinimumButtonBrightness
        ))
    }
}

private extension ThemeColor {
    enum Constants {
        static let minimumButtonBrightness = 0.35
        static let channelMaximum = 255.0
        static let quantizedMinimumButtonBrightness = ceil(minimumButtonBrightness * channelMaximum)
            / channelMaximum
        static let hueCycle = 360.0

    }

    struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

    struct HSB {
        let hue: Double
        let saturation: Double
        let brightness: Double
    }


    static func rgb(from hex: String) -> RGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(ColorHex.color(from: hex)).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGB(red: Double(red), green: Double(green), blue: Double(blue))
    }

    static func hsb(from rgb: RGB) -> HSB {
        let maximum = max(rgb.red, rgb.green, rgb.blue)
        let minimum = min(rgb.red, rgb.green, rgb.blue)
        let delta = maximum - minimum
        let saturation = maximum == 0 ? 0 : delta / maximum
        let hue: Double

        if delta == 0 {
            hue = 0
        } else if maximum == rgb.red {
            hue = 60 * ((rgb.green - rgb.blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maximum == rgb.green {
            hue = 60 * (((rgb.blue - rgb.red) / delta) + 2)
        } else {
            hue = 60 * (((rgb.red - rgb.green) / delta) + 4)
        }

        return HSB(
            hue: wrappedHue(hue),
            saturation: saturation,
            brightness: maximum
        )
    }

    static func rgb(from hsb: HSB) -> RGB {
        let chroma = hsb.brightness * hsb.saturation
        let sector = wrappedHue(hsb.hue) / 60
        let secondary = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let match = hsb.brightness - chroma
        let channels: (Double, Double, Double)

        switch sector {
        case 0..<1: channels = (chroma, secondary, 0)
        case 1..<2: channels = (secondary, chroma, 0)
        case 2..<3: channels = (0, chroma, secondary)
        case 3..<4: channels = (0, secondary, chroma)
        case 4..<5: channels = (secondary, 0, chroma)
        default: channels = (chroma, 0, secondary)
        }

        return RGB(
            red: channels.0 + match,
            green: channels.1 + match,
            blue: channels.2 + match
        )
    }

    static func hexString(from hsb: HSB) -> String {
        let rgb = rgb(from: hsb)
        return ColorHex.string(
            red: CGFloat(rgb.red),
            green: CGFloat(rgb.green),
            blue: CGFloat(rgb.blue)
        )
    }





    static func wrappedHue(_ hue: Double) -> Double {
        let remainder = hue.truncatingRemainder(dividingBy: Constants.hueCycle)
        return remainder < 0 ? remainder + Constants.hueCycle : remainder
    }

    static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
