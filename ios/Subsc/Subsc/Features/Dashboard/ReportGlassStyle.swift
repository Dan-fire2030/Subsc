import SwiftUI

/// レポートカードの外枠です。
///
/// **2026-08-05に、色付きガラスから「面」の表現へ変えました。**
/// 黒猫の画面では地が墨（または白磁）で、カードはその上に置く一段明るい面です。
/// カード自体を色付きのガラスにすると、費目の色分けと競合して
/// **グラフの色が背景色に引きずられて見える**ためです。
///
/// **2026-08-06にマットへ変えました。境界線も落ち影も持ちません。**
/// 線を引くと線そのものが情報として読まれ、影を落とすと面が「箱」に見えます。
/// 地との差は**明度3%前後**だけで、境目は見えないまま領域が伝わります。
/// 角丸を26と大きく取っているのは、線が無いぶん輪郭の丸みで一塊を示すためです。
///
/// Liquid Glass はボタン・ツールバー・検索といった**操作部品に残しています**。
/// **画面で光るのは操作部品だけ**になり、「光っている＝触れる」が手がかりになります。
struct ReportCardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                BlackCatPalette.surface,
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
    }
}

/// レポートカード内の操作ボタン（前後の期間・今期間へ戻る）の見た目です。
struct ReportControlButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
        } else {
            content
                .buttonStyle(.plain)
                .background(.black.opacity(0.16), in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.32), lineWidth: 0.7)
                }
        }
    }
}

/// 小さめのカプセル背景です。ボタンスタイルではなくラベルへ直接当てるので、
/// 見た目を小さく保ったまま外側で44ptのタップ領域を確保できます。
struct CompactGlassCapsuleModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.black.opacity(0.16), in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.32), lineWidth: 0.7)
                }
        }
    }
}

// MARK: - グラフ要素のガラス

/// グラフの図形（円・帯・リング）をガラスに見せるための素材です。
///
/// **4つのスタイルで同じ質感にするため、値をここへ集めています。**
/// 各ファイルへ書き分けると、後から濃さや光沢を揃え直せなくなります。
///
/// **色は薄めすぎません。** 費目・種別の色分けは情報そのもので、
/// 透過を強くすると4色の区別が付かなくなり、グラフとして機能しなくなります。
enum ReportChartGlass {
    /// 塗りのグラデーションです。上を明るく、下を沈ませて厚みを出します。
    static func fill(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(0.96),
                color.opacity(0.74),
                color.opacity(0.88)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 縁のリムライトです。光が縁を回り込んでいるように見せます。
    static let rim = LinearGradient(
        colors: [.white.opacity(0.62), .white.opacity(0.08), .white.opacity(0.28)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let rimWidth: CGFloat = 0.8

    /// iOS 26 で重ねるガラスのティントの濃さです。
    /// **強くすると色が飛びます。** 質感を足すだけに留めます。
    static let tintOpacity = 0.16

    /// 浮いて見せるための落ち影です。図形の色を薄く敷き、地の色に馴染ませます。
    static func shadowColor(_ color: Color) -> Color {
        color.opacity(0.34)
    }
}

/// グラフの1要素をガラスとして描きます。
///
/// iOS 26 では自前のグラデーションの上に `glassEffect` を重ねます。
/// `ReportCardSurfaceModifier` と同じ二段構えで、iOS 17〜25 でも
/// グラデーション・光沢・リムライトだけで同じ方向の見た目になります。
struct ReportChartGlassShape<S: Shape>: View {
    let shape: S
    let color: Color
    /// 光沢の高さです。**マット化で使わなくなりました**が、呼び出し側の記述を
    /// 一斉に書き換えると差分が大きくなるため、引数は残して無視しています。
    var glossHeight: CGFloat = 0
    var glossInsetRatio: CGFloat = 0.18
    /// 塗りを差し替えます。向きに意味がある図形のために残しています。
    var fillOverride: LinearGradient?

    var body: some View {
        // **単色のフラット塗りです（2026-08-06）。**
        // 光沢もリムライトも、色の上に白を乗せる処理です。淡いカテゴリ色ほど白飛びして
        // 隣の費目と見分けづらくなっていました。フラットなら指定した色がそのまま出ます。
        //
        // 塗りを `LinearGradient` のまま渡しているのは、**呼び出し側が
        // `fillOverride` で向きのある塗りを差し込める**ようにしておくためです。
        shape.fill(fillOverride ?? LinearGradient(colors: [color, color], startPoint: .top, endPoint: .bottom))
    }
}

// **`GlassEffectContainer` はグラフでは使いません。**
//
// 取り込みの負荷を1回へ寄せられるため一度は導入しましたが、ガラスを1枚へまとめる際に
// 中の非ガラス要素（バブルのラベルと上部の光沢）がガラスの下へ潜り、完全に見えなくなりました。
// 要素の外側に `.overlay` を足しても、要素の中へ入れても同じです。
// 数値が読めなくなる代償が大きすぎるため、グラフの要素には個別に `glassEffect` を当てます。

// **`LiquidGlassCardBackground` は削除しました（2026-08-05）。**
//
// テーマ色のグラデーションでレポートカードを塗るための背景でしたが、
// カードを「面」の表現（`BlackCatPalette.surface`）へ変えたことで使い道が無くなりました。
// テーマ色は画面全体のうっすらとした光（`AppLiquidGlassBackground`）に残っています。
