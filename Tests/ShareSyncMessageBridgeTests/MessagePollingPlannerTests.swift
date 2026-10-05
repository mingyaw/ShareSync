import XCTest
@testable import ShareSyncMessageBridge

final class MessagePollingPlannerTests: XCTestCase {
    func testPlannerPollsImmediatelyWhileAFullBatchMayHaveMoreWork() {
        var planner = MessagePollingPlanner()

        XCTAssertEqual(planner.nextDelay(after: .workRemaining), 0)
        XCTAssertEqual(planner.nextDelay(after: .idle), 5)
    }

    func testFailureBackoffIsBoundedAndSuccessResetsIt() {
        var planner = MessagePollingPlanner(configuration: MessagePollingConfiguration(
            idleInterval: 10,
            initialFailureDelay: 2,
            maximumFailureDelay: 8
        ))

        XCTAssertEqual(planner.nextDelay(after: .failed), 2)
        XCTAssertEqual(planner.nextDelay(after: .failed), 4)
        XCTAssertEqual(planner.nextDelay(after: .failed), 8)
        XCTAssertEqual(planner.nextDelay(after: .failed), 8)
        XCTAssertEqual(planner.nextDelay(after: .idle), 10)
        XCTAssertEqual(planner.consecutiveFailureCount, 0)
    }

    func testRateLimitUsesServerDelayWithoutIncreasingFailureBackoff() {
        var planner = MessagePollingPlanner(configuration: MessagePollingConfiguration(
            maximumFailureDelay: 60
        ))

        XCTAssertEqual(planner.nextDelay(after: .rateLimited(retryAfter: 12)), 12)
        XCTAssertEqual(planner.consecutiveFailureCount, 0)
        XCTAssertEqual(planner.nextDelay(after: .rateLimited(retryAfter: 600)), 60)
    }

    func testWakeOrNetworkRecoveryRequestsImmediatePollAndResetsBackoff() {
        var planner = MessagePollingPlanner()
        _ = planner.nextDelay(after: .failed)

        XCTAssertEqual(planner.recoveryDelay(), 0)
        XCTAssertEqual(planner.consecutiveFailureCount, 0)
    }

    func testOutcomeMapperUsesBatchLimitAndPreservesRateLimitDelay() {
        let mapper = MessagePollingOutcomeMapper(batchLimit: 2)
        let full = MessageForwardingRunResult(
            inspectedCount: 2,
            eligibleCount: 0,
            deliveredCount: 0,
            duplicateCount: 0,
            deniedCounts: [:],
            nextCursor: MessageCursor(rowID: 2)
        )
        let partial = MessageForwardingRunResult(
            inspectedCount: 1,
            eligibleCount: 0,
            deliveredCount: 0,
            duplicateCount: 0,
            deniedCounts: [:],
            nextCursor: MessageCursor(rowID: 3)
        )

        XCTAssertEqual(mapper.outcome(result: full), .workRemaining)
        XCTAssertEqual(mapper.outcome(result: partial), .idle)
        XCTAssertEqual(
            mapper.outcome(error: MessageForwardingPipelineError.rateLimited(retryAfter: 9)),
            .rateLimited(retryAfter: 9)
        )
        XCTAssertEqual(
            mapper.outcome(error: TelegramBotConnectorError.rateLimited(retryAfter: 14)),
            .rateLimited(retryAfter: 14)
        )
    }

    func testReplyOutcomeMapperContinuesFullAndUnconfirmedBatches() {
        let mapper = TelegramReplyPollingOutcomeMapper(batchLimit: 2)
        let full = TelegramReplyRunResult(
            inspectedCount: 2,
            sentCount: 0,
            ignoredCount: 2,
            unconfirmedCount: 0
        )
        let partial = TelegramReplyRunResult(
            inspectedCount: 1,
            sentCount: 0,
            ignoredCount: 1,
            unconfirmedCount: 0
        )

        XCTAssertEqual(mapper.outcome(result: full), .workRemaining)
        XCTAssertEqual(mapper.outcome(result: partial), .idle)
        XCTAssertEqual(
            mapper.outcome(error: IMessageReplyDeliveryError.deliveryUnconfirmed),
            .workRemaining
        )
        XCTAssertEqual(
            mapper.outcome(error: TelegramBotConnectorError.rateLimited(retryAfter: 20)),
            .rateLimited(retryAfter: 20)
        )
    }
}
