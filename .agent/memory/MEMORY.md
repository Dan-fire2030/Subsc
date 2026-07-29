# MEMORY

## プロジェクト概要

Subsc（サブスク管理アプリ）。1リポジトリに2実装が同居している。

### iOSネイティブ版 — 本流
- 場所：`ios/Subsc/`（`Subsc.xcodeproj` / Scheme `Subsc`）
- 構成：SwiftUI + SwiftData、CloudKitプライベートDBで同一Apple ID端末間を同期。独自アカウント・外部DBなし
- 対応：iPhone専用 / iOS 17以降 / プライマリ言語は日本語
- ソース構成：`Subsc/App`（起動・ルート・保存方式）、`Subsc/Features/{Dashboard,Settings,Subscriptions}`、`Subsc/Models`、`Subsc/Services`（為替・通知）
- テスト：`SubscTests`（ユニット）/ `SubscUITests`（UI）
- 主な機能：一覧・検索・絞り込み、追加/編集/スワイプ削除、月間・年間レポート、USD入力の円換算、契約周期に応じた更新日の自動繰り越し、更新日前のローカル通知
- 識別情報・リリース手順・完了状況の唯一の情報源は `ios/Subsc/AppStore/RELEASE_RUNBOOK.md`（Bundle ID・Team ID・App Store Connect ID・CloudKitコンテナ等）

### Web/PWA版 — 廃止予定
- 場所：`app/`（Next.js App Router）、`worker/`、`db/`（Drizzle schema）、`drizzle/`（マイグレーション0000〜0006）
- 構成：vinext（Cloudflare Workers上のNext.js）+ Cloudflare D1 + Drizzle ORM + Tailwind
- ルートの `README.md` は vinext-starter 由来の記述のままで、Subscの説明にはなっていない
- `package.json` の name は `site-creator-vinext-starter`（未改名）
- 主要スクリプト：`npm run dev` / `build` / `start` / `test`（buildしてから `tests/rendered-html.test.mjs`）/ `lint` / `db:generate`

## 学習した知識・教訓

### iOSテスト実行時はCloudKitへミラーリングしない
`ios/Subsc/Subsc/App/StorageMode.swift` の `StorageMode.resolve` が、起動引数 `-ui-testing` または `XCTest` 接頭辞の環境変数を検出して `.inMemory` を選ぶ。
- 理由1：テストホストは署名なしで起動されることがあり、iCloud entitlementなしでCloudKitコンテナを要求すると Core Data が起動途中で停止する
- 理由2：テストが実行者本人のiCloudプライベートDBへ書き込むのを防ぐ
- したがって、保存方式の判定ロジックを変更する際はテストが署名を要求し始めないか必ず確認する

### ブランチ運用
- TestFlight向け作業は `codex/testflight-build-N` 系のブランチで進めてきた
- remoteは2つ：`github`（GitHub: Dan-fire2030/Subsc）と `origin`（chatgpt-team.site のミラー）。pushする際はどちらへ送るかを明示して確認する
