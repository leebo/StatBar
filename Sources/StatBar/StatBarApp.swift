import SwiftUI

@main
struct StatBarApp: App {
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var settings = AppSettings()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarExtraView(monitor: monitor, settings: settings)
        } label: {
            HStack(spacing: 8) {
                // CPU 使用率
                HStack(spacing: 2) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                    if let cpu = monitor.cpu {
                        Text(String(format: "%.0f%%", cpu.usage))
                            .font(.system(size: 11, design: .monospaced))
                    } else {
                        Text("--")
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
                
                // 内存使用率
                HStack(spacing: 2) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 10))
                    if let memory = monitor.memory {
                        Text(String(format: "%.0f%%", memory.usagePercent))
                            .font(.system(size: 11, design: .monospaced))
                    } else {
                        Text("--")
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
                
                // 磁盘使用率
                HStack(spacing: 2) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 10))
                    if let disk = monitor.disk {
                        Text(String(format: "%.0f%%", disk.usagePercent))
                            .font(.system(size: 11, design: .monospaced))
                    } else {
                        Text("--")
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
                
                // 网络速度（可选）
                if settings.showNetworkInMenuBar, let network = monitor.network {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9))
                        Text(formatSpeed(network.downloadSpeed))
                            .font(.system(size: 10, design: .monospaced))
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9))
                        Text(formatSpeed(network.uploadSpeed))
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
            }
        }
        .menuBarExtraStyle(.window)
        
        // 设置窗口
        WindowGroup("设置") {
            SettingsView(settings: settings, monitor: monitor)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 400)
    }
    
    private func formatSpeed(_ bytesPerSec: UInt64) -> String {
        if bytesPerSec < 1024 {
            return "\(bytesPerSec)B"
        } else if bytesPerSec < 1024 * 1024 {
            return String(format: "%.0fK", Double(bytesPerSec) / 1024.0)
        } else {
            return String(format: "%.1fM", Double(bytesPerSec) / 1_048_576.0)
        }
    }
}
