import XCTest
@testable import Subsc

@MainActor
final class ExchangeRateServiceTests: XCTestCase {
    func testFreshCacheAvoidsNetworkRequest() async throws {
        let suiteName = "ExchangeRateServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        ExchangeRateService.store(
            UsdJpyQuote(
                rate: 150,
                rateDate: "2027-01-01",
                fetchedAt: now.addingTimeInterval(-60),
                isStale: false
            ),
            defaults: defaults
        )
        let session = FailingExchangeRateSession()

        let quote = try await ExchangeRateService.usdJpy(
            session: session,
            defaults: defaults,
            now: now
        )

        XCTAssertEqual(quote.rate, 150)
        XCTAssertFalse(quote.isStale)
        XCTAssertEqual(session.requestCount, 0)
    }

    func testExpiredCacheIsReturnedAsStaleWhenNetworkFails() async throws {
        let suiteName = "ExchangeRateServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        ExchangeRateService.store(
            UsdJpyQuote(
                rate: 149,
                rateDate: "2026-12-31",
                fetchedAt: now.addingTimeInterval(-24 * 60 * 60),
                isStale: false
            ),
            defaults: defaults
        )
        let session = FailingExchangeRateSession()

        let quote = try await ExchangeRateService.usdJpy(
            session: session,
            defaults: defaults,
            now: now
        )

        XCTAssertEqual(quote.rate, 149)
        XCTAssertTrue(quote.isStale)
        XCTAssertEqual(session.requestCount, 1)
    }
}

@MainActor
private final class FailingExchangeRateSession: ExchangeRateSession {
    private(set) var requestCount = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        throw URLError(.notConnectedToInternet)
    }
}
