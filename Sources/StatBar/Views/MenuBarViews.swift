import SwiftUI

// MARK: - 菜单栏视图

struct MenuBarView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        HStack(spacing: 8) {
            // CPU
            if let cpu = monitor.cpu {
                MetricIcon(name: "cpu", color: .blue)
                Text(String(format: "%.0f%%", cpu.usage))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            Divider()
            
            // 内存
            if let memory = monitor.memory {
                MetricIcon(name: "memorychip", color: .purple)
                Text(String(format: "%.1fG", memory.usedGB))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            Divider()
            
            // 网络
            if let network = monitor.network {
                MetricIcon(name: "network", color: .green)
                HStack(spacing: 2) {
                    Text("↓\(network.downloadSpeedFormatted)")
                    Text("↑\(network.uploadSpeedFormatted)")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - 指标图标

struct MetricIcon: View {
    let name: String
    let color: Color
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(color)
            .font(.system(size: 12))
    }
    
    private var iconName: String {
        switch name {
        case "cpu": return "cpu"
        case "memorychip": return "memorychip"
        case "network": return "network"
        case "battery": return "battery.100"
        case "thermometer": return "thermometer.medium"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - 下拉面板视图

struct MenuBarExtraView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var selectedTab: DetailTab = .cpu
    
    enum DetailTab: String, CaseIterable {
        case cpu = "CPU"
        case memory = "内存"
        case disk = "磁盘"
        case network = "网络"
        case battery = "电池"
        case processes = "进程"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab 选择器
            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedTab {
                    case .cpu:
                        CPUDetailView(monitor: monitor)
                    case .memory:
                        MemoryDetailView(monitor: monitor)
                    case .disk:
                        DiskDetailView(monitor: monitor)
                    case .network:
                        NetworkDetailView(monitor: monitor)
                    case .battery:
                        BatteryDetailView(monitor: monitor)
                    case .processes:
                        ProcessListView(monitor: monitor)
                    }
                }
                .padding()
            }
            .frame(height: 400)
            
            Divider()
            
            // 底部操作
            HStack {
                Button("设置") {
                    // 打开设置窗口
                }
                
                Spacer()
                
                Button("退出 StatBar") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        }
        .frame(width: 320)
    }
}

// MARK: - CPU 详情视图

struct CPUDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 当前值
            if let cpu = monitor.cpu {
                HStack {
                    VStack(alignment: .leading) {
                        Text("CPU 使用率")
                            .font(.headline)
                        Text(String(format: "%.1f%%", cpu.usage))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(cpu.coreCount) 核心")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let temp = cpu.temperature {
                            Text(String(format: "%.0f°C", temp))
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // 详细信息
                HStack(spacing: 16) {
                    GaugeView(value: cpu.user / 100, color: .blue, label: "用户")
                    GaugeView(value: cpu.system / 100, color: .red, label: "系统")
                    GaugeView(value: cpu.idle / 100, color: .gray, label: "空闲")
                }
            }
            
            Divider()
            
            // 历史图表
            Text("历史 (60秒)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !monitor.history.cpu.isEmpty {
                LineChartView(data: monitor.history.cpu, color: .blue)
                    .frame(height: 80)
            }
        }
    }
}

// MARK: - 内存详情视图

struct MemoryDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let memory = monitor.memory {
                HStack {
                    VStack(alignment: .leading) {
                        Text("内存")
                            .font(.headline)
                        Text(String(format: "%.1f / %.1f GB", memory.usedGB, memory.totalGB))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(memory.pressure.rawValue)
                            .font(.subheadline)
                            .foregroundColor(memory.pressure == .nominal ? .green : .orange)
                        
                        Text(String(format: "%.0f%%", memory.usagePercent))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 内存详情
                VStack(alignment: .leading, spacing: 8) {
                    MemoryBar(title: "活跃", value: Double(memory.active), total: Double(memory.total), color: .blue)
                    MemoryBar(title: "非活跃", value: Double(memory.inactive), total: Double(memory.total), color: .purple)
                    MemoryBar(title: "固定", value: Double(memory.wired), total: Double(memory.total), color: .red)
                    MemoryBar(title: "压缩", value: Double(memory.compressed), total: Double(memory.total), color: .orange)
                }
            }
            
            Divider()
            
            // 历史图表
            Text("历史 (60秒)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !monitor.history.memory.isEmpty {
                LineChartView(data: monitor.history.memory, color: .purple)
                    .frame(height: 80)
            }
        }
    }
}

struct MemoryBar: View {
    let title: String
    let value: Double
    let total: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .frame(width: 50, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value / total))
                }
            }
            .frame(height: 8)
            
            Text(formatBytes(UInt64(value)))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - 磁盘详情视图

struct DiskDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let disk = monitor.disk {
                HStack {
                    VStack(alignment: .leading) {
                        Text("磁盘")
                            .font(.headline)
                        Text(disk.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(String(format: "%.0f%% 已用", disk.usagePercent))
                            .font(.headline)
                        Text(String(format: "%.0f GB 可用", disk.freeGB))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 使用进度条
                ProgressView(value: Double(disk.used), total: Double(disk.total))
                    .tint(disk.usagePercent > 80 ? .red : .blue)
                
                HStack {
                    Text(String(format: "%.0f GB 已用", Double(disk.used) / 1_073_741_824.0))
                    Spacer()
                    Text(String(format: "%.0f GB 总计", disk.totalGB))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 网络详情视图

struct NetworkDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let network = monitor.network {
                HStack {
                    VStack(alignment: .leading) {
                        Text("网络")
                            .font(.headline)
                        Text("接口: \(network.interface)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // 上传下载速度
                HStack(spacing: 24) {
                    VStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text(network.downloadSpeedFormatted)
                            .font(.headline)
                        Text("下载")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        Text(network.uploadSpeedFormatted)
                            .font(.headline)
                        Text("上传")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                
                Divider()
                
                // 历史图表
                Text("历史 (60秒)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !monitor.history.networkDown.isEmpty {
                    VStack(alignment: .leading) {
                        Text("下载")
                            .font(.caption)
                            .foregroundColor(.green)
                        LineChartView(data: monitor.history.networkDown, color: .green)
                            .frame(height: 50)
                    }
                }
                
                if !monitor.history.networkUp.isEmpty {
                    VStack(alignment: .leading) {
                        Text("上传")
                            .font(.caption)
                            .foregroundColor(.blue)
                        LineChartView(data: monitor.history.networkUp, color: .blue)
                            .frame(height: 50)
                    }
                }
            }
        }
    }
}

// MARK: - 电池详情视图

struct BatteryDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let battery = monitor.battery {
                HStack {
                    VStack(alignment: .leading) {
                        Text("电池")
                            .font(.headline)
                        Text(String(format: "%d%%", battery.level))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.100")
                            .font(.largeTitle)
                            .foregroundColor(battery.isCharging ? .green : .primary)
                        
                        Text(battery.powerSource.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 详细信息
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("状态")
                        Spacer()
                        Text(battery.isCharging ? "充电中" : "使用电池")
                            .foregroundColor(battery.isCharging ? .green : .primary)
                    }
                    
                    if let time = battery.timeRemaining {
                        HStack {
                            Text("剩余时间")
                            Spacer()
                            Text("\(time) 分钟")
                        }
                    }
                    
                    if let cycles = battery.cycleCount {
                        HStack {
                            Text("循环次数")
                            Spacer()
                            Text("\(cycles)")
                        }
                    }
                    
                    if let health = battery.health {
                        HStack {
                            Text("电池健康")
                            Spacer()
                            Text(health.rawValue)
                                .foregroundColor(health == .normal ? .green : .orange)
                        }
                    }
                }
                .font(.subheadline)
            } else {
                Text("无电池信息")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 进程列表视图

struct ProcessListView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var sortBy: ProcessSort = .memory
    
    enum ProcessSort {
        case cpu, memory
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 排序选择
            HStack {
                Text("进程")
                    .font(.headline)
                
                Spacer()
                
                Picker("排序", selection: $sortBy) {
                    Text("CPU").tag(ProcessSort.cpu)
                    Text("内存").tag(ProcessSort.memory)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            // 进程列表
            if monitor.topProcesses.isEmpty {
                Text("加载中...")
                    .foregroundColor(.secondary)
            } else {
                ForEach(monitor.topProcesses) { process in
                    ProcessRow(process: process)
                }
            }
        }
    }
}

struct ProcessRow: View {
    let process: ProcessInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(process.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text("PID: \(process.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(String(format: "%.0f MB", process.memoryMB))
                    .font(.subheadline.monospacedDigit())
                
                Text(String(format: "%.1f%%", process.cpuUsage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 仪表盘视图

struct GaugeView: View {
    let value: Double
    let color: Color
    let label: String
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .frame(width: 50, height: 50)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 折线图视图

struct LineChartView: View {
    let data: [StatsDataPoint]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(data.count - 1)
                
                let maxValue = data.map(\.value).max() ?? 1
                let minValue = data.map(\.value).min() ?? 0
                let range = maxValue - minValue
                
                for (index, point) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - CGFloat((point.value - minValue) / range) * height
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
