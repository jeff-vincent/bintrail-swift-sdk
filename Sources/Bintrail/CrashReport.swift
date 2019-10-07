import KSCrash

internal struct CrashReport {

    let executable: Executable

    let device: Device

    let crash: Crash

    let binaryImages: [BinaryImage]

    let processName: String?

    let identifier: String?

    let timestamp: Date?

    let type: String?

    let version: String?
}

extension CrashReport: Decodable {

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: DecodingKey.self)

        executable = try container.decode(Executable.self, forKey: .system)

        device = try container.decode(Device.self, forKey: .system)

        // Crash report

        let reportContainer = try container.nestedContainer(keyedBy: DecodingKey.self, forKey: .report)

        processName = try reportContainer.decode(String?.self, forKey: .processName)

        identifier = try reportContainer.decode(String?.self, forKey: .identifier)

        if let value = try reportContainer.decode(String?.self, forKey: .timestamp) {
            timestamp = CrashReporter.dateFormatter.date(from: value)
        } else {
            timestamp = nil
        }

        type = try reportContainer.decode(String?.self, forKey: .type)

        version = try reportContainer.decode(String?.self, forKey: .version)

        // Crash

        crash = try container.decode(Crash.self, forKey: .crash)

        // Binary images

        binaryImages = try container.decode([BinaryImage].self, forKey: .binaryImages)

    }
}

extension CrashReport: Encodable {}

extension CrashReport {

    struct DecodingKey: CodingKey {

        let intValue: Int? = nil

        init?(intValue: Int) {
            return nil
        }

        internal let stringValue: String

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        static let address = DecodingKey(stringValue: KSCrashField_Address)
        static let contents = DecodingKey(stringValue: KSCrashField_Contents)
        static let exception = DecodingKey(stringValue: KSCrashField_Exception)
        static let firstObject = DecodingKey(stringValue: KSCrashField_FirstObject)
        static let index = DecodingKey(stringValue: KSCrashField_Index)
        static let ivars = DecodingKey(stringValue: KSCrashField_Ivars)
        static let language = DecodingKey(stringValue: KSCrashField_Language)
        static let name = DecodingKey(stringValue: KSCrashField_Name)
        static let userInfo = DecodingKey(stringValue: KSCrashField_UserInfo)
        static let referencedObject = DecodingKey(stringValue: KSCrashField_ReferencedObject)
        static let type = DecodingKey(stringValue: KSCrashField_Type)
        static let uuid = DecodingKey(stringValue: KSCrashField_UUID)
        static let value = DecodingKey(stringValue: KSCrashField_Value)

        static let error = DecodingKey(stringValue: KSCrashField_Error)
        static let jsonData = DecodingKey(stringValue: KSCrashField_JSONData)

        static let clss = DecodingKey(stringValue: KSCrashField_Class)
        static let lastDeallocObject = DecodingKey(stringValue: KSCrashField_LastDeallocObject)

        static let instructionAddress = DecodingKey(stringValue: KSCrashField_InstructionAddr)
        static let lineOfCode = DecodingKey(stringValue: KSCrashField_LineOfCode)
        static let objectAddress = DecodingKey(stringValue: KSCrashField_ObjectAddr)
        static let objectName = DecodingKey(stringValue: KSCrashField_ObjectName)
        static let symbolAddress = DecodingKey(stringValue: KSCrashField_SymbolAddr)
        static let symbolName = DecodingKey(stringValue: KSCrashField_SymbolName)

        static let dumpEnd = DecodingKey(stringValue: KSCrashField_DumpEnd)
        static let dumpStart = DecodingKey(stringValue: KSCrashField_DumpStart)
        static let growDirection = DecodingKey(stringValue: KSCrashField_GrowDirection)
        static let overflow = DecodingKey(stringValue: KSCrashField_Overflow)
        static let stackPointer = DecodingKey(stringValue: KSCrashField_StackPtr)

        static let backtrace = DecodingKey(stringValue: KSCrashField_Backtrace)
        static let basic = DecodingKey(stringValue: KSCrashField_Basic)
        static let crashed = DecodingKey(stringValue: KSCrashField_Crashed)
        static let currentThread = DecodingKey(stringValue: KSCrashField_CurrentThread)
        static let dispatchQueue = DecodingKey(stringValue: KSCrashField_DispatchQueue)
        static let notableAddresses = DecodingKey(stringValue: KSCrashField_NotableAddresses)
        static let registers = DecodingKey(stringValue: KSCrashField_Registers)
        static let skipped = DecodingKey(stringValue: KSCrashField_Skipped)
        static let stack = DecodingKey(stringValue: KSCrashField_Stack)

        static let imageAddress = DecodingKey(stringValue: KSCrashField_ImageAddress)
        static let imageVmAddress = DecodingKey(stringValue: KSCrashField_ImageVmAddress)
        static let imageSize = DecodingKey(stringValue: KSCrashField_ImageSize)
        static let imageMajorVersion = DecodingKey(stringValue: KSCrashField_ImageMajorVersion)
        static let imageMinorVersion = DecodingKey(stringValue: KSCrashField_ImageMinorVersion)
        static let imageRevisionVersion = DecodingKey(stringValue: KSCrashField_ImageRevisionVersion)

        static let free = DecodingKey(stringValue: KSCrashField_Free)
        static let usable = DecodingKey(stringValue: KSCrashField_Usable)

        static let code = DecodingKey(stringValue: KSCrashField_Code)
        static let codeName = DecodingKey(stringValue: KSCrashField_CodeName)
        static let cppException = DecodingKey(stringValue: KSCrashField_CPPException)
        static let exceptionName = DecodingKey(stringValue: KSCrashField_ExceptionName)
        static let mach = DecodingKey(stringValue: KSCrashField_Mach)
        static let nsException = DecodingKey(stringValue: KSCrashField_NSException)
        static let reason = DecodingKey(stringValue: KSCrashField_Reason)
        static let signal = DecodingKey(stringValue: KSCrashField_Signal)
        static let subcode = DecodingKey(stringValue: KSCrashField_Subcode)
        static let userReported = DecodingKey(stringValue: KSCrashField_UserReported)

        static let lastDeallocatedNSException = DecodingKey(stringValue: KSCrashField_LastDeallocedNSException)
        static let processState = DecodingKey(stringValue: KSCrashField_ProcessState)

        static let activeTimeSinceCrash = DecodingKey(stringValue: KSCrashField_ActiveTimeSinceCrash)
        static let aciveTimeSinceLaunch = DecodingKey(stringValue: KSCrashField_ActiveTimeSinceLaunch)
        static let appActive = DecodingKey(stringValue: KSCrashField_AppActive)
        static let appInForeground = DecodingKey(stringValue: KSCrashField_AppInFG)
        static let backgroundTimeSinceCrash = DecodingKey(stringValue: KSCrashField_BGTimeSinceCrash)
        static let backgroundTimeSinceLaunch = DecodingKey(stringValue: KSCrashField_BGTimeSinceLaunch)
        static let launchCountSinceCrash = DecodingKey(stringValue: KSCrashField_LaunchesSinceCrash)
        static let sessionCountSinceCrash = DecodingKey(stringValue: KSCrashField_SessionsSinceCrash)
        static let sessionCoundSinceLaunch = DecodingKey(stringValue: KSCrashField_SessionsSinceLaunch)

        static let crash = DecodingKey(stringValue: KSCrashField_Crash)
        static let debug = DecodingKey(stringValue: KSCrashField_Debug)
        static let diagnistics = DecodingKey(stringValue: KSCrashField_Diagnosis)
        static let identifier = DecodingKey(stringValue: KSCrashField_ID)
        static let report = DecodingKey(stringValue: KSCrashField_Report)
        static let timestamp = DecodingKey(stringValue: KSCrashField_Timestamp)
        static let version = DecodingKey(stringValue: KSCrashField_Version)

        static let crashedThread = DecodingKey(stringValue: KSCrashField_CrashedThread)

        static let appStatistics = DecodingKey(stringValue: KSCrashField_AppStats)
        static let binaryImages = DecodingKey(stringValue: KSCrashField_BinaryImages)
        static let system = DecodingKey(stringValue: KSCrashField_System)
        static let memory = DecodingKey(stringValue: KSCrashField_Memory)
        static let threads = DecodingKey(stringValue: KSCrashField_Threads)
        static let user = DecodingKey(stringValue: KSCrashField_User)
        static let consoleLog = DecodingKey(stringValue: KSCrashField_ConsoleLog)

        static let incomplete = DecodingKey(stringValue: KSCrashField_Incomplete)
        static let recrashReport = DecodingKey(stringValue: KSCrashField_RecrashReport)

        static let appStartTime = DecodingKey(stringValue: KSCrashField_AppStartTime)
        static let appUUID = DecodingKey(stringValue: KSCrashField_AppUUID)
        static let bootTime = DecodingKey(stringValue: KSCrashField_BootTime)
        static let bundleId = DecodingKey(stringValue: KSCrashField_BundleID)
        static let bundleName = DecodingKey(stringValue: KSCrashField_BundleName)
        static let bundleShortVersion = DecodingKey(stringValue: KSCrashField_BundleShortVersion)
        static let bundleVersion = DecodingKey(stringValue: KSCrashField_BundleVersion)
        static let cpuArchitecture = DecodingKey(stringValue: KSCrashField_CPUArch)
        static let cpuType = DecodingKey(stringValue: KSCrashField_CPUType)
        static let cpuSubtype = DecodingKey(stringValue: KSCrashField_CPUSubType)
        static let cpuBinaryType = DecodingKey(stringValue: KSCrashField_BinaryCPUType)
        static let cpuBinarySubtype = DecodingKey(stringValue: KSCrashField_BinaryCPUSubType)
        static let deviceAppHash = DecodingKey(stringValue: KSCrashField_DeviceAppHash)
        static let executable = DecodingKey(stringValue: KSCrashField_Executable)
        static let executablePath = DecodingKey(stringValue: KSCrashField_ExecutablePath)
        static let isJailBroken = DecodingKey(stringValue: KSCrashField_Jailbroken)
        static let kernelVersion = DecodingKey(stringValue: KSCrashField_KernelVersion)
        static let machine = DecodingKey(stringValue: KSCrashField_Machine)
        static let model = DecodingKey(stringValue: KSCrashField_Model)
        static let osVersion = DecodingKey(stringValue: KSCrashField_OSVersion)
        static let parentProcessId = DecodingKey(stringValue: KSCrashField_ParentProcessID)
        static let processId = DecodingKey(stringValue: KSCrashField_ProcessID)
        static let processName = DecodingKey(stringValue: KSCrashField_ProcessName)
        static let size = DecodingKey(stringValue: KSCrashField_Size)
        static let storage = DecodingKey(stringValue: KSCrashField_Storage)
        static let systemName = DecodingKey(stringValue: KSCrashField_SystemName)
        static let systemVersion = DecodingKey(stringValue: KSCrashField_SystemVersion)
        static let timeZone = DecodingKey(stringValue: KSCrashField_TimeZone)
        static let buildType = DecodingKey(stringValue: KSCrashField_BuildType)
    }

}
