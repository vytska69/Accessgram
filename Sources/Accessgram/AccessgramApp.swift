import AppKit
import SwiftUI

// Keeps the app alive in the background when the window is closed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Held for the app lifetime — releasing it re-enables App Nap.
    private var backgroundActivity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationService.shared.requestPermission()
        backgroundActivity = ProcessInfo.processInfo.beginActivity(
            options: [.background, .userInitiatedAllowingIdleSystemSleep],
            reason: "Receiving Telegram messages"
        )
        NSSetUncaughtExceptionHandler { exception in
            Log.writeCrash(
                reason: "\(exception.name.rawValue): \(exception.reason ?? "no reason")",
                trace: exception.callStackSymbols
            )
        }
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        Log.write("App launched — v\(version)\(sandboxed ? " [sandboxed]" : "")")
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
