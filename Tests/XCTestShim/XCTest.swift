@_exported import Foundation

open class XCTestCase {
    public init() {}
}

public enum XCTestRegistry {
    public static var checks = 0
    public static var failures: [String] = []
    public static func record(_ message: String, _ file: StaticString, _ line: UInt) {
        failures.append("\(file):\(line) \(message)")
    }
}

public func XCTFail(_ message: String = "", file: StaticString = #file, line: UInt = #line) {
    XCTestRegistry.checks += 1
    XCTestRegistry.record("XCTFail: \(message)", file, line)
}

public func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool, _ message: String = "",
                          file: StaticString = #file, line: UInt = #line) {
    XCTestRegistry.checks += 1
    do { if try !expression() { XCTestRegistry.record("XCTAssertTrue failed. \(message)", file, line) } }
    catch { XCTestRegistry.record("threw \(error). \(message)", file, line) }
}

public func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool, _ message: String = "",
                           file: StaticString = #file, line: UInt = #line) {
    XCTestRegistry.checks += 1
    do { if try expression() { XCTestRegistry.record("XCTAssertFalse failed. \(message)", file, line) } }
    catch { XCTestRegistry.record("threw \(error). \(message)", file, line) }
}

public func XCTAssertNil(_ expression: @autoclosure () throws -> Any?, _ message: String = "",
                         file: StaticString = #file, line: UInt = #line) {
    XCTestRegistry.checks += 1
    do { if let v = try expression() { XCTestRegistry.record("XCTAssertNil: got \(v). \(message)", file, line) } }
    catch { XCTestRegistry.record("threw \(error). \(message)", file, line) }
}

public func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T,
                                         _ b: @autoclosure () throws -> T, _ message: String = "",
                                         file: StaticString = #file, line: UInt = #line) {
    XCTestRegistry.checks += 1
    do { let av = try a(); let bv = try b()
         if av != bv { XCTestRegistry.record("XCTAssertEqual: \(av) != \(bv). \(message)", file, line) } }
    catch { XCTestRegistry.record("threw \(error). \(message)", file, line) }
}

public func XCTAssertEqual<T: FloatingPoint>(_ a: @autoclosure () throws -> T,
                                             _ b: @autoclosure () throws -> T, accuracy: T,
                                             _ message: String = "",
                                             file: StaticString = #file, line: UInt = #line) {
    XCTestRegistry.checks += 1
    do { let av = try a(); let bv = try b()
         if abs(av - bv) > accuracy {
             XCTestRegistry.record("XCTAssertEqual(acc): \(av) != \(bv). \(message)", file, line) } }
    catch { XCTestRegistry.record("threw \(error). \(message)", file, line) }
}
