public final class Session {

    internal struct Metadata: Codable {

        internal let startedAt: Date

        internal var device: Device?

        internal var executable: Executable?

        internal var remoteIdentifier: String?

        internal var appIdentifier: String?
    }

    private lazy var dispatchQueue = DispatchQueue(label: "com.bintrail.session(\(localIdentifier.uuidString))")

    private var entries = Queue<SessionEntry>()

    private var dequeueDispatchWorkItem: DispatchWorkItem?

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

    private func writeEntries() {
        dequeueDispatchWorkItem?.cancel()
        dequeueDispatchWorkItem = nil

        let dequeuedEntries = entries.dequeueAll()

        do {
            try writeEntries(dequeuedEntries)
        } catch {
            entries.enqueue(dequeuedEntries)
            bt_debug("Failed to write entries to file", error)
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

    var directoryUrl: URL? {
        return fileManager.bintrailDirectoryUrl?
            .appendingPathComponent("sessions")
            .appendingPathComponent(localIdentifier.uuidString)
    }

    func createDirectoryIfNeeded() throws {

        guard let directoryUrl = directoryUrl else {
            throw FileError.failedToObtainDirectoryURL
        }

        guard !fileManager.fileExists(atPath: directoryUrl.path) else {
            return
        }

        try fileManager.createDirectory(at: directoryUrl, withIntermediateDirectories: true, attributes: nil)

        #if DEBUG
        bt_debug("Created session directory at", directoryUrl.path)
        #endif
    }
}

// MARK: Metadata

internal extension Session {

    var metadataFileUrl: URL? {
        return directoryUrl?.appendingPathComponent("metadata.json")
    }

    var metadataFileExists: Bool {
        guard let fileUrl = metadataFileUrl else {
            return false
        }

        return fileManager.fileExists(atPath: fileUrl.path)
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
        try createDirectoryIfNeeded()

        guard let metadataFileUrl = metadataFileUrl else {
            throw FileError.failedToObtainMetadataFileURL
        }

        if metadataFileExists {
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

    var entriesFileExists: Bool {
        guard let url = entriesFileUrl else {
            return false
        }

        return fileManager.fileExists(atPath: url.path)
    }

    func writeEntries<T>(_ entries: T) throws where T: Collection, T.Element == SessionEntry {

        guard let entriesFileUrl = entriesFileUrl else {
            throw FileError.failedToObtainEntriesFileURL
        }

        guard entries.isEmpty == false else {
            return
        }

        try createDirectoryIfNeeded()

        if !entriesFileExists {
            fileManager.createFile(atPath: entriesFileUrl.path, contents: Data(), attributes: nil)
        }

        let fileHandle = try FileHandle(forWritingTo: entriesFileUrl)
        fileHandle.seekToEndOfFile()

        defer {
            fileHandle.closeFile()
        }

        let jsonEncoder = JSONEncoder.bintrailDefault
        jsonEncoder.outputFormatting.remove(.prettyPrinted)

        guard let newLine = "\n".data(using: .utf8) else {
            throw FileError.failedToEncodeString
        }

        for entry in entries {
            try fileHandle.write(jsonEncoder.encode(entry))
            fileHandle.write(newLine)
        }
    }
}
