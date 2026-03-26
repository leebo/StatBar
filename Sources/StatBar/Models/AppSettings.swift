import Foundation
import Combine
import ServiceManagement

// MARK: - 应用设置

public class AppSettings: ObservableObject {
    
    // MARK: - 显示设置
    
    @Published public var showCPU: Bool = true {
        didSet { save() }
    }
    
    @Published public var showMemory: Bool = true {
        didSet { save() }
    }
    
    @Published public var showDisk: Bool = false {
        didSet { save() }
    }
    
    @Published public var showNetwork: Bool = true {
        didSet { save() }
    }
    
    @Published public var showBattery: Bool = true {
        didSet { save() }
    }
    
    @Published public var showTemperature: Bool = false {
        didSet { save() }
    }
    
    @Published public var showProcesses: Bool = true {
        didSet { save() }
    }
    
    // MARK: - 更新间隔
    
    @Published public var updateInterval: TimeInterval = 1.0 {
        didSet { save() }
    }
    
    // MARK: - 进程排序
    
    @Published public var processSortBy: ProcessSortType = .memory {
        didSet { save() }
    }
    
    public enum ProcessSortType: String, CaseIterable {
        case cpu = "CPU 使用率"
        case memory = "内存使用"
        case name = "名称"
    }
    
    // MARK: - 开机自启动
    
    @Published public var launchAtLogin: Bool = false {
        didSet {
            save()
            setLaunchAtLogin(launchAtLogin)
        }
    }
    
    // MARK: - 历史数据长度
    
    @Published public var historyLength: Int = 60 {
        didSet { save() }
    }
    
    // MARK: - 私有属性
    
    private let defaults = UserDefaults.standard
    private let prefix = "com.statbar."
    
    // MARK: - 初始化
    
    public init() {
        load()
    }
    
    // MARK: - 加载/保存
    
    private func load() {
        showCPU = defaults.bool(forKey: prefix + "showCPU", defaultValue: true)
        showMemory = defaults.bool(forKey: prefix + "showMemory", defaultValue: true)
        showDisk = defaults.bool(forKey: prefix + "showDisk", defaultValue: false)
        showNetwork = defaults.bool(forKey: prefix + "showNetwork", defaultValue: true)
        showBattery = defaults.bool(forKey: prefix + "showBattery", defaultValue: true)
        showTemperature = defaults.bool(forKey: prefix + "showTemperature", defaultValue: false)
        showProcesses = defaults.bool(forKey: prefix + "showProcesses", defaultValue: true)
        updateInterval = defaults.double(forKey: prefix + "updateInterval", defaultValue: 1.0)
        historyLength = defaults.integer(forKey: prefix + "historyLength", defaultValue: 60)
        
        if let sortRaw = defaults.string(forKey: prefix + "processSortBy"),
           let sortType = ProcessSortType(rawValue: sortRaw) {
            processSortBy = sortType
        }
        
        // 检查当前登录项状态
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    
    private func save() {
        defaults.set(showCPU, forKey: prefix + "showCPU")
        defaults.set(showMemory, forKey: prefix + "showMemory")
        defaults.set(showDisk, forKey: prefix + "showDisk")
        defaults.set(showNetwork, forKey: prefix + "showNetwork")
        defaults.set(showBattery, forKey: prefix + "showBattery")
        defaults.set(showTemperature, forKey: prefix + "showTemperature")
        defaults.set(showProcesses, forKey: prefix + "showProcesses")
        defaults.set(updateInterval, forKey: prefix + "updateInterval")
        defaults.set(historyLength, forKey: prefix + "historyLength")
        defaults.set(processSortBy.rawValue, forKey: prefix + "processSortBy")
    }
    
    // MARK: - 开机自启动
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}

// MARK: - UserDefaults 扩展

extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
    
    func double(forKey key: String, defaultValue: Double) -> Double {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return double(forKey: key)
    }
    
    func integer(forKey key: String, defaultValue: Int) -> Int {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return integer(forKey: key)
    }
}
