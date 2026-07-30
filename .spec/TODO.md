# TODO - タスクリスト

## 優先度：高
（現在なし）

## 優先度：中
- [ ] `Features/Dashboard/DashboardView.swift`（670行）の分割。AGENTS.mdの400行目安を超えている
- [ ] レポートの棒グラフと「サービス別料金」シートを、金額 > 0 のデータで目視確認する
      （`ReportCard.swift` 分割時に、シミュレーターMCPで金額欄へ入力できず未確認のまま）

## 優先度：低
- [ ] ルート `README.md` の Web版セクションは、Web版の廃止が進んだら削除する

## 完了済み
- [x] `Features/Dashboard/ReportCard.swift`（776行）を6ファイルへ分割（2026-07-30）
  - [x] `ReportPager` / `ReportPage` / `GlassBarChart` / `ReportBreakdownSheet` / `ReportGlassStyle` を切り出し
  - [x] `project.pbxproj` へ新規5ファイルを登録
  - [x] ビルドとユニットテスト52件が成功、正規化差分ゼロで「移動のみ」を確認
  - [x] シミュレーターでカード表示・期間切替・スワイプ・「今月」復帰を目視確認
- [x] 初期セットアップ
- [x] AGENTS.md の整備（目的・Git運用・iOSビルドとテスト・コーディング規約・リリース運用・Codex委譲）
- [x] README.md を Subsc の内容へ書き換え
- [x] 未マージだった TestFlight ビルド2〜4 の作業を main へ取り込み
- [x] 収益化方針の決定（広告は採用せず、1.0.0は無料でリリース）
- [x] カテゴリ・カラーのカスタム追加と一覧表示の改善（2026-07-30）
  - [x] `ColorHex` と `CategoryCatalog` を新規追加、ユニットテスト28件（合計52件合格）
  - [x] `project.pbxproj` へ新規4ファイルを登録
  - [x] フォームにカスタムカテゴリ入力と `ColorPicker` を追加、`colorName` の不具合を修正
  - [x] 一覧行にメモ（1行省略）とカテゴリバッジを追加
  - [x] シミュレーターで通常サイズと最大文字サイズを目視確認
  - [x] SPECの受け入れ条件を照合、KNOWLEDGE.mdに知見を記録
