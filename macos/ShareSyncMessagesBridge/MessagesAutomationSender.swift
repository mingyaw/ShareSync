import Foundation

final class MessagesAutomationSender: IMessageReplySending {
    enum AutomationError: Error, Equatable {
        case launchFailed
        case permissionDenied
        case recipientUnavailable
        case sendFailed(Int32)
        case timedOut

        var isDefinitiveFailure: Bool {
            switch self {
            case .launchFailed, .permissionDenied, .recipientUnavailable: return true
            case .sendFailed, .timedOut: return false
            }
        }
    }

    private static let script = """
    on run argv
        set targetHandle to item 1 of argv
        set messageBody to item 2 of argv
        tell application "Messages"
            set targetAccount to first account whose service type is iMessage
            set targetParticipant to participant targetHandle of targetAccount
            send messageBody to targetParticipant
        end tell
    end run
    """

    private let timeout: TimeInterval

    init(timeout: TimeInterval = 15) {
        self.timeout = max(timeout, 1)
    }

    func send(text: String, to recipientHandle: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", Self.script, recipientHandle, text]
        process.standardOutput = FileHandle.nullDevice
        let errorPipe = Pipe()
        process.standardError = errorPipe
        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }
        do {
            try process.run()
        } catch {
            throw AutomationError.launchFailed
        }
        guard completion.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            throw AutomationError.timedOut
        }
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            if errorOutput.contains("(-1743)") {
                throw AutomationError.permissionDenied
            }
            if errorOutput.contains("(-1728)") {
                throw AutomationError.recipientUnavailable
            }
            throw AutomationError.sendFailed(process.terminationStatus)
        }
    }
}

extension MessagesAutomationSender.AutomationError: IMessageReplySendFailure {}
