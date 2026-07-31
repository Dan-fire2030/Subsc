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

### セッション開始時はシミュレーターパネルも必ず開く（2026-07-30）
セッション冒頭にサブエージェント可視化ダッシュボードを Browser パネルへ表示するが、**それとは別に
iOSシミュレーターパネルも開く**。Browser と シミュレーターのパネルは共存できるので競合しない。

**`attach` が「already attached」を返したら、実際にはパネルが開いていない。**
前セッションのアタッチ状態が残っていて「もう開いている」と誤判定されるため。この場合は
`detach` してから `attach` し直すと「Simulator panel opened」が返り、パネルが表示される。

なお、パネルの表示有無とタップ注入・スクリーンショットは独立している。パネルが出ていなくても
ヘッドレスの確認は動くので、「操作できているからパネルも出ている」とは判断できない。

### 使用上限ガードはデスクトップアプリでは発火しない（2026-07-31）
`~/.claude/codex-usage-guard.sh` は `~/.claude/rate-limits.json` から使用率を読むが、
**そのキャッシュを書くのはステータスライン（`statusline-command.sh`）だけ**。
そして**ステータスラインはターミナルCLIでしか呼ばれず、デスクトップアプリのセッションでは動かない**。
実測：7/30 23:50 に書かれたキャッシュが、7/31 のセッションを丸ごと通しても更新されず約20時間据え置き。
結果 `MAX_AGE=1800` を常に超え、ガードは毎回無音で `exit 0` する。スクリプト自体に不具合はない。

→ このため**閾値ガードに頼らず、常時有効な `~/.claude/rules/codex-delegation.md` を基準とする**。

**デスクトップアプリには使用率の供給源が存在しない（2026-08-01 追加調査）。**
`~/.claude/usage_data.jsonl` は9秒前まで更新されていて新しいが、中身は `{"ts": ...}` だけの
9000行超で使用率を持たない。`rate-limits.json` は同時点で25時間前のまま。
**「使用率N%で何かする」仕組みは、この環境では作れない。** 作っても無音で死ぬ。
セッションの長さを見たいなら、この環境で取れる信号は `PreCompact`（コンテキスト圧縮）だけ。

### Codexへの委譲は意識して実行する（2026-08-01）
haruto さんの指示。**目的はトークン管理**。ルールに委譲対象と書いてあるものは迷わず渡す。
実際、5セッション連続で未使用のまま、AGENTS.md が明示している「自分の変更に対する独立レビュー」を
飛ばしていた。CloudKitスキーマを含む変更でこれをやると、Production反映後に直せなくなる。

**レビューは実際に効いた。** 固定費機能の4コミットを読ませて10件の指摘、うち7件が妥当、
4件はこちらが作り込んだ実バグ（過去実績が最新レートで再換算される／同期重複で金額が不定／
年払い変動費の過大計上／金額を触っていない編集で実績が作られる）。

ただし**Codexの報告を鵜呑みにしない**。「対応した」と言っていた見込み表示が実際には
未実装で、`isEstimated` を参照する画面が1つも無かった。委譲後は必ず自分で grep して確認する。

### 全プロジェクト共通ルールは `~/.claude/rules/*.md` に置く（2026-07-31）
`~/.claude/CLAUDE.md` は存在せず、**`~/.claude/rules/` 配下の `.md` がディレクトリ単位で自動読み込みされる**
（`settings.json` に参照リストはない）。ここに1ファイル置けば全プロジェクトのセッション冒頭に入る。
フックもステータスラインも不要なので、環境差で壊れない。反映は次セッションから。

### Codexはサブエージェント経由で動かす（2026-07-31）
haruto さんの指示。Bash から `codex exec` を直接叩かず `codex:codex-rescue`（`/codex:rescue`）を使う。
継続は新規に `Agent` を起こさず `SendMessage` で同じエージェントへ送る（新規はコールドスタートに戻るため）。
例外は AGENTS.md が直接実行を明示している場合（本リポジトリの画像生成ルール）。

### シェルスクリプトのJSON出力をzshの `echo` で検証しない（2026-07-31）
**zsh の `echo` は引数中の `\n` を実際の改行に展開する。** JSON文字列内のエスケープが壊れ、
`jq` が "control characters must be escaped" で落ちる。スクリプトは正しいのにテストだけ失敗する。
検証には `printf '%s'` を使うか、一度ファイルへ落としてから読む。

### iOSテスト実行時はCloudKitへミラーリングしない
`ios/Subsc/Subsc/App/StorageMode.swift` の `StorageMode.resolve` が、起動引数 `-ui-testing` または `XCTest` 接頭辞の環境変数を検出して `.inMemory` を選ぶ。
- 理由1：テストホストは署名なしで起動されることがあり、iCloud entitlementなしでCloudKitコンテナを要求すると Core Data が起動途中で停止する
- 理由2：テストが実行者本人のiCloudプライベートDBへ書き込むのを防ぐ
- したがって、保存方式の判定ロジックを変更する際はテストが署名を要求し始めないか必ず確認する

### mainが長期間放置されていた（2026-07-29に解消）
TestFlightビルド2〜4の作業は `codex/testflight-build-2` で進められ、mainへマージされていなかった。
2026-07-29 に `docs/project-guidelines` 経由でまとめてmainへfast-forwardマージし、`f37ff58` で解消済み。
ブランチ運用ルール自体は AGENTS.md の「Git運用ルール」を参照。
