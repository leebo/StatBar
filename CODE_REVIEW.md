# StatBar Code Review Report

## 🔴 严重问题

### 1. 磁盘读写速度始终为 0
**位置**: `SystemMonitor.swift` - `DiskService.readDiskStats()`
```swift
private func readDiskStats() -> (readBytes: UInt64, writeBytes: UInt64)? {
    // macOS 没有 /proc/diskstats，使用 IOKit 替代
    // 简化实现，返回 nil
    return nil  // ❌ 始终返回 nil
}
```
**影响**: 磁盘读写速度永远显示为 0，无法正常工作。

---

### 2. 进程 CPU 使用率在 async 上下文中使用 DispatchSemaphore
**位置**: `SystemMonitor.swift` - `ProcessService.getProcessCPUUsage()`
```swift
private let lock = DispatchSemaphore(value: 1)

private func getProcessCPUUsage(...) -> Double {
    lock.wait()  // ❌ 可能导致死锁
    defer { lock.signal() }
    ...
}
```
**影响**: 在 async 上下文中使用信号量可能导致线程阻塞。

---

## 🟡 中等问题

### 3. 内存使用计算不准确
**位置**: `SystemMonitor.swift` - `MemoryService.getUsage()`
```swift
let used = active + wired + compressed  // ❌ 不包含 speculative 等
```
**修复**: 应该使用 `used = total - free - inactive - speculative` 或 `total - free`

---

### 4. StatsHistory.addPoint 方法设计问题
**位置**: `SystemStats.swift`
```swift
private mutating func addPoint(_ array: inout [StatsDataPoint], ...) {
    // 当前使用 workaround 避免 exclusive access 问题
}
```
**建议**: 使用 actor 或更优雅的并发安全设计。

---

### 5. 进程列表每次访问都重新排序
**位置**: `MenuBarViews.swift` - `ProcessListView`
```swift
private var sortedProcesses: [ProcessEntry] {
    // ❌ 每次访问都重新排序
    switch settings.processSortBy {
    ...
    }
}
```
**建议**: 缓存排序结果。

---

### 6. 设置窗口可能创建多个
**位置**: `MenuBarViews.swift` - `openSettings()`
```swift
if let window = NSApplication.shared.windows.first(where: { $0.title == "设置" }) {
    // 可能有多个同名窗口
}
```
**建议**: 使用单例模式或检查所有同名窗口。

---

## 🟢 小问题

### 7. 网络速度显示逻辑不完善
**问题**: 速度为 0 时也显示"计算中..."
```swift
if monitor.isFirstUpdate || network.downloadSpeed == 0 {
    Text("计算中...")  // ❌ 速度确实为 0 时不应显示"计算中..."
}
```

### 8. Timer 未在正确的 RunLoop 模式
**位置**: `SystemMonitor.swift` - `start()`
```swift
RunLoop.current.add(updateTimer!, forMode: .common)
```
**注意**: 需要确保在主线程调用。

### 9. SMCKeyData 结构体未完全初始化
**位置**: `SystemMonitor.swift`
```swift
private struct SMCKeyData {
    var bytes: (UInt8, ...) = (0,0,0,...)  // 32 个字节
}
```
**建议**: 使用 `withUnsafeMutableBytes` 或更安全的 API。

---

## 🔧 建议修复优先级

1. **高优先级**: 磁盘读写速度实现
2. **中优先级**: 内存计算修正、进程排序优化
3. **低优先级**: UI 显示优化、代码清理

---

_Generated: 2026-03-27_
