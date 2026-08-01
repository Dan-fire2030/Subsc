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
    }

    private enum Keys {
        static let buttonHex = "theme.buttonHex"
        static let cardHex = "theme.cardHex"
    }

    /// テスト時に本物の`UserDefaults`を汚さないよう、既定値つきで注入します。
    private let defaults: UserDefaults

    var buttonHex: String {
        didSet { defaults.set(buttonHex, forKey: Keys.buttonHex) }
    }

    var cardHex: String {
        didSet { defaults.set(cardHex, forKey: Keys.cardHex) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.buttonHex = defaults.string(forKey: Keys.buttonHex) ?? Defaults.buttonHex
        self.cardHex = defaults.string(forKey: Keys.cardHex) ?? Defaults.cardHex
    }

    /// 自由選択で破綻した配色から復帰できるよう、両方をまとめて戻します。
    func resetToDefaults() {
        buttonHex = Defaults.buttonHex
        cardHex = Defaults.cardHex
    }

    /// 既定のままかどうかです。「既定に戻す」を出し分けるために使います。
    var isDefault: Bool {
        buttonHex == Defaults.buttonHex && cardHex == Defaults.cardHex
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
}
