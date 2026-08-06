import Observation
import SwiftUI

/// 利用者が選んだテーマ色を保持します。
///
/// 端末ごとの見た目の好みなので、CloudKitへは同期せず`UserDefaults`に閉じます。
/// スキーマを増やさないぶん、Productionへのスキーマ反映と無関係に変更できます。
@Observable
final class ThemeStore {
    /// 既定値です。**2026-08-05のリデザインで黒猫の配色へ変えました。**
    /// 色を選んでいない利用者の見た目も変わります（それがリデザインの目的です）。
    enum Defaults {
        /// タブバー・リンクの色です。**2026-08-05に金目へ変えました。**
        /// 青のままだと、墨と金目の画面で操作部品だけがiOS標準の顔で残ります。
        static let buttonHex = "#D9A43C"
        /// これまで唯一の表示だった横棒グラフに最も近い、構成比が素直に読める表示です。
        static let chartStyle = ReportChartStyle.bar
    }

    private enum Keys {
        static let buttonHex = "theme.buttonHex"
        static let chartStyle = "theme.chartStyle"
    }

    /// テスト時に本物の`UserDefaults`を汚さないよう、既定値つきで注入します。
    private let defaults: UserDefaults

    var buttonHex: String {
        didSet { defaults.set(buttonHex, forKey: Keys.buttonHex) }
    }

    /// グラフの表示方法です。保存値が壊れていても既定へ倒して起動を止めません。
    var chartStyle: ReportChartStyle {
        didSet { defaults.set(chartStyle.rawValue, forKey: Keys.chartStyle) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.buttonHex = defaults.string(forKey: Keys.buttonHex) ?? Defaults.buttonHex
        self.chartStyle = defaults.string(forKey: Keys.chartStyle)
            .flatMap(ReportChartStyle.init(rawValue:)) ?? Defaults.chartStyle
    }

    /// 自由選択で破綻した配色から復帰できるよう、まとめて戻します。
    func resetToDefaults() {
        buttonHex = Defaults.buttonHex
        chartStyle = Defaults.chartStyle
    }

    /// 既定のままかどうかです。「既定に戻す」を出し分けるために使います。
    ///
    /// `ColorPicker` は同じ色でも表記が揺れた文字列を返すことがあるため、
    /// 生の文字列ではなく正規形で比べます。表示名の判定とも基準を揃えています。
    var isDefault: Bool {
        ColorHex.canonical(buttonHex) == ColorHex.canonical(Defaults.buttonHex)
            && chartStyle == Defaults.chartStyle
    }

    // MARK: - 設定画面に出す名前

    /// ボタン色の表示名です。
    var buttonColorName: String {
        Self.displayName(for: buttonHex, whenDefault: Defaults.buttonHex)
    }

    /// 既定値は現在の画面の色を実測したもので、プリセットのブルー（`#007AFF`）とは別の色です。
    /// そのままプリセット名を引くと、何も変更していない利用者に「カスタム」と見えてしまうため、
    /// 既定値だけは「既定」と呼びます。
    private static func displayName(for hex: String, whenDefault defaultHex: String) -> String {
        ColorHex.canonical(hex) == ColorHex.canonical(defaultHex)
            ? "既定"
            : ThemeColorPreset.title(for: hex)
    }

    /// 設定画面で使う、テーマの影響を受けないボタン色です。
    ///
    /// 色を選んでいる最中に設定画面自身の色まで動くと、
    /// **何を変えているのかが分かりにくくなります**。設定画面は既定色で固定します。
    static var fixedButtonColor: Color {
        ColorHex.color(from: ThemeColor.buttonTint(from: Defaults.buttonHex))
    }

    // MARK: - 画面が使う色

    /// タブバーやリンクの色です。暗すぎる指定だけ引き上げます。
    var buttonColor: Color {
        ColorHex.color(from: ThemeColor.buttonTint(from: buttonHex))
    }
}

// **カードの色を選ぶ設定は削除しました（2026-08-06）。**
//
// カードは黒猫の配色では「地から浮いた面」で、色を持たせる場所ではありません。
// 選べるままにすると、面の明度差だけで作った構造がその都度崩れます。
// 画面全体へうっすら掛ける光は `BlackCatPalette.accent`（金目）で固定しました。
//
// 保存値（`theme.cardHex`）は `UserDefaults` に残りますが、読まなくなるだけです。
// 消しに行かないのは、**戻したくなったときに利用者の選択が残っている**ほうが良いためで、
// 残っていても他の設定と衝突しません。
