import Foundation

/// 同梱カタログの中身です。ロジックは `ServiceCatalog` にあり、ここはデータだけを置きます。
///
/// 追加・改名の方針：
/// - **日本で契約者が多いものを優先**します。網羅より、探して見つかることを優先します
/// - 名前は**日本で表示されている表記**に合わせます（`Amazonプライム` など）
/// - 色は**そのサービスを思い出せる色**で足ります。ブランドガイドの厳密な再現は目的ではありません
/// - **料金・プラン名は入れません**（`ServiceCatalog` の説明を参照）
enum ServiceCatalogEntries {
    static let services: [CatalogService] = video + music + reading + tools + games + living + health + communication

    // MARK: - 動画

    private static let video: [CatalogService] = [
        CatalogService(
            name: "Netflix",
            category: "エンタメ",
            colorHex: "#E50914",
            aliases: ["ネトフリ", "ネットフリックス"]
        ),
        CatalogService(
            name: "Amazonプライム",
            category: "生活",
            colorHex: "#00A8E1",
            aliases: ["プライム", "Amazon Prime", "アマプラ", "プライムビデオ"]
        ),
        CatalogService(
            name: "Disney+",
            category: "エンタメ",
            colorHex: "#113CCF",
            aliases: ["ディズニープラス", "ディズニー"]
        ),
        CatalogService(
            name: "U-NEXT",
            category: "エンタメ",
            colorHex: "#000000",
            aliases: ["ユーネクスト"]
        ),
        CatalogService(name: "Hulu", category: "エンタメ", colorHex: "#1CE783", aliases: ["フールー"]),
        CatalogService(
            name: "ABEMAプレミアム",
            category: "エンタメ",
            colorHex: "#22C55E",
            aliases: ["アベマ", "abema"]
        ),
        CatalogService(name: "DAZN", category: "エンタメ", colorHex: "#F8F800", aliases: ["ダゾーン"]),
        CatalogService(
            name: "dアニメストア",
            category: "エンタメ",
            colorHex: "#FF7F00",
            aliases: ["ディーアニメ", "danime"]
        ),
        CatalogService(name: "Apple TV", category: "エンタメ", colorHex: "#1D1D1F", aliases: ["アップルTV"]),
        CatalogService(name: "Lemino", category: "エンタメ", colorHex: "#E4007F", aliases: ["レミノ"]),
        CatalogService(name: "WOWOW", category: "エンタメ", colorHex: "#0068B7", aliases: ["ワウワウ"])
    ]

    // MARK: - 音楽

    private static let music: [CatalogService] = [
        CatalogService(
            name: "Spotify",
            category: "音楽",
            colorHex: "#1DB954",
            aliases: ["スポティファイ", "スポチファイ"]
        ),
        CatalogService(
            name: "Apple Music",
            category: "音楽",
            colorHex: "#FA243C",
            aliases: ["アップルミュージック"]
        ),
        CatalogService(
            name: "YouTube Premium",
            category: "音楽",
            colorHex: "#FF0000",
            aliases: ["ユーチューブ", "YouTube Music", "ようつべ"]
        ),
        CatalogService(
            name: "Amazon Music Unlimited",
            category: "音楽",
            colorHex: "#25D1DA",
            aliases: ["アマゾンミュージック"]
        ),
        CatalogService(name: "AWA", category: "音楽", colorHex: "#FF0055", aliases: ["アワ"]),
        CatalogService(name: "LINE MUSIC", category: "音楽", colorHex: "#06C755", aliases: ["ラインミュージック"])
    ]

    // MARK: - 読む・聴く

    private static let reading: [CatalogService] = [
        CatalogService(
            name: "Kindle Unlimited",
            category: "エンタメ",
            colorHex: "#0F9D58",
            aliases: ["キンドル", "kindle"]
        ),
        CatalogService(name: "Audible", category: "エンタメ", colorHex: "#F8991C", aliases: ["オーディブル"]),
        CatalogService(name: "dマガジン", category: "エンタメ", colorHex: "#CC0033", aliases: ["ディーマガジン"]),
        CatalogService(name: "楽天マガジン", category: "エンタメ", colorHex: "#BF0000", aliases: ["らくてんマガジン"]),
        CatalogService(
            name: "少年ジャンプ+",
            category: "エンタメ",
            colorHex: "#D7000F",
            aliases: ["ジャンプ", "jump"]
        )
    ]

    // MARK: - 仕事・学習

    private static let tools: [CatalogService] = [
        CatalogService(name: "iCloud+", category: "仕事・学習", colorHex: "#3693F3", aliases: ["アイクラウド"]),
        CatalogService(name: "Google One", category: "仕事・学習", colorHex: "#4285F4", aliases: ["グーグルワン"]),
        CatalogService(name: "Dropbox", category: "仕事・学習", colorHex: "#0061FF", aliases: ["ドロップボックス"]),
        CatalogService(
            name: "Microsoft 365",
            category: "仕事・学習",
            colorHex: "#D83B01",
            aliases: ["オフィス", "office", "マイクロソフト"]
        ),
        CatalogService(
            name: "Adobe Creative Cloud",
            category: "仕事・学習",
            colorHex: "#DA1F26",
            aliases: ["アドビ", "adobe", "フォトショ"]
        ),
        CatalogService(name: "Notion", category: "仕事・学習", colorHex: "#111111", aliases: ["ノーション"]),
        CatalogService(name: "Evernote", category: "仕事・学習", colorHex: "#00A82D", aliases: ["エバーノート"]),
        CatalogService(name: "1Password", category: "仕事・学習", colorHex: "#0572EC", aliases: ["ワンパスワード"]),
        CatalogService(name: "ChatGPT", category: "仕事・学習", colorHex: "#10A37F", aliases: ["チャットGPT", "openai"]),
        CatalogService(name: "Claude", category: "仕事・学習", colorHex: "#D97757", aliases: ["クロード", "anthropic"]),
        CatalogService(
            name: "GitHub Copilot",
            category: "仕事・学習",
            colorHex: "#24292F",
            aliases: ["ギットハブ", "copilot"]
        ),
        CatalogService(name: "Canva", category: "仕事・学習", colorHex: "#00C4CC", aliases: ["キャンバ"]),
        CatalogService(name: "Figma", category: "仕事・学習", colorHex: "#A259FF", aliases: ["フィグマ"]),
        CatalogService(name: "Slack", category: "仕事・学習", colorHex: "#4A154B", aliases: ["スラック"]),
        CatalogService(name: "スタディサプリ", category: "仕事・学習", colorHex: "#FF6B00", aliases: ["すたさぷ"])
    ]

    // MARK: - ゲーム

    private static let games: [CatalogService] = [
        CatalogService(
            name: "Nintendo Switch Online",
            category: "エンタメ",
            colorHex: "#E60012",
            aliases: ["ニンテンドー", "スイッチ", "switch"]
        ),
        CatalogService(
            name: "PlayStation Plus",
            category: "エンタメ",
            colorHex: "#003791",
            aliases: ["プレステ", "ps plus", "psプラス"]
        ),
        CatalogService(
            name: "Xbox Game Pass",
            category: "エンタメ",
            colorHex: "#107C10",
            aliases: ["エックスボックス", "ゲームパス"]
        ),
        CatalogService(name: "Apple Arcade", category: "エンタメ", colorHex: "#FF2D55", aliases: ["アップルアーケード"])
    ]

    // MARK: - 生活

    private static let living: [CatalogService] = [
        CatalogService(name: "Uber One", category: "生活", colorHex: "#06C167", aliases: ["ウーバー", "uber eats"]),
        CatalogService(name: "楽天プレミアム", category: "生活", colorHex: "#BF0000", aliases: ["らくてんプレミアム"]),
        CatalogService(
            name: "NHK受信料",
            category: "生活",
            colorHex: "#F26522",
            costType: .fixed,
            aliases: ["エヌエイチケー", "nhk"]
        ),
        CatalogService(
            name: "コストコ年会費",
            category: "生活",
            colorHex: "#E31837",
            costType: .fixed,
            aliases: ["costco", "こすとこ"]
        )
    ]

    // MARK: - 健康

    private static let health: [CatalogService] = [
        CatalogService(name: "chocoZAP", category: "健康", colorHex: "#FFD400", aliases: ["ちょこざっぷ", "チョコザップ"]),
        CatalogService(name: "Apple Fitness+", category: "健康", colorHex: "#A2FA4B", aliases: ["フィットネス"]),
        CatalogService(name: "エニタイムフィットネス", category: "健康", colorHex: "#7C2529", aliases: ["エニタイム", "anytime"]),
        CatalogService(name: "あすけん", category: "健康", colorHex: "#8DC21F", aliases: ["アスケン"])
    ]

    // MARK: - 通信

    /// **種別は通信費です。** サブスク扱いにすると、種別ごとの集計の意味が変わります。
    private static let communication: [CatalogService] = [
        CatalogService(
            name: "docomo",
            category: "生活",
            colorHex: "#CC0033",
            costType: .communication,
            aliases: ["ドコモ", "どこも"]
        ),
        CatalogService(
            name: "au",
            category: "生活",
            colorHex: "#EB5505",
            costType: .communication,
            aliases: ["エーユー", "kddi"]
        ),
        CatalogService(
            name: "SoftBank",
            category: "生活",
            colorHex: "#B0B0B0",
            costType: .communication,
            aliases: ["ソフトバンク"]
        ),
        CatalogService(
            name: "楽天モバイル",
            category: "生活",
            colorHex: "#BF0000",
            costType: .communication,
            aliases: ["らくてんモバイル", "rakuten"]
        ),
        CatalogService(
            name: "ahamo",
            category: "生活",
            colorHex: "#000000",
            costType: .communication,
            aliases: ["アハモ"]
        ),
        CatalogService(
            name: "povo",
            category: "生活",
            colorHex: "#FFE100",
            costType: .communication,
            aliases: ["ポヴォ", "ポボ"]
        ),
        CatalogService(
            name: "LINEMO",
            category: "生活",
            colorHex: "#06C755",
            costType: .communication,
            aliases: ["ラインモ"]
        ),
        CatalogService(
            name: "UQ mobile",
            category: "生活",
            colorHex: "#E4007F",
            costType: .communication,
            aliases: ["ユーキュー", "uqモバイル"]
        ),
        CatalogService(
            name: "Y!mobile",
            category: "生活",
            colorHex: "#FF0033",
            costType: .communication,
            aliases: ["ワイモバイル", "ymobile"]
        ),
        CatalogService(
            name: "mineo",
            category: "生活",
            colorHex: "#00A0E9",
            costType: .communication,
            aliases: ["マイネオ"]
        ),
        CatalogService(
            name: "IIJmio",
            category: "生活",
            colorHex: "#005BAC",
            costType: .communication,
            aliases: ["アイアイジェイ", "みおふぉん"]
        ),
        CatalogService(
            name: "NURO光",
            category: "生活",
            colorHex: "#E60012",
            costType: .communication,
            aliases: ["ニューロ", "nuro"]
        ),
        CatalogService(
            name: "ドコモ光",
            category: "生活",
            colorHex: "#CC0033",
            costType: .communication,
            aliases: ["どこもひかり"]
        ),
        CatalogService(
            name: "SoftBank光",
            category: "生活",
            colorHex: "#8E8E8E",
            costType: .communication,
            aliases: ["ソフトバンクひかり"]
        ),
        CatalogService(
            name: "auひかり",
            category: "生活",
            colorHex: "#EB5505",
            costType: .communication,
            aliases: ["エーユーひかり"]
        )
    ]
}
