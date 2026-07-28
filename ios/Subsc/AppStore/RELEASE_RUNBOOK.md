# Subsc iOS Release Runbook

最終更新：2026-07-27

この文書はSubsc固有のリリース情報と作業状態を記録します。パスワード、APIキー、証明書の秘密鍵は記録しません。

## アプリ識別情報

| 項目 | 値 |
|---|---|
| Xcodeプロジェクト | `Subsc.xcodeproj` |
| Scheme | `Subsc` |
| Bundle ID | `com.tonaria.subsc` |
| Team ID | `2ZR6Z7NP8H` |
| 対応端末 | iPhone |
| 最低対応OS | iOS 17以降 |
| ホーム画面名 | Subsc |
| App Store掲載名 | Subsc - サブスク管理 |
| App Store Connect App ID | `6795086857` |
| SKU | `subsc-ios-20260727` |
| プライマリ言語 | 日本語 |
| 現在のバージョン | 1.0.0 |
| 現在のビルド | 1 |

## 管理画面

- App Store Connect：<https://appstoreconnect.apple.com/apps/6795086857>
- TestFlight：<https://appstoreconnect.apple.com/teams/c6305443-6aaf-448d-957e-46cd59359530/apps/6795086857/testflight>
- CloudKit Console：<https://icloud.developer.apple.com/dashboard/>

## CloudKit

| 項目 | 値 |
|---|---|
| Container | `iCloud.com.tonaria.subsc` |
| Database | ユーザーごとのPrivate Database |
| Productionスキーマ | 2026-07-27反映済み |
| Record Type | `CD_Subscription` |
| Fields | 27 |
| Indexes | 54 |

Developmentで作成したテストレコードはProductionへコピーされません。TestFlight版とApp Store版はProductionを使用するため、同じBundle ID、CloudKit Container、互換スキーマ、Apple Accountを維持する限り、TestFlight中のユーザーデータは正式版へ引き継がれます。

モデルへ項目を追加した場合は、Development署名のアプリで代表データを保存し、CloudKit Consoleで差分を確認してからProductionへ追加反映します。Productionへ反映済みのRecord TypeやFieldは削除前提で設計しません。

## 署名とアップロード

- App Store用Export設定：`AppStore/ExportOptions.plist`
- App Store Connect直接送信用設定：`AppStore/UploadOptions.plist`
- `ITSAppUsesNonExemptEncryption = false`
- CloudKit Production entitlementを使用
- `get-task-allow = false`
- 1024×1024 App Storeアイコンはアルファなし

2026-07-27にバージョン1.0.0、ビルド1をApp Store Connectへアップロード済みです。Apple側のアップロード受領に成功し、ユーザーによる実機TestFlight確認まで進行しています。

同じバージョンを再アップロードする場合は、先に`CURRENT_PROJECT_VERSION`を増やして新しいArchiveを作成します。

## リリース前の必須確認

### アプリ

- [x] 単体テスト9件合格
- [x] Release Archive成功
- [x] CloudKit Productionスキーマ反映
- [x] TestFlightビルド1アップロード
- [x] 実機TestFlightインストール
- [ ] 実機でサブスクの追加・編集・削除を確認
- [ ] 実機でUSD入力と円換算を確認
- [ ] 実機で通知許可・1日前通知・時刻指定を確認
- [ ] オフライン編集後の再同期を確認
- [ ] 同じApple Accountの2台で同期を確認
- [ ] TestFlightからApp Store版への更新時にデータ維持を確認
- [ ] 最大文字サイズとVoiceOverを実機確認

### App Store Connect

- [ ] プライバシーポリシー公開URL
- [ ] サポート公開URL
- [ ] サポート用メールアドレス
- [ ] iPhone用スクリーンショット
- [ ] 概要・キーワード・カテゴリ
- [ ] App Privacy回答
- [ ] 年齢区分の質問回答
- [ ] App Review連絡先
- [ ] 「サインインが必要です」をオフ
- [ ] 価格と配信地域
- [ ] リリース方法を確認
- [ ] 審査提出前の最終承認

## App Review向け要点

- 独自ログインはありません。
- ユーザーデータは端末と本人のiCloud Private Databaseへ保存します。
- 米ドル選択時のみFrankfurter APIから日次USD/JPY参考レートを取得します。
- サブスク名や料金を為替APIへ送信しません。
- 更新通知はiOSのローカル通知です。
- アプリ内課金や自動更新サブスクリプションの販売機能はありません。

## 既知のリリース時トラブル

### CloudKitに`Users`しか表示されない

開発端末またはシミュレーターがiCloud未ログインの可能性があります。アカウント状態がAvailableであることを確認し、Development版で代表データを保存してCloudKit export成功ログを確認します。

### `Couldn't create new PCS blob`

iCloud初回ログイン直後の保護領域初期化で発生しました。iCloudサービスの再接続とアプリ再起動後、zone作成、import、exportが成功したことを確認して解消しました。

### `missingApp(bundleId: "com.tonaria.subsc")`

App Store Connectに対応するアプリ枠がない状態です。現在はApp ID `6795086857`として作成済みです。

### App Store名`Subsc`が使用済み

App Store掲載名は`Subsc - サブスク管理`を使用します。端末上の表示名は`Subsc`のままです。

### アップロード認証

アプリ専用パスワードをファイルへ保存せず、Xcodeへログイン済みのApple Accountと`-allowProvisioningUpdates`を使用します。

## 次の安全な作業

1. 実機TestFlightの機能確認を完了する。
2. 公開URL、連絡先、スクリーンショットを用意する。
3. App Store Connectのプライバシー、年齢区分、価格、審査情報を入力する。
4. 最終確認後にApp Reviewへ提出する。

