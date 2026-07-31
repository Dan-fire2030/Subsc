# Project guide line

## プロジェクトの原則
- 本プロジェクトのプラン作成、および回答は全て日本語で行う

## プロジェクトの目的
- **Subsc**（サブスクリプション管理アプリ）の開発。契約中のサブスクを一覧・管理し、月間／年間の支払いレポートと更新日前の通知でコストを把握できるようにする
- **iOSネイティブ版（`ios/Subsc`）が本流**。新機能・改善は原則こちらに実装する
- Web/PWA版（`app/`, `worker/`, `db/`, `drizzle/`）は初期実装であり、**将来的に廃止してiOSへ完全移行する方針**
  - 新機能をWeb版に追加しない。iOS移行の妨げになる箇所から段階的に削除・アーカイブしていく
  - Web版のコードに触れる必要が生じた場合は、修正するのか削除するのかをユーザーに確認してから着手する

## 作業対象の優先順位
- 指示に対象の明示がない場合、まず iOSネイティブ版（`ios/Subsc`）の作業と解釈する。Web版が対象と思われる場合は確認を取る
- iOS版の識別情報・リリース手順・完了状況は `ios/Subsc/AppStore/RELEASE_RUNBOOK.md` を参照する（秘密鍵・パスワード・APIキーは記録しない）

## Git運用ルール
- **修正内容ごとに適宜ブランチを切って作業し、完了したら main にマージする**。main で直接作業しない
  - 例外：ドキュメントの軽微な追記・修正など影響範囲が閉じている変更は、ユーザーの了解があれば main へ直接コミットしてよい
- ブランチ名は `<type>/<内容>` 形式にする（例：`docs/project-guidelines`、`fix/notification-schedule`）。`<type>` はコミットメッセージと同じ語彙を使う：`feat` / `fix` / `refactor` / `docs` / `test` / `chore` / `perf` / `ci`
- コミットメッセージは `<type>: <説明>` 形式で、説明は日本語で書く
- **main へマージする前に、マージ範囲がその作業の内容と一致しているかを必ず確認する**（`git log --oneline main..<branch>` と `git diff --stat main..<branch>`）。他ブランチの未マージ作業を意図せず巻き込む場合は、ユーザーに範囲を確認してからマージする
- マージは可能な限り fast-forward で行う
- push先のリモートは **`github`**（GitHub: Dan-fire2030/Subsc）を既定とする。`origin`（chatgpt-team.site のミラー）へは明示的な指示があった場合のみ push する

## iOSのビルドとテスト
- 作業ディレクトリは `ios/Subsc`。Xcodeプロジェクトは `Subsc.xcodeproj`、Schemeは `Subsc`
- 検証環境：Xcode 26.6 / iPhoneシミュレーター。既定の確認先は `iPhone 17 Pro`
- ビルド確認：
  ```bash
  cd ios/Subsc && xcodebuild build -project Subsc.xcodeproj -scheme Subsc \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
  ```
- ユニットテスト（`SubscTests`）：
  ```bash
  cd ios/Subsc && xcodebuild test -project Subsc.xcodeproj -scheme Subsc \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SubscTests
  ```
- **Swiftコードを変更したら、コミット前にビルドとユニットテストを通す**。通らない状態でコミットしない
- **UIテスト（`SubscUITests`）はこのMacのCLIからは実行できない**（テストランナーが起動しない既知の制約）。UIテストを追加・変更した場合は、CLIで通せないことを明示して報告し、Xcodeから実行するようユーザーに依頼する
- テストはXCTest（`import XCTest` / `@testable import Subsc`）を使う。新規テストも既存に合わせXCTestで書く
- 時刻・カレンダー依存のテストは `Calendar(identifier: .gregorian)` と固定日付を使い、実行日に依存させない
- iOS 26では画面全体がLiquid Glassで描画され、iOS 17〜25は従来表示にフォールバックする。UI変更時は両系統の見た目を意識する（実機確認はユーザーに依頼する）

## Swift / SwiftUI コーディング規約
既存コードの流儀に合わせる。逸脱する場合は理由を述べる。

- **表示文字列・エラーメッセージ・doc コメントは日本語**で書く。doc コメントは `///` を使い、「なぜそうしているか」を残す
- ファイル構成は機能単位：`App/`（起動・ルート・保存方式）、`Features/<機能名>/`、`Models/`、`Services/`
  - 1ファイル400行程度を目安にし、超えるならビューを分割する。現状 `Features/Dashboard/ReportCard.swift` が776行と最大で、分割候補
  - ファイル内限定のビューは `private struct` にする
- `@Model` クラスは `final class` にする
- **テスト可能性のため、外部依存は既定値付き引数で注入する**（例：`calendar: Calendar = .current`、`processInfo: ProcessInfo = .processInfo`）。グローバル状態を直接参照しない
- 定数は型に閉じた `enum` + `static let` でまとめる（例：`enum CloudSyncConfiguration { static let containerIdentifier = ... }`）。マジックナンバー・裸の文字列リテラルを散らさない
- 列挙型は `String` の rawValue を持たせ、表示名は `var title: String` として型側に置く。ビュー側で文字列を組み立てない
- エラーは握り潰さない。復旧可能なら代替手段へフォールバックし、利用者に何が起きたか日本語で伝える（`SubscApp.init` のインメモリ復旧と `StartupFailureView` が手本）

### SwiftData + CloudKit の制約（必ず守る）
CloudKitのプライベートDBへミラーリングするため、`@Model` の設計に制約がある。破ると同期が壊れる。

- **すべての保存プロパティに既定値を持たせるか Optional にする**。CloudKitミラーリングは非Optionalかつ既定値なしのプロパティを許さない
- **`@Attribute(.unique)` などの一意制約を使わない**
- **配列や辞書を直に保存しない**。`leadDaysCSV` / `leadHoursCSV` のようにCSV文字列で保存し、`[Int]` は computed property で出し入れする
- enumは直接保存せず `~Raw: String` として保存し、computed property（getter/setter）で型付きの値を扱う
- **Productionへ反映済みの Record Type / Field は削除前提で設計しない**。項目を追加したら、Development署名のアプリで代表データを保存し、CloudKit Consoleで差分を確認してからProductionへ反映する
- テスト実行時はCloudKitへミラーリングしない（`App/StorageMode.swift`）。署名なしのテストホストでCloudKitコンテナを要求するとCore Dataが起動途中で停止し、かつ実行者本人のiCloudへ書き込んでしまうため。**保存方式の判定ロジックを変更する際は、テストが署名を要求し始めないか必ず確認する**

## TestFlight / リリース運用
- **`ios/Subsc/AppStore/RELEASE_RUNBOOK.md` が識別情報・ビルド番号・完了状況の唯一の情報源**。これらをAGENTS.mdやMEMORY.mdに複製しない
- **パスワード、APIキー、証明書の秘密鍵をリポジトリに記録しない**。アップロードはXcodeへログイン済みのApple Accountと `-allowProvisioningUpdates` を使い、アプリ専用パスワードをファイルへ保存しない
- 同じバージョンを再アップロードする場合は、先に `CURRENT_PROJECT_VERSION`（ビルド番号）を増やして新しいArchiveを作る
- **アップロード後は RELEASE_RUNBOOK を更新する**：新しいビルド番号、そのビルドに含めた変更、Apple側の受領結果、「最終更新」日付。更新は独立したコミット（`chore: record TestFlight build N upload`）にする
- リリース前チェックリストの項目を勝手に `[x]` にしない。実機確認が必要な項目はユーザーが確認した報告を受けてから更新する
- App Store Connectの入力、公開URLの用意、実機確認はユーザーの作業。エージェントは代行せず、必要な作業を具体的に提示する
- 審査向けの前提（独自ログインなし、データは端末と本人のiCloud Private DBのみ、為替APIへサブスク名や料金を送信しない、アプリ内課金なし）を壊す変更は、実装前にユーザーへ影響を説明する

## 触ってはいけないもの
- **`.openai/` 配下**（`hosting.json` のバインディング宣言など）はホスティング基盤の設定。指示なく変更しない
- **生成物・キャッシュは編集もコミットもしない**：`node_modules/`、`dist/`、`build/`、`.vinext/`、`.wrangler/`、`outputs/`、`work/`、`tsconfig.tsbuildinfo`、`ios/Subsc/Subsc.xcodeproj/xcuserdata/`
- **Web/PWA版（`app/`, `worker/`, `db/`, `drizzle/`）に新機能を追加しない**。触る必要が出たら修正か削除かを確認してから着手する
- `drizzle/` の既存マイグレーションファイルを書き換えない（適用済みのため）。スキーマ変更が必要なら `npm run db:generate` で新規生成する
- ルートの `README.md` はSubscの説明として整備済み。vinext-starterのテンプレート文へ戻さない

## Local Skills
- セッション開始時にプロジェクトのローカルスキルを `.agent/skills/` 配下で確認する

## Codexへの委譲ルール

### モデルと呼び出し
- 使用モデルは **`gpt-5.6-sol`**。`~/.codex/config.toml` で既定に設定済みのため、**`--model` / `-m` は付けない**（`model_reasoning_effort = "medium"`、`service_tier = "priority"` も設定済み）
- 別モデルを使いたい場合のみ明示的に指定する。ユーザーが「spark」と言った場合は `gpt-5.3-codex-spark` を指す
- **呼び出しは `codex:codex-rescue` サブエージェント（`/codex:rescue`）経由に一本化する。Bash から `codex exec` を直接叩かない。例外はなく、画像生成も同じ経路を通す**
  - 背景実行・`--write`・前回セッションの継続（`--resume`）に対応しており、メインスレッドのコンテキストを消費せずに走らせられる
  - 継続の依頼は新しくエージェントを起こさず `SendMessage` で同じエージェントへ送る。新規に `Agent` を呼ぶとコールドスタートに戻る
- `codex` コマンドが見つからない場合は PATH（`~/.npm-global/bin`）を確認する。それでも使えない場合は勝手に代替手段を取らず、ユーザーに報告して指示を仰ぐ
- 全プロジェクト共通の線引きは `~/.claude/rules/codex-delegation.md`（Claude Codeでは自動読み込み）。本セクションはこのリポジトリ固有の補足

### Codexに任せる作業
1. **ビットマップ画像の生成** — エージェント側で生成できないため必ず委譲する。詳細は下の「画像生成ルール」に従う
2. **詰まった時のセカンドオピニオン** — 同じバグの診断や実装に2〜3回失敗したら、抱え込まずCodexへ渡す。同じモデルで再試行するより別モデルの視点が有効
3. **自分の変更に対する独立レビュー** — `/codex:review`（実装上の欠陥）、`/codex:adversarial-review`（実装方針・設計判断・トレードオフ自体を疑う）。設計判断を含む変更ほどadversarialが向く
4. **長時間・範囲を絞れない調査** — 事前に見る場所を特定できない原因調査など。背景実行すればメインスレッドのコンテキストを消費しない
5. **多数ファイルにまたがる機械的な一括変換**

### Codexに任せない作業
- 短い実装・小さい修正。往復コストの方が高い（`codex-rescue` も設計上、単純な依頼を受け取らない）
- **会話の文脈が必要な作業**。Codexは毎回コールドスタートで、この会話での決定事項やブランチ経緯を知らない。説明コストが作業量を超えるなら自分でやる
- iOSのビルド・テスト検証（`xcodebuild` の手順とシミュレーター操作手段はメインスレッド側にある）
- リリース判断とRELEASE_RUNBOOKの状態更新

### 委譲時の注意
- **Codexに書き込みを許して走らせている間、同じファイルを自分で編集しない**。`--sandbox workspace-write` や `--write` ではCodex側もファイルを書くため衝突する。委譲中は手を止めるか、別ファイルに専念する
- レビューや調査のみを依頼する場合は、書き込みを許可しない（読み取り専用で走らせる）

## 画像生成ルール（必須）
- **画像ファイル（PNG / JPEG / WebP 等のビットマップ画像：イラスト・アイコン・バナー・写真風画像など）の生成は、必ず Codex に委譲する**。Claude や Gemini 等のエージェントが自前ツールで画像ファイルを生成してはならない
- **呼び出しは上の「Codexへの委譲ルール」と同じく `codex:codex-rescue` サブエージェント（`/codex:rescue`）経由**。Bash から `codex exec` を直接叩かない
- 依頼文には「画像の内容・用途」「保存先の絶対パス」「ファイル名」「サイズ・形式」を必ず含めること
- **ユーザーの依頼にこれらの情報（保存先パス・ファイル名・サイズ・形式）が含まれていない場合は、Codexに委譲する前に AskUserQuestion ツールで不足分をユーザーに確認する**（Claude Code以外の同等ツールでは各ツールの質問手段を使う）。妥当なデフォルト案（例：`.output/images/` 配下・内容が分かるファイル名・PNG）を選択肢の先頭に提示してよいが、確認せずに勝手に決めて実行しない
- 生成後はファイルの存在（`ls` 等）を確認してからユーザーに報告する
- 対象外：SVG・Mermaid・HTML/CSS などコードとして記述する図解は各エージェントが直接作成してよい
- Codexが使えない場合（上の「Codexへの委譲ルール」のPATH確認を経てもなお使えない場合）は、**勝手に代替手段で画像を生成せず**ユーザーに報告して指示を仰ぐ

# Memory & Handoff Instructions

## 3ファイルの役割と哲学
- 本ファイル（AGENTS.md）は「厳格なルール」、人が作成
- MEMORY.mdは「積み上がる経験」、AIが作成・AIが利用
- HANDOFF.mdは「セッション間の引き継ぎ」、AIが作成・AIが利用、ただし人間がレビューし必要な情報をキュレーションする

## セッション開始時（必須）
セッション開始時、ユーザーへの最初の応答の前に、以下の2ファイルを読み込み、読み込んだことを報告すること：
- `.agent/memory/MEMORY.md`  （学習した知識・教訓）
- `.agent/handoff/HANDOFF.md` （前回の作業引き継ぎ）

## メモリ管理
- 新しい知識・教訓を記録する際は `.agent/memory/MEMORY.md` を更新
- 既存のMEMORY.mdを更新する前に、現在のファイルを`.agent/memory/archive/YYYY-MM-DD.md` にアーカイブしてから新規作成
- ローカルの自動メモリ機能（~/.claude/ 配下）は使用しない
- MEMORY.mdは200行以内を維持すること
- 本ファイルと重複する内容はMEMORY.mdに書かない

## ハンドオフ管理
- ハンドオフは `/handoff` コマンドで作成（Claude Codeの場合）
- 保存先は `.agent/handoff/HANDOFF.md`（固定名）
- 作成時は既存ファイルを `.agent/handoff/archive/YYYY-MM-DD-HHMM.md` にリネームしてからHANDOFF.mdを新規作成する
- 時刻はローカル時刻・24時間表記

## 仕様駆動開発（SDD）ルール
- コーディングや業務作業を開始する前に、必ず `.spec/` 配下の4ファイルを確認・更新すること
- 作業の順序：PLAN（目的確認）→ SPEC（要件確認）→ TODO（タスク確認）→ 実作業
- **PLAN.mdは人間の口頭メモ・自由記述**であり、箇条書き・口語・断片的な内容で構わない
- PLAN.mdを読んだら、そのまま実装に入らず、不明点をヒアリングしながらSPEC.mdを作成・確定させること
- SPEC.mdが確定してからTODO.mdのタスク分解を行い、ユーザーの承認を得てから実作業を開始する
- 作業完了後は TODO.md の該当タスクにチェックを入れ、KNOWLEDGE.md に学びを記録する
- 仕様が不明確な場合は作業を開始せず、ユーザーに確認してから SPEC.md を更新する
- 新しい開発サイクルを始める際は `/newplan` コマンドを使用する

## フォルダ用途
- `.spec/`：設計ドキュメント（PLAN / SPEC / TODO / KNOWLEDGE）。アーカイブは `.spec/archive/` 配下に格納する
- `.output/`：成果物・アウトプット（記事MD、コード、資料など完成したもの）
- `.references/`：参考資料・素材（PDFや画像、URLメモ、サンプルコードなど作業の入力素材）
