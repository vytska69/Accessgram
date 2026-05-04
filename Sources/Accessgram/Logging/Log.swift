import Foundation

enum Log {
    static let fileURL: URL = {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let dir = lib.appendingPathComponent("Logs/Accessgram")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("accessgram.log")
    }()

    private static let queue = DispatchQueue(label: "log", qos: .utility)
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
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
                try? data.write(to: fileURL)
            }
        }
    }

    static func writeCrash(reason: String, trace: [String]) {
        let header = "=== CRASH: \(reason) ==="
        let body = trace.joined(separator: "\n")
        write("\(header)\n\(body)\n\(String(repeating: "=", count: 60))")
    }
}
