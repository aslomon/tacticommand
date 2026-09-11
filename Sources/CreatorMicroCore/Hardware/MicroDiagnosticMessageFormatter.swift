import Foundation

public enum MicroDiagnosticMessageFormatter {
    public static func message(for error: Error) -> String {
        if error is DecodingError {
            return "The device sent an unreadable message. It was ignored; control remains active."
        }
        if let described = error as? LocalizedError,
            let description = described.errorDescription
        {
            return description
        }
        return "The device sent an unexpected message. It was ignored; control remains active."
    }
}
