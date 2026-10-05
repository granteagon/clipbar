import AppKit
import SwiftUI
import ClipBarCore

/// Renders real app views with isolated sample data. Never loads or saves user history.
enum ScreenshotRenderer {
    @MainActor static func render(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let preferences = Preferences(read: { _ in nil }, write: { _, _ in }, forced: { _ in false }, sync: {})
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let sampleImage = NSImage(size: NSSize(width: 640, height: 360), flipped: false) { rect in
            NSGradient(starting: .systemIndigo, ending: .systemPink)?.draw(in: rect, angle: 25)
            let text = "Copy. Choose. Paste." as NSString
            text.draw(at: NSPoint(x: 58, y: 160), withAttributes: [.font: NSFont.systemFont(ofSize: 42, weight: .bold), .foregroundColor: NSColor.white])
            return true
        }
        let imageData = sampleImage.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:]) }
        let store = Store(prefs: preferences, pasteboard: board, monitor: false, previewItems: [
            Clip(text: "Small app. One useful job.", sourceApp: "TextEdit"),
            Clip(image: imageData, sourceApp: "Preview"),
            Clip(text: "https://github.com/granteagon/clipbar", sourceApp: "Safari"),
            Clip(text: "Coffee\nNotebook\nA little more focus", sourceApp: "Notes"),
            Clip(text: "Thanks — that works for me.", sourceApp: "Mail"),
            Clip(text: "brew install granteagon/tap/clipbar", sourceApp: "Terminal")
        ])
        store.selectedID = store.history.items.first?.id
        try png(HistoryView(store: store, choose: { _ in }, settings: {}).environment(\.colorScheme, .dark), to: directory.appendingPathComponent("clipboard-history.png"))
        try png(SettingsView(store: store, pane: .history).environment(\.colorScheme, .dark), to: directory.appendingPathComponent("history-settings.png"))
    }
    @MainActor private static func png<V: View>(_ view: V, to url: URL) throws {
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderBack(nil)
        defer { window.orderOut(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url)
    }
}
