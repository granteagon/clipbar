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
    private let paster = PasteController()
    private var selectionSession = SelectionSession()
    private var status: NSStatusItem!
    private var panel: HistoryPanel!
    private var settings: NSWindow?
    private var settingsTabs: NSTabViewController?
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?
    private var releaseTimer: Timer?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store = Store()
        installMenus()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipBar clipboard history")
        status.button?.target = self; status.button?.action = #selector(toggle)
        panel = HistoryPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 540), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.title = "ClipBar"; panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false; panel.level = .popUpMenu
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        hotKey.action = { [weak self] in
            guard let self else { return }
            if self.panel.isVisible { self.navigate(1) }
            else { self.showPicker(fromShortcut: true) }
        }
        store.settingsChanged = { [weak self] in self?.registerShortcut() }
        registerShortcut()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .flagsChanged {
                if !event.modifierFlags.contains(.command) { self.commitRelease() }
                return event
            }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
            if (self.panel.isKeyWindow || self.settings?.isKeyWindow == true),
               modifiers == .command, event.charactersIgnoringModifiers == "," {
                self.showSettings(); return nil
            }
            guard self.panel.isKeyWindow else { return event }
            if event.keyCode == 53 { self.selectionSession.cancel(); self.panel.orderOut(nil); self.previousApp?.activate(options: []); return nil }
            if [125, 126, 36, 76].contains(Int(event.keyCode)) {
                if event.keyCode == 125 { self.navigate(1, modifiersHeld: event.modifierFlags.contains(.command)) }
                else if event.keyCode == 126 { self.navigate(-1, modifiersHeld: event.modifierFlags.contains(.command)) }
                else if let clip = self.store.selected { self.choose(clip) }
                return nil
            }
            return event
        }
        if store.prefs.bool("ShowMenuBarIcon") { toggle() }
    }
    private func installMenus() {
        let menu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu(title: "ClipBar")
        let preferences = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        preferences.target = self; appMenu.addItem(preferences)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit ClipBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        let editItem = NSMenuItem(); let editMenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        editItem.submenu = editMenu; menu.addItem(editItem); NSApp.mainMenu = menu
    }
    @objc private func openSettings() { showSettings() }
    private func registerShortcut() {
        let name = store.prefs.value("Shortcut") as? String ?? "command-backslash"
        store.shortcutError = hotKey.register(name) ? nil : "Shortcut is in use. Choose another shortcut or use the menu bar icon."
        status.button?.toolTip = store.shortcutError ?? "ClipBar — clipboard history"
        // Keep a recovery path even when a saved or managed shortcut is unavailable.
        status.isVisible = store.prefs.bool("ShowMenuBarIcon") || store.shortcutError != nil
    }
    @objc func toggle() { showPicker(fromShortcut: false) }
    private func showPicker(fromShortcut: Bool) {
        paster.cancel(); releaseTimer?.invalidate(); selectionSession.begin(modifiersHeld: fromShortcut)
        if panel.isVisible { panel.orderOut(nil); return }
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        store.selectedID = store.history.items.first?.id
        store.applyPolicy()
        panel.contentView = NSHostingView(rootView: HistoryView(store: store, choose: { [weak self] clip in
            self?.choose(clip)
        }, settings: { [weak self] in self?.showSettings() }))
        panel.setContentSize(NSSize(width: 600, height: store.pickerHeight))
        panel.center(); NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil)
        // Poll actual modifier state as well as listening for flagsChanged. The release
        // event can be delivered before this panel becomes key during app activation.
        let timer = Timer(timeInterval: 0.016, repeats: true) { [weak self] _ in
            guard !CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand) else { return }
            self?.commitRelease()
        }
        releaseTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    private func commitRelease() {
        guard panel.isVisible, selectionSession.release() else { return }
        releaseTimer?.invalidate(); releaseTimer = nil
        if let clip = store.selected { choose(clip) }
        else { panel.orderOut(nil); previousApp?.activate(options: []) }
    }
    private func navigate(_ delta: Int, modifiersHeld: Bool = true) {
        let items = store.filtered
        guard !items.isEmpty else { return }
        let index = items.firstIndex(where: { $0.id == store.selectedID }) ?? 0
        store.selectedID = items[max(0, min(items.count - 1, index + delta))].id
        selectionSession.navigate(modifiersHeld: modifiersHeld)
    }
    private func choose(_ clip: Clip) {
        selectionSession.cancel(); releaseTimer?.invalidate(); releaseTimer = nil
        store.copy(clip)
        panel.orderOut(nil)
        previousApp?.activate(options: [])
        store.pasteNotice = nil
        guard store.prefs.bool("PasteAutomatically") else {
            panel.orderOut(nil); previousApp?.activate(options: []); return
        }
        guard PasteController.permitted else {
            store.pasteNotice = "Copied. Allow Accessibility to paste directly into your previous app."
            return
        }
        guard let target = previousApp else {
            store.pasteNotice = "Copied. Open history from your editing app to paste there automatically."
            return
        }
        panel.orderOut(nil)
        paster.paste(into: target) { [weak self] message in self?.store.pasteNotice = message }
    }
    private func showSettings() {
        selectionSession.cancel(); releaseTimer?.invalidate(); releaseTimer = nil; paster.cancel()
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
    func windowDidResignKey(_ notification: Notification) { if (notification.object as? NSWindow) === panel { selectionSession.cancel(); releaseTimer?.invalidate(); releaseTimer = nil; panel.orderOut(nil) } }
    func applicationDidBecomeActive(_ notification: Notification) { store?.applyPolicy() }
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
