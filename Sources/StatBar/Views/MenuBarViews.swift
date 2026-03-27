import SwiftUI

// MARK: - 下拉面板视图

struct MenuBarExtraView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    @State private var selectedTab: DetailTab = .cpu
    
    enum DetailTab: String, CaseIterable {
        case cpu = "CPU"
        case memory = "内存"
        case disk = "磁盘"
        case network = "网络"
        case battery = "电池"
        case processes = "进程"
        
        var icon: String {
            switch self {
            case .cpu: return "cpu"
            case .memory: return "memorychip"
            case .disk: return "externaldrive"
            case .network: return "network"
            case .battery: return "battery.100"
            case .processes: return "list.bullet"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab 选择器
            HStack(spacing: 0) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            Text(tab.rawValue)
                                .font(.system(size: 10))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedTab {
                    case .cpu:
                        CPUDetailView(monitor: monitor, settings: settings)
                    case .memory:
                        MemoryDetailView(monitor: monitor, settings: settings)
                    case .disk:
                        DiskDetailView(monitor: monitor)
                    case .network:
                        NetworkDetailView(monitor: monitor, settings: settings)
                    case .battery:
                        BatteryDetailView(monitor: monitor)
                    case .processes:
                        ProcessListView(monitor: monitor, settings: settings)
                    }
                }
                .padding()
            }
            .frame(height: 420)
            
            Divider()
            
            // 底部操作
            HStack {
                Button {
                    openSettings()
                } label: {
                    Label("设置", systemImage: "gear")
                }
                
                Spacer()
                
                if let cpu = monitor.cpu {
                    Text(String(format: "CPU: %.0f%%", cpu.usage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("退出", systemImage: "power")
                }
            }
            .padding()
        }
        .frame(width: 340)
    }
    
    private func openSettings() {
        // 激活应用
        NSApp.activate(ignoringOtherApps: true)
        
        // 查找或创建设置窗口
        if let window = NSApplication.shared.windows.first(where: { $0.title == "设置" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // 手动创建设置窗口
            let settingsView = SettingsView(settings: settings, monitor: monitor)
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 500, height: 400))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - CPU 详情视图

struct CPUDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    
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
                    }
                }
                
                // 详细信息
                HStack(spacing: 16) {
                    GaugeView(value: cpu.user / 100, color: .blue, label: "用户")
                    GaugeView(value: cpu.system / 100, color: .red, label: "系统")
                    GaugeView(value: cpu.idle / 100, color: .gray, label: "空闲")
                }
                
                // 每个核心的使用率
                if !cpu.coreUsages.isEmpty {
                    Divider()
                    
                    Text("各核心使用率")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 显示所有核心（按 4 列排列）
                    let columns = 4
                    let rows = (cpu.coreCount + columns - 1) / columns
                    
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<columns, id: \.self) { col in
                                let index = row * columns + col
                                if index < cpu.coreCount {
                                    CoreUsageView(
                                        index: index,
                                        usage: cpu.coreUsages[index]
                                    )
                                }
                            }
                        }
                    }
                }
            } else {
                // 首次加载时显示加载状态
                HStack {
                    VStack(alignment: .leading) {
                        Text("CPU 使用率")
                            .font(.headline)
                        Text("计算中...")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            
            Divider()
            
            // 历史图表
            Text("历史 (\(settings.historyLength)秒)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !monitor.history.cpu.isEmpty {
                LineChartView(data: monitor.history.cpu, color: .blue)
                    .frame(height: 80)
            } else {
                Text("等待数据...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 80)
            }
        }
    }
}

// MARK: - 核心使用率视图

struct CoreUsageView: View {
    let index: Int
    let usage: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Text("C\(index)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
            
            // 小型进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForUsage(usage))
                        .frame(width: geometry.size.width * CGFloat(usage / 100))
                }
            }
            .frame(height: 6)
            
            Text(String(format: "%.0f%%", usage))
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(width: 36)
    }
    
    private func colorForUsage(_ usage: Double) -> Color {
        if usage > 80 {
            return .red
        } else if usage > 50 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - 内存详情视图

struct MemoryDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    
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
            Text("历史 (\(settings.historyLength)秒)")
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
                // 读写速度面板（始终显示）
                HStack(spacing: 24) {
                    VStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.green)
                        Text(disk.readSpeedFormatted)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("读取")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Image(systemName: "arrow.up.circle")
                            .foregroundColor(.blue)
                        Text(disk.writeSpeedFormatted)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("写入")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                Divider()
                
                // 分区列表
                Text("磁盘分区")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(disk.partitions) { partition in
                    DiskPartitionRow(partition: partition)
                }
            }
        }
    }
}

// MARK: - 磁盘分区行

struct DiskPartitionRow: View {
    let partition: DiskPartitionInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // 分区名称和图标
                HStack(spacing: 4) {
                    Image(systemName: partition.isRoot ? "internaldrive" : "externaldrive")
                        .font(.caption)
                        .foregroundColor(partition.isRoot ? .blue : .secondary)
                    
                    Text(partition.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if partition.isRoot {
                        Text("系统")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue)
                            .cornerRadius(3)
                    }
                }
                
                Spacer()
                
                // 使用百分比
                Text(String(format: "%.0f%%", partition.usagePercent))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(partition.usagePercent > 80 ? .red : .primary)
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(partition.usagePercent > 80 ? Color.red : (partition.usagePercent > 60 ? Color.orange : Color.blue))
                        .frame(width: geometry.size.width * CGFloat(partition.usagePercent / 100))
                }
            }
            .frame(height: 6)
            
            // 容量信息
            HStack {
                Text(String(format: "%.0f GB 可用", partition.freeGB))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f / %.0f GB", partition.usedGB, partition.totalGB))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 网络详情视图

struct NetworkDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    
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
                Text("历史 (\(settings.historyLength)秒)")
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
            } else {
                Text("网络信息加载中...")
                    .foregroundColor(.secondary)
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
                    
                    if let time = battery.timeRemaining, time > 0 {
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
                                .foregroundColor(health == .normal ? .green : health == .serviceRecommended ? .orange : .red)
                        }
                    }
                }
                .font(.subheadline)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "battery.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("无电池信息")
                        .foregroundColor(.secondary)
                    Text("此设备可能没有内置电池")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }
}

// MARK: - 进程列表视图

struct ProcessListView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 排序选择
            HStack {
                Text("进程")
                    .font(.headline)
                
                Spacer()
                
                Picker("排序", selection: $settings.processSortBy) {
                    ForEach(AppSettings.ProcessSortType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            
            // 进程列表
            if monitor.topProcesses.isEmpty {
                Text("加载中...")
                    .foregroundColor(.secondary)
            } else {
                ForEach(sortedProcesses) { process in
                    ProcessRow(process: process)
                }
            }
        }
    }
    
    private var sortedProcesses: [ProcessEntry] {
        switch settings.processSortBy {
        case .cpu:
            return monitor.topProcesses.sorted { $0.cpuUsage > $1.cpuUsage }
        case .memory:
            return monitor.topProcesses.sorted { $0.memoryUsage > $1.memoryUsage }
        case .name:
            return monitor.topProcesses.sorted { $0.name < $1.name }
        }
    }
}

struct ProcessRow: View {
    let process: ProcessEntry
    
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
                
                if process.cpuUsage > 0 {
                    Text(String(format: "%.1f%%", process.cpuUsage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
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
                    .trim(from: 0, to: min(value, 1.0))
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
    var maxPoints: Int = 60
    
    var body: some View {
        GeometryReader { geometry in
            let displayData = Array(data.suffix(maxPoints))
            
            ZStack {
                // 背景网格
                Path { path in
                    let height = geometry.size.height
                    for i in 0...4 {
                        let y = height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                
                // 数据线
                Path { path in
                    guard displayData.count > 1 else { return }
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(max(displayData.count - 1, 1))
                    
                    let values = displayData.map(\.value)
                    let maxValue = values.max() ?? 1
                    let minValue = values.min() ?? 0
                    
                    // 处理所有值相同的情况
                    let range: Double
                    if maxValue == minValue {
                        // 所有值相同，让线条在中间
                        range = max(maxValue * 2, 1)
                    } else {
                        range = maxValue - minValue
                    }
                    
                    for (index, point) in displayData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedValue: Double
                        if maxValue == minValue {
                            normalizedValue = 0.5  // 中间位置
                        } else {
                            normalizedValue = (point.value - minValue) / range
                        }
                        let y = height - CGFloat(normalizedValue) * height * 0.9 - height * 0.05
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                // 填充区域
                Path { path in
                    guard displayData.count > 1 else { return }
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(max(displayData.count - 1, 1))
                    
                    let values = displayData.map(\.value)
                    let maxValue = values.max() ?? 1
                    let minValue = values.min() ?? 0
                    
                    let range: Double
                    if maxValue == minValue {
                        range = max(maxValue * 2, 1)
                    } else {
                        range = maxValue - minValue
                    }
                    
                    path.move(to: CGPoint(x: 0, y: height))
                    
                    for (index, point) in displayData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedValue: Double
                        if maxValue == minValue {
                            normalizedValue = 0.5
                        } else {
                            normalizedValue = (point.value - minValue) / range
                        }
                        let y = height - CGFloat(normalizedValue) * height * 0.9 - height * 0.05
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    path.addLine(to: CGPoint(x: CGFloat(displayData.count - 1) * stepX, y: height))
                    path.closeSubpath()
                }
                .fill(color.opacity(0.1))
            }
        }
    }
}
