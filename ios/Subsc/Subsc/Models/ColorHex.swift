import SwiftUI
import UIKit

/// `Color` と `#RRGGBB` 形式の文字列を相互変換します。
///
/// SwiftDataへは16進数の文字列として保存するため、表示時と保存時に変換が必要です。
/// `ColorPicker` はDisplay P3の色を返すことがあり、sRGB成分が0...1の範囲外に
/// なりうるため、書き出し時にクランプします。
enum ColorHex {
    /// 変換できない入力に対して使う色です。
    static let fallback = "#000000"

    /// 16進数の文字列を `Color` へ変換します。解釈できない場合は黒を返します。
    static func color(from hex: String) -> Color {
        guard let digits = hexDigits(from: hex),
              let value = UInt32(digits, radix: 16) else {
            return Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
        }
        return Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }

    /// `Color` を `#RRGGBB` 形式へ変換します。成分を取得できない場合は黒を返します。
    static func string(from color: Color) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return fallback
        }
        return string(red: red, green: green, blue: blue)
    }

    /// sRGBの成分から `#RRGGBB` 形式を組み立てます。範囲外の成分はクランプします。
    static func string(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        String(
            format: "#%02X%02X%02X",
            channel(red),
            channel(green),
            channel(blue)
        )
    }

    /// 入力を `#RRGGBB` の正規形へ揃えます。保存値の比較に使います。
    static func canonical(_ hex: String) -> String {
        guard let digits = hexDigits(from: hex) else { return fallback }
        return "#\(digits)"
    }

    /// その色を背景にしたとき、上の文字を黒にすべきかを返します。
    ///
    /// **黄色の上の白文字は読めません**（DAZN・povo・chocoZAP のようなブランド色）。
    /// 明るさは知覚に合わせた重み付けで求めます。読み取れない色では白のままにし、
    /// 従来の見え方を変えません。
    static func prefersDarkText(on hex: String) -> Bool {
        guard let digits = hexDigits(from: hex),
              let value = UInt32(digits, radix: 16) else {
            return false
        }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return 0.299 * red + 0.587 * green + 0.114 * blue > 0.6
    }

    /// `#` や前後の空白を取り除き、6桁の16進数だけを取り出します。
    private static func hexDigits(from hex: String) -> String? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutHash = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard withoutHash.count == 6,
              withoutHash.allSatisfy(\.isHexDigit) else {
            return nil
        }
        return withoutHash.uppercased()
    }

    private static func channel(_ value: CGFloat) -> Int {
        Int((min(max(value, 0), 1) * 255).rounded())
    }
}
