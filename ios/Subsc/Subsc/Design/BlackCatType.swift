import SwiftUI

/// 黒猫のデザイン言語の書体です。
///
/// **段は4つだけにします**（金額・見出し・本文・補足）。段を増やすほど画面はうるさくなり、
/// 「どれが今いちばん大事か」が消えます。
///
/// **すべて相対指定（`.system(_:design:weight:)`）です。** 固定ptにすると、
/// 文字を大きくしている利用者の画面で崩れます。
enum BlackCatType {
    /// レポートの合計です。画面でいちばん大きい数字。
    static let amount = Font.system(.largeTitle, design: .rounded, weight: .bold)
    /// 一覧の行に出る金額です。合計より一段小さく、行の中では最も強い。
    static let rowAmount = Font.system(.subheadline, design: .rounded, weight: .semibold)
    /// 見出しです。
    static let title = Font.system(.title3, weight: .bold)
    /// 本文（費目名など）です。
    static let body = Font.system(.body, weight: .semibold)
    /// 補足（更新日・メモ）です。
    static let label = Font.system(.caption)
    /// 小さなラベル（バッジの中）です。
    static let badge = Font.system(.caption2, weight: .semibold)
}

/// 余白と角丸です。**4の倍数で刻みます。**
///
/// 刻みを決めておかないと、画面ごとに 10 / 11 / 13 のような値が混ざり、
/// 直接は気づかれないまま「なんとなく雑」に見えます。
enum BlackCatSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    /// 角丸です。カード＞行＞バッジの順に小さくし、入れ子の関係を形でも示します。
    enum Corner {
        static let card: CGFloat = 22
        static let row: CGFloat = 14
        static let badge: CGFloat = 999
    }
}
