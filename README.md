# Accessgram

A native macOS Telegram client built from scratch with **first-class VoiceOver accessibility**. Every screen, every message, every action is reachable without a mouse and announces itself correctly to screen readers.

> **Status: early alpha.** Core messaging works. Many Telegram features are not yet implemented — see the [TODO](#todo) section.

---

## Features

| Area | What works |
|---|---|
| **Auth** | Phone → SMS code → 2FA password |
| **Chats** | Chat list, unread badges, search, pin/unpin, mark as unread |
| **Messages** | Text, photos, videos, audio, documents, stickers, animated emoji, voice notes, locations, contacts, polls, forwarded messages, pinned messages |
| **Service messages** | Title change, members added/removed, group creation, screenshot taken, auto-delete timer, etc. |
| **Actions** | Reply, edit (own messages), forward, delete, reactions |
| **Search** | Per-chat full-text search |
| **Contacts** | Browse and open conversations from your contact list |
| **Notifications** | System notifications with chat open on click |
| **Settings** | Profile info, notification settings per scope, privacy rules, active sessions management |
| **Accessibility** | Full VoiceOver labels on every element, live message announcements, custom rotor actions, keyboard shortcuts |

---

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later (Swift 5.9+)
- TDLib installed via Homebrew: `brew install tdlib`
- Telegram API credentials from <https://my.telegram.org>

---

## Setup

### 1. Install TDLib

```bash
brew install tdlib
```

### 2. Get API credentials

Go to <https://my.telegram.org>, log in, and create an app to get your **API ID** and **API hash**.

### 3. Add credentials to the project

Open `Sources/Accessgram/ViewModels/AppViewModel.swift` and replace:

```swift
private let apiId: Int    = 0   // ← your API ID
private let apiHash: String = "" // ← your API hash
```

### 4. Run

```bash
open Package.swift
```

Xcode will open the Swift Package. Select the **Accessgram** scheme and press **⌘R**.

---

## Accessibility

### VoiceOver — Chat List

Each row is announced as a single combined element:

> *"Alice, 3 unread, Last: You: Hello, 14:32"*

Unread badges on tab bar tabs are read:

> *"Messages, 12 unread"*

### VoiceOver — Chat View

Every message bubble announces: **sender → content → time → read status → reactions**

| Message type | Announcement |
|---|---|
| Text | *"Alice, Good morning!, at 09:15"* |
| Photo | *"Bob, Photo: sunset view, at 18:40"* |
| Voice | *"Alice, Voice message, 0:32, at 10:05"* |
| Sticker | *"Alice, 🔥 sticker, at 12:00"* |
| Service | *"Joined the group"* (no bubble, centered) |

Incoming messages are **announced automatically** via `NSAccessibility.announcementRequested` — no need to move focus.

### VoiceOver — Rotor Actions

With VoiceOver focus on a message bubble (**VO+U → Actions**):
- **Reply** — quote the message in your reply
- **Edit** — edit your own messages
- **Forward** — forward to another chat
- **Delete** — delete the message

### Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| ⌘1 | Switch to Messages tab |
| ⌘2 | Switch to Contacts tab |
| ⌘3 | Open Settings |
| ⌘F | Search within current chat |
| ⌘N | Focus message input field |
| ⏎ Return | Send message |
| ⇧⏎ Shift+Return | New line in message |
| ⌘↓ | Jump to latest message |

---

## Project Structure

```
Sources/
├── CTDLib/                        C header + modulemap for TDLib
└── Accessgram/
    ├── AccessgramApp.swift        App entry point + notification handling
    ├── TDLib/
    │   ├── TDLibClient.swift      Swift actor wrapping TDLib JSON API
    │   ├── TDLibClient+Auth.swift Auth API calls
    │   ├── TDLibClient+Chats.swift Message/history API calls
    │   ├── TDLibClient+ChatList.swift Chat list API calls
    │   ├── TDLibClient+Settings.swift Notifications/privacy/sessions API
    │   ├── TDLibTypes.swift       All data types (Message, Chat, etc.)
    │   └── TDLibUpdate.swift      TDLib update event parsing
    ├── Models/
    │   ├── Chat.swift
    │   ├── Message.swift
    │   └── User.swift
    ├── Services/
    │   └── NotificationService.swift
    ├── ViewModels/
    │   ├── AppViewModel.swift       Auth state machine
    │   ├── ChatListViewModel.swift
    │   ├── ChatViewModel.swift      Message loading, updates, scroll
    │   ├── ChatViewModel+Actions.swift Forward/edit/react
    │   ├── ProfileViewModel.swift
    │   └── SettingsViewModel.swift
    └── Views/
        ├── Auth/            Phone / code / password entry screens
        ├── Chat/            Message bubbles, input bar, audio player
        ├── ChatList/        Sidebar list with search and compose
        ├── Contacts/        Contact browser
        ├── Profile/         Chat/user profile sheet
        ├── Settings/        Settings sheet (notifications, privacy, sessions)
        ├── MainView.swift   Split-view shell with tab bar
        └── RootView.swift   Auth state router
```

---

## TODO

### Bugs / polish
- [x] Initial chat open sometimes loads fewer than 50 messages on a cold cache — spinner shown while loading; retries if <10 messages returned
- [x] Long messages don't have a "show more / show less" toggle
- [ ] No in-app error recovery for TDLib initialization failures beyond "Try Again"
- [x] Message timestamps don't show full date for older messages (only time)
- [x] Sticker rendering is emoji text-only — now downloads WebP and renders as image, falls back to emoji for Lottie/unknown formats

### Missing message types
- [x] GIF / animation (`messageAnimation`)
- [ ] Invoice / payment messages
- [ ] Game messages
- [x] Dice messages
- [ ] Geo live location

### Missing chat features
- [x] Video playback (tap on video opens in Quick Look or default player)
- [ ] Image gallery / swipe between photos in the same chat
- [ ] Inline reply preview loads the full message from the API (currently shows quote text only)
- [ ] Message scheduling
- [ ] Slow-mode indicator for groups
- [ ] Supergroup/channel member list
- [x] Message link copying (supergroups/channels)
- [ ] Rich text formatting in composer (bold, italic, code)
- [ ] Link preview in outgoing messages
- [x] Drag-and-drop file attachments

### Missing screens
- [x] Global search (across all chats)
- [x] Saved Messages chat
- [ ] Chat folders / filters sidebar
- [ ] Notification settings per individual chat (not just scope)
- [ ] Blocked users list
- [ ] Two-step verification settings
- [ ] Privacy exceptions (allow/deny specific users)

### Platform / infrastructure
- [ ] Push notifications via Apple Push Notification service (currently polls)
- [ ] Multiple Telegram accounts
- [ ] iCloud backup of local settings
- [ ] Crash reporting
- [ ] App Sandbox + hardened runtime for distribution
- [ ] Localization (currently English only)
