import Foundation

/// レポートカードの費目別グラフの表示方法です。
///
/// 1つに絞らず利用者に選ばせています。伝えたいこと（構成比）は同じでも、
/// 好みと画面の見やすさは人によって違うためです。
enum ReportChartStyle: String, CaseIterable, Identifiable {
    /// 積み上げた1本の帯。構成比が最も素直に読める。
    case bar
    /// 同心のリング。
    case ring
    /// 面積が金額を表す円。ズームで細部を見る。
    case bubble
    /// 縦のバー。横スクロールで全件を見る。
    case column

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bar: "帯"
        case .ring: "リング"
        case .bubble: "バブル"
        case .column: "縦バー"
        }
    }

    /// 設定画面で、その表示が何を見せるものかを一言で伝えます。
    var summary: String {
        switch self {
        case .bar: "種別ごとの割合を1本の帯で表します"
        case .ring: "種別ごとの割合を同心のリングで表します"
        case .bubble: "費目ごとの金額を円の大きさで表します。つまんで拡大できます"
        case .column: "費目ごとの金額を縦のバーで表します。横にスクロールできます"
        }
    }

    var systemImage: String {
        switch self {
        case .bar: "rectangle.split.3x1.fill"
        case .ring: "circle.circle"
        case .bubble: "circle.hexagongrid.fill"
        case .column: "chart.bar.fill"
        }
    }

    /// 種別ごとに集計して見せるか、費目ごとに1つずつ見せるかです。
    ///
    /// 帯とリングは要素が多いと潰れるため種別（最大4つ）へまとめます。
    /// バブルと縦バーはズームや横スクロールという工夫があるので全件を出します。
    var aggregatesByCostType: Bool {
        switch self {
        case .bar, .ring: true
        case .bubble, .column: false
        }
    }
}
