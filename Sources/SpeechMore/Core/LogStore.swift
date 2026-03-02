import Foundation

@MainActor
final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var entries: [String] = []
    private let maxEntries = 2000

    func append(_ message: String) {
        let timestamp = Self.formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        entries.append(line)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

/// Log to both NSLog and LogStore
func appLog(_ message: String) {
    NSLog("%@", message)
    Task { @MainActor in
        LogStore.shared.append(message)
    }
}
