import Foundation

enum Log {
    private static let fileURL = URL(fileURLWithPath: "/Users/vytautas/Downloads/accessgram-debug.log")
    private static let queue = DispatchQueue(label: "log", qos: .utility)
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func clear() {
        queue.async {
            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    static func write(_ message: String) {
        let line = "[\(fmt.string(from: Date()))] \(message)\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: fileURL, atomically: false, encoding: .utf8)
            }
        }
    }
}
