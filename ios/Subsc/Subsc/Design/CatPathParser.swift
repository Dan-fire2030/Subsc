import SwiftUI

/// SVGのパスデータを SwiftUI の `Path` へ変換します。
///
/// **猫の絵は座標を手で置くと破綻します。** 生成した下絵を輪郭抽出してベジェ化したものが
/// 元データで、点の数が1状態あたり数百に及ぶため、`addCurve` を並べて書き写せません。
/// そこで元の書式のまま持ち、ここで読みます。
///
/// **対応するのは絶対座標の `M` / `C` / `Z` だけです。** 元データがこの3つしか使っておらず、
/// 汎用のSVGパーサーを持つと、使わない分岐まで正しさを保証し続けることになるためです。
/// 相対座標（小文字）・`L`・`A`・指数表記は解釈せず読み飛ばします。
///
/// **数が足りない命令は、途中まで採用せず丸ごと捨てます。** 中途半端に採用すると
/// 直前の点から意図しない線が伸び、絵が壊れたまま気づけません。
enum CatPathParser {
    /// パスデータ1本を `Path` へ変換します。
    static func path(from data: String) -> Path {
        var path = Path()
        var command: Character?
        var numbers: [CGFloat] = []
        let characters = Array(data)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character == "," || character.isWhitespace {
                index += 1
                continue
            }

            if character.isLetter {
                apply(command, numbers, to: &path)
                numbers.removeAll(keepingCapacity: true)
                command = character
                index += 1
                continue
            }

            let start = index
            if character == "-" || character == "+" { index += 1 }
            while index < characters.count, characters[index].isNumber || characters[index] == "." {
                index += 1
            }

            // **必ず1文字は進めます。** 読めない文字で位置が止まると無限ループになります。
            guard index > start, let value = Double(String(characters[start..<index])) else {
                index = start + 1
                continue
            }
            numbers.append(CGFloat(value))
        }

        apply(command, numbers, to: &path)
        return path
    }

    /// 命令1つを適用します。
    private static func apply(_ command: Character?, _ numbers: [CGFloat], to path: inout Path) {
        switch command {
        case "M":
            guard numbers.count >= 2 else { return }
            path.move(to: CGPoint(x: numbers[0], y: numbers[1]))

        case "C":
            // 3次ベジエは6数値で1本。命令の文字を繰り返さず数値だけ続ける書き方に備え、
            // 6ずつ取り出せる分だけ進めます。余りは捨てます。
            // 始点が無いまま曲線を足すと Core Graphics 側で不正な形になります。
            // **ループの外で1度だけ見ます。** `currentPoint` は溜めた要素をたどるため、
            // 1本ごとに呼ぶと本数の2乗に比例して遅くなります。
            guard path.currentPoint != nil else { return }
            var offset = 0
            while offset + 6 <= numbers.count {
                path.addCurve(
                    to: CGPoint(x: numbers[offset + 4], y: numbers[offset + 5]),
                    control1: CGPoint(x: numbers[offset], y: numbers[offset + 1]),
                    control2: CGPoint(x: numbers[offset + 2], y: numbers[offset + 3])
                )
                offset += 6
            }

        case "Z":
            path.closeSubpath()

        default:
            return
        }
    }
}
