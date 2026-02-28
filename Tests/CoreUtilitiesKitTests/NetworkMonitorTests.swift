import XCTest
import Network
@testable import CoreUtilitiesKit

final class NetworkMonitorTests: XCTestCase {
    func testDeriveQualityOffline() {
        let quality = NetworkMonitor.deriveQuality(
            connected: false,
            isConstrained: false,
            isExpensive: false,
            interfaceType: .wifi
        )
        XCTAssertEqual(quality, .offline)
    }

    func testDeriveQualityConstrainedIsPoor() {
        let quality = NetworkMonitor.deriveQuality(
            connected: true,
            isConstrained: true,
            isExpensive: false,
            interfaceType: .wifi
        )
        XCTAssertEqual(quality, .poor)
    }

    func testDeriveQualityWifiIsExcellent() {
        let quality = NetworkMonitor.deriveQuality(
            connected: true,
            isConstrained: false,
            isExpensive: false,
            interfaceType: .wifi
        )
        XCTAssertEqual(quality, .excellent)
    }

    func testDeriveQualityExpensiveCellularIsGood() {
        let quality = NetworkMonitor.deriveQuality(
            connected: true,
            isConstrained: false,
            isExpensive: true,
            interfaceType: .cellular
        )
        XCTAssertEqual(quality, .good)
    }
}
