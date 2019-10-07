import KSCrash

enum CrashReporterError: Error {
    case reportNotFound
    case jsonDecodingError(Error)
}

internal class CrashReporter {

    private static var dateFormatterInternal: DateFormatter?

    static var dateFormatter: DateFormatter {
        if let dateFormatter = dateFormatterInternal {
            return dateFormatter
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatterInternal = dateFormatter
        return dateFormatter
    }

    let jsonDecoder = JSONDecoder()

    func install() {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown"
        let baseUrl: URL?

        if let directory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
            baseUrl = URL(fileURLWithPath: directory)
                .appendingPathComponent("KSCrash")
                .appendingPathComponent(appName)
        } else {
            baseUrl = nil
        }

        kscrash_install(appName, baseUrl?.path)
        sendCrashReports()

    }

    var reportIdentifiers: [Int64] {
        var reportCount = kscrash_getReportCount()

        var identifiers = [Int64](repeating: 0, count: Int(reportCount))

        reportCount = identifiers.withUnsafeMutableBufferPointer { buffer in
            kscrash_getReportIDs(buffer.baseAddress, reportCount)
        }

        return identifiers

    }

    func loadReport(withIdentifier identifier: Int64) -> Result<CrashReport, CrashReporterError> {
        guard let pointer = kscrash_readReport(identifier) else {
            return .failure(.reportNotFound)
        }

        let data = Data(bytesNoCopy: pointer, count: strlen(pointer), deallocator: .free)

        if let string = String(data: data, encoding: .utf8) {
            print(string)
        }

        do {
            return .success(
                try jsonDecoder.decode(CrashReport.self, from: data)
            )
        } catch {
            return .failure(.jsonDecodingError(error))
        }

    }

    private var monitorContext: KSCrash_MonitorContext? {
        guard let crashMonitorAPI = kscm_system_getAPI() else {
            return nil
        }

        var fakeEvent = KSCrash_MonitorContext()

        crashMonitorAPI.pointee.addContextualInfoToEvent(&fakeEvent)

        return fakeEvent
    }

    var device: Device? {
        guard let context = monitorContext else {
            return nil
        }

        let system = context.System

        return Device(
            platformName: String(cString: system.systemName),
            platformVersion: String(cString: system.osVersion),
            platformVersionName: String(cString: system.machine),
            kernelVersion: String(cString: system.kernelVersion),
            bootTime: CrashReporter.dateFormatter.date(from: String(cString: system.bootTime)),
            isJailBroken: system.isJailbroken,
            processor: Device.Processor(
                architecture: String(cString: system.cpuArchitecture),
                type: system.cpuType,
                subType: system.cpuSubType,
                binaryType: system.binaryCPUType,
                binarySubtype: system.binaryCPUSubType
            ),
            memory: Device.MemoryInfo(
                size: system.memorySize,
                free: system.freeMemory,
                usable: system.usableMemory
            )
        )
    }

    var executable: Executable? {
        guard let context = monitorContext else {
            return nil
        }

        let system = context.System

        return Executable(
            identifier: String(cString: system.appID),
            name: String(cString: system.bundleID),
            version: Int(String(cString: system.bundleVersion)),
            versionName: String(cString: system.bundleShortVersion),
            startTime: CrashReporter.dateFormatter.date(from: String(cString: system.appStartTime)),
            title: String(cString: system.bundleName),
            path: String(cString: system.executablePath)
        )
    }

    func sendCrashReports() {

        for report in self {
            switch report {
            case .success(let report):
                print(report)
            case .failure(let error):
                print(error)
            }
        }
    }

}

extension CrashReporter: Sequence {

    __consuming func makeIterator() -> AnyIterator<Result<CrashReport, CrashReporterError>> {
        var identifiers = reportIdentifiers

        return AnyIterator {
            guard identifiers.isEmpty == false else {
                return nil
            }

            return self.loadReport(withIdentifier: identifiers.removeFirst())
        }
    }
}
