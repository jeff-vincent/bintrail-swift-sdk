import KSCrash
#if canImport(UIKit)
import UIKit
#endif

enum CrashReporterError: Error {
    case reportNotFound
    case jsonDecodingError(Error)
}

internal class CrashReporter {

    let jsonEncoder: JSONEncoder
    let jsonDecoder: JSONDecoder

    var userInfo = CrashReportBody.UserInfo() {
        didSet {
            writeUserInfo()
        }
    }

    init(jsonEncoder: JSONEncoder, jsonDecoder: JSONDecoder) {
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
    }

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
        writeUserInfo()
    }

    private func writeUserInfo() {
        do {
            try jsonEncoder.encode(userInfo).withUnsafeBytes { bytes in
                kscrash_setUserInfoJSON(bytes.bindMemory(to: Int8.self).baseAddress)
            }

        } catch {
            bt_print("Warning! Could not encode user info.")
        }
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

        do {
            return .success(
                CrashReport(
                    identifier: identifier,
                    body: try jsonDecoder.decode(CrashReportBody.self, from: data)
                )
            )
        } catch {
            return .failure(.jsonDecodingError(error))
        }
    }

    func deleteReport(withIdentifier identifier: Int64) {
        kscrash_deleteReportWithID(identifier)
    }

    func deleteReports<T: Sequence>(withIdentifiers identifiers: T) where T.Element == Int64 {
        for identifier in identifiers {
            deleteReport(withIdentifier: identifier)
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
            identifier: String(cString: system.deviceAppHash),
            machine: String(cString: system.machine),
            model: String(cString: system.model),
            platform: Device.Platform(
                name: String(cString: system.systemName),
                versionCode: String(cString: system.osVersion),
                versionName: String(cString: system.systemVersion)
            ),
            name: userInfo.deviceName,
            localeIdentifier: Locale.current.identifier,
            timeZoneIdentifier: String(cString: system.timezone),
            kernelVersion: String(cString: system.kernelVersion),
            bootTime: CrashReport.secondPrecisionDateFormatter.date(from: String(cString: system.bootTime)),
            isJailBroken: system.isJailbroken,
            processor: Device.Processor(
                architecture: String(cString: system.cpuArchitecture),
                type: system.cpuType,
                subType: system.cpuSubType
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
            name: String(cString: system.executableName),
            identifier: String(cString: system.appID),
            package: Executable.Package(
                identifier: String(cString: system.bundleID),
                versionName: String(cString: system.bundleShortVersion),
                versionCode: String(cString: system.bundleVersion),
                name: String(cString: system.bundleName)
            ),
            startTime: CrashReport.secondPrecisionDateFormatter.date(from: String(cString: system.appStartTime)),
            title: String(cString: system.bundleName),
            path: String(cString: system.executablePath)
        )
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
