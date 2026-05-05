import Foundation
import Observation

/// App-level preferences synced via iCloud Key-Value Store.
/// Falls back to UserDefaults when iCloud is unavailable.
@Observable
@MainActor
final class AppPreferences {
    static let shared = MainActor.assumeIsolated { AppPreferences() }

    // MARK: - Preferences

    var showFormatBar: Bool = true { didSet { save("showFormatBar", showFormatBar) } }
    var compactChatList: Bool = false { didSet { save("compactChatList", compactChatList) } }
    var playSoundOnMessage: Bool = true { didSet { save("playSoundOnMessage", playSoundOnMessage) } }
    var jumpToLatestOnOpen: Bool = true { didSet { save("jumpToLatestOnOpen", jumpToLatestOnOpen) } }

    // MARK: - iCloud status

    var iCloudAvailable: Bool = false

    // MARK: - Init

    private init() {
        load()
        iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.load() }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: - Persistence

    private func load() {
        showFormatBar = bool("showFormatBar", default: true)
        compactChatList = bool("compactChatList", default: false)
        playSoundOnMessage = bool("playSoundOnMessage", default: true)
        jumpToLatestOnOpen = bool("jumpToLatestOnOpen", default: true)
    }

    private func bool(_ key: String, default fallback: Bool) -> Bool {
        let kv = NSUbiquitousKeyValueStore.default
        // If the key has never been set in KV store, the value is false (zero).
        // Use UserDefaults as ground truth for first-launch defaults.
        if kv.object(forKey: key) != nil {
            return kv.bool(forKey: key)
        }
        return UserDefaults.standard.object(forKey: key) != nil
            ? UserDefaults.standard.bool(forKey: key)
            : fallback
    }

    private func save(_ key: String, _ value: Bool) {
        NSUbiquitousKeyValueStore.default.set(value, forKey: key)
        UserDefaults.standard.set(value, forKey: key)
    }
}
