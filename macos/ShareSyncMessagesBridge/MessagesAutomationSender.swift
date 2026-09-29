import Foundation

final class MessagesAutomationSender: IMessageReplySending {
    enum AutomationError: Error, Equatable {
        case launchFailed
        case permissionDenied
        case recipientUnavailable
        case sendFailed(Int32)
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

    func send(text: String, to recipientHandle: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", Self.script, recipientHandle, text]
        process.standardOutput = Pipe()
        let errorPipe = Pipe()
        process.standardError = errorPipe
        do {
            try process.run()
        } catch {
            throw AutomationError.launchFailed
        }
        process.waitUntilExit()
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
