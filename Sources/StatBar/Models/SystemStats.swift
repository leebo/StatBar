import Foundation

// MARK: - CPU 信息

public struct CPUInfo: Equatable {
    public let usage: Double           // 总使用率 (0-100)
    public let user: Double            // 用户态
    public let system: Double          // 内核态
    public let idle: Double            // 空闲
    public let temperature: Double?    // 温度 (°C)
    public let coreCount: Int          // 核心数
    public let timestamp: Date
    
    public static func == (lhs: CPUInfo, rhs: CPUInfo) -> Bool {
        lhs.usage == rhs.usage &&
        lhs.user == rhs.user &&
        lhs.system == rhs.system &&
        lhs.idle == rhs.idle &&
        lhs.temperature == rhs.temperature &&
        lhs.coreCount == rhs.coreCount
    }
    
    public init(usage: Double, user: Double, system: Double, idle: Double, 
                temperature: Double? = nil, coreCount: Int) {
        self.usage = usage
        self.user = user
        self.system = system
        self.idle = idle
        self.temperature = temperature
        self.coreCount = coreCount
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

// MARK: - 磁盘信息

public struct DiskInfo {
    public let total: UInt64           // 总空间 (bytes)
    public let free: UInt64            // 可用空间
    public let used: UInt64            // 已用空间
    public let readSpeed: UInt64       // 读取速度 (bytes/s)
    public let writeSpeed: UInt64      // 写入速度 (bytes/s)
    public let name: String            // 卷名称
    public let timestamp: Date
    
    public var freeGB: Double {
        Double(free) / 1_073_741_824.0
    }
    
    public var totalGB: Double {
        Double(total) / 1_073_741_824.0
    }
    
    public var usagePercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
    
    public init(total: UInt64, free: UInt64, used: UInt64, 
                readSpeed: UInt64, writeSpeed: UInt64, name: String) {
        self.total = total
        self.free = free
        self.used = used
        self.readSpeed = readSpeed
        self.writeSpeed = writeSpeed
        self.name = name
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
    public let timestamp: Date
    
    public init(cpu: Double? = nil, gpu: Double? = nil, battery: Double? = nil,
                ambient: Double? = nil, palmRest: Double? = nil) {
        self.cpu = cpu
        self.gpu = gpu
        self.battery = battery
        self.ambient = ambient
        self.palmRest = palmRest
        self.timestamp = Date()
    }
}

// MARK: - 进程信息

public struct ProcessInfo: Identifiable {
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
    public let topProcesses: [ProcessInfo]
    public let timestamp: Date
    
    public init(cpu: CPUInfo, memory: MemoryInfo, disk: DiskInfo, network: NetworkInfo,
                battery: BatteryInfo?, temperature: TemperatureInfo?, topProcesses: [ProcessInfo]) {
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
        
        addPoint(&self.cpu, timestamp: now, value: cpu)
        addPoint(&self.memory, timestamp: now, value: memory)
        addPoint(&self.networkDown, timestamp: now, value: Double(netDown) / 1_048_576.0)
        addPoint(&self.networkUp, timestamp: now, value: Double(netUp) / 1_048_576.0)
    }
    
    private mutating func addPoint(_ array: inout [StatsDataPoint], timestamp: Date, value: Double) {
        array.append(StatsDataPoint(timestamp: timestamp, value: value))
        if array.count > maxPoints {
            array.removeFirst()
        }
    }
}
