import Foundation

struct UsdJpyQuote: Codable, Sendable {
    let rate: Double
    let rateDate: String
    let fetchedAt: Date
    let isStale: Bool
}

@MainActor
protocol ExchangeRateSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ExchangeRateSession {}

enum ExchangeRateError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "ドル円レートを取得できませんでした。通信状況を確認してください。"
    }
}

@MainActor
enum ExchangeRateService {
    private static let endpoint = URL(string: "https://api.frankfurter.dev/v2/rate/USD/JPY")!
    private static let cacheKey = "subsc.usd-jpy-quote"
    private static let cacheLifetime: TimeInterval = 4 * 60 * 60

    static func usdJpy(
        forceRefresh: Bool = false,
        session: any ExchangeRateSession = URLSession.shared,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) async throws -> UsdJpyQuote {
        let cached = cachedQuote(defaults: defaults)
        if !forceRefresh,
           let cached,
           now.timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            return cached
        }

        do {
            var request = URLRequest(url: endpoint)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 12

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw ExchangeRateError.unavailable
            }

            let payload = try JSONDecoder().decode(RateResponse.self, from: data)
            guard payload.rate.isFinite, payload.rate > 0 else {
                throw ExchangeRateError.unavailable
            }

            let quote = UsdJpyQuote(
                rate: payload.rate,
                rateDate: payload.date,
                fetchedAt: now,
                isStale: false
            )
            store(quote, defaults: defaults)
            return quote
        } catch {
            if let cached {
                return UsdJpyQuote(
                    rate: cached.rate,
                    rateDate: cached.rateDate,
                    fetchedAt: cached.fetchedAt,
                    isStale: true
                )
            }
            throw ExchangeRateError.unavailable
        }
    }

    private static func cachedQuote(defaults: UserDefaults) -> UsdJpyQuote? {
        guard let data = defaults.data(forKey: cacheKey),
              let quote = try? JSONDecoder().decode(UsdJpyQuote.self, from: data),
              quote.rate.isFinite,
              quote.rate > 0 else {
            return nil
        }
        return quote
    }

    static func store(_ quote: UsdJpyQuote, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(quote) else { return }
        defaults.set(data, forKey: cacheKey)
    }
}

private struct RateResponse: Decodable {
    let date: String
    let rate: Double
}
