@testable import SwiftGooglePlaceSearch
import XCTest

final class SwiftGooglePlaceSearchTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(SwiftGooglePlaceSearch(googleAPIKey: "").googleAPIKey, "")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
