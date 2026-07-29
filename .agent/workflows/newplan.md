以下の手順で新しい開発サイクルを開始してください：

1. `.spec/` 配下の4ファイルが存在する場合、本日の日付（ローカル時刻）で `.spec/archive/` 配下にアーカイブする（フォルダがなければ作成する）：
   - `PLAN.md`      → `.spec/archive/PLAN-YYYY-MM-DD.md`      に移動
   - `SPEC.md`      → `.spec/archive/SPEC-YYYY-MM-DD.md`      に移動
   - `TODO.md`      → `.spec/archive/TODO-YYYY-MM-DD.md`      に移動
   - `KNOWLEDGE.md` → `.spec/archive/KNOWLEDGE-YYYY-MM-DD.md` に移動

2. 新しいファイルを以下の通り作成する：
   - `PLAN.md`：空テンプレートで新規作成
   - `SPEC.md`：空テンプレートで新規作成
   - `TODO.md`：空テンプレートで新規作成
   - `KNOWLEDGE.md`：アーカイブした内容をそのままコピーして新規作成（知見を引き継ぐ）

3. 完了後、以下を報告する：
   - アーカイブしたファイル一覧
   - 「新しいPLAN.mdにやりたいことを自由に書いてください」
