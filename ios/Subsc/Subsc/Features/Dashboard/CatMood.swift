import Foundation

/// 相棒の黒猫が、いまどの姿で座っているかです。
///
/// **文言ではなく姿勢で状況を伝える**ため、状態ごとにシルエットごと変えます
/// （目と耳だけの差し替えでは、並べても見分けがつきませんでした）。
enum CatMood: String, CaseIterable, Identifiable {
    /// 特筆すべきことがない。基準の姿勢。
    case calm
    /// 支出が直近の平均より目立って多い。うずくまる。
    case worried
    /// 支出が直近の平均より少ない。胸を張る。
    case pleased
    /// 大きな支払いが近い。背を伸ばして見張る。
    case watching
    /// 変動費が未入力のまま月末が近い。立ち上がって両手を上げる。
    case nudging
    /// 費目がまだ1件も無い。横を向いて指し示す。
    case guiding

    var id: String { rawValue }

    /// 支援技術へ読み上げる名前です。画面には文字として出しません。
    var title: String {
        switch self {
        case .calm: "いつもどおり"
        case .worried: "支出が増えています"
        case .pleased: "支出が落ち着いています"
        case .watching: "大きな支払いが近づいています"
        case .nudging: "未入力の金額があります"
        case .guiding: "費目がまだありません"
        }
    }
}

extension CatMood {
    /// 判定に使う閾値です。マジックナンバーを散らさないよう型に閉じます。
    enum Threshold {
        /// 平均比でこれを超えたら「増えた」とみなします。
        /// **わずかな増減で表情が動くと落ち着かない**ため、幅を持たせています。
        static let increaseRatio = 1.15
        /// 平均比でこれを下回ったら「減った」とみなします。
        static let decreaseRatio = 0.85
        /// 閾値ちょうどを「超えていない」側に倒すための遊びです。
        /// 丸め誤差で表情が入れ替わるのを防ぎます。
        static let epsilon = 1e-9
        /// 月末まで何日以内なら催促するかです。
        /// **まだ入力する時間があるうちに急かすと、毎日出続けて意味を失います。**
        static let nudgeWithinDaysOfMonthEnd = 7
    }

    /// いまの状況から状態を1つ選びます。
    ///
    /// **優先順位は、利用者の行動につながる順**です：
    /// 案内（まだ何も無い）→ 催促（入力してほしい）→ 見張る（これから出ていく）
    /// → 増減（すでに出た額の評価）。
    ///
    /// 保存データに依存しない引数だけを受け取り、実行日も注入します。
    /// 画面から切り離してテストできるようにするためです。
    static func decide(
        registrationCount: Int,
        monthlyTotal: Double,
        recentAverage: Double?,
        hasUpcomingLargeCharge: Bool,
        hasUnenteredVariableCost: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CatMood {
        if registrationCount <= 0 { return .guiding }

        if hasUnenteredVariableCost, isNearMonthEnd(now: now, calendar: calendar) {
            return .nudging
        }

        if hasUpcomingLargeCharge { return .watching }

        // 比較できる過去が無い月や、平均が0円の月は増減を語りません。
        // 0で割ると必ず「増えた」になり、初月の利用者を無用に心配させます。
        guard let average = recentAverage, average > 0 else { return .calm }

        // **平均に倍率を掛けて比べません。** `50,000 × 1.15` は 57499.999… になり、
        // ちょうど閾値の額が「超えた」と判定されます。割って比にすれば、
        // 閾値と同じ表現の値どうしの比較になり、境目が意図どおりに閉じます。
        let ratio = monthlyTotal / average
        if ratio > Threshold.increaseRatio + Threshold.epsilon { return .worried }
        if ratio < Threshold.decreaseRatio - Threshold.epsilon { return .pleased }
        return .calm
    }

    /// 月末が近いかどうかです。月の長さが月ごとに違うため、日数で決め打ちしません。
    private static func isNearMonthEnd(now: Date, calendar: Calendar) -> Bool {
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return false }
        let lastDay = range.upperBound - 1
        let today = calendar.component(.day, from: now)
        return lastDay - today < Threshold.nudgeWithinDaysOfMonthEnd
    }
}
