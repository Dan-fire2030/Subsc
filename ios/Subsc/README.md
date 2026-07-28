# Subsc for iOS

SubscのSwiftUIネイティブ版です。データはSwiftDataへオフライン保存され、同じApple IDの端末間ではCloudKitのプライベートデータベースを通じて同期されます。

## 開き方

`Subsc.xcodeproj` をXcodeで開き、iOS 17以降のiPhoneシミュレーターまたは実機を選んで実行します。

## 現在の対応範囲

- サブスク一覧・検索・絞り込み
- 検索候補・利用中・停止中・終了履歴
- 追加・編集・スワイプ削除
- 月間・年間レポート
- 米ドル入力と日次のドル円参考レートによる円換算
- SwiftDataによるオフライン保存
- CloudKitによる同一Apple ID端末間の同期
- 契約周期に応じた更新日の自動繰り越し
- 更新日前の日数・時間指定のローカル通知と予約の自動再同期
- Privacy Manifestとアプリ内プライバシー説明
- iPhone向けSubscアプリアイコン

独自アカウントや外部DBは使用しません。

## リリース前に必要な外部作業

- CloudKitのProductionスキーマ反映とTestFlightビルド1のアップロードは完了済みです。
- App Store ConnectへプライバシーポリシーURLとサポートURLを登録します。
- iCloud同期、オフライン編集、通知を実機2台で確認します。
- App Store情報と審査情報を完成させ、最終承認後にApp Reviewへ提出します。

最新の識別情報、完了状況、確認項目、トラブル対処は
[`AppStore/RELEASE_RUNBOOK.md`](AppStore/RELEASE_RUNBOOK.md)を参照してください。
