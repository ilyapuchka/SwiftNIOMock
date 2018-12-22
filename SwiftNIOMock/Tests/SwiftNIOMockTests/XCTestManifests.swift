import XCTest

extension SwiftNIOMockTests {
    static let __allTests = [
        ("testCanRedirectRequestAndInterceptResponse", testCanRedirectRequestAndInterceptResponse),
        ("testCanRestartServer", testCanRestartServer),
        ("testCanReturnDefaultResponse", testCanReturnDefaultResponse),
        ("testCanRunTwoServersOnDifferentPorts", testCanRunTwoServersOnDifferentPorts),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SwiftNIOMockTests.__allTests),
    ]
}
#endif
