import XCTest
@testable import SDKLogger

/// A reference box so an `@autoclosure` message expression can record how many
/// times it was actually evaluated.
private final class EvaluationCounter {
    private(set) var count = 0
    /// Side-effecting expression: bumps the counter and returns `text`.
    func make(_ text: String) -> String {
        count += 1
        return text
    }
}

/// Mock conformer that either evaluates the forwarded message closure or defers
/// it, and records what it received. This is the whole point of the test suite:
/// the protocol requirement hands us a `() -> String` we may choose never to call.
private final class MockLogger: SDKLoggerProtocol {
    enum Level: CaseIterable { case verbose, debug, info, warning, error }

    let evaluatesMessage: Bool
    private(set) var evaluatedMessages: [String] = []
    private(set) var deferredClosures: [() -> String] = []
    private(set) var capturedLevels: [Level] = []
    private(set) var capturedFiles: [String] = []
    private(set) var capturedLines: [Int] = []

    init(evaluatesMessage: Bool) {
        self.evaluatesMessage = evaluatesMessage
    }

    private func record(_ level: Level, _ message: @escaping () -> String, _ file: String, _ line: Int) {
        capturedLevels.append(level)
        capturedFiles.append(file)
        capturedLines.append(line)
        if evaluatesMessage {
            evaluatedMessages.append(message())
        } else {
            deferredClosures.append(message)
        }
    }

    func verbose(message: @escaping () -> String, file: String, function: String, line: Int) {
        record(.verbose, message, file, line)
    }

    func debug(message: @escaping () -> String, file: String, function: String, line: Int) {
        record(.debug, message, file, line)
    }

    func info(message: @escaping () -> String, file: String, function: String, line: Int) {
        record(.info, message, file, line)
    }

    func warning(message: @escaping () -> String, file: String, function: String, line: Int) {
        record(.warning, message, file, line)
    }

    func error(message: @escaping () -> String, file: String, function: String, line: Int) {
        record(.error, message, file, line)
    }
}

/// Routes a lazily-supplied message through the *convenience* call site for the
/// given level. Crucially, `message()` here is itself wrapped by the convenience
/// method's `@autoclosure`, so nothing is evaluated at this hop — laziness is
/// preserved end-to-end.
private func callConvenience(_ logger: SDKLoggerProtocol,
                             level: MockLogger.Level,
                             message: @escaping @autoclosure () -> String) {
    switch level {
    case .verbose: logger.verbose(message())
    case .debug: logger.debug(message())
    case .info: logger.info(message())
    case .warning: logger.warning(message())
    case .error: logger.error(message())
    }
}

final class SDKLoggerTests: XCTestCase {

    /// Deferral: a conformer that never invokes the closure must never run the
    /// message's side effect. Invoking the captured closure afterwards runs it
    /// exactly once and yields the correct string. Covers all five methods.
    func testMessageIsNotEvaluatedWhenConformerDefers() {
        for level in MockLogger.Level.allCases {
            let logger = MockLogger(evaluatesMessage: false)
            let counter = EvaluationCounter()

            callConvenience(logger, level: level, message: counter.make("deferred-\(level)"))

            XCTAssertEqual(counter.count, 0, "\(level): message must not be evaluated when the conformer defers")
            XCTAssertEqual(logger.deferredClosures.count, 1, "\(level): closure should have reached the conformer")
            XCTAssertEqual(logger.capturedLevels, [level])

            // Now evaluate on demand, as a real logger would when it decides to emit.
            let produced = logger.deferredClosures[0]()
            XCTAssertEqual(counter.count, 1, "\(level): on-demand evaluation must run the side effect exactly once")
            XCTAssertEqual(produced, "deferred-\(level)")
        }
    }

    /// Evaluation: a conformer that invokes the closure runs the side effect
    /// exactly once and receives the correct string. Covers all five methods.
    func testMessageIsEvaluatedOnceWhenConformerEmits() {
        for level in MockLogger.Level.allCases {
            let logger = MockLogger(evaluatesMessage: true)
            let counter = EvaluationCounter()

            callConvenience(logger, level: level, message: counter.make("emitted-\(level)"))

            XCTAssertEqual(counter.count, 1, "\(level): emitting conformer must evaluate the message exactly once")
            XCTAssertEqual(logger.evaluatedMessages, ["emitted-\(level)"])
            XCTAssertEqual(logger.capturedLevels, [level])
        }
    }

    /// Ergonomics / source-compatibility: plain literals and interpolations
    /// compile and pass through the real call sites unchanged, and default
    /// `#file`/`#line` metadata is populated.
    func testStringLiteralsAndInterpolationAreSourceCompatible() {
        let logger = MockLogger(evaluatesMessage: true)
        let value = 42

        logger.debug("plain literal")
        logger.info("x=\(value)")

        XCTAssertEqual(logger.evaluatedMessages, ["plain literal", "x=42"])
        XCTAssertEqual(logger.capturedLevels, [.debug, .info])
        XCTAssertFalse(logger.capturedFiles.contains(where: { $0.isEmpty }), "default #file should be captured")
    }
}
