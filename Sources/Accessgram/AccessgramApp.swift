import SwiftUI
import AppKit

// Keeps the app alive in the background when the window is closed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationService.shared.requestPermission()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct AccessgramApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appViewModel = MainActor.assumeIsolated { AppViewModel() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appViewModel)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Log Out") {
                    Task { await appViewModel.logOut() }
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}
