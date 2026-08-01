import Observation
import SwiftUI

/// 利用者が選んだテーマ色を保持します。
///
/// 端末ごとの見た目の好みなので、CloudKitへは同期せず`UserDefaults`に閉じます。
/// スキーマを増やさないぶん、Productionへのスキーマ反映と無関係に変更できます。
@Observable
final class ThemeStore {
    /// 既定値です。**現在の画面と同じ色**にしてあり、未設定の利用者の見た目を変えません。
    enum Defaults {
        /// `RootView` の `.tint` に入っていた色です。
        static let buttonHex = "#1473FA"
        /// レポートカードのグラデーション1色目です。
        static let cardHex = "#0D61EB"
        /// これまで唯一の表示だった横棒グラフに最も近い、構成比が素直に読める表示です。
        static let chartStyle = ReportChartStyle.bar
    }

    private enum Keys {
        static let buttonHex = "theme.buttonHex"
        static let cardHex = "theme.cardHex"
        static let chartStyle = "theme.chartStyle"
    }

    /// テスト時に本物の`UserDefaults`を汚さないよう、既定値つきで注入します。
    private let defaults: UserDefaults

    var buttonHex: String {
        didSet { defaults.set(buttonHex, forKey: Keys.buttonHex) }
    }

    var cardHex: String {
        didSet { defaults.set(cardHex, forKey: Keys.cardHex) }
    }

    /// グラフの表示方法です。保存値が壊れていても既定へ倒して起動を止めません。
    var chartStyle: ReportChartStyle {
        didSet { defaults.set(chartStyle.rawValue, forKey: Keys.chartStyle) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.buttonHex = defaults.string(forKey: Keys.buttonHex) ?? Defaults.buttonHex
        self.cardHex = defaults.string(forKey: Keys.cardHex) ?? Defaults.cardHex
        self.chartStyle = defaults.string(forKey: Keys.chartStyle)
            .flatMap(ReportChartStyle.init(rawValue:)) ?? Defaults.chartStyle
    }

    /// 自由選択で破綻した配色から復帰できるよう、まとめて戻します。
    func resetToDefaults() {
        buttonHex = Defaults.buttonHex
        cardHex = Defaults.cardHex
        chartStyle = Defaults.chartStyle
    }

    /// 既定のままかどうかです。「既定に戻す」を出し分けるために使います。
    ///
    /// `ColorPicker` は同じ色でも表記が揺れた文字列を返すことがあるため、
    /// 生の文字列ではなく正規形で比べます。表示名の判定とも基準を揃えています。
    var isDefault: Bool {
        ColorHex.canonical(buttonHex) == ColorHex.canonical(Defaults.buttonHex)
            && ColorHex.canonical(cardHex) == ColorHex.canonical(Defaults.cardHex)
            && chartStyle == Defaults.chartStyle
    }

    // MARK: - 設定画面に出す名前

    /// ボタン色の表示名です。
    var buttonColorName: String {
        Self.displayName(for: buttonHex, whenDefault: Defaults.buttonHex)
    }

    /// カード色の表示名です。
    var cardColorName: String {
        Self.displayName(for: cardHex, whenDefault: Defaults.cardHex)
    }

    /// 既定値は現在の画面の色を実測したもので、プリセットのブルー（`#007AFF`）とは別の色です。
    /// そのままプリセット名を引くと、何も変更していない利用者に「カスタム」と見えてしまうため、
    /// 既定値だけは「既定」と呼びます。
    private static func displayName(for hex: String, whenDefault defaultHex: String) -> String {
        ColorHex.canonical(hex) == ColorHex.canonical(defaultHex)
            ? "既定"
            : ThemeColorPreset.title(for: hex)
    }

    // MARK: - 画面が使う色

    /// タブバーやリンクの色です。暗すぎる指定だけ引き上げます。
    var buttonColor: Color {
        ColorHex.color(from: ThemeColor.buttonTint(from: buttonHex))
    }

    /// カードの基準色です。白文字が読める範囲へ補正済みの色を返します。
    var cardBaseColor: Color {
        ColorHex.color(from: ThemeColor.readableCardBase(from: cardHex))
    }

    /// カード背景の3色グラデーションです。1色の選択から生成します。
    var cardGradientColors: [Color] {
        ThemeColor.cardGradient(from: cardHex).map(ColorHex.color(from:))
    }

    /// グラデーション2色目です。カード上と画面背景で光らせる円に使います。
    ///
    /// 呼び出し側で `cardGradientColors[1]` と書くと、段数を変えたときに
    /// 範囲外アクセスで落ちます。名前で取り出せるようにして落ちない形にします。
    var cardHighlightColor: Color {
        let colors = cardGradientColors
        return colors.count > 1 ? colors[1] : cardBaseColor
    }

    /// グラデーション3色目です。用途は `cardHighlightColor` と同じです。
    var cardAccentColor: Color {
        cardGradientColors.last ?? cardBaseColor
    }
}
