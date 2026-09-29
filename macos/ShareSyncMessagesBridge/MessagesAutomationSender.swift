import Foundation

final class MessagesAutomationSender: IMessageReplySending {
    enum AutomationError: Error {
        case launchFailed
        case sendFailed(Int32)
    }

    private static let script = """
    on run argv
        set targetHandle to item 1 of argv
        set messageBody to item 2 of argv
        tell application "Messages"
            set targetAccount to first account whose service type is iMessage
            set targetParticipant to first participant of targetAccount whose handle is targetHandle
            send messageBody to targetParticipant
        end tell
    end run
    """

    func send(text: String, to recipientHandle: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", Self.script, recipientHandle, text]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            throw AutomationError.launchFailed
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AutomationError.sendFailed(process.terminationStatus)
        }
    }
}
