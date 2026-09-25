import AppKit
import SwiftUI
import ClipBarCore

final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var store: Store!
    private let hotKey = HotKey()
    private var status: NSStatusItem!
    private var panel: HistoryPanel!
    private var settings: NSWindow?
    private var settingsTabs: NSTabViewController?
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store = Store()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipBar clipboard history")
        status.button?.target = self; status.button?.action = #selector(toggle)
        panel = HistoryPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 480), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "ClipBar"; panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false; panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        hotKey.action = { [weak self] in self?.toggle() }
        store.settingsChanged = { [weak self] in self?.registerShortcut() }
        registerShortcut()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
            if (self.panel.isKeyWindow || self.settings?.isKeyWindow == true),
               modifiers == .command, event.charactersIgnoringModifiers == "," {
                self.showSettings(); return nil
            }
            guard self.panel.isKeyWindow else { return event }
            if event.keyCode == 53 { self.panel.orderOut(nil); self.previousApp?.activate(options: []); return nil }
            if [125, 126, 36, 76].contains(Int(event.keyCode)) {
                NotificationCenter.default.post(name: .init("ClipBar.navigation"), object: Int(event.keyCode))
                return nil
            }
            return event
        }
        if store.prefs.bool("ShowMenuBarIcon") { toggle() }
    }
    private func registerShortcut() {
        let name = store.prefs.value("Shortcut") as? String ?? "command-backslash"
        store.shortcutError = hotKey.register(name) ? nil : "Shortcut is in use. Choose another shortcut or use the menu bar icon."
        status.button?.toolTip = store.shortcutError ?? "ClipBar — clipboard history"
        // Keep a recovery path even when a saved or managed shortcut is unavailable.
        status.isVisible = store.prefs.bool("ShowMenuBarIcon") || store.shortcutError != nil
    }
    @objc func toggle() {
        if panel.isVisible { panel.orderOut(nil); return }
        previousApp = NSWorkspace.shared.frontmostApplication
        store.applyPolicy()
        panel.contentView = NSHostingView(rootView: HistoryView(store: store, choose: { [weak self] clip in
            self?.store.copy(clip); self?.panel.orderOut(nil); self?.previousApp?.activate(options: [])
        }, settings: { [weak self] in self?.showSettings() }))
        panel.center(); NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil)
    }
    private func showSettings() {
        panel.orderOut(nil)
        if settings == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            for pane in SettingsPane.allCases {
                let item = NSTabViewItem(viewController: NSHostingController(rootView: SettingsView(store: store, pane: pane)))
                item.viewController?.title = "\(pane.rawValue) — ClipBar"
                item.label = pane.rawValue
                item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.rawValue)
                tabs.addTabViewItem(item)
            }
            settingsTabs = tabs
            settings = NSWindow(contentViewController: tabs)
            settings?.styleMask = [.titled, .closable]
            settings?.title = "ClipBar Settings"
            settings?.isReleasedWhenClosed = false
            settings?.toolbarStyle = .preference
            settings?.setContentSize(NSSize(width: 560, height: 440))
            settings?.center()
        }
        NSApp.activate(ignoringOtherApps: true); settings?.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if settings?.isVisible == true { NSApp.activate(ignoringOtherApps: true); settings?.makeKeyAndOrderFront(nil) }
        else if !panel.isVisible { toggle() }
        else { NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil) }
        return false
    }
    func windowDidResignKey(_ notification: Notification) { if (notification.object as? NSWindow) === panel { panel.orderOut(nil) } }
    func applicationWillTerminate(_ notification: Notification) { store.persist() }
}

@main enum ClipBarMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
