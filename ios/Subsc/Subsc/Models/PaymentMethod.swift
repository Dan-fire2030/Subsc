import Foundation

/// 支払い方法です。どこから引き落とされるかを記録するためのもので、集計には使いません。
///
/// 「◯◯カード」のような具体名は選択肢では表しきれないため、
/// `Subscription.paymentMethodNote` の自由入力と組み合わせて使います。
enum PaymentMethod: String, CaseIterable, Codable, Identifiable {
    case unspecified
    case creditCard
    case bankTransfer
    case convenienceStore
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unspecified: "未設定"
        case .creditCard: "クレジットカード"
        case .bankTransfer: "口座振替"
        case .convenienceStore: "コンビニ払い"
        case .other: "その他"
        }
    }
}
