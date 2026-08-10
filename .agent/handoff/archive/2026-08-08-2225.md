# HANDOFF - 2026-08-08 22:25

> **ビルド12のArchiveは完成し、アップロードだけが残っている。**
> 失敗の原因は **Appleの定期メンテナンス**（日本時間 8/8 21:30〜翌00:00）で、こちら側に不具合はない。
> **明けてから再送するだけで終わる。Archiveの作り直しは不要。**
>
> ブランチ `feat/onboarding-tutorial`、**`github` へ push 済み・未pushゼロ**。
>
> **今日の最大の失敗：Appleのエラー文言を信じて原因を2回誤診した。**
> 「年末年始のため受付停止」「No Accounts with App Store Connect Access」はどちらも的外れだった。

## 使用ツール

Claude Code（Opus 5）。
Codex CLI（`codex:codex-rescue` サブエージェント経由）を**アイコンのPNG化に1回だけ使用**。
Gemini CLI は未使用。

シミュレーターは **iPhone 17 Pro `45C04581-A59B-45D3-B443-0B7C3987FD9F`**。

---

## 現在のタスクと進捗

### 完了：黒猫マスコットのSwiftUI移植

- [x] **検討成果40ファイルの保全**（`655ffab`）
      `.output/design-system/brand/`。**採用・不採用の別は同ディレクトリの `README.md` に書いた**
- [x] **猫6状態の移植**（`1d1cf10`）
      SVGのパスデータを文字列のまま持ち、`CatPathParser`（絶対座標の `M`/`C`/`Z` のみ）で読む。
      `addCurve` を書き写す案は1状態200〜320本あり非現実的だった。
      `static let` で1度だけ読むので描画のたびの解釈も起きない。
      色はハードコードせず `BlackCatPalette.cat` / `.catEye` を渡している
- [x] **パーサーのテスト11件**。実機画面でソースSVGと一致することをライト・ダーク両方で確認済み
- [x] **`currentPoint` の2乗オーダーを解消**（`64dabfd`）

### 完了：起動後にCPUが100%へ張り付く不具合の修正（★猫とは無関係の既存バグ）

- [x] **原因特定と修正**（`3193508`）、**データの形を増やしたテスト**（`76f9e25`）
- 仕組み：`RootView` の `.task(id: notificationSyncID)` が鍵に `Loan.updatedAt` を含む一方、
  そのタスクから呼ばれる `LoanPaymentStore.synchronize` が**差分の有無に関わらず**
  `loan.updatedAt = .now` を書いていた。**タスクが自分の再発火条件を書き換える自己再帰**
- 発火条件：**停止中の借入が1件でもあること**（`deferPastDue` → `synchronize` を通るため）
- 実測：起動直後に `reconcileSubscriptions` が**501回**。SwiftDataへの書き込みが止まらず、
  **CloudKitへの同期も延々と発生していた**
- 直し方：`synchronize` を「**値が違うときだけ書く**」形に。行の各項目・`isClosed`・
  関係の組み直し・`updatedAt` の全てに適用
- 検証：**修正後は冷えた起動を計18試行して一度も再現せず**（修正前は5回中2〜3回）

### 完了：アプリアイコンの差し替え

- [x] **`app-icon-v2.svg` → 1024×1024 PNG**（生成はCodexへ委譲）。
      `sips` と `file` でサイズ・アルファなし・sRGBを**自分で実測確認**
- [x] **`AppIcon.appiconset` と `AppIconPreview.imageset` の両方**を差し替え（`62bc84c`）。
      **md5が生成元と3つとも一致**することを確認。ビルド11の「設定画面だけ旧アイコン」は解消
- [x] シミュレーターのホーム画面と設定画面の両方で新アイコンを確認

### 完了：ドキュメント

- [x] `.spec/TODO.md` / `.spec/KNOWLEDGE.md` / `.agent/memory/MEMORY.md`（`f52a61e`）
- [x] `AppStore/RELEASE_RUNBOOK.md`（`f9334dc` → `97fabd4` → `ad6d589`）

### 未完了：TestFlight ビルド12のアップロード ← **次にやる唯一のこと**

- [x] ビルド番号 11 → 12（`c27733d`）
- [x] ユニットテスト全通過
- [x] **CloudKitスキーマの反映は不要**（ビルド11以降 `@Model` の保存プロパティに増減なしを確認）
- [x] **Archive成功**。`CFBundleShortVersionString = 1.0.0` / `CFBundleVersion = 12` /
      `com.tonaria.subsc`、`Assets.car` に `AppIcon` と `AppIconPreview` が両方1024×1024、
      事前レンダリングの120pxアイコンが新意匠であることまで**中身を開いて確認済み**
- [ ] **アップロード（Appleのメンテナンスで失敗）**

### 未完了（繰り越し）

- [ ] **実機での確認**（harutoさんの作業）
- [ ] **main へのマージ**（harutoさんの判断で実機確認の後）
- [ ] **「つきねこ」の商標確認**（J-PlatPat）
- [ ] `PrivacyPolicy-ja.md` のアプリ名差し替え（公開済みURLの文書）
- [ ] Codexによる adversarial review
- [ ] App Store Connect の掲載情報入力、スクリーンショット撮影

---

## 試したこと・結果

### 成功したアプローチ

- **★間欠的な不具合は、試行を繰り返して割合で見る。** 3条件×5試行のスクリプトを回して初めて
  「どの条件でも同じ割合で出る＝自分の変更と無関係」が分かった。1回ずつの比較では誤診する
- **★CPUの判定は累積CPU時間の差分で行う。** `ps -o %cpu` は減衰平均で当てにならない
  ```bash
  A=$(ps -p $PID -o time=); sleep 10; B=$(ps -p $PID -o time=)   # 差分を秒へ直して率を出す
  ```
  **起動直後は正常でも40〜50%出る。** 10秒で0へ落ちれば正常、平坦に100%が続けばループ
- **★犯人捜しは `Self._printChanges()` が決定打。** 何が変わって再評価されているかが直接出る。
  `xcrun simctl launch --console` で拾う。`sample` はどこで時間を使ったかしか分からず遠回りだった
  ```
  RootView: \Loan.updatedAt changed.        ← これが延々と繰り返される
  DashboardView: \Loan.updatedAt, @self changed.
  ReportPager: @self changed.
  ```
  さらに疑う値を `print` して**異なり数を数える**と確定できた（505回中503通り＝毎回変わっている）
- **条件を揃えて比べる。** 最初「変更後は冷えた状態、変更前は温まった状態」で比べて誤診した。
  シミュレーターは起動直後で挙動が変わる
- **SwiftDataの中身はSQLiteで直接見られる。** 発火条件（停止中の借入の有無）の確認に使った
  ```bash
  DB=$(find ~/Library/Developer/CoreSimulator/Devices/<udid>/data/Containers/Data/Application -name default.store | head -1)
  sqlite3 -header "$DB" "select ZCLIENTID, ZISPAUSED, ZISCLOSED from ZLOAN;"
  ```
- **Archiveの中身のアイコンを開いて確認した。** `Assets.car` を `assetutil --info` で見て、
  事前レンダリングされた `AppIcon60x60@2x.png` を実際に目視した。
  ビルド11の混入事故と同じことを繰り返さないため
- **Codexの報告は自分で検証した。** PNGのサイズ・アルファ・色空間を `sips` と `file` で実測

### 失敗したアプローチ・つまずき

- **★【最重要】Appleのエラー文言から原因を読もうとして2回誤診した。**
  アップロードが `No Accounts with App Store Connect Access` で落ち、
  併記された「年末年始のため受付停止。12月29日以降に再試行を」（**8月なのに**）を見て、
  ① 年会費の失効 → ② 別のApple IDでログイン、と順に外した。
  **正解はAppleの定期メンテナンス。** メンバーシップもアカウントも正常だった。
  **メンテナンス中は、無関係な認証エラーの形で落ちる。**
  → **アップロードが理由不明で落ちたら、アカウントを疑う前にステータスフィードを見る**
- **★Appleのステータスページ（HTML）はJavaScript描画で読めない。** `.json` は404。
  **正しいのは `.js`**（302で `www.apple.com` 側へ転送される）
  ```bash
  curl -sL https://developer.apple.com/system-status/data/system_status_en_US.js | head -c 2000
  ```
- **★「変更前は0%だった」を2回の観測で結論づけた。** 実際は変更前も同じ割合で出ていた。
  ユーザーへ「あなたの変更が原因で確定」と誤って報告し、後で撤回している
- **`file://` はBrowserパネルで開けない**（about:blankになる）。
  スクラッチ配下を `python3 -m http.server` で配ってから `http://127.0.0.1:<port>/` で開いた
- **`mcp__Claude_Code_iOS_Simulator__control` の `attach` が「already attached」を返しても、
  実際にパネルが出ていないことがある。** `detach`→`attach` し、
  `~/Library/Logs/Claude/main.log` に `ios h264 stream` が出ているかで判定する
- **`sips` はSVGを扱えない。** ビットマップ生成はCodexへ委譲するルールなので、そもそも自前でやらない

---

## 次のセッションで最初にやること

1. **状態の確認**
   ```bash
   git branch --show-current                    # → feat/onboarding-tutorial
   git log --oneline github/feat/onboarding-tutorial..HEAD | wc -l   # → 0（push済み）
   grep -n CURRENT_PROJECT_VERSION ios/Subsc/Subsc.xcodeproj/project.pbxproj  # → 12
   ls ~/Library/Developer/Xcode/Archives/2026-08-08/                # → Archiveがある
   ```
2. **Appleのメンテナンスが明けているか確認する**
   ```bash
   curl -sL https://developer.apple.com/system-status/data/system_status_en_US.js | head -c 2000
   ```
3. **アップロードを再送する。Archiveの作り直しは不要**
   ```bash
   cd ios/Subsc && xcodebuild -exportArchive \
     -archivePath ~/Library/Developer/Xcode/Archives/2026-08-08/"Subsc 2026-08-08 22.10.xcarchive" \
     -exportOptionsPlist AppStore/UploadOptions.plist \
     -exportPath /tmp/subsc-export12 -allowProvisioningUpdates
   ```
   **`** EXPORT SUCCEEDED **` と `Upload succeeded.` の両方**を確認する
4. **RELEASE_RUNBOOK を更新する。** ビルド12の節は「Archiveまで完了、アップロードは未完了」と
   書いてあるので、**受領できたら書き換える**。「既知のリリース時トラブル」の
   メンテナンスの項は記録として残す
5. push（`github`）→ harutoさんへ実機確認を依頼

---

## 注意点・ブロッカー

### 未コミット・未マージのまま残しているもの

- **作業ツリーはクリーン**（このHANDOFFのコミットを除く）。**未pushもゼロ**
- **`feat/onboarding-tutorial` は main へ未マージ。** harutoさんの判断で実機確認の後

### 人間にしかできない作業

- **実機でのTestFlight確認。** 優先順位つきで下記「未検証の項目」を参照
- **Apple ID / iCloud のパスワードと2要素認証コードの入力**（今回は不要と判明したが、
  Xcodeのアカウントが切れた場合は必要）
- **「つきねこ」の商標確認**（J-PlatPat または弁理士）
- **App Store用スクリーンショットの撮影**（撮影はharutoさん、加工はCodex）
- **「審査へ提出」ボタン**

### ビルド12で未検証の項目（実機で確認したい順）

1. **停止中の借入がある状態での起動時のCPUと発熱。** 今回直した不具合そのもの。
   シミュレーターでは18試行して再現しないが、**実機は未確認**
2. **アイコンの実寸表示**（29pt、明るい／暗い壁紙での馴染み）
3. **iOS 17〜25のフォールバック表示**（ずっと未検証）
4. **チュートリアルの最大文字サイズでの見え方**（一度失敗している箇所）
5. **停止からの再開（`resume`）の画面動作**

### 壊してはいけない前提

- **保存データの形を変えない。** `@Model` の保存プロパティ、CloudKitのRecord Type名・フィールド名
  （**今日の変更でも一切変えていない。CloudKit反映は不要**）
- **Bundle ID `com.tonaria.subsc`** / **Team ID `2ZR6Z7NP8H`** / **App ID `6795086857`**
- **`synchronize` で無条件に `updatedAt` を書かない**（今日直した無限ループの原因）
- **`ReportPager` の重複した `makePage` 呼び出しを1回にまとめない**（CPU100%になる）
- **`ScrollView(.horizontal)` + `LazyHStack` + `containerRelativeFrame` +
  `.scrollTargetBehavior(.paging)` の組み合わせを使わない**
- **アイコンを差し替えるときは `AppIcon` と `AppIconPreview` の両方を更新する**
- **`CatArtworkData.swift` を手で編集しない。** 元のSVGを直して機械的に写し直す
- **年払いを再び1/12へならさない。** グラフに光沢・落ち影・縁を戻さない。
  猫の口調で文言を書かない
- pbxprojへの新規ファイル登録は手作業。**次の空き番は 161。`+` を含むパスは引用符が要る**

### 検証用に残しているデータ・一時的な状態

- **シミュレーターの検証データ：費目9件＋借入2件（うち1件が停止中）、8月の合計 ¥16,356。**
  **停止中の1件が今回の無限ループの再現条件なので、消さないこと**
- **シミュレーターの外観はダークへ戻してある**
- **Archiveは `~/Library/Developer/Xcode/Archives/2026-08-08/` にある**（スクラッチではないので消えない）
- **再現プローブとDerivedDataはスクラッチ配下。セッションが変わると消える。**
  プローブは「shutdown → boot → install → launch → 8秒待つ → 10秒間の累積CPU差分」を
  繰り返すだけなので、必要なら作り直す
