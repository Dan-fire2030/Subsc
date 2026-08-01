import Foundation

/// 費目の種別です。カテゴリ（エンタメ・仕事など）より一段上の分類で、
/// 「サブスクなのか、通信費なのか」を表します。
///
/// 利用者が増やせない固定の4種類にしています。種別ごとにアイコンや集計の扱いを
/// 型側へ持たせたいためで、自由追加にするとそれができなくなります。
/// 自由な分類が欲しい場合は既存のカテゴリを使います。
enum CostType: String, CaseIterable, Codable, Identifiable {
    case subscription
    case communication
    case utility
    case fixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subscription: "サブスク"
        case .communication: "通信費"
        case .utility: "光熱費"
        case .fixed: "その他固定費"
        }
    }

    var systemImage: String {
        switch self {
        case .subscription: "repeat.circle.fill"
        case .communication: "wifi"
        case .utility: "bolt.fill"
        case .fixed: "house.fill"
        }
    }

    /// レポートで種別を見分けるための色です。
    ///
    /// カード背景は必ず暗い色へ補正されるため、明るく高彩度な色なら背景上で見分けられます。
    /// また、利用中の緑・停止中のオレンジ・削除の赤という状態色と意味が衝突しない色を選んでいます。
    var colorHex: String {
        switch self {
        case .subscription: "#64D2FF"
        case .communication: "#BF5AF2"
        case .utility: "#FFD60A"
        case .fixed: "#FF6482"
        }
    }

    /// 金額が毎月変わることが多い種別かどうかです。
    /// 登録時のトグルの初期値を決めるだけで、実際に変動費かどうかは費目ごとに指定します。
    var suggestsVariableAmount: Bool {
        self == .utility
    }
}
