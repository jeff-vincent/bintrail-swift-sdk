import Foundation

public enum LogType: String, Codable {
    case debug
    case info
    case warning
    case error
    case fatal
}

internal struct Log {

    private let identifier = UUID()

    let level: LogType

    let message: String

    let line: Int

    let column: Int

    let function: String

    let file: String

    let timestamp: Date
}

extension Log: Equatable {
    public static func == (lhs: Log, rhs: Log) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

extension Log: Codable {}

public func bt_log(
    _ items: Any...,
    type: LogType,
    terminator: String = " ",
    file: StaticString = #file,
    function: StaticString = #function,
    line: Int = #line,
    column: Int = #column
) {
    Bintrail.shared.currentSession.log(
        items,
        type: type,
        timestamp: Date(),
        file: file,
        function: function,
        line: line,
        column: column
    )
}
