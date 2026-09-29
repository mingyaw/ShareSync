import Foundation

public enum MessageForwardingRuntimeBlock: Error, Equatable, Sendable {
    case paused
    case outsideSchedule
}

public struct MessageForwardingSchedule: Equatable, Sendable {
    public let weekdays: Set<Int>
    public let startMinute: Int
    public let endMinute: Int
    public let timeZoneIdentifier: String

    public init(
        weekdays: Set<Int>,
        startMinute: Int,
        endMinute: Int,
        timeZoneIdentifier: String
    ) {
        self.weekdays = weekdays.filter { (1...7).contains($0) }
        self.startMinute = min(max(startMinute, 0), 1_439)
        self.endMinute = min(max(endMinute, 0), 1_439)
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public func contains(_ date: Date) -> Bool {
        guard !weekdays.isEmpty,
              let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return false
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute else {
            return false
        }
        let minuteOfDay = hour * 60 + minute

        if startMinute == endMinute {
            return weekdays.contains(weekday)
        }
        if startMinute < endMinute {
            return weekdays.contains(weekday)
                && (startMinute..<endMinute).contains(minuteOfDay)
        }
        if minuteOfDay >= startMinute {
            return weekdays.contains(weekday)
        }
        let previousWeekday = weekday == 1 ? 7 : weekday - 1
        return minuteOfDay < endMinute && weekdays.contains(previousWeekday)
    }
}

public struct MessageForwardingRuntimeGate: Equatable, Sendable {
    public let isPaused: Bool
    public let schedule: MessageForwardingSchedule?

    public init(isPaused: Bool = false, schedule: MessageForwardingSchedule? = nil) {
        self.isPaused = isPaused
        self.schedule = schedule
    }

    public func validate(at date: Date) throws {
        if isPaused { throw MessageForwardingRuntimeBlock.paused }
        if let schedule, !schedule.contains(date) {
            throw MessageForwardingRuntimeBlock.outsideSchedule
        }
    }
}

public enum MessageRateLimitDecision: Equatable, Sendable {
    case allowed
    case limited(retryAfter: TimeInterval)
}

public final class MessageDeliveryRateLimiter {
    private let maximumDeliveries: Int
    private let interval: TimeInterval
    private var reservations: [Date] = []
    private let lock = NSLock()

    public init(maximumDeliveries: Int, interval: TimeInterval) {
        self.maximumDeliveries = max(maximumDeliveries, 1)
        self.interval = max(interval, 1)
    }

    public func reserve(at date: Date) -> MessageRateLimitDecision {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = date.addingTimeInterval(-interval)
        reservations.removeAll { $0 <= cutoff }
        guard reservations.count >= maximumDeliveries else {
            reservations.append(date)
            return .allowed
        }
        let retryAfter = max((reservations[0].addingTimeInterval(interval)).timeIntervalSince(date), 0)
        return .limited(retryAfter: retryAfter)
    }
}
