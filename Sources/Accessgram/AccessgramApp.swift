import SwiftUI

@main
struct AccessgramApp: App {
    @State private var appViewModel = AppViewModel()

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
