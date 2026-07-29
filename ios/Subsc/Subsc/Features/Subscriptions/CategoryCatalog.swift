import Foundation

/// カテゴリの選択肢の組み立てと、ユーザーが入力した新しいカテゴリ名の検証を担います。
///
/// カテゴリは専用のモデルを持たず、登録済みサブスクリプションが使っている値から導出します。
/// CloudKitのRecord Type追加とProductionスキーマの反映作業を避けるためです。
/// その代わり、あるカテゴリを使う最後のサブスクリプションを削除すると選択肢からも消えます。
enum CategoryCatalog {
    /// 常に先頭へ固定表示するカテゴリです。
    static let presets = ["エンタメ", "仕事・学習", "音楽", "生活", "健康", "その他"]

    /// カテゴリ名の文字数上限です。
    static let maxNameLength = 20

    enum ValidationResult: Equatable {
        /// 受け入れた名前です。既存と一致した場合は既存側の表記を返します。
        case accepted(String)
        /// 却下した理由です。利用者へそのまま表示できる日本語の文章です。
        case failure(String)
    }

    /// 選択肢を組み立てます。プリセットを固定順で並べ、そのあとにカスタムを名前順で並べます。
    /// - Parameters:
    ///   - usedCategories: 登録済みサブスクリプションが使っているカテゴリ
    ///   - selected: 編集中の値。他から参照されていなくても選択肢に残します
    static func options(usedCategories: [String], selected: String? = nil) -> [String] {
        var seenKeys = Set(presets.map(normalizedKey))
        var customs: [String] = []

        for value in usedCategories + [selected].compactMap({ $0 }) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = normalizedKey(trimmed)
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            customs.append(trimmed)
        }

        customs.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        return presets + customs
    }

    /// 入力された名前を検証します。既存と大文字小文字違いで一致する場合は既存の表記を返します。
    static func validate(_ input: String, existing: [String]) -> ValidationResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure("カテゴリ名を入力してください。")
        }
        guard trimmed.count <= maxNameLength else {
            return .failure("カテゴリ名は\(maxNameLength)文字以内で入力してください。")
        }

        let key = normalizedKey(trimmed)
        if let match = existing.first(where: { normalizedKey($0) == key }) {
            return .accepted(match.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .accepted(trimmed)
    }

    /// 重複判定に使うキーです。前後の空白を無視し、大文字小文字を区別しません。
    private static func normalizedKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
