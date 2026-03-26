import SwiftUI

@main
struct StatBarApp: App {
    @StateObject private var monitor = SystemMonitor()
    
    var body: some Scene {
        MenuBarExtra("StatBar") {
            MenuBarExtraView(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}
