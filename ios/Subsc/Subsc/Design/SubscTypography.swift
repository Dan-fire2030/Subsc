import SwiftUI

/// アプリの書体です（2026-10-15にパステルの案Aへ合わせました）。
///
/// **段は4つだけにします**（金額・見出し・本文・補足）。段を増やすほど画面はうるさくなり、
/// 「どれが今いちばん大事か」が消えます。
///
/// **すべて相対指定（`.system(_:design:weight:)`）です。** 固定ptにすると、
/// 文字を大きくしている利用者の画面で崩れます。
///
/// **フォントは同梱しません。** 数字は SF Rounded（`design: .rounded`）で丸みを出し、
/// 和文はシステム書体（ヒラギノ角ゴ）のままにします。同梱するとアプリが数MB重くなり、
/// 文字サイズの拡大にも別の手当てが要るためです。
enum SubscTypography {
    /// レポートの合計です。画面でいちばん大きい数字。
    static let amount = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    /// 一覧の行に出る金額です。合計より小さく、行の中では最も強い。
    /// 費目名と同じ大きさにし、太さと丸みで金額だと分かるようにします。
    static let rowAmount = Font.system(.body, design: .rounded, weight: .bold)
    /// 見出しです。
    static let title = Font.system(.title3, weight: .bold)
    /// 本文（費目名など）です。
    static let body = Font.system(.body, weight: .semibold)
    /// 補足（更新日・メモ）です。パステルのカードの上でも読めるよう、caption から一段上げました。
    static let label = Font.system(.footnote)
    /// 小さなラベル（バッジの中）です。
    static let badge = Font.system(.caption2, weight: .semibold)
}

/// 余白と角丸です。**4の倍数で刻みます。**
///
/// 刻みを決めておかないと、画面ごとに 10 / 11 / 13 のような値が混ざり、
/// 直接は気づかれないまま「なんとなく雑」に見えます。
enum SubscSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    /// 角丸です。カード＞行＞バッジの順に小さくし、入れ子の関係を形でも示します。
    enum Corner {
        static let card: CGFloat = 26
        static let row: CGFloat = 22
        static let badge: CGFloat = 999
    }
}
