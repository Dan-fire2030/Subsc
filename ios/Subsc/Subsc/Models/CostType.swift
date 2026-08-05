import Foundation

/// 費目の種別です。カテゴリ（エンタメ・仕事など）より一段上の分類で、
/// 「サブスクなのか、通信費なのか」を表します。
///
/// 利用者が増やせない固定の5種類にしています。種別ごとにアイコンや集計の扱いを
/// 型側へ持たせたいためで、自由追加にするとそれができなくなります。
/// 自由な分類が欲しい場合は既存のカテゴリを使います。
enum CostType: String, CaseIterable, Codable, Identifiable {
    case subscription
    case communication
    case utility
    case fixed
    /// 借金・ローンの返済です。元本と利息を持ち、返済予定表から金額が決まります。
    case loan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subscription: "サブスク"
        case .communication: "通信費"
        case .utility: "光熱費"
        case .fixed: "その他固定費"
        case .loan: "借入・ローン"
        }
    }

    var systemImage: String {
        switch self {
        case .subscription: "repeat.circle.fill"
        case .communication: "wifi"
        case .utility: "bolt.fill"
        case .fixed: "house.fill"
        case .loan: "banknote.fill"
        }
    }

    /// レポートで種別を見分けるための色です。
    ///
    /// カード背景は必ず暗い色へ補正されるため、明るく高彩度な色なら背景上で見分けられます。
    /// また、利用中の緑・停止中のオレンジ・削除の赤という状態色と意味が衝突しない色を選んでいます。
    var colorHex: String {
        // **黒猫のパレット（`BlackCatPalette.Category`）から選びます（2026-08-05）。**
        // 種別は費目より上位の区別なので、費目の色と同じ体系から取り、
        // 彩度だけが飛び抜けることのないようにします。
        switch self {
        case .subscription: "#7FB3D5"
        case .communication: "#C4B37F"
        case .utility: "#E0A66B"
        case .fixed: "#D98FA6"
        // 鈍色。借入は**費目の寄せ先から外してある唯一の色**なので、
        // 一覧で費目に紛れません（`BlackCatPalette.Category.hueTargets`）。
        case .loan: "#8FA8C4"
        }
    }

    /// 費目（`Subscription`）のフォームで選べる種別です。
    ///
    /// **借入・ローンは含めません。** 借入は元本と利息を持つ別のモデル（`Loan`）で扱うため、
    /// ここで選べてしまうと「返済予定表の無い借入」ができてしまいます。
    static var subscriptionSelectable: [CostType] {
        allCases.filter { $0 != .loan }
    }

    /// 金額が毎月変わることが多い種別かどうかです。
    /// 登録時のトグルの初期値を決めるだけで、実際に変動費かどうかは費目ごとに指定します。
    var suggestsVariableAmount: Bool {
        self == .utility
    }
}
