import AppKit
import ApplicationServices

final class PasteController {
    private var timer: Timer?
    static var permitted: Bool { AXIsProcessTrusted() }
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        // The OS prompt may have already been dismissed. Open the pane explicitly.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    static func restart() {
        let alert = NSAlert()
        alert.messageText = "Restart ClipBar?"
        alert.informativeText = "History that is not saved across restarts will be cleared."
        alert.addButton(withTitle: "Restart"); alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { app, error in
            DispatchQueue.main.async {
                if app != nil { NSApp.terminate(nil) }
                else { let alert = NSAlert(); alert.messageText = "Could not restart ClipBar"; alert.informativeText = error?.localizedDescription ?? "Quit and reopen ClipBar manually."; alert.runModal() }
            }
        }
    }
    func cancel() { timer?.invalidate(); timer = nil }
    func paste(into target: NSRunningApplication, failed: @escaping (String) -> Void) {
        cancel()
        guard Self.permitted else { failed("Copied. Enable Accessibility in Settings to paste automatically."); return }
        guard !target.isTerminated, target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            failed("Copied. Return to your editing app and press ⌘V."); return
        }
        guard target.activate(options: []) else { failed("Copied. The previous app could not be activated."); return }
        let deadline = Date().addingTimeInterval(1.2)
        var readySince: Date?
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            let flags = CGEventSource.flagsState(.combinedSessionState)
            let released = flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate]).isEmpty
            let focused = NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
            if focused && released {
                if readySince == nil { readySince = Date() }
                if Date().timeIntervalSince(readySince!) >= 0.08 {
                    timer.invalidate(); self?.timer = nil
                    guard Self.permitted, !target.isTerminated,
                          let source = CGEventSource(stateID: .privateState),
                          let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                          let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
                        failed("Copied. Automatic paste is unavailable; press ⌘V in your app."); return
                    }
                    down.flags = .maskCommand; up.flags = .maskCommand
                    down.postToPid(target.processIdentifier); up.postToPid(target.processIdentifier)
                    return
                }
            } else { readySince = nil }
            if Date() >= deadline {
                timer.invalidate(); self?.timer = nil
                failed("Copied. Automatic paste was cancelled because focus or modifier keys changed.")
            }
        }
    }
}
