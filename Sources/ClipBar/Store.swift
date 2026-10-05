import AppKit
import ClipBarCore

final class Store: ObservableObject {
    @Published private(set) var history = History()
    @Published var selectedID: UUID?
    @Published var pasteNotice: String?
    @Published var accessibilityGranted = PasteController.permitted
    var filtered: [Clip] { history.items }
    var pickerHeight: CGFloat { CGFloat(max(2, min(history.items.count, 11))) * 43 + 100 }
    var selected: Clip? { filtered.first(where: { $0.id == selectedID }) ?? filtered.first }
    @Published var paused = false
    @Published var error: String?
    @Published var revision = 0
    @Published var shortcutError: String?
    let prefs: Preferences
    private let vault: Vault
    private let pasteboard: NSPasteboard
    private let monitoring: Bool
    private var changeCount: Int
    private var timer: Timer?
    private var locked = false
    private var observers: [NSObjectProtocol] = []
    private var ticks = 0
    private var previousPersistence = false
    var settingsChanged: (() -> Void)?
    init(prefs: Preferences = Preferences(), vault: Vault = Vault(),
         pasteboard: NSPasteboard = .general, monitor: Bool = true, previewItems: [Clip] = []) {
        self.prefs = prefs; self.vault = vault; self.pasteboard = pasteboard
        self.monitoring = monitor; self.changeCount = pasteboard.changeCount
        if !monitor {
            for item in previewItems.reversed() { history.add(item, limit: prefs.limit, hours: 0) }
            return
        }
        prefs.refresh()
        do {
            if prefs.bool("PersistHistory") && prefs.bool("CaptureEnabled") {
                for item in try vault.load().reversed() { history.add(item, limit: prefs.limit, hours: prefs.hours) }
                try vault.save(history.items)
            } else { try vault.delete() }
        } catch { self.error = "Saved history could not be opened or removed. Check Keychain and file access." }
        previousPersistence = prefs.bool("PersistHistory")
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in self?.lock() })
        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in self?.unlock() })
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.lock() })
        observers.append(workspace.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.unlock() })
        observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.lock() })
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.unlock() })
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
    }
    func lock() { locked = true; if prefs.bool("ClearOnLock") { clear() }; NSApp.hide(nil) }
    func unlock() { changeCount = pasteboard.changeCount; locked = false }
    func update(_ key: String, _ value: Any) { prefs.set(key, value); applyPolicy(); persist(); settingsChanged?() }
    func applyPolicy() {
        prefs.refresh(); revision += 1; accessibilityGranted = PasteController.permitted
        let previous = history.items
        if !prefs.bool("CaptureEnabled") || (locked && prefs.bool("ClearOnLock")) { history.clear() }
        history.prune(limit: prefs.limit, hours: prefs.hours)
        let persistence = prefs.bool("PersistHistory")
        if history.items != previous || !persistence || persistence != previousPersistence { persist() }
        previousPersistence = persistence
    }
    private func tick() {
        ticks += 1
        if ticks % 4 == 0 { applyPolicy(); settingsChanged?() }
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        let source = NSWorkspace.shared.frontmostApplication
        guard CapturePolicy.allows(types: (pasteboard.types ?? []).map(\.rawValue),
                                   sourceBundleID: source?.bundleIdentifier, excluded: prefs.excluded,
                                   enabled: prefs.bool("CaptureEnabled"), paused: paused, locked: locked) else { return }
        // Inspect only known representations; never resolve file URLs or fetch remote content.
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            history.add(Clip(text: text, sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName), limit: prefs.limit, hours: prefs.hours)
        } else if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff), data.count <= History.itemLimit {
            history.add(Clip(image: data, sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName), limit: prefs.limit, hours: prefs.hours)
        } else { return }
        persist()
    }
    func copy(_ clip: Clip) {
        let board = pasteboard
        board.clearContents()
        if let text = clip.text { board.setString(text, forType: .string) }
        if let data = clip.image { board.setData(data, forType: data.starts(with: [137, 80, 78, 71]) ? .png : .tiff) }
        changeCount = board.changeCount
    }
    func remove(_ id: UUID) { history.remove(id); persist() }
    func clear() { history.clear(); changeCount = pasteboard.changeCount; persist() }
    func clearClipboard() { pasteboard.clearContents(); clear() }
    func persist() {
        guard monitoring else { return }
        do {
            if prefs.bool("PersistHistory") && prefs.bool("CaptureEnabled") { try vault.save(history.items) }
            else { try vault.delete() }
            error = nil
        } catch { self.error = "History could not be saved or removed. Check Keychain and file access." }
    }
}
