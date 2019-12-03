import Foundation

internal extension JSONEncoder {
    static var bintrailDefault: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        #if DEBUG
            encoder.outputFormatting = [.prettyPrinted]
        #endif

        if #available(iOS 11, *) {
            encoder.outputFormatting.insert(.sortedKeys)
        }

        return encoder
    }
}
