import Foundation

private func bt_print_internal(_ items: [Any], terminator: String, prefix: StaticString) {
    let message = items.map { item in
        String(describing: item)
    }.joined(separator: terminator)

    print(prefix, message)
}

private func bt_log_internal(_ items: @autoclosure () -> [Any], terminator: String, prefix: StaticString) {
    #if DEBUG
    guard Bintrail.isDebugModeEnabled else {
        return
    }
    bt_print_internal(items(), terminator: terminator, prefix: prefix)
    #endif
}

internal func bt_log_internal(_ items: Any..., terminator: String = " ", prefix: StaticString = "[BINTRAIL DEBUG]") {
    bt_log_internal(items, terminator: terminator, prefix: prefix)
}
