import Foundation
import IOKit.ps
import Darwin
import Dispatch

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
    @Published public var isFirstUpdate: Bool = true  // 标记首次更新
    
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
    private var previousDisk: DiskInfo?
    
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
        // 自动启动监控
        Task { @MainActor in
            self.start()
        }
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
        self.battery = newBattery
        self.temperature = newTemperature
        self.topProcesses = newProcesses
        
        // 计算磁盘读写速度
        if let newDisk = newDisk {
            if let prevDisk = previousDisk {
                let elapsed = newDisk.timestamp.timeIntervalSince(prevDisk.timestamp)
                if elapsed > 0 {
                    let readSpeed = (newDisk.readBytes - prevDisk.readBytes) / UInt64(elapsed)
                    let writeSpeed = (newDisk.writeBytes - prevDisk.writeBytes) / UInt64(elapsed)
                    self.disk = DiskInfo(
                        partitions: newDisk.partitions,
                        readBytes: newDisk.readBytes,
                        writeBytes: newDisk.writeBytes,
                        readSpeed: readSpeed,
                        writeSpeed: writeSpeed
                    )
                } else {
                    self.disk = newDisk
                }
            } else {
                self.disk = newDisk
            }
            previousDisk = newDisk
        }
        
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
            } else {
                self.network = newNetwork
            }
        } else {
            // 首次获取，设置速度为 0
            self.network = newNetwork
        }
        previousNetwork = newNetwork
        
        // 标记首次更新完成
        if isFirstUpdate {
            isFirstUpdate = false
        }
        
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
    private var previousCoreTicks: [[UInt64]] = []  // 每个核心的 ticks
    private var isFirstCall = true
    
    public init() {}
    
    public func getUsage() async -> CPUInfo? {
        let coreCount = Foundation.ProcessInfo.processInfo.processorCount
        
        // 获取总体 CPU 使用率
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
        
        // 获取每个核心的使用率
        var coreUsages: [Double] = []
        
        var numCPUs = natural_t(0)
        var cpuInfo: processor_info_array_t?
        var numCPUInfo = mach_msg_type_number_t(0)
        
        let coreResult = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )
        
        if coreResult == KERN_SUCCESS, let info = cpuInfo {
            let ticksPerCore = Int(numCPUInfo) / Int(numCPUs)
            var currentCoreTicks: [[UInt64]] = []
            
            for i in 0..<Int(numCPUs) {
                let baseIndex = i * ticksPerCore
                let user = UInt64(info[baseIndex + Int(CPU_STATE_USER)])
                let system = UInt64(info[baseIndex + Int(CPU_STATE_SYSTEM)])
                let idle = UInt64(info[baseIndex + Int(CPU_STATE_IDLE)])
                let nice = UInt64(info[baseIndex + Int(CPU_STATE_NICE)])
                
                currentCoreTicks.append([user, system, idle, nice])
                
                // 计算该核心的使用率
                if i < previousCoreTicks.count {
                    let prev = previousCoreTicks[i]
                    let userDelta = Double(user - prev[0])
                    let systemDelta = Double(system - prev[1])
                    let idleDelta = Double(idle - prev[2])
                    let niceDelta = Double(nice - prev[3])
                    
                    let total = userDelta + systemDelta + idleDelta + niceDelta
                    if total > 0 {
                        let usage = (userDelta + systemDelta) / total * 100
                        coreUsages.append(max(0, min(100, usage)))
                    } else {
                        coreUsages.append(0)
                    }
                } else {
                    coreUsages.append(0)
                }
            }
            
            previousCoreTicks = currentCoreTicks
            
            // 释放内存
            let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }
        
        // 首次调用返回默认值
        if isFirstCall {
            isFirstCall = false
            previousTicks = (userTicks, systemTicks, idleTicks, niceTicks)
            // 返回 0% 使用率作为初始值
            return CPUInfo(
                usage: 0,
                user: 0,
                system: 0,
                idle: 100,
                coreCount: coreCount,
                coreUsages: Array(repeating: 0, count: coreCount)
            )
        }
        
        // 计算总体增量
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
            
            return CPUInfo(
                usage: usage,
                user: user,
                system: system,
                idle: idle,
                coreCount: coreCount,
                coreUsages: coreUsages.isEmpty ? Array(repeating: 0, count: coreCount) : coreUsages
            )
        } else {
            previousTicks = (userTicks, systemTicks, idleTicks, niceTicks)
            return CPUInfo(
                usage: 0,
                user: 0,
                system: 0,
                idle: 100,
                coreCount: coreCount,
                coreUsages: Array(repeating: 0, count: coreCount)
            )
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
        
        // 更准确的内存使用计算：total - free (可用内存)
        // macOS 的 "App Memory" ≈ active + wired + compressed
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
    
    public init() {}
    
    public func getUsage() async -> DiskInfo? {
        var partitions: [DiskPartitionInfo] = []
        
        // 获取所有挂载的卷
        let fileManager = FileManager.default
        let volumeKeys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRootFileSystemKey
        ]
        
        let options: FileManager.VolumeEnumerationOptions = [.skipHiddenVolumes]
        
        // 枚举所有挂载的卷
        if let volumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: volumeKeys, options: options) {
            for url in volumeURLs {
                // 跳过网络卷和系统隐藏卷
                guard let resourceValues = try? url.resourceValues(forKeys: Set(volumeKeys)) else { continue }
                
                guard let total = resourceValues.volumeTotalCapacity else { continue }
                guard let free = resourceValues.volumeAvailableCapacity else { continue }
                let name = resourceValues.volumeName ?? "未知"
                let isRoot = resourceValues.volumeIsRootFileSystem ?? false
                
                // 只显示根分区和大于 1GB 的本地卷
                let isLargeEnough = total > 1_073_741_824  // 1GB
                let isLocal = !url.path.hasPrefix("/Volumes/") || isLargeEnough
                
                if isRoot || isLocal {
                    let partition = DiskPartitionInfo(
                        total: UInt64(total),
                        free: UInt64(free),
                        used: UInt64(total - free),
                        name: name,
                        mountPoint: url.path
                    )
                    partitions.append(partition)
                }
            }
        }
        
        // 确保至少有根分区
        if partitions.isEmpty {
            if let attributes = try? fileManager.attributesOfFileSystem(forPath: "/") {
                let total = (attributes[.systemSize] as? UInt64) ?? 0
                let free = (attributes[.systemFreeSize] as? UInt64) ?? 0
                let volumeName = fileManager.displayName(atPath: "/")
                let partition = DiskPartitionInfo(
                    total: total,
                    free: free,
                    used: total - free,
                    name: volumeName,
                    mountPoint: "/"
                )
                partitions.append(partition)
            }
        }
        
        // 按挂载点排序（根分区在前）
        partitions.sort { $0.isRoot ? true : ($1.isRoot ? false : $0.mountPoint < $1.mountPoint) }
        
        // 读取磁盘 I/O 统计
        let diskStats = readDiskStats()
        
        return DiskInfo(
            partitions: partitions,
            readBytes: diskStats.readBytes,
            writeBytes: diskStats.writeBytes
        )
    }
    
    private func readDiskStats() -> (readBytes: UInt64, writeBytes: UInt64) {
        var readBytes: UInt64 = 0
        var writeBytes: UInt64 = 0
        
        // 使用 IOKit 获取磁盘统计
        let matching = IOServiceMatching("IOMedia")
        let iterator = UnsafeMutablePointer<io_iterator_t>.allocate(capacity: 1)
        defer { iterator.deallocate() }
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        
        var service = IOIteratorNext(iterator.pointee)
        while service != 0 {
            defer { 
                IOObjectRelease(service)
                service = IOIteratorNext(iterator.pointee)
            }
            
            // 获取父设备（通常是硬盘驱动器）
            var parentIterator = io_iterator_t()
            guard IORegistryEntryGetParentIterator(service, kIOServicePlane, &parentIterator) == KERN_SUCCESS else {
                continue
            }
            
            var parent = IOIteratorNext(parentIterator)
            IOObjectRelease(parentIterator)
            
            guard parent != 0 else { continue }
            defer { IOObjectRelease(parent) }
            
            // 获取统计属性
            if let properties = IORegistryEntryCreateCFProperty(parent, "Statistics" as CFString, kCFAllocatorDefault, 0) {
                if let stats = properties.takeRetainedValue() as? [String: Any] {
                    // 读取字节数
                    if let read = stats["Bytes (Read)"] as? UInt64 {
                        readBytes += read
                    }
                    // 写入字节数
                    if let write = stats["Bytes (Write)"] as? UInt64 {
                        writeBytes += write
                    }
                }
            }
        }
        
        IOObjectRelease(iterator.pointee)
        return (readBytes, writeBytes)
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
                
                // 统计物理接口 (en0, en1, etc) 和 Wi-Fi 桥接
                if ifaName.hasPrefix("en") || ifaName.hasPrefix("bridge") || ifaName.hasPrefix("lo") {
                    if let data = addr.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                        bytesIn += UInt64(networkData.ifi_ibytes)
                        bytesOut += UInt64(networkData.ifi_obytes)
                        packetsIn += UInt64(networkData.ifi_ipackets)
                        packetsOut += UInt64(networkData.ifi_opackets)
                        
                        // 跳过 loopback
                        if !ifaName.hasPrefix("lo") && (bytesIn > 0 || bytesOut > 0) {
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
        
        // 获取电池详细信息
        var cycleCount: Int?
        var health: BatteryHealth?
        
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            
            // 循环次数
            if let properties = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0) {
                if let cycles = properties.takeRetainedValue() as? Int {
                    cycleCount = cycles
                }
            }
            
            // 电池健康
            if let maxCapacityProp = IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0),
               let designCapacityProp = IORegistryEntryCreateCFProperty(service, "DesignCapacity" as CFString, kCFAllocatorDefault, 0) {
                
                if let maxCapacity = maxCapacityProp.takeRetainedValue() as? Int,
                   let designCapacity = designCapacityProp.takeRetainedValue() as? Int,
                   designCapacity > 0 {
                    
                    let healthPercent = Double(maxCapacity) / Double(designCapacity) * 100
                    
                    if healthPercent >= 80 {
                        health = .normal
                    } else if healthPercent >= 60 {
                        health = .serviceRecommended
                    } else {
                        health = .poor
                    }
                }
            }
        }
        
        return BatteryInfo(
            level: level,
            isCharging: isCharging,
            timeRemaining: timeRemaining,
            powerSource: powerSourceEnum,
            cycleCount: cycleCount,
            health: health
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
        var ambient: Double?
        var palmRest: Double?
        var fanSpeed: Int?
        
        // CPU 温度 - 尝试多种键值（不同机型不同）
        let cpuKeys = ["TC0D", "TC0E", "TC0F", "TC0H", "TC0P", "TC0C", "TCAD"]
        for key in cpuKeys {
            if let temp = readTemperature(key: key) {
                cpu = temp
                break
            }
        }
        
        // GPU 温度
        let gpuKeys = ["TG0D", "TG0P", "TGDD", "TG1D"]
        for key in gpuKeys {
            if let temp = readTemperature(key: key) {
                gpu = temp
                break
            }
        }
        
        // 电池温度
        let batteryKeys = ["TB0T", "TB1T", "TB2T", "TB3T"]
        for key in batteryKeys {
            if let temp = readTemperature(key: key) {
                battery = temp
                break
            }
        }
        
        // 环境温度
        ambient = readTemperature(key: "TA0P")
        
        // 掌托温度
        palmRest = readTemperature(key: "Th0H") ?? readTemperature(key: "Th1H")
        
        // 风扇转速 - 尝试多个风扇
        let fanKeys = ["F0Ac", "F1Ac", "F2Ac"]
        for key in fanKeys {
            if let speed = readFanSpeed(key: key) {
                fanSpeed = speed
                break
            }
        }
        
        return TemperatureInfo(
            cpu: cpu,
            gpu: gpu,
            battery: battery,
            ambient: ambient,
            palmRest: palmRest,
            fanSpeed: fanSpeed
        )
    }
    
    private func readTemperature(key: String) -> Double? {
        guard smcConnection != 0 else { return nil }
        
        var input = SMCKeyData()
        var output = SMCKeyData()
        var inputSize = Int(MemoryLayout<SMCKeyData>.size)
        var outputSize = Int(MemoryLayout<SMCKeyData>.size)
        
        // 将键名转换为 4 字节代码
        let keyBytes = key.utf8.map { UInt8($0) }
        guard keyBytes.count == 4 else { return nil }
        
        input.key = UInt32(bytes: keyBytes)
        input.data8 = SMC_CMD_READ_KEYINFO
        
        let result = IOConnectCallStructMethod(
            smcConnection,
            UInt32(KERNEL_INDEX_SMC),
            &input,
            inputSize,
            &output,
            &outputSize
        )
        
        guard result == KERN_SUCCESS else { return nil }
        
        let dataSize = output.keyInfo.dataSize
        
        input.keyInfo.dataSize = dataSize
        input.data8 = SMC_CMD_READ_BYTES
        
        let result2 = IOConnectCallStructMethod(
            smcConnection,
            UInt32(KERNEL_INDEX_SMC),
            &input,
            inputSize,
            &output,
            &outputSize
        )
        
        guard result2 == KERN_SUCCESS else { return nil }
        
        // 解析温度值 (SP78 格式: 高字节整数，低字节小数)
        let temp = Double(output.bytes.0) + Double(output.bytes.1) / 256.0
        return temp
    }
    
    private func readFanSpeed(key: String) -> Int? {
        guard let value = readSMCValue(key: key) else { return nil }
        return Int(value)
    }
    
    private func readSMCValue(key: String) -> UInt16? {
        guard smcConnection != 0 else { return nil }
        
        var input = SMCKeyData()
        var output = SMCKeyData()
        var inputSize = Int(MemoryLayout<SMCKeyData>.size)
        var outputSize = Int(MemoryLayout<SMCKeyData>.size)
        
        let keyBytes = key.utf8.map { UInt8($0) }
        guard keyBytes.count == 4 else { return nil }
        
        input.key = UInt32(bytes: keyBytes)
        input.data8 = SMC_CMD_READ_KEYINFO
        
        let result = IOConnectCallStructMethod(
            smcConnection,
            UInt32(KERNEL_INDEX_SMC),
            &input,
            inputSize,
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
            inputSize,
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
    
    // 存储进程的 CPU 时间
    private var processCPUTimes: [Int32: (total: UInt64, timestamp: Date)] = [:]
    private let lock = DispatchSemaphore(value: 1)
    
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
        
        let now = Date()
        
        for proc in procList {
            let pid = proc.kp_proc.p_pid
            let name = withUnsafePointer(to: proc.kp_proc.p_comm) {
                String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
            }
            
            // 获取内存使用 (RSS)
            let memSize = UInt64(proc.kp_eproc.e_xrssize) * UInt64(vm_kernel_page_size)
            
            // 获取 CPU 使用率
            let cpuUsage = getProcessCPUUsage(pid: pid, kinfoProc: proc, now: now)
            
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
        
        // 按内存排序（默认）
        processList.sort { $0.memoryUsage > $1.memoryUsage }
        return Array(processList.prefix(limit))
    }
    
    private func getProcessCPUUsage(pid: Int32, kinfoProc: kinfo_proc, now: Date) -> Double {
        // 使用 proc_pid_rusage 获取 CPU 时间
        var usage: rusage_info_t?
        let result = proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, &usage)
        
        guard result == 0, let info = usage else { return 0 }
        
        // 从 rusage_info_v6 获取时间
        // ri_user_time 和 ri_system_time 是 uint64_t，单位是纳秒
        let infoPtr = info.assumingMemoryBound(to: rusage_info_current.self).pointee
        let totalTime = infoPtr.ri_user_time + infoPtr.ri_system_time
        
        lock.wait()
        defer { lock.signal() }
        
        // 计算增量
        if let prev = processCPUTimes[pid] {
            let elapsed = now.timeIntervalSince(prev.timestamp)
            guard elapsed > 0 else { return 0 }
            
            let timeDelta = Double(totalTime - prev.total) / 1_000_000_000.0  // 纳秒转秒
            let cpuPercent = timeDelta / elapsed * 100.0  // 转换为百分比
            
            // 更新记录
            processCPUTimes[pid] = (totalTime, now)
            
            // 限制最大值（单核最大 100%，多核可以超过）
            return min(cpuPercent, Double(ProcessInfo.processInfo.processorCount) * 100.0)
        } else {
            // 首次记录
            processCPUTimes[pid] = (totalTime, now)
            return 0
        }
    }
}
