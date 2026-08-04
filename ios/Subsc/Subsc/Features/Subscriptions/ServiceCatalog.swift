import Foundation

/// 費目の追加でひな型として選べる、よく使われるサービスです。
///
/// **料金を持ちません。** 値上げのたびに古い額を提示することになり、
/// 「アプリが入れた額」と実際の請求が食い違うほうが害が大きいためです。
/// プランによっても違うので、金額は利用者に入れてもらいます。
///
/// **ロゴ画像も持ちません。** 商標の使用許諾が絡むうえ、審査で問題になり得ます。
/// 見分けは既存の頭文字タイルとブランド色で足ります。
struct CatalogService: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let category: String
    let colorHex: String
    let costType: CostType
    /// 通称・略称・ローマ字表記です。正式名称しか引けないと、結局一覧をスクロールすることになります。
    let aliases: [String]

    init(
        name: String,
        category: String,
        colorHex: String,
        costType: CostType = .subscription,
        aliases: [String] = []
    ) {
        self.name = name
        self.category = category
        self.colorHex = colorHex
        self.costType = costType
        self.aliases = aliases
    }
}

/// カテゴリごとにまとめた表示用の1区画です。
struct CatalogSection: Identifiable, Equatable {
    var id: String { category }
    let category: String
    let services: [CatalogService]
}

/// 同梱カタログの検索と並べ替えを担います。
///
/// **通信は一切しません。** サービスの一覧を外部から取ると「利用者がどのサービスを
/// 契約しようとしているか」を送ることになり、「データは端末と本人のiCloudにしか無い」という
/// 審査向けの前提が崩れます。更新はアプリのリリースに乗せます。
enum ServiceCatalog {
    static let all: [CatalogService] = ServiceCatalogEntries.services

    /// 名前・通称・カテゴリのいずれかに含まれるものを返します。空の入力では全件を返します。
    static func search(_ query: String) -> [CatalogService] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }

        let key = normalized(trimmed)
        return all.filter { service in
            let haystack = [service.name, service.category] + service.aliases
            return haystack.contains { normalized($0).contains(key) }
        }
    }

    /// カテゴリごとにまとめます。**並びは `CategoryCatalog.presets` の順**に揃え、
    /// 費目の追加画面のカテゴリ選択と前後関係が食い違わないようにします。
    static var grouped: [CatalogSection] {
        sections(from: all)
    }

    /// 検索結果を同じ規則でまとめます。該当の無いカテゴリは区画ごと落とします。
    static func sections(from services: [CatalogService]) -> [CatalogSection] {
        CategoryCatalog.presets.compactMap { category in
            let matching = services.filter { $0.category == category }
            guard !matching.isEmpty else { return nil }
            return CatalogSection(category: category, services: matching)
        }
    }

    /// 大文字小文字と全角半角の違いを無視して比べるための正規化です。
    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
