# TODO - タスクリスト

## 優先度：高
（現在なし）

## 優先度：中
- [ ] レポートの棒グラフと「サービス別料金」シートを、金額 > 0 のデータで目視確認する
      （`ReportCard.swift` 分割時に、シミュレーターMCPで金額欄へ入力できず未確認のまま）
- [ ] 絞り込みピッカーの切り替えと `DashboardEmptyState` の目視確認
      （`DashboardView.swift` 分割時に未達。ピッカーは注入タップが届かず、空状態は登録0件が必要）

## 優先度：低
- [ ] ルート `README.md` の Web版セクションは、Web版の廃止が進んだら削除する

## 完了済み
- [x] 設定画面の「通知を許可」が実機で無反応だった問題を修正（2026-07-31）
  - [x] `NotificationPermission` を新設し、状態に応じてボタンを出し分け（ユニットテスト7件）
  - [x] 拒否済み・許可済みでは設定アプリへ誘導、設定から戻ったら状態を取り直す
  - [x] シミュレーターで「許可済み→iOSの設定を開く」と設定アプリ遷移・復帰を目視確認
- [x] `Features/Subscriptions/SubscriptionFormView.swift`（642行）を7ファイルへ分割（2026-07-31）
  - [x] フォームの各セクション・カテゴリ/カラー・下書き比較・保存・為替取得を extension へ分離
  - [x] `NotificationTimingView` と `ExchangeRateLoadStatus` を独立させ、最大230行に収めた
  - [x] `project.pbxproj` へ新規6ファイルを登録
  - [x] ビルドとユニットテストが成功、正規化差分で「元の行が1行も欠けていない」ことを確認
  - [x] シミュレーターで追加フォームと通知タイミング画面を目視確認
- [x] `Features/Dashboard/DashboardView.swift`（670行）を5ファイルへ分割（2026-07-30）
  - [x] `DashboardSearchFilter` / `DashboardEmptyState` / `SubscriptionRow` を切り出し
  - [x] `SubscriptionDetailView` を `Features/Subscriptions/` へ移動
  - [x] `project.pbxproj` へ新規4ファイルを登録
  - [x] ビルドとユニットテスト52件が成功、正規化差分ゼロで「移動のみ」を確認
  - [x] シミュレーターで一覧・行・詳細画面・戻る操作を目視確認
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
