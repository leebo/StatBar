# StatBar - macOS 性能监控菜单栏应用

类似 iStat Menus 的 macOS 菜单栏系统监控工具。

## 功能

### 核心监控
- **CPU** - 使用率、核心数、温度
- **内存** - 使用量、压力状态、详细分类
- **磁盘** - 读写速度、剩余空间
- **网络** - 上传/下载速度、接口信息
- **电池** - 电量、充电状态、循环次数

### 高级功能
- **温度传感器** - CPU/GPU/电池温度
- **进程管理** - CPU/内存排序、进程详情
- **历史图表** - 60秒历史数据曲线

## 技术栈

- **UI**: SwiftUI (macOS 11+)
- **系统数据**: IOKit + libproc
- **图表**: 自定义绘制
- **温度传感器**: SMC (System Management Controller)

## 项目结构

```
StatBar/
├── Sources/StatBar/
│   ├── StatBarApp.swift          # 入口
│   ├── Models/
│   │   └── SystemStats.swift     # 数据模型
│   ├── Services/
│   │   └── SystemMonitor.swift   # 监控服务
│   ├── Views/
│   │   └── MenuBarViews.swift    # UI 视图
│   └── Info.plist                # 配置
└── Package.swift
```

## 构建

### 使用 Xcode

1. 在 macOS 上打开项目
2. 使用 Xcode 打开 `Package.swift`
3. 选择目标为 macOS
4. 构建 (Cmd+B)

### 使用命令行

```bash
cd StatBar
swift build -c release
```

## 使用

1. 启动应用后，菜单栏会出现监控图标
2. 点击菜单栏图标显示详细面板
3. 通过标签页切换不同监控项
4. 设置页面可自定义显示项

## 注意事项

### 权限要求

- **温度传感器**: 需要管理员权限或正确签名的应用
- **进程信息**: 部分系统进程可能需要权限

### 兼容性

- **macOS 11+** (Big Sur)
- 支持 Intel 和 Apple Silicon

## 开发计划

### Phase 1: 核心监控 ✅
- [x] CPU 使用率
- [x] 内存使用
- [x] 磁盘空间
- [x] 网络速度

### Phase 2: 高级功能
- [ ] 温度传感器 (需要 SMC 访问)
- [ ] 风扇转速
- [ ] 进程 CPU 使用率

### Phase 3: UI 完善
- [ ] 设置页面
- [ ] 开机自启动
- [ ] 通知警报

## License

MIT
