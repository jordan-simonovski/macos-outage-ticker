import Foundation

// ponytail: 40 lines of asserts instead of XCTest, which needs Xcode. Swap back
// to a .testTarget with XCTest the day this repo builds on a machine that has it.
enum Check {
    static var failures: [String] = []
    static var checks = 0

    static func isTrue(_ condition: Bool, _ message: @autoclosure () -> String = "",
                       file: String = #filePath, line: Int = #line) {
        checks += 1
        guard !condition else { return }
        let detail = message()
        failures.append("\(file):\(line): expected true\(detail.isEmpty ? "" : " — \(detail)")")
    }

    static func isFalse(_ condition: Bool, _ message: @autoclosure () -> String = "",
                        file: String = #filePath, line: Int = #line) {
        isTrue(!condition, message(), file: file, line: line)
    }

    static func equal<T: Equatable>(_ actual: T, _ expected: T,
                                    _ message: @autoclosure () -> String = "",
                                    file: String = #filePath, line: Int = #line) {
        checks += 1
        guard actual != expected else { return }
        let detail = message()
        failures.append("\(file):\(line): \(actual) != \(expected)\(detail.isEmpty ? "" : " — \(detail)")")
    }

    static func notEqual<T: Equatable>(_ actual: T, _ other: T,
                                       _ message: @autoclosure () -> String = "",
                                       file: String = #filePath, line: Int = #line) {
        checks += 1
        guard actual == other else { return }
        failures.append("\(file):\(line): both were \(actual)\(message().isEmpty ? "" : " — \(message())")")
    }

    static func isNil<T>(_ value: T?, _ message: @autoclosure () -> String = "",
                         file: String = #filePath, line: Int = #line) {
        isTrue(value == nil, message(), file: file, line: line)
    }

    static func notNil<T>(_ value: T?, _ message: @autoclosure () -> String = "",
                          file: String = #filePath, line: Int = #line) {
        isTrue(value != nil, message(), file: file, line: line)
    }

    static func throwsError(_ body: () throws -> Void,
                            file: String = #filePath, line: Int = #line) {
        checks += 1
        do {
            try body()
            failures.append("\(file):\(line): expected an error, none thrown")
        } catch {}
    }

    static func report() -> Never {
        if failures.isEmpty {
            print("PASS — \(checks) checks")
            exit(0)
        }
        failures.forEach { print("FAIL \($0)") }
        print("\(failures.count) failure(s) of \(checks) checks")
        exit(1)
    }
}
