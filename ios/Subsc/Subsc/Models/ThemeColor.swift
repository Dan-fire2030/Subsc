import SwiftUI
import UIKit

/// 保存形式のsRGB十六進文字列から、可読性を保ったテーマ色を生成します。
///
/// UIの `Color` ではなく文字列で入出力し、表示層や呼び出し順に依存しない
/// テスト可能な変換として閉じ込めます。
enum ThemeColor {
    /// 白文字が読める輝度範囲に収め、色相と彩度を保ったカード基準色を返します。
    static func readableCardBase(from hex: String) -> String {
        let canonical = ColorHex.canonical(hex)
        let rgb = rgb(from: canonical)
        let currentLuminance = relativeLuminance(of: rgb)

        guard currentLuminance > Constants.maximumCardLuminance
                || currentLuminance < Constants.minimumCardLuminance else {
            return canonical
        }

        let hsb = hsb(from: rgb)
        let correctedBrightness: Double

        if currentLuminance > Constants.maximumCardLuminance {
            correctedBrightness = resolvedBrightness(
                for: hsb,
                between: 0...hsb.brightness,
                satisfying: { relativeLuminance(of: $0) <= Constants.maximumCardLuminance },
                preferUpperBound: true
            )
        } else {
            correctedBrightness = resolvedBrightness(
                for: hsb,
                between: hsb.brightness...1,
                satisfying: { relativeLuminance(of: $0) >= Constants.minimumCardLuminance },
                preferUpperBound: false
            )
        }

        return quantizedReadableHex(
            hue: hsb.hue,
            saturation: hsb.saturation,
            brightness: correctedBrightness,
            raisesBrightness: currentLuminance < Constants.minimumCardLuminance
        )
    }

    /// 単色指定でも既存カードの立体感を保てるよう、相対的な色相差を持つ3色を返します。
    ///
    /// **基準色だけでなく、生成した各停止色にも輝度の補正をかけます。**
    /// 色相と明度をずらすと輝度が動くため、基準色だけ補正しても
    /// グラデーションの端（既定色なら右下のシアン寄り）で白文字が読めなくなります。
    static func cardGradient(from hex: String) -> [String] {
        let base = hsb(from: rgb(from: readableCardBase(from: hex)))
        return Constants.gradientStops.map { stop in
            let shifted = hexString(from: HSB(
                hue: wrappedHue(base.hue + stop.hueOffset),
                saturation: clamped(base.saturation * stop.saturationMultiplier),
                brightness: clamped(base.brightness * stop.brightnessMultiplier)
            ))
            return readableCardBase(from: shifted)
        }
    }

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
        static let maximumCardLuminance = 0.179
        static let minimumCardLuminance = 0.02
        static let minimumButtonBrightness = 0.35
        static let channelMaximum = 255.0
        static let quantizedMinimumButtonBrightness = ceil(minimumButtonBrightness * channelMaximum)
            / channelMaximum
        static let binarySearchIterations = 40
        static let hueCycle = 360.0

        static let gradientStops = [
            GradientStop(hueOffset: 0, saturationMultiplier: 1, brightnessMultiplier: 1),
            GradientStop(hueOffset: 40, saturationMultiplier: 0.80, brightnessMultiplier: 0.89),
            GradientStop(hueOffset: -17, saturationMultiplier: 1, brightnessMultiplier: 0.957)
        ]
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

    struct GradientStop {
        let hueOffset: Double
        let saturationMultiplier: Double
        let brightnessMultiplier: Double
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

    static func relativeLuminance(of rgb: RGB) -> Double {
        0.2126 * linearized(rgb.red)
            + 0.7152 * linearized(rgb.green)
            + 0.0722 * linearized(rgb.blue)
    }

    static func linearized(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }

    static func resolvedBrightness(
        for hsb: HSB,
        between range: ClosedRange<Double>,
        satisfying condition: (RGB) -> Bool,
        preferUpperBound: Bool
    ) -> Double {
        var lower = range.lowerBound
        var upper = range.upperBound

        for _ in 0..<Constants.binarySearchIterations {
            let midpoint = (lower + upper) / 2
            let candidate = rgb(from: HSB(
                hue: hsb.hue,
                saturation: hsb.saturation,
                brightness: midpoint
            ))
            if condition(candidate) == preferUpperBound {
                lower = midpoint
            } else {
                upper = midpoint
            }
        }
        return preferUpperBound ? lower : upper
    }

    static func quantizedReadableHex(
        hue: Double,
        saturation: Double,
        brightness: Double,
        raisesBrightness: Bool
    ) -> String {
        var adjustedBrightness = brightness
        let step = 1 / Constants.channelMaximum

        for _ in 0...Int(Constants.channelMaximum) {
            let result = hexString(from: HSB(
                hue: hue,
                saturation: saturation,
                brightness: adjustedBrightness
            ))
            let luminance = relativeLuminance(of: rgb(from: result))
            let isReadable = raisesBrightness
                ? luminance >= Constants.minimumCardLuminance
                : luminance <= Constants.maximumCardLuminance
            if isReadable { return result }
            adjustedBrightness = clamped(adjustedBrightness + (raisesBrightness ? step : -step))
        }

        return hexString(from: HSB(
            hue: hue,
            saturation: saturation,
            brightness: adjustedBrightness
        ))
    }

    static func wrappedHue(_ hue: Double) -> Double {
        let remainder = hue.truncatingRemainder(dividingBy: Constants.hueCycle)
        return remainder < 0 ? remainder + Constants.hueCycle : remainder
    }

    static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
