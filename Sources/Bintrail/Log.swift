import Foundation

public enum LogType: String, Codable, CaseIterable, Comparable {
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

    public static func < (lhs: LogType, rhs: LogType) -> Bool {
        return lhs.intValue < rhs.intValue
    }
}

extension LogType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .trace:
            return "TRACE"
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warning:
            return "WARN"
        case .error:
            return "ERROR"
        case .fatal:
            return "FATAL"
        }
    }
}

public enum LogFilter {
    case all
    case select(Set<LogType>)
    case severityFrom(LogType)

    public func contains(logType: LogType) -> Bool {
        switch self {
        case .all: return true
        case .severityFrom(let from): return logType >= from
        case .select(let set): return set.contains(logType)
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

extension Log: CustomDebugStringConvertible {
    private static var debugDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y-MM-dd H:m:ss.SSSS"
        return dateFormatter
    }()

    var debugDescription: String {
        String(
            format: "[%@]\t%@ - %@",
            String(describing: level),
            Log.debugDateFormatter.string(from: timestamp),
            message
        )
    }
}

extension Log: Equatable {
    public static func == (lhs: Log, rhs: Log) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

extension Log: Codable {}

public func bt_log(
    _ item: @autoclosure () -> Any,
    _ type: LogType = .info,
    file: StaticString = #file,
    function: StaticString = #function,
    line: Int = #line,
    column: Int = #column,
    instance: Bintrail = .shared
) {
    guard instance.logFilter.contains(logType: type) else {
        return
    }

    let log = Log(
        level: type,
        message: String(describing: item()),
        line: line,
        column: column,
        function: String(describing: function),
        file: String(describing: file),
        timestamp: Date()
    )

    if Sysctl.isDebuggerAttached == true {
        debugPrint(log)
    }

    instance.currentSession.add(.log(log))
}
