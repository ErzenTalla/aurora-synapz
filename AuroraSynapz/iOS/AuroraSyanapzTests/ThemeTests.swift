import XCTest
@testable import AuroraSyanapz

final class ThemeTests: XCTestCase {

    // MARK: - asCurrency

    func testAsCurrencyRoundsToNearestDollar() {
        XCTAssertEqual(1000.0.asCurrency(), "$1,000")
        XCTAssertEqual(0.0.asCurrency(), "$0")
        XCTAssertEqual(1_500_000.0.asCurrency(), "$1,500,000")
    }

    func testAsCurrencyNegative() {
        XCTAssertEqual((-500.0).asCurrency(), "-$500")
    }

    func testAsCurrencyPreciseShowsCents() {
        XCTAssertEqual(1234.56.asCurrencyPrecise(), "$1,234.56")
        XCTAssertEqual(0.01.asCurrencyPrecise(), "$0.01")
        XCTAssertEqual(0.0.asCurrencyPrecise(), "$0.00")
    }

    func testAsCurrencyPreciseNegative() {
        XCTAssertEqual((-99.99).asCurrencyPrecise(), "-$99.99")
    }

    // MARK: - asPct

    func testAsPctPositiveShowsPlus() {
        XCTAssertEqual(5.25.asPct(), "+5.25%")
    }

    func testAsPctNegativeShowsMinus() {
        XCTAssertEqual((-3.10).asPct(), "-3.10%")
    }

    func testAsPctZeroShowsPlus() {
        XCTAssertEqual(0.0.asPct(), "+0.00%")
    }

    func testAsPctTwoDecimalPlaces() {
        XCTAssertEqual(1.0.asPct(), "+1.00%")
        XCTAssertEqual(10.123.asPct(), "+10.12%")
    }

    // MARK: - color()

    func testColorPositiveIsGreen() {
        XCTAssertEqual(5.0.color(), Theme.green)
    }

    func testColorNegativeIsRed() {
        XCTAssertEqual((-5.0).color(), Theme.red)
    }

    func testColorZeroIsGreen() {
        XCTAssertEqual(0.0.color(), Theme.green)
    }
}
