import SwiftUI

// MARK: - 设置视图

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings, monitor: monitor)
                .tabItem {
                    Label("通用", systemImage: "gear")
                }
            
            DisplaySettingsView(settings: settings)
                .tabItem {
                    Label("显示", systemImage: "eye")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - 通用设置

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        Form {
            Section("更新频率") {
                Picker("刷新间隔", selection: $settings.updateInterval) {
                    Text("0.5 秒").tag(0.5)
                    Text("1 秒").tag(1.0)
                    Text("2 秒").tag(2.0)
                    Text("5 秒").tag(5.0)
                }
                .onChange(of: settings.updateInterval) { _ in
                    monitor.updateInterval = settings.updateInterval
                }
            }
            
            Section("历史数据") {
                Picker("历史长度", selection: $settings.historyLength) {
                    Text("30 秒").tag(30)
                    Text("60 秒").tag(60)
                    Text("120 秒").tag(120)
                    Text("300 秒").tag(300)
                }
            }
            
            Section("进程列表") {
                Picker("排序方式", selection: $settings.processSortBy) {
                    ForEach(AppSettings.ProcessSortType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
            
            Section("启动") {
                Toggle("开机自启动", isOn: $settings.launchAtLogin)
                    .help("登录时自动启动 StatBar")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - 显示设置

struct DisplaySettingsView: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section("菜单栏显示") {
                Toggle("CPU 使用率", isOn: $settings.showCPU)
                Toggle("内存使用", isOn: $settings.showMemory)
                Toggle("网络速度", isOn: $settings.showNetwork)
                Toggle("电池状态", isOn: $settings.showBattery)
                Toggle("温度", isOn: $settings.showTemperature)
            }
            
            Section("下拉面板") {
                Toggle("显示进程列表", isOn: $settings.showProcesses)
                Toggle("显示磁盘信息", isOn: $settings.showDisk)
            }
            
            Section("说明") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("提示")
                        .font(.headline)
                    Text("• 菜单栏显示的项目会影响菜单栏宽度")
                    Text("• 温度传感器需要管理员权限")
                    Text("• 进程 CPU 使用率需要额外权限")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
