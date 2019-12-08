import Foundation

internal extension JSONEncoder {
    static var bintrailDefault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        #if DEBUG
            encoder.outputFormatting = [.prettyPrinted]
        #endif

        if #available(iOS 11, macOS 10.13, watchOS 4.0, tvOS 11.0, *) {
            encoder.outputFormatting.insert(.sortedKeys)
        }

        return encoder
    }
}
