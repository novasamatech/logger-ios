import Testing
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

/// Mock conformer that either evaluates the forwarded message closure or leaves
/// it untouched, and records what it received. This is the whole point of the
/// suite: the protocol requirement hands us a `() -> String` we may choose never
/// to call. The closure is non-escaping, so an emitting conformer must evaluate
/// it synchronously within the call.
private final class MockLogger: SDKLoggerProtocol {
    enum Level: CaseIterable { case verbose, debug, info, warning, error }

    let evaluatesMessage: Bool
    private(set) var evaluatedMessages: [String] = []
    private(set) var capturedLevels: [Level] = []
    private(set) var capturedFiles: [String] = []
    private(set) var capturedLines: [Int] = []

    init(evaluatesMessage: Bool) {
        self.evaluatesMessage = evaluatesMessage
    }

    private func record(_ level: Level, _ message: () -> String, _ file: String, _ line: Int) {
        capturedLevels.append(level)
        capturedFiles.append(file)
        capturedLines.append(line)
        if evaluatesMessage {
            evaluatedMessages.append(message())
        }
        // When not emitting, the closure is deliberately never invoked.
    }

    func verbose(message: () -> String, file: String, function: String, line: Int) {
        record(.verbose, message, file, line)
    }

    func debug(message: () -> String, file: String, function: String, line: Int) {
        record(.debug, message, file, line)
    }

    func info(message: () -> String, file: String, function: String, line: Int) {
        record(.info, message, file, line)
    }

    func warning(message: () -> String, file: String, function: String, line: Int) {
        record(.warning, message, file, line)
    }

    func error(message: () -> String, file: String, function: String, line: Int) {
        record(.error, message, file, line)
    }
}

/// Routes a lazily-supplied message through the *convenience* call site for the
/// given level. Crucially, `message()` here is itself wrapped by the convenience
/// method's `@autoclosure`, so nothing is evaluated at this hop — laziness is
/// preserved end-to-end.
private func callConvenience(_ logger: SDKLoggerProtocol,
                             level: MockLogger.Level,
                             message: @autoclosure () -> String) {
    switch level {
    case .verbose: logger.verbose(message())
    case .debug: logger.debug(message())
    case .info: logger.info(message())
    case .warning: logger.warning(message())
    case .error: logger.error(message())
    }
}

@Suite struct SDKLoggerTests {

    /// Deferral: a conformer that never invokes the closure must never run the
    /// message's side effect. Covers all five methods.
    @Test func messageIsNotEvaluatedWhenConformerDefers() {
        for level in MockLogger.Level.allCases {
            let logger = MockLogger(evaluatesMessage: false)
            let counter = EvaluationCounter()

            callConvenience(logger, level: level, message: counter.make("deferred-\(level)"))

            #expect(counter.count == 0, "\(level): message must not be evaluated when the conformer defers")
            #expect(logger.evaluatedMessages.isEmpty)
            #expect(logger.capturedLevels == [level])
        }
    }

    /// Evaluation: a conformer that invokes the closure runs the side effect
    /// exactly once and receives the correct string. Covers all five methods.
    @Test func messageIsEvaluatedOnceWhenConformerEmits() {
        for level in MockLogger.Level.allCases {
            let logger = MockLogger(evaluatesMessage: true)
            let counter = EvaluationCounter()

            callConvenience(logger, level: level, message: counter.make("emitted-\(level)"))

            #expect(counter.count == 1, "\(level): emitting conformer must evaluate the message exactly once")
            #expect(logger.evaluatedMessages == ["emitted-\(level)"])
            #expect(logger.capturedLevels == [level])
        }
    }

    /// Ergonomics / source-compatibility: plain literals and interpolations
    /// compile and pass through the real call sites unchanged, and default
    /// `#file`/`#line` metadata is populated.
    @Test func stringLiteralsAndInterpolationAreSourceCompatible() {
        let logger = MockLogger(evaluatesMessage: true)
        let value = 42

        logger.debug("plain literal")
        logger.info("x=\(value)")

        #expect(logger.evaluatedMessages == ["plain literal", "x=42"])
        #expect(logger.capturedLevels == [.debug, .info])
        #expect(!logger.capturedFiles.contains(where: { $0.isEmpty }), "default #file should be captured")
    }
}
