import Foundation
import IOKit.ps

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
    @Published public var topProcesses: [ProcessInfo] = []
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
    
    public var updateInterval: TimeInterval = 1.0
    public var enabledMetrics: Set<MetricType> = Set(MetricType.allCases)
    
    public enum MetricType: CaseIterable {
        case cpu, memory, disk, network, battery, temperature, processes
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
        var newProcesses: [ProcessInfo] = []
        
        // 并发获取所有数据
        await withTaskGroup(of: Void.self) { group in
            if enabledMetrics.contains(.cpu) {
                group.addTask {
                    if let info = await self.cpuService.getUsage() {
                        await MainActor.run { newCPU = info }
                    }
                }
            }
            
            if enabledMetrics.contains(.memory) {
                group.addTask {
                    if let info = await self.memoryService.getUsage() {
                        await MainActor.run { newMemory = info }
                    }
                }
            }
            
            if enabledMetrics.contains(.disk) {
                group.addTask {
                    if let info = await self.diskService.getUsage() {
                        await MainActor.run { newDisk = info }
                    }
                }
            }
            
            if enabledMetrics.contains(.network) {
                group.addTask {
                    if let info = await self.networkService.getUsage() {
                        await MainActor.run { newNetwork = info }
                    }
                }
            }
            
            if enabledMetrics.contains(.battery) {
                group.addTask {
                    if let info = await self.batteryService.getUsage() {
                        await MainActor.run { newBattery = info }
                    }
                }
            }
            
            if enabledMetrics.contains(.temperature) {
                group.addTask {
                    if let info = await self.temperatureService.getTemperatures() {
                        await MainActor.run { newTemperature = info }
                    }
                }
            }
            
            if enabledMetrics.contains(.processes) {
                group.addTask {
                    let processes = await self.processService.getTopProcesses(limit: 10)
                    await MainActor.run { newProcesses = processes }
                }
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
        
        let userTicks = cpuLoad.cpu_ticks.0
        let systemTicks = cpuLoad.cpu_ticks.1
        let idleTicks = cpuLoad.cpu_ticks.2
        let niceTicks = cpuLoad.cpu_ticks.3
        
        let totalTicks = userTicks + systemTicks + idleTicks + niceTicks
        guard totalTicks > 0 else { return nil }
        
        let user = Double(userTicks) / Double(totalTicks) * 100
        let system = Double(systemTicks) / Double(totalTicks) * 100
        let idle = Double(idleTicks) / Double(totalTicks) * 100
        let usage = user + system
        
        let coreCount = ProcessInfo.processInfo.processorCount
        
        return CPUInfo(
            usage: usage,
            user: user,
            system: system,
            idle: idle,
            coreCount: coreCount
        )
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
        
        let total = UInt64(ProcessInfo.processInfo.physicalMemory)
        let free = UInt64(stats.free_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        
        let pressure: MemoryPressure
        let pressureStatus = stats.mem_pressure_status
        switch pressureStatus {
        case 1: pressure = .warning
        case 2, 3: pressure = .critical
        default: pressure = .nominal
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
    
    public init() {}
    
    public func getUsage() async -> DiskInfo? {
        let fileManager = FileManager.default
        
        guard let attributes = try? fileManager.attributesOfFileSystem(forPath: "/") else {
            return nil
        }
        
        let total = (attributes[.systemSize] as? UInt64) ?? 0
        let free = (attributes[.systemFreeSize] as? UInt64) ?? 0
        let used = total - free
        
        // 磁盘速度需要通过 IOKit 获取，这里简化处理
        // 实际实现需要 IOStoragestatistics
        
        return DiskInfo(
            total: total,
            free: free,
            used: used,
            readSpeed: 0,
            writeSpeed: 0,
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
        guard IOPSCopyPowerSourcesInfo() != nil else { return nil }
        
        guard let powerSources = IOPSCopyPowerSourcesList().takeRetainedValue() as? [[String: Any]] else {
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
        if let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery")) {
            defer { IOObjectRelease(service) }
            
            if let properties = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Int {
                cycleCount = properties
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
    
    public init() {}
    
    public func getTemperatures() async -> TemperatureInfo? {
        // 温度需要通过 SMC (System Management Controller) 获取
        // 这里提供简化实现，实际需要连接 IOKit 的 AppleSMC 服务
        
        var cpu: Double?
        var gpu: Double?
        var battery: Double?
        
        // 尝试获取 SMC 服务
        let matching = IOServiceMatching("AppleSMC")
        var iterator: io_iterator_t = 0
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        
        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        
        // 读取温度键值
        // TC0C, TC0D, TC0E, TC0F - CPU 温度
        // TG0D - GPU 温度
        // TB0T - 电池温度
        
        cpu = readSMCTemperature(service, key: "TC0D")
        gpu = readSMCTemperature(service, key: "TG0D")
        battery = readSMCTemperature(service, key: "TB0T")
        
        return TemperatureInfo(cpu: cpu, gpu: gpu, battery: battery)
    }
    
    private func readSMCTemperature(_ service: io_object_t, key: String) -> Double? {
        // SMC 温度读取需要底层实现
        // 这里返回 nil，实际实现需要使用 SMC 命令
        return nil
    }
}

// MARK: - Process Service

public class ProcessService {
    
    public init() {}
    
    public func getTopProcesses(limit: Int = 10) async -> [ProcessInfo] {
        var processList: [ProcessInfo] = []
        
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
            
            // 获取 CPU 使用率需要额外计算
            // 获取内存使用率
            let memSize = proc.kp_eproc.e_xrssize * UInt16(Int32(vm_kernel_page_size) / 1024)
            
            let processInfo = ProcessInfo(
                id: pid,
                name: name,
                cpuUsage: 0,  // 需要 task_info 计算
                memoryUsage: UInt64(memSize) * 1024,
                threads: 0,
                user: "",
                startTime: nil
            )
            
            processList.append(processInfo)
        }
        
        // 按内存排序，取前 N 个
        processList.sort { $0.memoryUsage > $1.memoryUsage }
        return Array(processList.prefix(limit))
    }
}
