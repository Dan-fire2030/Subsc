import Foundation

/// 起動時チュートリアルの1ページぶんの内容です。
///
/// **文言をビュー側で組み立てません。** 表示する順と中身を1箇所にまとめ、
/// ページを足す・入れ替えるときにビューを読まなくて済むようにします。
///
/// **猫の口調で書きません。** 金額を扱うアプリなので、事実と演出の区別が
/// つかなくなる書き方は避けます（リデザインで決めた方針）。
struct TutorialPage: Identifiable, Equatable {
    let id: Int
    /// 見出しです。**体言止めにせず、何ができるかを動詞で書きます。**
    let title: String
    /// 本文です。**3行に収まる長さを目安にします。** 長い案内は読まれません。
    let body: String
    /// 添える絵です。ビットマップを持たず、SF Symbolsで足ります。
    let systemImage: String
}

extension TutorialPage {
    /// 出す順の4ページです。
    ///
    /// **順番に意味があります。** 費目の登録（誰でも使う）→ 借入（使う人には中核）
    /// → レポート（貯まってから効く）→ 通知とデータ（安心して続けるための前提）。
    static let all: [TutorialPage] = [
        TutorialPage(
            id: 0,
            title: "毎月の支払いを登録する",
            body: """
            サブスク、通信費、光熱費などを費目として登録します。\
            金額が毎月変わる費目は、月ごとの実績をあとから入力できます。
            """,
            systemImage: "square.stack.3d.up"
        ),
        TutorialPage(
            id: 1,
            title: "借入と返済を管理する",
            body: """
            住宅ローンや奨学金を、借りたときの条件からでも今の残高からでも登録できます。\
            返済予定表と完済予定日は自動で計算されます。
            """,
            systemImage: "banknote"
        ),
        TutorialPage(
            id: 2,
            title: "レポートで全体を見る",
            body: """
            月間・年間の支払いを集計します。左右にスワイプで期間を移動でき、\
            年払いは更新月にまとめて計上します。
            """,
            systemImage: "chart.bar.xaxis"
        ),
        TutorialPage(
            id: 3,
            title: "通知で取りこぼさない",
            body: """
            更新日や返済日の前に通知でお知らせします。\
            データは端末と本人のiCloudにだけ保存され、外部へ送ることはありません。
            """,
            systemImage: "bell.badge"
        )
    ]
}
