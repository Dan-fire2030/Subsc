# TODO - パステルへの全面リデザイン

最終整理：2026-10-15
ブランチ：**`feat/pastel-redesign`**（ベースは `feat/app-icon-pastel-circles`）
SPEC：`.spec/SPEC.md`（2026-10-15 確定）
現在のビルド番号：`ios/Subsc/AppStore/RELEASE_RUNBOOK.md` を正とする

前サイクル（アーカイブ機能）の一覧は `.spec/archive/TODO-2026-10-15.md`。

**状態：harutoさんの承認待ち。承認を得るまで実作業に入らない。**

pbxprojへの登録は手作業（**次の空き番：ファイル 185、グループ 25**）。
追加前に `grep -oE "\b(AA|BB|DD)[0-9]{22}\b" project.pbxproj | sort -u` で使用済みを確かめる。

---

## フェーズ0：アイコン（済）

- [x] アイコンを K3 に差し替え（AppIcon と AppIconPreview の両方）
- [x] Icon Composer 用のレイヤーSVGを `ios/Subsc/AppStore/IconSource/` に置く

## フェーズ1：色の土台を差し替える（TDD）

画面にはまだ手を入れない。ここが終わった時点で「色だけ新しい」状態でビルドが通ること。

- [ ] 新パレット（地・カード・文字・費目の7色・増減の色）を `dynamic(light:dark:)` で定義する
- [ ] 型名を `BlackCatPalette` から改める（参照は約40ファイル。**機械的な置換だけの独立コミット**にする）
- [ ] 費目のプリセット（`ThemeColorPreset`）と種別の既定色（`CostType`）を新パレットへ
- [ ] テスト：旧パレットの7色が、それぞれ新パレットの意図した色へ寄ること（`HarmonizedColorTests` を書き換え）
- [ ] テスト：保存値（16進文字列）は書き換わらないこと
- [ ] テーマ色の既定を `#6A4FC9` へ（`ThemeStoreTests` を更新）
- [ ] 書体の段（`BlackCatType`）を案Aの大きさへ。相対指定は維持する

## フェーズ2：新しい猫（TDD）

- [ ] のぞく猫を SwiftUI の図形で描く部品にする（ライト／ダーク）
- [ ] `CatMood` の6つを表情（目・耳・小さな符号）で出し分ける
- [ ] 読み上げ名（`accessibilityName`）は今の文言を引き継ぐ
- [ ] 旧部品（`CatArt` / `CatArtworkData` / `CatPathParser` と `CatPathParserTests`）を削除する
- [ ] 空の画面（`DashboardEmptyState`）の「案内」も新しい猫へ

## フェーズ3：ホームとレポートを分ける

- [ ] ホーム：合計カード（内訳の帯つき・のぞく猫）＋次の支払いカード
- [ ] ホーム：費目の行をパステルの角丸カードへ（`SubscriptionRow` / `LoanRow`）
- [ ] ホーム：絞り込み・並び替え・検索・アーカイブ欄が今どおり動くこと
- [ ] レポート画面を新設し、合計カードから開く（月／年、種別の絞り込み、スワイプでの期間移動）
- [ ] グラフ4種（帯・リング・バブル・縦バー）を新パレットで洗い直す。今月の棒に猫
- [ ] `ReportBreakdownSheet` を新しい見た目へ
- [ ] 不要になったホーム側のレポート部品を整理する

## フェーズ4：残りの画面

- [ ] カレンダー：支払い日のマスを費目の色で、今日・選択日の印、日付の見出しに肉球
- [ ] 登録・編集フォーム：プレビューカード、種別ボタン、色見本
- [ ] 費目の詳細、金額の記録、通知タイミング
- [ ] 借入（一覧の行・詳細・返済予定・フォーム）
- [ ] 設定（テーマ色・グラフ表示の選択画面を含む）
- [ ] チュートリアル（`TutorialView`）

## フェーズ5：仕上げと確認

- [ ] ダーク版を全画面で確認（キャンバスの「案A ダークモード」に合わせる）
- [ ] 文字サイズ最大で崩れないこと（シミュレーター）
- [ ] iOS 17〜25 の表示（Liquid Glass なし）を確認（シミュレーター）
- [ ] UIテスト（`SubscUITests`）の識別子が崩れていないか確認し、Xcodeでの実行をharutoさんへ依頼
- [ ] ユニットテストを全件通す
- [ ] 実機での確認をharutoさんへ依頼

## フェーズ6：配布

- [ ] main へマージ（範囲を `git log --oneline main..feat/pastel-redesign` で確認してから）
- [ ] TestFlight へ配布（`/ios-testflight-release`）。RELEASE_RUNBOOK を更新
- [ ] App Store 用スクリーンショットの撮り直し（実画面をharutoさんが撮影 → Codexが加工）
