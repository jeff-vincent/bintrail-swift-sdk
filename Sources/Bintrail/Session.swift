public final class Session {

    internal struct Metadata: Codable {

        internal let startedAt: Date

        internal let device: Device?

        internal let executable: Executable?

        internal private(set) var remoteIdentifier: String?

        internal func withRemoteIdentifier(_ identifier: String) -> Metadata {
            var new = self
            new.remoteIdentifier = identifier
            return new
        }
    }

    private lazy var dispatchQueue = DispatchQueue(label: "com.bintrail.session(\(localIdentifier.uuidString))")

    private var entries = Queue<SessionEntry>()

    private var dequeueDispatchWorkItem: DispatchWorkItem?

    internal let localIdentifier: UUID

    internal let fileManager: FileManager

    private var currentSendUrgency: Float = 0

    internal init(fileManager: FileManager) {

        localIdentifier = UUID()

        self.fileManager = fileManager
    }

    fileprivate init(localIdentifier: UUID, fileManager: FileManager) {
        self.localIdentifier = localIdentifier
        self.fileManager = fileManager
    }

    internal func add(_ entry: SessionEntry) {
        dispatchQueue.async {

            self.dequeueDispatchWorkItem?.cancel()

            self.entries.enqueue(entry)

            let replacementDispatchWorkItem = DispatchWorkItem { [weak self] in
                self?.writeEntries()
            }

            self.dequeueDispatchWorkItem = replacementDispatchWorkItem
            self.dispatchQueue.asyncAfter(deadline: .now() + 5, execute: replacementDispatchWorkItem)
        }
    }

    func writeEntries() {
        dequeueDispatchWorkItem?.cancel()
        dequeueDispatchWorkItem = nil

        let dequeuedEntries = entries.dequeueAll()

        do {
            try writeEntries(dequeuedEntries)
        } catch {
            entries.enqueue(dequeuedEntries)
            bt_log_internal("Failed to write entries to file", error)
        }
    }
}

extension Session: Equatable {
    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.localIdentifier == rhs.localIdentifier
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

    func writeEntries<T>(_ entries: T) throws where T: Collection, T.Element == SessionEntry {

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
            bt_log_internal("Creating entry file at ", entriesFileUrl.relativePath)
            fileManager.createFile(atPath: entriesFileUrl.path, contents: Data(), attributes: nil)
        }

        let fileHandle = try FileHandle(forWritingTo: entriesFileUrl)
        fileHandle.seekToEndOfFile()

        let jsonEncoder = JSONEncoder.bintrailDefault
        jsonEncoder.outputFormatting.remove(.prettyPrinted)

        guard let newLine = "\n".data(using: .utf8) else {
            throw FileError.failedToEncodeString
        }

        for entry in entries {
            currentSendUrgency += entry.sendUrgency
            do {
                try fileHandle.write(jsonEncoder.encode(entry))
            } catch {
                bt_log_internal("Failed to encode entry")
            }
            fileHandle.write(newLine)
        }

        fileHandle.closeFile()

        if currentSendUrgency >= 1 {
            bt_log_internal("Send urgency for session (\(localIdentifier)) at \(currentSendUrgency)")
            try moveEntriesFileToOutfilesDirectory()
            currentSendUrgency = 0
        }
    }
}

// MARK: Entries out files

internal struct SessionActionRequest {

    enum Action {
        case uploadMetadata(Session.Metadata)
        case uploadEntries(SessionEntriesBatch)
        case none(Error?)
        case metadataMissing
    }

    let session: Session

    let action: Action

    fileprivate init(session: Session, action: Action) {
        self.session = session
        self.action = action
    }
}

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

        bt_log_internal("Creating directory entry outfile directory for session \(localIdentifier)")

        try fileManager.createDirectoryIfNeeded(at: directoryUrl, withIntermediateDirectories: true)

        let destinationFileUrl = directoryUrl.appendingPathComponent("\(UUID().uuidString).json")

        bt_log_internal("Moving entries file")

        try fileManager.moveItem(
            at: entriesFileUrl,
            to: destinationFileUrl
        )
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
        }
    }
}

internal enum SessionSendError: Error {
    case metadataMissing
    case underlying(Error)
}

internal extension Session {

    private static func loadEntriesFromFile(at fileUrl: URL) throws -> [SessionEntry] {

        let jsonLines = try String(contentsOf: fileUrl, encoding: .utf8).split { character in
            character.isNewline
        }

        var entries: [SessionEntry] = []

        for jsonLine in jsonLines {
            do {
                entries.append(
                    try JSONDecoder.bintrailDefault.decode(
                        SessionEntry.self,
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
            do {
                guard let metadata = try self.loadMetadata() else {
                    throw SessionSendError.metadataMissing
                }

                guard let remoteIdentifier = metadata.remoteIdentifier else {

                    bt_log_internal("Session \(self.localIdentifier) lacks remote identifier. Uploading metadata...")

                    client.upload(sessionMetadata: metadata) { result in
                        switch result {
                        case .success(let response):
                            do {
                                try self.saveMetadata(
                                    metadata: metadata.withRemoteIdentifier(response.remoteIdentifier)
                                )
                                self.send(using: client, completion: completion)
                            } catch {
                                completion(.underlying(error))
                            }
                        case .failure(let error):
                            completion(.underlying(error))
                        }
                    }
                    return
                }

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

                    if case .failure(let error) = result {
                        completion(.underlying(error))
                        return
                    }

                    do {
                        try self.fileManager.removeItem(at: outFileUrl)
                        self.send(using: client, completion: completion)
                    } catch {
                        completion(.underlying(error))
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
