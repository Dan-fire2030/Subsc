# KNOWLEDGE - ドメイン知識・調査結果

## 業務・ドメイン知識

### Subscの性質と収益化の相性
- サブスク管理アプリは**起動頻度が低い**（ユーザーは月に数回しか開かない）
- この性質上、表示回数に比例する収益モデル（広告）は不利。一度の支払いで完結するモデル（買い切り）は起動頻度が弱点にならない
- 「サブスク管理アプリが自分のサブスクを要求する」構図はレビューで批判されやすく、継続課金は相性が悪い

## 調査・リサーチ結果

### Google AdMob（iOS）の導入要件 — 2026-07-30 調査
採用しない判断をしたが、再調査を避けるため記録する。

- 使うのは AdSense ではなく **AdMob（Google Mobile Ads SDK）**
- 要件：Xcode 16.0以上 / iOS Deployment Target 13.0以上（Subscは Xcode 26.6・iOS 17+ なので充足）
- 導入：SPM `https://github.com/googleads/swift-package-manager-google-mobile-ads.git`、または CocoaPods `Google-Mobile-Ads-SDK`
- `Info.plist` に `GADApplicationIdentifier`（AdMob App ID）と `SKAdNetworkItems`（Googleは `cstr6suwn9.skadnetwork`）が必要
- 初期化は `GADMobileAds.sharedInstance` の `start()`
- **UMP SDK（同意管理）が必要**。起動ごとに `requestConsentInfoUpdate` → `loadAndPresentIfRequired` → `canRequestAds` が true になってから広告要求
- EEA/UK/スイス対象なら **`start()` より前に同意を取る**必要がある（`start()` 時点で広告のプリロードが始まるため）
- 開発中は必ずテスト広告IDかテストデバイス登録を使う。本番広告ユニットで自己テストするとポリシー違反でアカウント停止リスク

導入した場合に連鎖して必要になる作業（採用しなかった主因）：
- App Store Connect の App Privacy 回答を全面見直し（識別子・使用状況データの収集、**トラッキング**の申告）
- `PrivacyInfo.xcprivacy` の更新
- ATT許諾ダイアログと `NSUserTrackingUsageDescription`（IDFAを使う場合）
- `AppStore/RELEASE_RUNBOOK.md` の「App Review向け要点」の書き換え

## 技術的な知見

### 課金を実装する場合の設計方針（未実装・将来用）
- **StoreKit 2** を使う。最低対応が iOS 17 なので全機能が使える。サーバー側のレシート検証は不要
- **購入状態を SwiftData / CloudKit に保存しない**。`Transaction.currentEntitlements` を正とする
  - App Storeアカウントに紐づくため端末間で自然に共有され、CloudKitミラーリングの制約（既定値必須・一意制約禁止・配列不可）を一切踏まない
- ただしSubscはオフライン優先なので、検証結果をローカルに保持し**オフラインでも有料機能が使える**設計にする
- **「購入を復元」ボタンは審査必須**（App Store Review Guideline 3.1.1）。設定画面に置く
- Xcode の StoreKit Configuration File を使えば、App Store Connect への登録を待たずにローカルで課金フローを検証できる

### Xcodeプロジェクトへのファイル追加手順（2026-07-30 確立）
`Subsc.xcodeproj` は `PBXFileSystemSynchronizedRootGroup` を使っていないため、新規 `.swift` は `project.pbxproj` を手で編集しないとビルド対象に入らない。IDは規則的で、`AA` + 連番がPBXBuildFile、`BB` + 連番がPBXFileReference、`DD` + 連番がPBXGroup。1ファイルにつき4箇所を追加する。

1. `PBXBuildFile` セクションに `AA...` の行（`fileRef` に対応する `BB...` を指定）
2. `PBXFileReference` セクションに `BB...` の行
3. 所属する `DD...` グループの `children` に `BB...`
4. 対象ターゲットの `Sources` ビルドフェーズに `AA...`

編集後は必ず `xcodebuild test` まで通して検証する。壊れていればプロジェクトが開けなくなるため、編集前にバックアップを取る。

### ColorPickerの色を16進数で保存する際の注意
`ColorPicker` はDisplay P3の色を返すことがあり、`UIColor.getRed` の成分が 0...1 の範囲外になりうる。クランプせずに `Int(value * 255)` すると破綻する。`Models/ColorHex.swift` の `channel(_:)` でクランプしてから丸めている。

また `Picker` の `selection` が選択肢に含まれていないと表示が空欄になる。プリセット外の色を選んだ場合に備え、`colorOptions` は現在の色を必ず含める。

### 一覧のカテゴリバッジで色を文字色に使わない理由
カラーを利用者が自由に選べるようになったため、淡い色を文字色にすると読めなくなる。バッジは文字色を `.secondary` に固定し、色は小さなドットでのみ示している。ドットは `@ScaledMetric(relativeTo: .caption2)` で文字サイズに追従させる（固定6ptだと最大文字サイズで相対的に見えなくなる）。

## 決定事項と理由

### 2026-07-30：広告（AdMob）は採用しない
- **理由1**：起動頻度が低く広告表示回数が伸びないため、収益がほぼ期待できない
- **理由2**：現在の審査向け前提（「ユーザーデータは端末と本人のiCloud Private Databaseへ保存」「サブスク名や料金を為替APIへ送信しない」）が崩れ、App Privacy回答・Privacy Manifest・ATT・Runbookの全面見直しが発生する
- **理由3**：iOS 26では画面全体がLiquid Glassで描画されるため、広告バナーの矩形が浮いて見える

### 2026-07-30：1.0.0 は完全無料でリリースする
- 収益化の仕組みより、まずリリースして見つけられることが優先。ダウンロードがなければ収益はゼロ
- 課金を1.0.0に含めるとリリースが遅れるトレードオフを避ける

### 2026-07-30：収益化はリリース後の反応を見て判断する。実施する場合は「新規機能の有料化」で行う
- **既存機能に上限や制限を後から追加しない**。すでに提供した機能を有料化するのは最も嫌われるパターンで、確実に低評価につながる
- 有料化の対象は新規開発する機能（例：CSV/PDFエクスポート、ホーム画面ウィジェット）とする
- モデル自体（買い切り / Tip Jar / サブスク）は未確定。判断はリリース後
