import Foundation

public protocol SDKLoggerProtocol {
    func verbose(message: @escaping () -> String, file: String, function: String, line: Int)
    func debug(message: @escaping () -> String, file: String, function: String, line: Int)
    func info(message: @escaping () -> String, file: String, function: String, line: Int)
    func warning(message: @escaping () -> String, file: String, function: String, line: Int)
    func error(message: @escaping () -> String, file: String, function: String, line: Int)
}

public extension SDKLoggerProtocol {
    func verbose(_ message: @escaping @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        verbose(message: message, file: file, function: function, line: line)
    }

    func debug(_ message: @escaping @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message: message, file: file, function: function, line: line)
    }

    func info(_ message: @escaping @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message: message, file: file, function: function, line: line)
    }

    func warning(_ message: @escaping @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        warning(message: message, file: file, function: function, line: line)
    }

    func error(_ message: @escaping @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message: message, file: file, function: function, line: line)
    }
}
