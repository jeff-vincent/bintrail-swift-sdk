import Foundation

public enum LogType: String, Codable, CaseIterable {
    case trace
    case debug
    case info
    case warning
    case error
    case fatal

    internal var intValue: Int {
        switch self {
        case .trace:
            return 1
        case .debug:
            return 2
        case .info:
            return 3
        case .warning:
            return 4
        case .error:
            return 5
        case .fatal:
            return 6
        }
    }
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
    #if DEBUG
    let message = items.map { item in
        String(describing: item)
    }.joined(separator: terminator)

    print("bt_log [\(type.rawValue.uppercased())]", message)
    #endif

    let log = Log(
        level: type,
        message: items.map({ String(describing: $0) }).joined(separator: terminator),
        line: line,
        column: column,
        function: String(describing: function),
        file: String(describing: file),
        timestamp: Date()
    )

    Bintrail.shared.currentSession.add(.log(log))
}
