import SwiftUI

// 辅助功能权限检测
func checkAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
    return AXIsProcessTrustedWithOptions(options as CFDictionary)
}

func requestAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    return AXIsProcessTrustedWithOptions(options as CFDictionary)
}

@main
struct StatBarApp: App {
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var settings = AppSettings()
    @State private var showPermissionAlert = false
    @State private var hasPermission = false
    
    init() {
        // 启动时检查权限
        _hasPermission = State(initialValue: checkAccessibilityPermission())
    }
    
    var body: some Scene {
        MenuBarExtra {
            if hasPermission {
                MenuBarExtraView(monitor: monitor, settings: settings)
            } else {
                PermissionView(hasPermission: $hasPermission)
            }
        } label: {
            if hasPermission {
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
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("需要权限")
                        .font(.system(size: 11))
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

// 权限请求视图
struct PermissionView: View {
    @Binding var hasPermission: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("需要系统权限")
                .font(.headline)
            
            Text("StatBar 需要辅助功能权限才能监控系统状态。\n\n请按以下步骤操作：")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("1.")
                    Text("点击下方按钮打开系统设置")
                }
                HStack {
                    Text("2.")
                    Text("找到「隐私与安全性」→「辅助功能」")
                }
                HStack {
                    Text("3.")
                    Text("点击 + 按钮添加 StatBar")
                }
                HStack {
                    Text("4.")
                    Text("勾选启用 StatBar")
                }
            }
            .font(.subheadline)
            .padding(.horizontal)
            
            Button(action: {
                // 请求权限（会弹出系统提示）
                _ = requestAccessibilityPermission()
                
                // 打开系统偏好设置
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("打开系统设置")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button(action: {
                // 重新检查权限
                hasPermission = checkAccessibilityPermission()
            }) {
                Text("我已经授权，重新检查")
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
        .frame(width: 300)
    }
}
