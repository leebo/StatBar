import SwiftUI

@main
struct StatBarApp: App {
    @StateObject private var monitor = SystemMonitor()
    
    var body: some Scene {
        MenuBarExtra("StatBar") {
            MenuBarExtraView(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: monitor.cpu) { _ in
            print("CPU: \(String(describing: $0.cpu?.usage))")
        }
    }
}
