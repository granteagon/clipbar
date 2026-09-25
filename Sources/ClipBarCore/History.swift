import Foundation

public struct Clip: Codable, Identifiable, Equatable {
    public var id: UUID
    public var date: Date
    public let text: String?
    public let image: Data?
    public var byteCount: Int { (text?.utf8.count ?? 0) + (image?.count ?? 0) }
    public init(text: String? = nil, image: Data? = nil, date: Date = Date()) {
        self.id = UUID(); self.date = date; self.text = text; self.image = image
    }
}

public struct History {
    public private(set) var items: [Clip] = []
    public static let itemLimit = 4 * 1024 * 1024
    public static let memoryLimit = 32 * 1024 * 1024
    public init() {}
    public mutating func add(_ clip: Clip, limit: Int, hours: Double, now: Date = Date()) {
        guard clip.byteCount > 0, clip.byteCount <= Self.itemLimit else { return }
        items.removeAll { $0.text == clip.text && $0.image == clip.image }
        items.insert(clip, at: 0)
        prune(limit: limit, hours: hours, now: now)
    }
    public mutating func prune(limit: Int, hours: Double, now: Date = Date()) {
        if hours > 0 { items.removeAll { now.timeIntervalSince($0.date) >= hours * 3600 } }
        items = Array(items.prefix(max(0, min(limit, 500))))
        var total = items.reduce(0) { $0 + $1.byteCount }
        while total > Self.memoryLimit, let last = items.popLast() { total -= last.byteCount }
    }
    public mutating func remove(_ id: UUID) { items.removeAll { $0.id == id } }
    public mutating func clear() { items.removeAll() }
}
