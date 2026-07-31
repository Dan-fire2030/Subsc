# SPEC - 技術仕様・要件定義

対象：iOSネイティブ版（`ios/Subsc`）
起点：カテゴリとカラーのカスタム追加、および一覧行へのメモ・カテゴリ表示
確定日：2026-07-30

## 機能要件

### 1. カスタムカテゴリの追加
現状はフォームの `categories`（プリセット6件）から選ぶだけで、任意のカテゴリを作れない。

- カテゴリの選択肢は次の和集合とする
  - プリセット6件：エンタメ / 仕事・学習 / 音楽 / 生活 / 健康 / その他
  - **既に登録されているサブスクが使用しているカテゴリ**
  - 編集中のサブスクが持つカテゴリ（他から参照されていなくても選択肢に残す）
- 並び順はプリセットを先頭の固定順、その後にカスタムを名前順で並べる
- 選択肢の末尾に「新しいカテゴリを追加」を置き、選ぶとテキスト入力を表示する
- 入力値の扱い
  - 前後の空白・改行をトリムする
  - トリム後が空文字なら追加せず、日本語のエラーメッセージを表示する
  - **20文字を超える入力は却下**し、上限文字数を含む日本語のエラーメッセージを表示する
  - 既存のカテゴリと一致する場合は新規作成せず既存の表記を選択する。一致判定は「トリム＋小文字化」した正規化キーの比較で行う（重複判定と選択肢の組み立てで同じキーを使う）
- **専用モデルは追加しない。** サブスクから導出するため、そのカテゴリを使う最後のサブスクを削除すると選択肢からも消える（決定事項として受容済み）

### 2. カスタムカラーの追加
現状は `colors`（プリセット5色）から選ぶだけ。

- プリセット5色の選択は残し、加えて **`ColorPicker` で任意色**を選べるようにする
- `ColorPicker` は不透明色のみ扱う（`supportsOpacity: false`）。アルファは保存しない
- 選択結果は `#RRGGBB` 形式の大文字16進数で `colorHex` に保存する
- 現在の `colorName(_:)` は未知の16進数をすべて「オレンジ」と表示する不具合がある。**プリセット以外は「カスタム」と表示するよう修正する**

### 3. 一覧行へのメモ表示
- `SubscriptionRow` にメモ（`notes`）を表示する
- **1行で省略**する（`lineLimit(1)`、末尾を「…」で切る）
- メモが空の場合は行を出さない（余白を作らない）

### 4. 一覧行のカテゴリをバッジ表示
カテゴリは既に `"\(category)・\(更新日)更新"` の形で表示されているが目立たない。

- カテゴリを更新日から分離し、**カプセル型バッジ**として表示する
- 更新日は従来どおりテキストで表示する
- **バッジの文字色はサブスクの色を使わず `.secondary` に固定し、色は小さなドットでのみ示す。** カラーを自由に選べるようになったため、淡い色を文字色にすると読めなくなる。カプセルの見た目は既存の「停止中」バッジと揃える
- ドットのサイズは `@ScaledMetric(relativeTo: .caption2)` で文字サイズに追従させる（固定サイズだと最大文字サイズで相対的に見えなくなる）

## 非機能要件

- **CloudKitのスキーマを変更しない。** 既存フィールド（`category` / `colorHex` / `notes`）のみを使うため、Productionスキーマの反映作業は発生しない
- ネットワークに依存しない。オフラインで全機能が動作する
- **Dynamic Type 対応を維持する。** 既存の `dynamicTypeSize.isAccessibilitySize` による縦積み切り替えを壊さない。最大文字サイズでバッジとメモが破綻しないこと
- **VoiceOver**：行は `accessibilityElement(children: .combine)` を維持し、カテゴリとメモが読み上げに含まれること
- iOS 26のLiquid Glass表示とiOS 17〜25のフォールバック表示の両方で破綻しないこと
- **純粋ロジックはユニットテストで担保する**（カテゴリ選択肢の組み立て・入力正規化・16進数の相互変換）。ビュー本体はテスト対象外
- 1ファイル400行を目安とする。既に `SubscriptionFormView.swift` が570行、`DashboardView.swift` が625行あるため、**新規ロジックは別ファイルへ切り出す**

## 技術構成

### 新規ファイル
| ファイル | 役割 |
|---|---|
| `Subsc/Models/ColorHex.swift` | `Color` ↔ `#RRGGBB` の相互変換。既存の `Color(hex:)` をここへ移設し、書き出し側を追加 |
| `Subsc/Features/Subscriptions/CategoryCatalog.swift` | カテゴリ選択肢の組み立てと入力値の正規化・検証（純粋ロジック、SwiftUI非依存） |
| `SubscTests/ColorHexTests.swift` | 16進数変換のテスト |
| `SubscTests/CategoryCatalogTests.swift` | カテゴリ選択肢と入力検証のテスト |

### 変更ファイル
| ファイル | 変更内容 |
|---|---|
| `Subsc/Models/Subscription.swift` | `Color` の extension を `ColorHex.swift` へ移設（`var color` はそのまま） |
| `Subsc/Features/Subscriptions/SubscriptionFormView.swift` | カテゴリ選択のカスタム追加、`ColorPicker` の追加、`colorName` の修正 |
| `Subsc/Features/Dashboard/DashboardView.swift` | `SubscriptionRow` にメモ表示とカテゴリバッジを追加 |
| `Subsc.xcodeproj/project.pbxproj` | 新規4ファイルの参照追加（このプロジェクトはファイル自動認識を使っていないため手動編集が必要） |

### 実装方針
- `CategoryCatalog` は SwiftData に依存させず、`[String]`（既存サブスクのカテゴリ）を入力に取る純粋な型とする。テスト時にモデルコンテナ不要
- フォーム側は `@Query` で既存サブスクを読み、そのカテゴリ配列を `CategoryCatalog` に渡す
- `ColorPicker` は `Color` をバインドするため、`colorHex` との間に `Binding` の変換層を置く
- 16進数の書き出しは `UIColor` 経由で sRGB 成分を取得する。`ColorPicker` は Display P3 の色を返しうるため、**0...1 の範囲外になる成分をクランプ**してから変換する

## 受け入れ条件

- [x] フォームで任意のカテゴリ名を追加でき、保存後もその値が保持される
- [x] 追加したカテゴリが、次回以降の追加・編集時の選択肢に現れる
- [x] 空文字・空白のみ・20文字超のカテゴリ名は追加できず、日本語のエラーが出る
- [x] 既存カテゴリと同名（大文字小文字違いを含む）を入力した場合、重複が作られない
- [x] フォームで任意の色を選べ、保存後も同じ色で表示される
- [x] プリセット以外の色を選んだとき、カラー名が「カスタム」と表示される
- [x] 一覧の各行にメモが1行で表示され、長いメモは末尾が省略される
- [x] メモが空のサブスクでは、一覧行にメモの行が出ない
- [x] 一覧の各行にカテゴリがバッジとして表示される
- [x] 最大文字サイズでも一覧行のレイアウトが破綻しない
- [x] `xcodebuild build` と `xcodebuild test -only-testing:SubscTests` が成功する

---

# SPEC 追補 — `ReportCard.swift` の分割

起点：TODO「`Features/Dashboard/ReportCard.swift`（776行）の分割」
確定日：2026-07-30

## 目的
`ReportCard.swift` が776行あり、AGENTS.md の「1ファイル400行程度を目安」を大きく超えている。
ビュー単位に分割して、変更時に読む範囲を絞れるようにする。

## 要件

### 振る舞いを変えない
これは純粋なリファクタリングであり、**画面の見た目・操作・アクセシビリティの挙動を一切変更しない**。
コードの移動と、ファイルをまたぐために必要なアクセスレベルの変更のみを行う。

### 分割単位
`Features/Dashboard/` 直下にフラットに配置する（サブフォルダを作らない。`project.pbxproj` へ
`PBXGroup` を新設せずに済み、手編集のリスクを下げるため）。

| ファイル | 含む型 | 役割 |
|---|---|---|
| `ReportCard.swift` | `ReportCard` | 期間ピッカーとカーソル状態の管理。カードの入口 |
| `ReportPager.swift` | `ReportPageData`, `ReportPager` | 横スワイプ、前後ボタン、VoiceOverの調整可能アクション |
| `ReportPage.swift` | `ReportPage` | 1期間分の合計額とチャート枠 |
| `GlassBarChart.swift` | `GlassBarChart`, `GlassBarRow` | サービス別の棒グラフと「ほかN件」ボタン |
| `ReportBreakdownSheet.swift` | `ReportBreakdownSheet`, `BreakdownRow` | サービス別料金の詳細シート |
| `ReportGlassStyle.swift` | `ReportCardSurfaceModifier`, `ReportControlButtonModifier`, `CompactGlassCapsuleModifier`, `LiquidGlassCardBackground` | iOS 26 の Liquid Glass と iOS 17〜25 フォールバックの見た目を集約 |

### アクセスレベルの方針
- **ファイルをまたいで使われる型のみ `private` を外して internal にする**
- 使用元と同じファイルに収まる型は `private` のまま残す
  （`GlassBarRow` / `BreakdownRow` / `LiquidGlassCardBackground`）
- モジュール内に同名の型がないことを確認済み

## 非機能要件
- 分割後の全ファイルが400行以下であること
- `xcodebuild build` と `xcodebuild test -only-testing:SubscTests`（52件）が成功すること
- CloudKitのスキーマ・`@Model` に影響を与えないこと（ビュー層のみの変更）
- UIテストの識別子を変更しないこと（CLIから検証できないため）

## 対象外
- `DashboardView.swift`（670行）の分割。別タスクとして TODO に残す
- ビューの構造や見た目の改善。今回は移動のみ

## 受け入れ条件
- [x] `ReportCard.swift` を含む分割後の全6ファイルが400行以下（最大192行）
- [x] `xcodebuild build` が成功する
- [x] `xcodebuild test -only-testing:SubscTests` が52件すべて成功する
- [x] `git diff` にビューの構造変更（移動とアクセスレベル以外）が含まれない
      → 元ファイルと分割後6ファイルの結合を、`import` / doc コメント / `private` 修飾子を除いて
        行の多重集合として比較し、差分ゼロを確認した
- [x] シミュレーターでカード表示・期間ピッカー・横スワイプ・「今月」復帰が分割前と同じに動く
- [ ] **未確認**：棒グラフ（`GlassBarChart` / `GlassBarRow`）とサービス別料金シート（`ReportBreakdownSheet`）。
      金額 > 0 のデータが必要だが、シミュレーターMCPのタップ座標がフォームの金額欄に届かず入力できなかった。
      Xcodeから手動で確認するか、UIテストで担保したい

---

# SPEC 追補 — `DashboardView.swift` の分割

起点：TODO「`Features/Dashboard/DashboardView.swift`（670行）の分割」
確定日：2026-07-30

## 目的
`DashboardView.swift` が670行あり、AGENTS.md の「1ファイル400行程度を目安」を超えている。
`ReportCard.swift` の分割と同じ方針で、ビュー単位に分割する。

## 要件

### 振る舞いを変えない
純粋なリファクタリングとし、**画面の見た目・操作・アクセシビリティの挙動を一切変更しない**。
コードの移動と、ファイルをまたぐために必要なアクセスレベルの変更のみを行う。

### 分割の粒度
**既に `private struct` / `private enum` になっている型を、そのまま別ファイルへ移すだけ**とする。
`body` 内に直書きされているセクション（「次の更新」など）を新しい View 型として抽出することはしない。
新しい型を作ると「元ファイルと分割後の結合を行の多重集合として比較する」検証が効かなくなり、
振る舞い不変を機械的に証明できなくなるため。

### 分割単位
| ファイル | 含む型 | 役割 |
|---|---|---|
| `Features/Dashboard/DashboardView.swift` | `DashboardView`, `SubscriptionEditor` | 一覧画面本体。絞り込み・検索・スワイプ操作・為替更新 |
| `Features/Dashboard/DashboardSearchFilter.swift` | `SubscriptionFilter`, `MinimizableSearchToolbarModifier` | 絞り込み条件と、iOS 26 の検索バー最小化 |
| `Features/Dashboard/DashboardEmptyState.swift` | `DashboardEmptyState` | 0件のときの案内 |
| `Features/Dashboard/SubscriptionRow.swift` | `SubscriptionRow`, `CategoryBadge` | 一覧の1行とカテゴリバッジ |
| `Features/Subscriptions/SubscriptionDetailView.swift` | `SubscriptionDetailView` | サブスク1件の詳細画面 |

`SubscriptionDetailView` はサブスク1件を扱う画面のため、`SubscriptionFormView.swift` と同じ
`Features/Subscriptions/` へ置く（`PBXGroup` は既存のものを使うので手編集のリスクは増えない）。

### アクセスレベルの方針
- ファイルをまたいで使われる型のみ `private` を外して internal にする
  （`SubscriptionFilter` / `MinimizableSearchToolbarModifier` / `DashboardEmptyState` /
  `SubscriptionRow` / `SubscriptionDetailView`）
- 使用元と同じファイルに収まる型は `private` のまま残す（`SubscriptionEditor` / `CategoryBadge`）
- モジュール内に同名の型がないことを確認済み

## 非機能要件
- 分割後の全ファイルが400行以下であること
- `xcodebuild build` と `xcodebuild test -only-testing:SubscTests`（52件）が成功すること
- CloudKitのスキーマ・`@Model` に影響を与えないこと（ビュー層のみの変更）
- UIテストの識別子（`add-subscription-button` / `empty-state-add-subscription-button`）を変更しないこと

## 対象外
- `SubscriptionFormView.swift`（642行）の分割。別タスクとして TODO に残す
- ビューの構造や見た目の改善。今回は移動のみ

## 受け入れ条件
- [x] 分割後の全5ファイルが400行以下（最大 `DashboardView.swift` の339行）
- [x] `xcodebuild build` が成功する
- [x] `xcodebuild test -only-testing:SubscTests` が52件すべて成功する
- [x] `git diff` にビューの構造変更（移動とアクセスレベル以外）が含まれない
      → 元ファイルと分割後5ファイルの結合を、`import` / doc コメント / `private` 修飾子を除いて
        行の多重集合として比較し、差分ゼロを確認した
- [x] シミュレーターで一覧・レポートカード・「次の更新」・カテゴリバッジ付きの行・詳細画面・
      戻る操作が分割前と同じに表示・動作する
- [ ] **未確認**：絞り込みピッカー（`SubscriptionFilter`）の切り替え。
      セグメンテッドピッカーへ注入したタップが届かず操作できなかった（4つの選択肢が
      正しく描画されていることは確認済み）
- [ ] **未確認**：`DashboardEmptyState`。表示には登録0件の状態が必要なため、検証用データを
      消さずに残す判断をした
