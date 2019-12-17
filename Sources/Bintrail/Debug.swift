import Foundation

internal func bt_log_internal(_ item: @autoclosure () -> Any, prefix: StaticString = "[BINTRAIL INTERNAL]") {
    guard Bintrail.isDebugModeEnabled && Sysctl.isDebuggerAttached == true else {
        return
    }

    print(String(describing: prefix) + String(describing: item()))
}
