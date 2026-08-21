import Foundation

extension ReportEntry {
    /// 借入の行に付ける接頭辞です。
    ///
    /// **費目と借入で `clientID` が衝突しても別項目として扱う**ために付けています。
    /// 組み立てる側（`ReportCalculator`）と読む側（`ReportEntryTarget`）で
    /// 別々に書くと、片方を直したときに引き当てが静かに壊れます。**定義はここ1箇所だけです。**
    static let loanIDPrefix = "loan-"

    /// 借入の行なら、その借入の `clientID` を返します。費目の行では `nil` です。
    var loanClientID: String? {
        guard id.hasPrefix(Self.loanIDPrefix) else { return nil }
        return String(id.dropFirst(Self.loanIDPrefix.count))
    }
}

/// 費目別料金の行を押したときに開く対象です。
///
/// **種別（`CostType`）では見分けられません。** 費目にも「借入・ローン」の種別があり、
/// 借入（`Loan`）と同じ種別になりえます。見分けは行のIDの接頭辞だけで行います。
enum ReportEntryTarget {
    case subscription(Subscription)
    case loan(Loan)

    /// 行に対応するモデルを探します。
    ///
    /// アーカイブや削除で対象が消えている行では `nil` を返します。
    /// **その場合は行を押せないようにします。** 開ける先が無いのに反応すると、
    /// 押しても何も起きない行になります。
    static func resolve(
        entry: ReportEntry,
        subscriptions: [Subscription],
        loans: [Loan]
    ) -> ReportEntryTarget? {
        if let clientID = entry.loanClientID {
            return loans.first { $0.clientID == clientID }.map(ReportEntryTarget.loan)
        }
        return subscriptions.first { $0.clientID == entry.id }.map(ReportEntryTarget.subscription)
    }
}
