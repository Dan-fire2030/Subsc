import SwiftUI

/// ドル円レートの取得状態です。取得できなくても保存済みレートで表示を続けられるよう `stale` を持ちます。
enum ExchangeRateLoadStatus: Equatable {
    case idle
    case loading
    case loaded
    case stale
    case failed
}

extension SubscriptionFormView {
    func loadExchangeRate(forceRefresh: Bool = false) async {
        exchangeRateStatus = .loading
        do {
            let quote = try await ExchangeRateService.usdJpy(forceRefresh: forceRefresh)
            withAnimation(.easeOut(duration: 0.22)) {
                exchangeRate = quote.rate
                exchangeRateDate = quote.rateDate
                exchangeRateStatus = quote.isStale ? .stale : .loaded
            }
            if validationMessage == "ドル円レートを取得してから保存してください。" {
                validationMessage = nil
            }
        } catch {
            exchangeRateStatus = exchangeRate > 0 ? .stale : .failed
            if exchangeRate == 0 {
                validationMessage = error.localizedDescription
            }
        }
    }
}
