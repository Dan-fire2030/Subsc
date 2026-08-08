# 黒猫マスコットとアプリアイコン

2026-08-08 の検討成果。**検討過程を追えるよう不採用案も残している**ため、
どれが正なのかをここに明記する。

## 採用したもの

| ファイル | 用途 |
|---|---|
| `cat-calm.svg` / `cat-worried.svg` / `cat-pleased.svg` / `cat-watching.svg` / `cat-nudging.svg` / `cat-guiding.svg` | 黒猫マスコット6状態。SwiftUI の `CatArt.swift` へ移植する元 |
| `app-icon-v2.svg` | アプリアイコン。円グラフ（3分割の金のドーナツ）＋中心の金のベタ円＋黒猫の顔 |
| `cat-*-ref.png` | 上記6状態の下絵。Codexが生成した1024pxのPNG |

- 色は黒 `#16151A` と金 `#C8901F` の2色。
- SwiftUI へ移す際、**色はハードコードせず `BlackCatPalette.cat` / `.catEye` を渡す**
  （ライト／ダークの追従を維持するため）。
- SVGには `width` / `height` 属性を書かない。`viewBox` だけにする（書くと縮小されない）。

## 不採用（検討過程の記録）

- 猫の別案：`cat-calm-v2.svg`、`cat-calm-v2-stylish.svg`、`cat-calm-v2-cute-v1.svg`、
  `cat-calm-v2-chubby.svg`、`cat-calm-current.svg`、`cat-calm-final.svg`
- アイコンの別案：`icon-a-coin.svg`、`icon-b-chart.svg`、`icon-b1.svg`、`icon-b2.svg`、
  `icon-b3.svg`、`icon-c-yen.svg`、`icon-d-cycle.svg`
  - 方向としては B（円グラフ）を選び、B1 を詰めて `app-icon-v2.svg` に至った。
  - **黒地に黒い顔を置く案は29ptで顔が沈んで猫だと分からない。**
    金の面に黒を抜く現行の構造が正しい。

## 一時ファイル

比較・検証のために作ったもの。参照する必要はない。

`*.html`（並べて見るためのページ）、`ref-*.png`、`head-crop.png`、`moods-sheet.png`

## 作り方

**座標を手で置く方法は4回試して4回とも破綻した**（目が「00」に見える／ヒゲが顔から飛び出す／
頭と胴がつながらない）。成立したのは次の流れ。

1. Codex に 1024px の PNG を生成させる（`cat-*-ref.png`）
2. 輪郭を抽出し、Douglas-Peucker で間引く
3. Catmull-Rom でベジェ化して SVG にする

実寸104ptで6状態が区別できること、アイコンが60ptでも29ptでも読めることは確認済み。
