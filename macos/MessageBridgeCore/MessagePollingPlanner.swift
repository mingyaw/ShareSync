import Foundation

public struct MessagePollingConfiguration: Equatable, Sendable {
    public let idleInterval: TimeInterval
    public let initialFailureDelay: TimeInterval
    public let maximumFailureDelay: TimeInterval

    public init(
        idleInterval: TimeInterval = 5,
        initialFailureDelay: TimeInterval = 2,
        maximumFailureDelay: TimeInterval = 300
    ) {
        self.idleInterval = max(idleInterval, 1)
        self.initialFailureDelay = max(initialFailureDelay, 1)
        self.maximumFailureDelay = max(maximumFailureDelay, self.initialFailureDelay)
    }
}

public enum MessagePollingOutcome: Equatable, Sendable {
    case idle
    case workRemaining
    case failed
    case rateLimited(retryAfter: TimeInterval)
}

public struct MessagePollingPlanner: Equatable, Sendable {
    public private(set) var consecutiveFailureCount = 0
    private let configuration: MessagePollingConfiguration

    public init(configuration: MessagePollingConfiguration = MessagePollingConfiguration()) {
        self.configuration = configuration
    }

    public mutating func nextDelay(after outcome: MessagePollingOutcome) -> TimeInterval {
        switch outcome {
        case .idle:
            consecutiveFailureCount = 0
            return configuration.idleInterval
        case .workRemaining:
            consecutiveFailureCount = 0
            return 0
        case .failed:
            consecutiveFailureCount += 1
            let exponent = min(consecutiveFailureCount - 1, 20)
            let delay = configuration.initialFailureDelay * pow(2, Double(exponent))
            return min(delay, configuration.maximumFailureDelay)
        case .rateLimited(let retryAfter):
            return min(max(retryAfter, 1), configuration.maximumFailureDelay)
        }
    }

    public mutating func recoveryDelay() -> TimeInterval {
        consecutiveFailureCount = 0
        return 0
    }
}

public struct MessagePollingOutcomeMapper {
    private let batchLimit: Int

    public init(batchLimit: Int = 100) {
        self.batchLimit = min(max(batchLimit, 1), 500)
    }

    public func outcome(result: MessageForwardingRunResult) -> MessagePollingOutcome {
        result.inspectedCount >= batchLimit ? .workRemaining : .idle
    }

    public func outcome(error: Error) -> MessagePollingOutcome {
        if case MessageForwardingPipelineError.rateLimited(let retryAfter) = error {
            return .rateLimited(retryAfter: retryAfter)
        }
        if case TelegramBotConnectorError.rateLimited(let retryAfter) = error {
            return .rateLimited(retryAfter: retryAfter)
        }
        return .failed
    }
}

public struct TelegramReplyPollingOutcomeMapper {
    private let batchLimit: Int

    public init(batchLimit: Int = 100) {
        self.batchLimit = min(max(batchLimit, 1), 100)
    }

    public func outcome(result: TelegramReplyRunResult) -> MessagePollingOutcome {
        result.inspectedCount >= batchLimit ? .workRemaining : .idle
    }

    public func outcome(error: Error) -> MessagePollingOutcome {
        if error is IMessageReplyDeliveryError {
            return .workRemaining
        }
        return MessagePollingOutcomeMapper(batchLimit: batchLimit).outcome(error: error)
    }
}
