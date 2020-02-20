import Dispatch
import Foundation

public final class Session {
    private lazy var dispatchQueue = DispatchQueue(label: "com.bintrail.session(\(localIdentifier.uuidString))")

    private var entries = Queue<Entry>()

    internal let localIdentifier: UUID

    internal let fileManager: FileManager

    internal init(fileManager: FileManager) {
        localIdentifier = UUID()

        self.fileManager = fileManager
    }

    fileprivate init(localIdentifier: UUID, fileManager: FileManager) {
        self.localIdentifier = localIdentifier
        self.fileManager = fileManager
    }

    internal func add(_ entry: Entry) {
        dispatchQueue.async {
            // Enqueue new entry
            self.entries.enqueue(entry)

            if self.entries.count > 100 {
                try? self.writeEnqueuedEntriesToFile()
            }
        }
    }

    func writeEnqueuedEntriesToFile() throws {
        // Dequeue entries
        let dequeuedEntries = self.entries.dequeueAll()

        do {
            // Try to write entries to file
            try self.writeEntriesToFile(dequeuedEntries)
        } catch {
            // If fails, put them back into the queue
            self.entries.enqueue(dequeuedEntries)
            throw error
        }
    }
}

extension Session: Equatable {
    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.localIdentifier == rhs.localIdentifier
    }
}

internal extension Session {
    struct Metadata: Codable {
        let startedAt: Date

        let device: Device

        let executable: Executable

        private(set) var remoteIdentifier: String?

        func withRemoteIdentifier(_ identifier: String) -> Metadata {
            var new = self
            new.remoteIdentifier = identifier
            return new
        }
    }
}

internal extension Session {
    enum EntryType: String, Codable {
        case log
        case event
    }

    enum Entry {
        case log(Log)
        case event(Event)

        var recordType: EntryType {
            switch self {
            case .log: return .log
            case .event: return .event
            }
        }

        var timestamp: Date {
            switch self {
            case .log(let value):
                return value.timestamp
            case .event(let value):
                return value.timestamp
            }
        }
    }
}

extension Session.Entry: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let type = try container.decode(Session.EntryType.self, forKey: .type)

        switch type {
        case .log:
            self = .log(try container.decode((Log.self), forKey: .value))
        case .event:
            self = .event(try container.decode(Event.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(recordType, forKey: .type)

        switch self {
        case .log(let value):
            try container.encode(value, forKey: .value)
        case .event(let value):
            try container.encode(value, forKey: .value)
        }
    }
}

internal extension Session {
    enum FileError: Error {
        case failedToObtainDirectoryURL

        case failedToObtainMetadataFileURL
        case failedToWriteMetadata

        case failedToObtainEntriesFileURL

        case failedToEncodeString
    }
}

private extension Session {
    static func sessionsDirectoryUrl(using fileManager: FileManager) -> URL? {
        return fileManager.bintrailDirectoryUrl?.appendingPathComponent("sessions")
    }

    var directoryUrl: URL? {
        Session.sessionsDirectoryUrl(using: fileManager)?.appendingPathComponent(localIdentifier.uuidString)
    }
}

// MARK: Loading

internal extension Session {
    static func loadSaved(using fileManager: FileManager) throws -> [Session] {
        guard let sessionsDirectoryUrl = sessionsDirectoryUrl(using: fileManager) else {
            return []
        }

        var result: [Session] = []

        for directoryName in try fileManager.contentsOfDirectory(atPath: sessionsDirectoryUrl.path) {
            guard let localIdentifier = UUID(uuidString: directoryName) else {
                bt_log_internal("Skipping directory named \(directoryName). Not a valid UUID")
                continue
            }

            result.append(Session(localIdentifier: localIdentifier, fileManager: fileManager))
        }

        return result
    }

    func deleteSavedData() throws {
        guard let directoryUrl = directoryUrl else {
            return
        }

        bt_log_internal("Deleting saved data for \(localIdentifier)")

        try fileManager.removeItem(at: directoryUrl)
    }
}

// MARK: Metadata

internal extension Session {
    var metadataFileUrl: URL? {
        return directoryUrl?.appendingPathComponent("metadata.json")
    }

    func loadMetadata() throws -> Metadata? {
        guard let fileUrl = metadataFileUrl else {
            return nil
        }

        guard fileManager.fileExists(atPath: fileUrl.path) else {
            return nil
        }

        return try JSONDecoder.bintrailDefault.decode(Metadata.self, from: Data(contentsOf: fileUrl))
    }

    func saveMetadata(metadata: Metadata) throws {
        guard let directoryUrl = directoryUrl else {
            throw FileError.failedToObtainDirectoryURL
        }

        try fileManager.createDirectoryIfNeeded(at: directoryUrl, withIntermediateDirectories: true)

        guard let metadataFileUrl = metadataFileUrl else {
            throw FileError.failedToObtainMetadataFileURL
        }

        if fileManager.fileExists(atPath: metadataFileUrl.path) {
            try fileManager.removeItem(at: metadataFileUrl)
        }

        guard fileManager.createFile(
            atPath: metadataFileUrl.path,
            contents: try JSONEncoder.bintrailDefault.encode(metadata),
            attributes: nil
            ) else {
                throw FileError.failedToWriteMetadata
        }
    }
}

// MARK: Entries

private extension Session {
    var entriesFileUrl: URL? {
        return directoryUrl?.appendingPathComponent("entries.json")
    }

    func writeEntriesToFile<T>(_ entries: T) throws where T: Collection, T.Element == Entry {
        guard entries.isEmpty == false else {
            return
        }

        guard let directoryUrl = directoryUrl else {
            throw FileError.failedToObtainDirectoryURL
        }

        guard let entriesFileUrl = entriesFileUrl else {
            throw FileError.failedToObtainEntriesFileURL
        }

        try fileManager.createDirectoryIfNeeded(at: directoryUrl, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: entriesFileUrl.path) {
            bt_log_internal("Creating entry file at \(entriesFileUrl.relativePath)")
            fileManager.createFile(atPath: entriesFileUrl.path, contents: Data(), attributes: nil)
        }

        let fileHandle = try FileHandle(forWritingTo: entriesFileUrl)
        fileHandle.seekToEndOfFile()

        let jsonEncoder = JSONEncoder.bintrailDefault
        jsonEncoder.outputFormatting.remove(.prettyPrinted)

        guard let newLine = "\n".data(using: .utf8) else {
            throw FileError.failedToEncodeString
        }

        var entriesWritten: Int = 0

        for entry in entries {
            do {
                try fileHandle.write(jsonEncoder.encode(entry))
                entriesWritten += 1
            } catch {
                bt_log_internal("Failed to encode entry")
            }
            fileHandle.write(newLine)
        }

        fileHandle.closeFile()

        bt_log_internal("Wrote \(entriesWritten)/\(entries.count) entries to entry file of session \(localIdentifier)")

        let entryFileAttributes = try fileManager.attributesOfItem(atPath: entriesFileUrl.path)

        if let fileSize = entryFileAttributes[.size] as? UInt, fileSize >= 1_024 * 1_014 {
            bt_log_internal("Entry file for session (\(localIdentifier)) its size limit. Moving.")
            try moveEntriesFileToOutfilesDirectory()
        }
    }
}

// MARK: Entries out files

private extension Session {
    func moveEntriesFileToOutfilesDirectory() throws {
        guard let entriesFileUrl = entriesFileUrl else {
            return
        }

        if !fileManager.fileExists(atPath: entriesFileUrl.path) {
            return
        }

        guard let directoryUrl = entryOutfilesDirectoryUrl else {
            return
        }

        try fileManager.createDirectoryIfNeeded(at: directoryUrl, withIntermediateDirectories: true)

        let destinationFileName = UUID().uuidString + ".json"

        let destinationFileUrl = directoryUrl.appendingPathComponent(destinationFileName)

        try fileManager.moveItem(
            at: entriesFileUrl,
            to: destinationFileUrl
        )

        bt_log_internal("Moved entries file to outfile named \(destinationFileName) for session (\(localIdentifier))")
    }

    var entryOutfilesDirectoryUrl: URL? {
        return directoryUrl?.appendingPathComponent("out").appendingPathComponent("entries")
    }

    func listEntryOutfiles() throws -> [URL] {
        guard let directoryUrl = entryOutfilesDirectoryUrl else {
            return []
        }

        try fileManager.createDirectoryIfNeeded(at: directoryUrl, withIntermediateDirectories: true)

        return try fileManager.contentsOfDirectory(atPath: directoryUrl.path).map { path in
            directoryUrl.appendingPathComponent(path)
        }.sorted { lhs, rhs in
            lhs.path < rhs.path
        }
    }
}

internal enum SessionSendError: Error {
    case metadataMissing
    case underlying(Error)
}

internal extension Session {
    private static func loadEntriesFromFile(at fileUrl: URL) throws -> [Entry] {
        let jsonLines = try String(contentsOf: fileUrl, encoding: .utf8).split { character in
            character.isNewline
        }

        var entries: [Entry] = []

        for jsonLine in jsonLines {
            do {
                entries.append(
                    try JSONDecoder.bintrailDefault.decode(
                        Entry.self,
                        from: Data(Array(jsonLine.utf8))
                    )
                )
            } catch {
                bt_log_internal("Failed to parse json line: \(jsonLine). Error: \(error)")
                continue
            }
        }

        return entries
    }

    func send(using client: Client, completion: @escaping (SessionSendError?) -> Void) {
        dispatchQueue.async {
            func postNotification(name: Notification.Name, userInfo: [String: Any]? = nil) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: name, object: self, userInfo: userInfo)
                }
            }

            do {
                guard let metadata = try self.loadMetadata() else {
                    throw SessionSendError.metadataMissing
                }

                guard let remoteIdentifier = metadata.remoteIdentifier else {
                    bt_log_internal("Session \(self.localIdentifier) lacks remote identifier. Uploading metadata...")
                    client.upload(sessionMetadata: metadata) { result in
                        self.dispatchQueue.async {
                            do {
                                try self.saveMetadata(
                                    metadata: metadata.withRemoteIdentifier(result.get().remoteIdentifier)
                                )
                                postNotification(name: Session.metadataIngestionSuccessNotification)

                                completion(nil)
                            } catch {
                                postNotification(
                                    name: Session.metadataIngestionFailureNotification,
                                    userInfo: [NSUnderlyingErrorKey: error]
                                )
                                completion(.underlying(error))
                            }
                        }
                    }
                    return
                }

                try self.moveEntriesFileToOutfilesDirectory()

                guard let outFileUrl = try self.listEntryOutfiles().first else {
                    bt_log_internal("Session \(self.localIdentifier) contains no more entry outfiles.")
                    completion(nil)
                    return
                }

                let entries = try Session.loadEntriesFromFile(at: outFileUrl)

                bt_log_internal(
                    "Uploading entries from \(outFileUrl.relativePath) for session (\(self.localIdentifier))"
                )

                client.upload(entries: entries, forSessionWithRemoteIdentifier: remoteIdentifier) { result in
                    self.dispatchQueue.async {
                        do {
                            try result.get()
                            try self.fileManager.removeItem(at: outFileUrl)
                            postNotification(name: Session.entriesIngestionSuccessNotificationName)
                            self.send(using: client, completion: completion)
                        } catch {
                            postNotification(
                                name: Session.entriesIngestionFailureNotificationName,
                                userInfo: [NSUnderlyingErrorKey: error]
                            )
                            completion(.underlying(error))
                        }
                    }
                }
            } catch let error as SessionSendError {
                completion(error)
            } catch {
                completion(.underlying(error))
            }
        }
    }
}

public extension Session {
    static let metadataIngestionSuccessNotification = Notification.Name(
        rawValue: "BintrailSessionMetadataIngestionSuccess"
    )

    static let metadataIngestionFailureNotification = Notification.Name(
        rawValue: "BintrailSessionMetadataIngestionFailure"
    )

    static let entriesIngestionSuccessNotificationName = Notification.Name(
        rawValue: "BintrailSessionEntriesIngestionSuccess"
    )

    static let entriesIngestionFailureNotificationName = Notification.Name(
        rawValue: "BintrailSessionEntriesIngestionFailure"
    )
}
