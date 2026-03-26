import SwiftUI

@main
struct StatBarApp: App {
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var settings = AppSettings()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarExtraView(monitor: monitor, settings: settings)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                if let cpu = monitor.cpu {
                    Text(String(format: "%.0f%%", cpu.usage))
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
        
        // 设置窗口
        WindowGroup("设置") {
            SettingsView(settings: settings)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 400)
        
        // 后台定时刷新
        .onAppear {
            monitor.updateInterval = settings.updateInterval
            monitor.start()
        }
        .onDisappear {
            monitor.stop()
        }
    }
}
