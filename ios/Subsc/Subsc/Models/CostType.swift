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

    /// 金額が毎月変わることが多い種別かどうかです。
    /// 登録時のトグルの初期値を決めるだけで、実際に変動費かどうかは費目ごとに指定します。
    var suggestsVariableAmount: Bool {
        self == .utility
    }
}
