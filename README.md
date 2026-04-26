# Accessgram

A native macOS Telegram client built from the ground up with **full VoiceOver accessibility**.

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later
- TDLib installed via Homebrew: `brew install tdlib`
- Telegram API credentials from <https://my.telegram.org>

## Setup

### 1. Install TDLib

```bash
brew install tdlib
```

### 2. Add your API credentials

Open `Sources/Accessgram/ViewModels/AppViewModel.swift` and replace:

```swift
private let apiId: Int    = 0          // ← your API ID
private let apiHash: String = ""       // ← your API hash
```

### 3. Open in Xcode

```bash
open Package.swift
```

Xcode will open the Swift Package. Select the **Accessgram** scheme and press ▶ Run.

## Accessibility Features

### VoiceOver in the Chat List
- Each conversation row is announced as a single element:
  *"Alice, 3 unread messages, Last: You: Hello, 14:32"*
- Custom VoiceOver actions via the **rotor** (VO + U → Actions):
  - Reply, Copy, Delete on individual messages

### VoiceOver in Chat
- Every message bubble announces: **sender → content → time → read status**
  - Text: *"Alice, Good morning!, at 09:15"*
  - Photo: *"Bob, Photo: sunset view, at 18:40"*
  - Voice: *"Alice, Voice message, 0:32, at 10:05"*
- Incoming messages are **announced automatically** via `NSAccessibility.announcementRequested`
- **Skip shortcut** ⌘N moves VoiceOver focus directly to the message input field

### Keyboard shortcuts
| Shortcut | Action |
|---|---|
| ⌘F | Focus search |
| ⌘N | Focus message input |
| Return | Send message |
| Shift-Return | New line in message |
| ⌘⇧L | Log out |

## Project Structure

```
Sources/
├── CTDLib/                  C header + modulemap for TDLib
└── Accessgram/
    ├── AccessgramApp.swift  App entry point
    ├── TDLib/
    │   ├── TDLibClient.swift   Swift actor wrapping TDLib JSON API
    │   └── TDLibUpdate.swift   All TDLib update / data types
    ├── Models/
    │   ├── Chat.swift
    │   ├── Message.swift
    │   └── User.swift
    ├── ViewModels/
    │   ├── AppViewModel.swift       Auth state machine
    │   ├── ChatListViewModel.swift
    │   └── ChatViewModel.swift
    └── Views/
        ├── Auth/            Phone / code / password screens
        ├── ChatList/        Sidebar with search
        └── Chat/            Message bubbles + input
```
