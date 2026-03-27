import Foundation

// MARK: - CPU 信息

public struct CPUInfo: Equatable {
    public let usage: Double           // 总使用率 (0-100)
    public let user: Double            // 用户态
    public let system: Double          // 内核态
    public let idle: Double            // 空闲
    public let temperature: Double?    // 温度 (°C)
    public let coreCount: Int          // 核心数
    public let coreUsages: [Double]    // 每个核心的使用率
    public let timestamp: Date
    
    public static func == (lhs: CPUInfo, rhs: CPUInfo) -> Bool {
        lhs.usage == rhs.usage &&
        lhs.user == rhs.user &&
        lhs.system == rhs.system &&
        lhs.idle == rhs.idle &&
        lhs.temperature == rhs.temperature &&
        lhs.coreCount == rhs.coreCount &&
        lhs.coreUsages == rhs.coreUsages
    }
    
    public init(usage: Double, user: Double, system: Double, idle: Double, 
                temperature: Double? = nil, coreCount: Int, coreUsages: [Double] = []) {
        self.usage = usage
        self.user = user
        self.system = system
        self.idle = idle
        self.temperature = temperature
        self.coreCount = coreCount
        self.coreUsages = coreUsages
        self.timestamp = Date()
    }
}

// MARK: - 内存信息

public struct MemoryInfo {
    public let total: UInt64           // 总内存 (bytes)
    public let used: UInt64            // 已用内存
    public let free: UInt64            // 可用内存
    public let active: UInt64          // 活跃内存
    public let inactive: UInt64        // 非活跃内存
    public let wired: UInt64           // 不可分页内存
    public let compressed: UInt64      // 压缩内存
    public let pressure: MemoryPressure
    public let timestamp: Date
    
    public var usedGB: Double {
        Double(used) / 1_073_741_824.0
    }
    
    public var totalGB: Double {
        Double(total) / 1_073_741_824.0
    }
    
    public var usagePercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
    
    public init(total: UInt64, used: UInt64, free: UInt64, active: UInt64,
                inactive: UInt64, wired: UInt64, compressed: UInt64, pressure: MemoryPressure) {
        self.total = total
        self.used = used
        self.free = free
        self.active = active
        self.inactive = inactive
        self.wired = wired
        self.compressed = compressed
        self.pressure = pressure
        self.timestamp = Date()
    }
}

public enum MemoryPressure: String {
    case nominal = "正常"
    case warning = "警告"
    case critical = "紧张"
}

// MARK: - 单个磁盘分区信息

public struct DiskPartitionInfo: Identifiable, Equatable {
    public let id: String              // 挂载路径作为 ID
    public let total: UInt64           // 总空间 (bytes)
    public let free: UInt64            // 可用空间
    public let used: UInt64            // 已用空间
    public let name: String            // 卷名称
    public let mountPoint: String      // 挂载路径
    public let isRoot: Bool            // 是否为根分区
    public let timestamp: Date
    
    public var freeGB: Double {
        Double(free) / 1_073_741_824.0
    }
    
    public var totalGB: Double {
        Double(total) / 1_073_741_824.0
    }
    
    public var usedGB: Double {
        Double(used) / 1_073_741_824.0
    }
    
    public var usagePercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
    
    public static func == (lhs: DiskPartitionInfo, rhs: DiskPartitionInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.total == rhs.total &&
        lhs.free == rhs.free &&
        lhs.used == rhs.used
    }
    
    public init(total: UInt64, free: UInt64, used: UInt64, name: String, mountPoint: String) {
        self.id = mountPoint
        self.total = total
        self.free = free
        self.used = used
        self.name = name
        self.mountPoint = mountPoint
        self.isRoot = mountPoint == "/"
        self.timestamp = Date()
    }
}

// MARK: - 磁盘信息（包含多分区 + I/O 速度）

public struct DiskInfo: Equatable {
    public let partitions: [DiskPartitionInfo]  // 所有分区
    public let readBytes: UInt64                // 累计读取字节数
    public let writeBytes: UInt64               // 累计写入字节数
    public let readSpeed: UInt64                // 读取速度 (bytes/s)
    public let writeSpeed: UInt64               // 写入速度 (bytes/s)
    public let timestamp: Date
    
    // 便捷访问根分区
    public var root: DiskPartitionInfo? {
        partitions.first { $0.isRoot }
    }
    
    // 兼容旧 API
    public var total: UInt64 { root?.total ?? 0 }
    public var free: UInt64 { root?.free ?? 0 }
    public var used: UInt64 { root?.used ?? 0 }
    public var name: String { root?.name ?? "未知" }
    public var freeGB: Double { root?.freeGB ?? 0 }
    public var totalGB: Double { root?.totalGB ?? 0 }
    public var usagePercent: Double { root?.usagePercent ?? 0 }
    
    public var readSpeedFormatted: String {
        formatSpeed(readSpeed)
    }
    
    public var writeSpeedFormatted: String {
        formatSpeed(writeSpeed)
    }
    
    private func formatSpeed(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B/s"
        } else if bytes < 1_048_576 {
            return String(format: "%.1f KB/s", Double(bytes) / 1024.0)
        } else if bytes < 1_073_741_824 {
            return String(format: "%.1f MB/s", Double(bytes) / 1_048_576.0)
        } else {
            return String(format: "%.1f GB/s", Double(bytes) / 1_073_741_824.0)
        }
    }
    
    public static func == (lhs: DiskInfo, rhs: DiskInfo) -> Bool {
        lhs.partitions == rhs.partitions &&
        lhs.readSpeed == rhs.readSpeed &&
        lhs.writeSpeed == rhs.writeSpeed
    }
    
    // 初始化（无速度信息）
    public init(partitions: [DiskPartitionInfo], readBytes: UInt64, writeBytes: UInt64) {
        self.partitions = partitions
        self.readBytes = readBytes
        self.writeBytes = writeBytes
        self.readSpeed = 0
        self.writeSpeed = 0
        self.timestamp = Date()
    }
    
    // 初始化（带速度信息）
    public init(partitions: [DiskPartitionInfo], readBytes: UInt64, writeBytes: UInt64,
                readSpeed: UInt64, writeSpeed: UInt64) {
        self.partitions = partitions
        self.readBytes = readBytes
        self.writeBytes = writeBytes
        self.readSpeed = readSpeed
        self.writeSpeed = writeSpeed
        self.timestamp = Date()
    }
    
    // 兼容旧初始化方法
    public init(total: UInt64, free: UInt64, used: UInt64, 
                readBytes: UInt64, writeBytes: UInt64, name: String) {
        let partition = DiskPartitionInfo(total: total, free: free, used: used, name: name, mountPoint: "/")
        self.partitions = [partition]
        self.readBytes = readBytes
        self.writeBytes = writeBytes
        self.readSpeed = 0
        self.writeSpeed = 0
        self.timestamp = Date()
    }
    
    public init(total: UInt64, free: UInt64, used: UInt64,
                readBytes: UInt64, writeBytes: UInt64,
                readSpeed: UInt64, writeSpeed: UInt64, name: String) {
        let partition = DiskPartitionInfo(total: total, free: free, used: used, name: name, mountPoint: "/")
        self.partitions = [partition]
        self.readBytes = readBytes
        self.writeBytes = writeBytes
        self.readSpeed = readSpeed
        self.writeSpeed = writeSpeed
        self.timestamp = Date()
    }
}

// MARK: - 网络信息

public struct NetworkInfo {
    public let bytesIn: UInt64          // 接收字节数
    public let bytesOut: UInt64         // 发送字节数
    public let packetsIn: UInt64        // 接收包数
    public let packetsOut: UInt64       // 发送包数
    public let downloadSpeed: UInt64    // 下载速度 (bytes/s)
    public let uploadSpeed: UInt64      // 上传速度 (bytes/s)
    public let interface: String        // 网络接口
    public let timestamp: Date
    
    public var downloadSpeedFormatted: String {
        formatSpeed(downloadSpeed)
    }
    
    public var uploadSpeedFormatted: String {
        formatSpeed(uploadSpeed)
    }
    
    private func formatSpeed(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B/s"
        } else if bytes < 1_048_576 {
            return String(format: "%.1f KB/s", Double(bytes) / 1024.0)
        } else if bytes < 1_073_741_824 {
            return String(format: "%.1f MB/s", Double(bytes) / 1_048_576.0)
        } else {
            return String(format: "%.1f GB/s", Double(bytes) / 1_073_741_824.0)
        }
    }
    
    public init(bytesIn: UInt64, bytesOut: UInt64, packetsIn: UInt64, packetsOut: UInt64,
                downloadSpeed: UInt64, uploadSpeed: UInt64, interface: String) {
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.packetsIn = packetsIn
        self.packetsOut = packetsOut
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.interface = interface
        self.timestamp = Date()
    }
}

// MARK: - 电池信息

public struct BatteryInfo {
    public let level: Int               // 电量百分比 (0-100)
    public let isCharging: Bool         // 是否充电
    public let timeRemaining: Int?      // 剩余时间 (分钟)
    public let powerSource: PowerSource
    public let cycleCount: Int?         // 循环次数
    public let health: BatteryHealth?   // 电池健康
    public let timestamp: Date
    
    public init(level: Int, isCharging: Bool, timeRemaining: Int?, 
                powerSource: PowerSource, cycleCount: Int?, health: BatteryHealth?) {
        self.level = level
        self.isCharging = isCharging
        self.timeRemaining = timeRemaining
        self.powerSource = powerSource
        self.cycleCount = cycleCount
        self.health = health
        self.timestamp = Date()
    }
}

public enum PowerSource: String {
    case battery = "电池"
    case acPower = "电源适配器"
    case unknown = "未知"
}

public enum BatteryHealth: String {
    case normal = "正常"
    case serviceRecommended = "建议维修"
    case poor = "差"
}

// MARK: - 温度信息

public struct TemperatureInfo {
    public let cpu: Double?             // CPU 温度
    public let gpu: Double?             // GPU 温度
    public let battery: Double?         // 电池温度
    public let ambient: Double?         // 环境温度
    public let palmRest: Double?        // 掌托温度
    public let fanSpeed: Int?           // 风扇转速 (RPM)
    public let timestamp: Date
    
    public init(cpu: Double? = nil, gpu: Double? = nil, battery: Double? = nil,
                ambient: Double? = nil, palmRest: Double? = nil, fanSpeed: Int? = nil) {
        self.cpu = cpu
        self.gpu = gpu
        self.battery = battery
        self.ambient = ambient
        self.palmRest = palmRest
        self.fanSpeed = fanSpeed
        self.timestamp = Date()
    }
}

// MARK: - 进程信息

public struct ProcessEntry: Identifiable {
    public let id: Int32                // PID
    public let name: String             // 进程名
    public let cpuUsage: Double         // CPU 使用率
    public let memoryUsage: UInt64      // 内存使用 (bytes)
    public let threads: Int             // 线程数
    public let user: String             // 用户
    public let startTime: Date?         // 启动时间
    
    public var memoryMB: Double {
        Double(memoryUsage) / 1_048_576.0
    }
    
    public init(id: Int32, name: String, cpuUsage: Double, memoryUsage: UInt64,
                threads: Int, user: String, startTime: Date?) {
        self.id = id
        self.name = name
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.threads = threads
        self.user = user
        self.startTime = startTime
    }
}

// MARK: - 系统统计汇总

public struct SystemStats {
    public let cpu: CPUInfo
    public let memory: MemoryInfo
    public let disk: DiskInfo
    public let network: NetworkInfo
    public let battery: BatteryInfo?
    public let temperature: TemperatureInfo?
    public let topProcesses: [ProcessEntry]
    public let timestamp: Date
    
    public init(cpu: CPUInfo, memory: MemoryInfo, disk: DiskInfo, network: NetworkInfo,
                battery: BatteryInfo?, temperature: TemperatureInfo?, topProcesses: [ProcessEntry]) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.battery = battery
        self.temperature = temperature
        self.topProcesses = topProcesses
        self.timestamp = Date()
    }
}

// MARK: - 历史数据点

public struct StatsDataPoint: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let value: Double
    
    public init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

// MARK: - 历史数据

public struct StatsHistory {
    public var cpu: [StatsDataPoint]
    public var memory: [StatsDataPoint]
    public var networkDown: [StatsDataPoint]
    public var networkUp: [StatsDataPoint]
    public let maxPoints: Int
    
    public init(maxPoints: Int = 60) {
        self.maxPoints = maxPoints
        self.cpu = []
        self.memory = []
        self.networkDown = []
        self.networkUp = []
    }
    
    public mutating func add(cpu: Double, memory: Double, netDown: UInt64, netUp: UInt64) {
        let now = Date()
        
        // 避免独占访问冲突，逐个添加
        var cpuData = self.cpu
        addPoint(&cpuData, timestamp: now, value: cpu)
        self.cpu = cpuData
        
        var memoryData = self.memory
        addPoint(&memoryData, timestamp: now, value: memory)
        self.memory = memoryData
        
        var networkDownData = self.networkDown
        addPoint(&networkDownData, timestamp: now, value: Double(netDown) / 1_048_576.0)
        self.networkDown = networkDownData
        
        var networkUpData = self.networkUp
        addPoint(&networkUpData, timestamp: now, value: Double(netUp) / 1_048_576.0)
        self.networkUp = networkUpData
    }
    
    private mutating func addPoint(_ array: inout [StatsDataPoint], timestamp: Date, value: Double) {
        array.append(StatsDataPoint(timestamp: timestamp, value: value))
        if array.count > maxPoints {
            array.removeFirst()
        }
    }
}
