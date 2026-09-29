import XCTest
@testable import ShareSyncMessageBridge

final class MessageForwardingRuntimeGateTests: XCTestCase {
    func testDaytimeScheduleIncludesOnlyConfiguredWindow() throws {
        let schedule = MessageForwardingSchedule(
            weekdays: [2],
            startMinute: 9 * 60,
            endMinute: 17 * 60,
            timeZoneIdentifier: "Asia/Taipei"
        )

        XCTAssertTrue(schedule.contains(try date("2026-09-28T10:00:00+08:00")))
        XCTAssertFalse(schedule.contains(try date("2026-09-28T18:00:00+08:00")))
        XCTAssertFalse(schedule.contains(try date("2026-09-29T10:00:00+08:00")))
    }

    func testOvernightScheduleUsesStartingWeekday() throws {
        let schedule = MessageForwardingSchedule(
            weekdays: [2],
            startMinute: 22 * 60,
            endMinute: 6 * 60,
            timeZoneIdentifier: "Asia/Taipei"
        )

        XCTAssertTrue(schedule.contains(try date("2026-09-28T23:00:00+08:00")))
        XCTAssertTrue(schedule.contains(try date("2026-09-29T05:59:00+08:00")))
        XCTAssertFalse(schedule.contains(try date("2026-09-29T06:00:00+08:00")))
    }

    func testPausedGateTakesPriority() throws {
        let gate = MessageForwardingRuntimeGate(isPaused: true)

        XCTAssertThrowsError(try gate.validate(at: Date())) { error in
            XCTAssertEqual(error as? MessageForwardingRuntimeBlock, .paused)
        }
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }
}
