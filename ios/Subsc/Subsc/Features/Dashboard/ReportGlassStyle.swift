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
///
/// **カードに色を持たせる設定は削除しました（2026-08-06）。**
/// カードは地から浮いた「面」で、色を選ぶ場所ではありません。選べるままにすると、
/// 面の明度差だけで作った構造がその都度崩れます。地へ掛ける光だけ金目で残しています。
struct ReportCardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                BlackCatPalette.surface,
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
    }
}

/// カードの中の沈んだ面です。合計のブロックとグラフの枠が使います。
///
/// 角丸だけを受け取る小さな部品にしているのは、**2箇所で同じ面を使う**ためです。
/// それぞれに `.background(_:in:)` を書くと、面の色を変えるときに片方だけ直す事故が起きます。
struct ReportInnerSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(BlackCatPalette.surfaceElevated)
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

// MARK: - グラフ要素の塗り

/// グラフの1要素（円・帯・棒）を描きます。
///
/// **単色のフラット塗りです（2026-08-06）。**
/// 以前はグラデーション・上端の光沢・縁のリムライト・色付きの落ち影を重ねていましたが、
/// どれも**色の上に白を乗せる処理**で、淡いカテゴリ色ほど白飛びして隣の費目と
/// 見分けづらくなっていました。フラットなら指定した色がそのまま出ます。
///
/// **画面で光るのは操作部品だけ**にすることで、「光っている＝触れる」が手がかりになります。
/// グラフは読むものであって触るものではないので、質感を持ちません。
///
/// 図形を型引数で受け取るのは、円・カプセル・角丸長方形で同じ塗り方を共有するためです。
struct ReportChartShape<S: Shape>: View {
    let shape: S
    let color: Color

    var body: some View {
        shape.fill(color)
    }
}

// **`GlassEffectContainer` はグラフでは使いません。**
//
// 取り込みの負荷を1回へ寄せられるため一度は導入しましたが、ガラスを1枚へまとめる際に
// 中の非ガラス要素（バブルのラベル）がガラスの下へ潜り、完全に見えなくなりました。
// 要素の外側に `.overlay` を足しても、要素の中へ入れても同じです。
// 数値が読めなくなる代償が大きすぎたためで、**マット化した今もガラスへ戻しません**。

// **`LiquidGlassCardBackground` は削除しました（2026-08-05）。**
//
// テーマ色のグラデーションでレポートカードを塗るための背景でしたが、
// カードを「面」の表現（`BlackCatPalette.surface`）へ変えたことで使い道が無くなりました。
// テーマ色は画面全体のうっすらとした光（`AppLiquidGlassBackground`）に残っています。
