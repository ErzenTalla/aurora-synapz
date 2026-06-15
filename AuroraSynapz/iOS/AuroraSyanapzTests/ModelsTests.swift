import XCTest
@testable import AuroraSyanapz

final class ModelsTests: XCTestCase {
    private let decoder = JSONDecoder()

    // MARK: - Portfolio

    func testPortfolioDecoding() throws {
        let json = """
        {
            "id": 1, "user_id": 2,
            "total_value": 125000.50, "cash_balance": 5000.00,
            "day_change": 1250.75, "day_change_pct": 1.01,
            "ytd_return": 8000.00, "ytd_return_pct": 6.84,
            "inception_date": "2023-01-15", "updated_at": "2024-06-01"
        }
        """.data(using: .utf8)!

        let p = try decoder.decode(Portfolio.self, from: json)
        XCTAssertEqual(p.id, 1)
        XCTAssertEqual(p.userId, 2)
        XCTAssertEqual(p.totalValue, 125000.50)
        XCTAssertEqual(p.cashBalance, 5000.00)
        XCTAssertEqual(p.dayChangePct, 1.01)
        XCTAssertEqual(p.inceptionDate, "2023-01-15")
        XCTAssertNil(p.allTimeGain)
    }

    func testPortfolioOptionalFields() throws {
        let json = """
        {
            "id": 1, "user_id": 1,
            "total_value": 0, "cash_balance": 0,
            "day_change": 0, "day_change_pct": 0,
            "ytd_return": 0, "ytd_return_pct": 0,
            "inception_date": "2024-01-01",
            "total_invested": 50000, "all_time_gain": 5000, "all_time_gain_pct": 10
        }
        """.data(using: .utf8)!

        let p = try decoder.decode(Portfolio.self, from: json)
        XCTAssertEqual(p.totalInvested, 50000)
        XCTAssertEqual(p.allTimeGain, 5000)
        XCTAssertEqual(p.allTimeGainPct, 10)
    }

    // MARK: - Holding

    func testHoldingDecoding() throws {
        let json = """
        {
            "id": 1, "user_id": 2,
            "symbol": "AAPL", "name": "Apple Inc.", "asset_class": "Equity",
            "shares": 10.5, "price": 185.50, "avg_cost": 150.00,
            "day_change": 2.35, "day_chg_pct": 1.28
        }
        """.data(using: .utf8)!

        let h = try decoder.decode(Holding.self, from: json)
        XCTAssertEqual(h.symbol, "AAPL")
        XCTAssertEqual(h.name, "Apple Inc.")
        XCTAssertEqual(h.assetClass, "Equity")
        XCTAssertEqual(h.shares, 10.5, accuracy: 0.001)
        XCTAssertEqual(h.price, 185.50, accuracy: 0.001)
        XCTAssertNil(h.marketValue)
    }

    func testHoldingComputedMarketValue() throws {
        let json = """
        {
            "id": 1, "user_id": 1,
            "symbol": "MSFT", "name": "Microsoft", "asset_class": "Equity",
            "shares": 5.0, "price": 400.0, "avg_cost": 300.0,
            "day_change": 0, "day_chg_pct": 0,
            "market_value": 2000.0, "total_gain": 500.0, "total_gain_pct": 33.33
        }
        """.data(using: .utf8)!

        let h = try decoder.decode(Holding.self, from: json)
        XCTAssertEqual(h.marketValue, 2000.0)
        XCTAssertEqual(h.totalGain, 500.0)
    }

    // MARK: - Transaction

    func testTransactionBuyDecoding() throws {
        let json = """
        {
            "id": 1, "type": "BUY",
            "symbol": "MSFT", "name": "Microsoft Corp",
            "shares": 5.0, "price": 420.00, "amount": 2100.00,
            "note": null, "created_at": "2024-05-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let tx = try decoder.decode(Transaction.self, from: json)
        XCTAssertEqual(tx.type, "BUY")
        XCTAssertEqual(tx.symbol, "MSFT")
        XCTAssertEqual(tx.amount, 2100.00)
        XCTAssertNil(tx.note)
    }

    func testTransactionDepositNullSymbol() throws {
        let json = """
        {
            "id": 2, "type": "DEPOSIT",
            "symbol": null, "name": null, "shares": null, "price": null,
            "amount": 10000.00, "note": "Initial deposit",
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let tx = try decoder.decode(Transaction.self, from: json)
        XCTAssertEqual(tx.type, "DEPOSIT")
        XCTAssertNil(tx.symbol)
        XCTAssertNil(tx.shares)
        XCTAssertEqual(tx.note, "Initial deposit")
        XCTAssertEqual(tx.amount, 10000.00)
    }

    // MARK: - PerformancePoint date parsing

    func testPerformancePointDateParsing() {
        let point = PerformancePoint(date: "2024-01-15", value: 100_000)
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month, .day], from: point.dateValue)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
    }

    func testPerformancePointInvalidDateFallsBack() {
        let point = PerformancePoint(date: "not-a-date", value: 0)
        XCTAssertNotNil(point.dateValue)
    }

    func testPerformancePointDecoding() throws {
        let json = """
        [
            {"date": "2024-01-01", "value": 100000},
            {"date": "2024-02-01", "value": 105000}
        ]
        """.data(using: .utf8)!

        let points = try decoder.decode([PerformancePoint].self, from: json)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].value, 100_000)
        XCTAssertEqual(points[1].date, "2024-02-01")
    }

    // MARK: - Contact

    func testContactFullName() throws {
        let json = """
        {
            "id": 1, "first_name": "John", "last_name": "Doe",
            "email": "john@example.com", "phone": "+1-555-0100",
            "service": "Portfolio Management", "assets": "$1M-$5M",
            "message": "Interested in your services",
            "created_at": "2024-06-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let c = try decoder.decode(Contact.self, from: json)
        XCTAssertEqual(c.fullName, "John Doe")
        XCTAssertEqual(c.email, "john@example.com")
        XCTAssertEqual(c.service, "Portfolio Management")
    }

    func testContactOptionalFields() throws {
        let json = """
        {
            "id": 2, "first_name": "Jane", "last_name": "Smith",
            "email": "jane@example.com",
            "phone": null, "service": null, "assets": null, "message": null,
            "created_at": "2024-06-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let c = try decoder.decode(Contact.self, from: json)
        XCTAssertNil(c.phone)
        XCTAssertNil(c.service)
        XCTAssertEqual(c.fullName, "Jane Smith")
    }

    // MARK: - AdminStats

    func testAdminStatsDecoding() throws {
        let json = """
        {
            "total_aum": 5000000.00, "client_count": 12,
            "contact_count": 45, "total_deposits": 250000.00
        }
        """.data(using: .utf8)!

        let s = try decoder.decode(AdminStats.self, from: json)
        XCTAssertEqual(s.totalAum, 5_000_000.00)
        XCTAssertEqual(s.clientCount, 12)
        XCTAssertEqual(s.contactCount, 45)
    }

    // MARK: - Document

    func testDocumentDecoding() throws {
        let json = """
        {
            "id": 1, "title": "Q4 2023 Statement",
            "type": "Statement", "period": "Q4 2023",
            "size_kb": 245, "created_at": "2024-01-10T00:00:00Z"
        }
        """.data(using: .utf8)!

        let d = try decoder.decode(Document.self, from: json)
        XCTAssertEqual(d.title, "Q4 2023 Statement")
        XCTAssertEqual(d.type, "Statement")
        XCTAssertEqual(d.sizeKb, 245)
    }
}
