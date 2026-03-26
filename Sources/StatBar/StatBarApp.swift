import SwiftUI

@main
struct StatBarApp: App {
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var settings = AppSettings()
    
    init() {
        // 启动监控
    }
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarExtraView(monitor: monitor, settings: settings)
        } label: {
            MenuBarLabel(monitor: monitor, settings: settings)
        }
        .menuBarExtraStyle(.window)
        .onAppear {
            monitor.start()
            checkLaunchAtLogin()
        }
        .onDisappear {
            monitor.stop()
        }
        
        // 设置窗口
        WindowGroup("设置") {
            SettingsView(settings: settings, monitor: monitor)
        }
        .defaultSize(width: 500, height: 400)
    }
    
    private func checkLaunchAtLogin() {
        // 检查是否设置了开机自启动
    }
}

// MARK: - 菜单栏标签

struct MenuBarLabel: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        HStack(spacing: 6) {
            // CPU
            if settings.showCPU, let cpu = monitor.cpu {
                HStack(spacing: 2) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                    Text(String(format: "%.0f%%", cpu.usage))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
            
            // 内存
            if settings.showMemory, let memory = monitor.memory {
                HStack(spacing: 2) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 10))
                    Text(String(format: "%.1fG", memory.usedGB))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
            
            // 网络
            if settings.showNetwork, let network = monitor.network {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9))
                    Text(network.downloadSpeedFormatted)
                        .font(.system(size: 10, design: .monospaced))
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9))
                    Text(network.uploadSpeedFormatted)
                        .font(.system(size: 10, design: .monospaced))
                }
            }
            
            // 温度
            if settings.showTemperature, let temp = monitor.temperature, let cpu = temp.cpu {
                HStack(spacing: 2) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 10))
                    Text(String(format: "%.0f°", cpu))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
            
            // 电池
            if settings.showBattery, let battery = monitor.battery {
                HStack(spacing: 2) {
                    Image(systemName: batteryIcon(for: battery))
                        .font(.system(size: 10))
                        .foregroundColor(battery.isCharging ? .green : .primary)
                    Text("\(battery.level)%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
    }
    
    private func batteryIcon(for battery: BatteryInfo) -> String {
        if battery.isCharging {
            return "battery.100.bolt"
        }
        switch battery.level {
        case 0..<20: return "battery.0"
        case 20..<40: return "battery.25"
        case 40..<60: return "battery.50"
        case 60..<80: return "battery.75"
        default: return "battery.100"
        }
    }
}
