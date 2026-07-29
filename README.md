# Subsc

サブスクリプション管理アプリです。契約中のサブスクを一覧・管理し、月間／年間の支払いレポートと更新日前の通知でコストを把握できます。

このリポジトリには2つの実装が同居しています。

| 実装 | 場所 | 位置づけ |
|---|---|---|
| iOSネイティブ版 | `ios/Subsc/` | **本流。新機能・改善はこちらに実装する** |
| Web/PWA版 | `app/`, `worker/`, `db/`, `drizzle/` | 初期実装。**将来的に廃止しiOSへ完全移行する** |

開発方針・エージェント向けの共通ルールは [AGENTS.md](AGENTS.md) を参照してください。

## iOSネイティブ版（本流）

SwiftUI製のネイティブアプリです。データはSwiftDataへオフライン保存され、同じApple IDの端末間ではCloudKitのプライベートデータベースを通じて同期されます。独自アカウントや外部DBは使用しません。

### 開き方

`ios/Subsc/Subsc.xcodeproj` をXcodeで開き、iOS 17以降のiPhoneシミュレーターまたは実機を選んで実行します。

### 構成

- `Subsc/App/` — アプリ起動、ルートビュー、データ保存方式の判定
- `Subsc/Features/` — `Dashboard`（レポート）、`Subscriptions`（追加・編集）、`Settings`
- `Subsc/Models/` — SwiftDataモデル
- `Subsc/Services/` — 為替レート取得、ローカル通知
- `SubscTests/` — ユニットテスト / `SubscUITests/` — UIテスト

テスト実行時はCloudKitへミラーリングせずインメモリ保存に切り替わります（`Subsc/App/StorageMode.swift`）。署名なしのテストホストでCloudKitコンテナを要求するとCore Dataが起動途中で停止するため、および実行者本人のiCloudへ書き込まないためです。

### 対応範囲

- サブスク一覧・検索・絞り込み（利用中／停止中／終了履歴）
- 追加・編集・スワイプ削除
- 月間・年間レポート
- 米ドル入力と日次のドル円参考レートによる円換算
- 契約周期に応じた更新日の自動繰り越し
- 更新日前の日数・時間指定のローカル通知と予約の自動再同期
- Privacy Manifestとアプリ内プライバシー説明

### リリース

識別情報、ビルド番号、完了状況、確認項目、トラブル対処は
[`ios/Subsc/AppStore/RELEASE_RUNBOOK.md`](ios/Subsc/AppStore/RELEASE_RUNBOOK.md) が唯一の情報源です。
パスワード・APIキー・証明書の秘密鍵は記録しません。

## Web/PWA版（廃止予定）

[vinext](https://github.com/cloudflare/vinext)（Cloudflare Workers上のNext.js）+ Cloudflare D1 + Drizzle ORM で動作します。`wrangler.jsonc` は使用しません。

**新機能はこちらに追加しません。** コードに触れる必要が生じた場合は、修正するのか削除するのかを確認してから着手してください。

### 前提

- Node.js `>=22.13.0`

### コマンド

```bash
npm install
```

- `npm run dev` — ローカル開発サーバーを起動
- `npm run build` — vinextのビルド出力を検証
- `npm test` — ビルドしてレンダリング結果を検証（`tests/rendered-html.test.mjs`）
- `npm run lint` — ESLint
- `npm run db:generate` — スキーマ変更後にDrizzleマイグレーションを生成

### 構成

- `app/` — Next.js App Router のページ・API・クライアントコンポーネント
- `worker/` — Cloudflare Worker エントリ
- `db/` — Drizzleスキーマとクエリ
- `drizzle/` — マイグレーション
- `.openai/hosting.json` — Sites の D1 / R2 バインディング宣言
- `vite.config.ts` — 宣言されたバインディングをローカル開発でシミュレート
- `examples/d1/` — D1のサンプル

### ホスティング環境の識別情報

OpenAI workspace sites 上では、リクエストヘッダーからサインイン中のユーザーを読み取れます。

- `oai-authenticated-user-email` — メールアドレス
- `oai-authenticated-user-full-name` — 氏名（任意）。`oai-authenticated-user-full-name-encoding: percent-encoded-utf-8` を伴うpercent-encoded UTF-8。存在しない場合はメールアドレスにフォールバックする

ChatGPTサインインのヘルパーは `app/chatgpt-auth.ts` にあります（`getChatGPTUser` / `requireChatGPTUser` / `chatGPTSignInPath` / `chatGPTSignOutPath`）。`returnTo` は同一オリジンの相対パスを渡します。保護されたページは per-request のIDヘッダーに依存するため `export const dynamic = "force-dynamic"` を指定します。

`/signin-with-chatgpt`、`/signout-with-chatgpt`、`/callback`、OAuthクッキー、IDヘッダーの注入はホスティング基盤側が管理するため、アプリ側でこれらのパスを実装しません。サインインはIDを確認するだけでworkspaceメンバーシップを保証しないため、範囲を制限する場合はホスティング側のアクセスポリシー、またはサーバー側の明示的なチェックを使います。

## 参考

- [vinext Documentation](https://github.com/cloudflare/vinext)
- [Drizzle D1 Guide](https://orm.drizzle.team/docs/get-started/d1-new)
