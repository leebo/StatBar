import Foundation
import IOKit.ps
import Darwin

// MARK: - 系统监控服务

@MainActor
public class SystemMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var cpu: CPUInfo?
    @Published public var memory: MemoryInfo?
    @Published public var disk: DiskInfo?
    @Published public var network: NetworkInfo?
    @Published public var battery: BatteryInfo?
    @Published public var temperature: TemperatureInfo?
    @Published public var topProcesses: [ProcessEntry] = []
    @Published public var history: StatsHistory
    
    // MARK: - Private Properties
    
    private var updateTimer: Timer?
    private let cpuService = CPUService()
    private let memoryService = MemoryService()
    private let diskService = DiskService()
    private let networkService = NetworkService()
    private let batteryService = BatteryService()
    private let temperatureService = TemperatureService()
    private let processService = ProcessService()
    
    private var previousNetwork: NetworkInfo?
    
    // MARK: - Configuration
    
    public var updateInterval: TimeInterval = 1.0 {
        didSet {
            if updateTimer != nil {
                start()
            }
        }
    }
    
    public var historyLength: Int = 60 {
        didSet {
            history = StatsHistory(maxPoints: historyLength)
        }
    }
    
    // MARK: - Initialization
    
    public init() {
        self.history = StatsHistory(maxPoints: 60)
    }
    
    // MARK: - Public Methods
    
    public func start() {
        stop()
        
        // 立即更新一次
        Task {
            await update()
        }
        
        // 启动定时器
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.update()
            }
        }
        
        RunLoop.current.add(updateTimer!, forMode: .common)
    }
    
    public func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    public func update() async {
        var newCPU: CPUInfo?
        var newMemory: MemoryInfo?
        var newDisk: DiskInfo?
        var newNetwork: NetworkInfo?
        var newBattery: BatteryInfo?
        var newTemperature: TemperatureInfo?
        var newProcesses: [ProcessEntry] = []
        
        // 并发获取所有数据
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                if let info = await self.cpuService.getUsage() {
                    await MainActor.run { newCPU = info }
                }
            }
            
            group.addTask {
                if let info = await self.memoryService.getUsage() {
                    await MainActor.run { newMemory = info }
                }
            }
            
            group.addTask {
                if let info = await self.diskService.getUsage() {
                    await MainActor.run { newDisk = info }
                }
            }
            
            group.addTask {
                if let info = await self.networkService.getUsage() {
                    await MainActor.run { newNetwork = info }
                }
            }
            
            group.addTask {
                if let info = await self.batteryService.getUsage() {
                    await MainActor.run { newBattery = info }
                }
            }
            
            group.addTask {
                if let info = await self.temperatureService.getTemperatures() {
                    await MainActor.run { newTemperature = info }
                }
            }
            
            group.addTask {
                let processes = await self.processService.getTopProcesses(limit: 15)
                await MainActor.run { newProcesses = processes }
            }
        }
        
        // 更新发布属性
        self.cpu = newCPU
        self.memory = newMemory
        self.disk = newDisk
        self.battery = newBattery
        self.temperature = newTemperature
        self.topProcesses = newProcesses
        
        // 计算网络速度
        if let newNetwork = newNetwork, let prevNetwork = previousNetwork {
            let elapsed = newNetwork.timestamp.timeIntervalSince(prevNetwork.timestamp)
            if elapsed > 0 {
                let downSpeed = (newNetwork.bytesIn - prevNetwork.bytesIn) / UInt64(elapsed)
                let upSpeed = (newNetwork.bytesOut - prevNetwork.bytesOut) / UInt64(elapsed)
                self.network = NetworkInfo(
                    bytesIn: newNetwork.bytesIn,
                    bytesOut: newNetwork.bytesOut,
                    packetsIn: newNetwork.packetsIn,
                    packetsOut: newNetwork.packetsOut,
                    downloadSpeed: downSpeed,
                    uploadSpeed: upSpeed,
                    interface: newNetwork.interface
                )
            }
        } else {
            self.network = newNetwork
        }
        previousNetwork = newNetwork
        
        // 更新历史数据
        if let cpu = self.cpu, let memory = self.memory, let network = self.network {
            history.add(
                cpu: cpu.usage,
                memory: memory.usagePercent,
                netDown: network.downloadSpeed,
                netUp: network.uploadSpeed
            )
        }
    }
}

// MARK: - CPU Service

public class CPUService {
    
    private var previousTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    
    public init() {}
    
    public func getUsage() async -> CPUInfo? {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        
        let userTicks = UInt64(cpuLoad.cpu_ticks.0)
        let systemTicks = UInt64(cpuLoad.cpu_ticks.1)
        let idleTicks = UInt64(cpuLoad.cpu_ticks.2)
        let niceTicks = UInt64(cpuLoad.cpu_ticks.3)
        
        // 计算增量
        if let prev = previousTicks {
            let userDelta = Double(userTicks - prev.user)
            let systemDelta = Double(systemTicks - prev.system)
            let idleDelta = Double(idleTicks - prev.idle)
            let niceDelta = Double(niceTicks - prev.nice)
            
            let total = userDelta + systemDelta + idleDelta + niceDelta
            guard total > 0 else { return nil }
            
            let user = userDelta / total * 100
            let system = systemDelta / total * 100
            let idle = idleDelta / total * 100
            let usage = user + system
            
            previousTicks = (userTicks, systemTicks, idleTicks, niceTicks)
            
            let coreCount = Foundation.ProcessInfo.processInfo.processorCount
            
            return CPUInfo(
                usage: usage,
                user: user,
                system: system,
                idle: idle,
                coreCount: coreCount
            )
        } else {
            previousTicks = (userTicks, systemTicks, idleTicks, niceTicks)
            return nil
        }
    }
}

// MARK: - Memory Service

public class MemoryService {
    
    public init() {}
    
    public func getUsage() async -> MemoryInfo? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        
        let pageSize = UInt64(vm_kernel_page_size)
        
        let total = UInt64(Foundation.ProcessInfo.processInfo.physicalMemory)
        let free = UInt64(stats.free_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        
        // 内存压力评估
        let pressure: MemoryPressure
        let usagePercent = Double(used) / Double(total)
        if usagePercent > 0.9 {
            pressure = .critical
        } else if usagePercent > 0.75 {
            pressure = .warning
        } else {
            pressure = .nominal
        }
        
        return MemoryInfo(
            total: total,
            used: used,
            free: free,
            active: active,
            inactive: inactive,
            wired: wired,
            compressed: compressed,
            pressure: pressure
        )
    }
}

// MARK: - Disk Service

public class DiskService {
    
    private var previousRead: UInt64 = 0
    private var previousWrite: UInt64 = 0
    private var previousTime: Date = Date()
    
    public init() {}
    
    public func getUsage() async -> DiskInfo? {
        let fileManager = FileManager.default
        
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: "/") else {
            return nil
        }
        
        let total = (attributes[.systemSize] as? UInt64) ?? 0
        let free = (attributes[.systemFreeSize] as? UInt64) ?? 0
        let used = total - free
        
        // 磁盘 I/O 统计需要 IOKit
        // 这里暂时返回 0，实际需要通过 IOStorageStatistics 获取
        let readSpeed: UInt64 = 0
        let writeSpeed: UInt64 = 0
        
        return DiskInfo(
            total: total,
            free: free,
            used: used,
            readSpeed: readSpeed,
            writeSpeed: writeSpeed,
            name: "Macintosh HD"
        )
    }
}

// MARK: - Network Service

public class NetworkService {
    
    public init() {}
    
    public func getUsage() async -> NetworkInfo? {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0 else { return nil }
        defer { freeifaddrs(interfaceAddresses) }
        
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var packetsIn: UInt64 = 0
        var packetsOut: UInt64 = 0
        var primaryInterface = "en0"
        
        var ptr = interfaceAddresses
        while ptr != nil {
            let addr = ptr!.pointee
            
            if let name = addr.ifa_name {
                let ifaName = String(cString: name)
                
                // 只统计物理接口 (en0, en1, etc)
                if ifaName.hasPrefix("en") || ifaName.hasPrefix("bridge") {
                    if let data = addr.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                        bytesIn += UInt64(networkData.ifi_ibytes)
                        bytesOut += UInt64(networkData.ifi_obytes)
                        packetsIn += UInt64(networkData.ifi_ipackets)
                        packetsOut += UInt64(networkData.ifi_opackets)
                        
                        if bytesIn > 0 || bytesOut > 0 {
                            primaryInterface = ifaName
                        }
                    }
                }
            }
            
            ptr = addr.ifa_next
        }
        
        return NetworkInfo(
            bytesIn: bytesIn,
            bytesOut: bytesOut,
            packetsIn: packetsIn,
            packetsOut: packetsOut,
            downloadSpeed: 0,  // 由 SystemMonitor 计算
            uploadSpeed: 0,
            interface: primaryInterface
        )
    }
}

// MARK: - Battery Service

public class BatteryService {
    
    public init() {}
    
    public func getUsage() async -> BatteryInfo? {
        // 检查是否有电池
        guard let powerSourcesInfo = IOPSCopyPowerSourcesInfo() else { return nil }
        
        guard let powerSources = IOPSCopyPowerSourcesList(powerSourcesInfo.takeRetainedValue()).takeRetainedValue() as? [[String: Any]] else {
            return nil
        }
        
        guard let powerSource = powerSources.first else { return nil }
        
        let level = (powerSource[kIOPSCurrentCapacityKey] as? Int) ?? 0
        let isCharging = (powerSource[kIOPSIsChargingKey] as? Bool) ?? false
        let timeRemaining = powerSource[kIOPSTimeToEmptyKey] as? Int
        
        let powerSourceState = (powerSource[kIOPSPowerSourceStateKey] as? String) ?? ""
        let powerSourceEnum: PowerSource
        switch powerSourceState {
        case kIOPSBatteryPowerValue: powerSourceEnum = .battery
        case kIOPSACPowerValue: powerSourceEnum = .acPower
        default: powerSourceEnum = .unknown
        }
        
        // 循环次数需要通过 IOKit 获取
        var cycleCount: Int?
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            
            if let properties = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0) {
                if let cycles = properties.takeRetainedValue() as? Int {
                    cycleCount = cycles
                }
            }
        }
        
        return BatteryInfo(
            level: level,
            isCharging: isCharging,
            timeRemaining: timeRemaining,
            powerSource: powerSourceEnum,
            cycleCount: cycleCount,
            health: nil  // 健康状态需要更多计算
        )
    }
}

// MARK: - Temperature Service

public class TemperatureService {
    
    private var smcConnection: io_connect_t = 0
    
    public init() {
        connectToSMC()
    }
    
    deinit {
        if smcConnection != 0 {
            IOServiceClose(smcConnection)
        }
    }
    
    private func connectToSMC() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            IOServiceOpen(service, mach_task_self_, 0, &smcConnection)
        }
    }
    
    public func getTemperatures() async -> TemperatureInfo? {
        var cpu: Double?
        var gpu: Double?
        var battery: Double?
        var fanSpeed: Int?
        
        // 读取 SMC 温度键值
        cpu = readTemperature(key: "TC0D") ?? readTemperature(key: "TC0E") ?? readTemperature(key: "TC0F")
        gpu = readTemperature(key: "TG0D")
        battery = readTemperature(key: "TB0T")
        
        // 读取风扇转速
        fanSpeed = readFanSpeed()
        
        return TemperatureInfo(cpu: cpu, gpu: gpu, battery: battery, fanSpeed: fanSpeed)
    }
    
    private func readTemperature(key: String) -> Double? {
        guard smcConnection != 0 else { return nil }
        
        var input = SMCKeyData()
        var output = SMCKeyData()
        var outputSize = UInt32(MemoryLayout<SMCKeyData>.size)
        
        // 将键名转换为 4 字节代码
        let keyBytes = key.utf8.map { UInt8($0) }
        guard keyBytes.count == 4 else { return nil }
        
        input.key = UInt32(bytes: keyBytes)
        input.data8 = SMC_CMD_READ_KEYINFO
        
        var inputSize = Int(MemoryLayout<SMCKeyData>.size)
        var outSize = Int(outputSize)
        let result = IOConnectCallStructMethod(
            smcConnection,
            UInt32(KERNEL_INDEX_SMC),
            &input,
            inputSize,
            &output,
            &outSize
        )
        outputSize = UInt32(outSize)
        
        guard result == KERN_SUCCESS else { return nil }
        
        let dataType = output.keyInfo.dataType
        let dataSize = output.keyInfo.dataSize
        
        input.keyInfo.dataSize = dataSize
        input.data8 = SMC_CMD_READ_BYTES
        
        outSize = Int(MemoryLayout<SMCKeyData>.size)
        let result2 = IOConnectCallStructMethod(
            smcConnection,
            UInt32(KERNEL_INDEX_SMC),
            &input,
            inputSize,
            &output,
            &outSize
        )
        
        guard result2 == KERN_SUCCESS else { return nil }
        
        // 解析温度值 (SP78 格式: 高字节整数，低字节小数)
        let temp = Double(output.bytes.0) + Double(output.bytes.1) / 256.0
        return temp
    }
    
    private func readFanSpeed() -> Int? {
        guard smcConnection != 0 else { return nil }
        
        // 尝试读取 F0Ac (风扇 0 实际转速)
        if let value = readSMCValue(key: "F0Ac") {
            return Int(value)
        }
        
        return nil
    }
    
    private func readSMCValue(key: String) -> UInt16? {
        guard smcConnection != 0 else { return nil }
        
        var input = SMCKeyData()
        var output = SMCKeyData()
        var outputSize = UInt32(MemoryLayout<SMCKeyData>.size)
        
        let keyBytes = key.utf8.map { UInt8($0) }
        guard keyBytes.count == 4 else { return nil }
        
        input.key = UInt32(bytes: keyBytes)
        input.data8 = SMC_CMD_READ_KEYINFO
        
        let result = IOConnectCallStructMethod(
            smcConnection,
            UInt32(KERNEL_INDEX_SMC),
            &input,
            UInt32(MemoryLayout<SMCKeyData>.size),
            &output,
            &outputSize
        )
        
        guard result == KERN_SUCCESS else { return nil }
        
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = SMC_CMD_READ_BYTES
        
        let result2 = IOConnectCallStructMethod(
            smcConnection,
            UInt32(KERNEL_INDEX_SMC),
            &input,
            UInt32(MemoryLayout<SMCKeyData>.size),
            &output,
            &outputSize
        )
        
        guard result2 == KERN_SUCCESS else { return nil }
        
        // 大端序
        return UInt16(output.bytes.0) << 8 | UInt16(output.bytes.1)
    }
}

// MARK: - SMC 常量和结构

private let KERNEL_INDEX_SMC: Int32 = 2
private let SMC_CMD_READ_KEYINFO: UInt8 = 9
private let SMC_CMD_READ_BYTES: UInt8 = 5

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers: UInt8 = 0
    var pad: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8_2: UInt8 = 0
    var data32_2: UInt32 = 0
    var keyInfo: SMCKeyInfo = SMCKeyInfo()
}

private struct SMCKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private extension UInt32 {
    init(bytes: [UInt8]) {
        self = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }
}

// MARK: - Process Service

public class ProcessService {
    
    public init() {}
    
    public func getTopProcesses(limit: Int = 15) async -> [ProcessEntry] {
        var processList: [ProcessEntry] = []
        
        // 获取进程列表
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var size = 0
        
        // 获取所需大小
        sysctl(&mib, 3, nil, &size, nil, 0)
        
        // 分配内存
        let count = size / MemoryLayout<kinfo_proc>.size
        var procList = [kinfo_proc](repeating: kinfo_proc(), count: count)
        
        // 获取进程列表
        sysctl(&mib, 3, &procList, &size, nil, 0)
        
        for proc in procList {
            let pid = proc.kp_proc.p_pid
            let name = withUnsafePointer(to: proc.kp_proc.p_comm) {
                String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
            }
            
            // 获取内存使用
            let memSize = UInt64(proc.kp_eproc.e_xrssize) * UInt64(vm_kernel_page_size)
            
            // 获取 CPU 使用率需要 task_info，这里暂时设为 0
            let cpuUsage: Double = 0
            
            let processEntry = ProcessEntry(
                id: pid,
                name: name,
                cpuUsage: cpuUsage,
                memoryUsage: memSize,
                threads: 0,
                user: "",
                startTime: nil
            )
            
            processList.append(processEntry)
        }
        
        // 按内存排序
        processList.sort { $0.memoryUsage > $1.memoryUsage }
        return Array(processList.prefix(limit))
    }
}
