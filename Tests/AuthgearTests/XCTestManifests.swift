import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    [testCase(AuthgearTests.allTests)]
}
#endif
