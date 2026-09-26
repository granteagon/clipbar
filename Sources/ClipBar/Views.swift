import SwiftUI
import ClipBarCore

struct HistoryView: View {
    @ObservedObject var store: Store
    var choose: (Clip) -> Void
    var settings: () -> Void
    private var filtered: [Clip] { store.filtered }
    private let selectionColors = [Color(red: 0.26, green: 0.24, blue: 0.88), Color(red: 0.53, green: 0.19, blue: 0.79)]
    private func title(_ clip: Clip) -> String {
        guard let text = clip.text else { return "Image" }
        return text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
    }
    private func detail(_ clip: Clip) -> String {
        var parts: [String] = []
        if let data = clip.image, let bitmap = NSBitmapImageRep(data: data) {
            parts.append("\(bitmap.pixelsWide) × \(bitmap.pixelsHigh)")
        } else if let text = clip.text {
            let lines = text.components(separatedBy: .newlines).count
            if lines > 1 { parts.append("\(lines) lines") }
        }
        if let app = clip.sourceApp { parts.append(app) }
        return parts.joined(separator: " · ")
    }
    @ViewBuilder private func thumbnail(_ clip: Clip, size: CGFloat) -> some View {
        if let data = clip.image, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size)
                .background(.white.opacity(0.08)).cornerRadius(3)
        } else {
            Image(systemName: clip.text.flatMap(URL.init(string:))?.scheme != nil ? "link" : "doc.text")
                .font(.system(size: size * 0.7)).foregroundStyle(.secondary).frame(width: size, height: size)
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let selected = store.selected { thumbnail(selected, size: 30) }
                else { Image(systemName: "clipboard").font(.title2) }
                Text(store.selected.map(title) ?? "Clipboard History").font(.system(size: 21)).lineLimit(1)
                Spacer()
                Button { if let clip = store.selected { choose(clip) } } label: {
                    Image(systemName: "return")
                        .resizable().scaledToFit().frame(width: 19, height: 16)
                        .frame(width: 42, height: 32)
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(PasteButtonStyle()).fixedSize().disabled(store.selected == nil)
                    .accessibilityLabel(store.prefs.bool("PasteAutomatically") ? "Paste selection" : "Copy selection")
                    .help(store.prefs.bool("PasteAutomatically") ? "Paste selection" : "Copy selection")
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 12)
                .background(LinearGradient(colors: [.purple.opacity(0.13), .orange.opacity(0.10)], startPoint: .leading, endPoint: .trailing))
            Divider()
            if let error = store.error { Text(error).font(.caption).foregroundColor(.red).padding(8) }
            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 32)).foregroundStyle(.purple)
                    Text("Your next copy starts here").font(.headline)
                    Text("Copy text or an image to add it to history.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filtered) { clip in
                                let selected = store.selected?.id == clip.id
                                Button { store.selectedID = clip.id; choose(clip) } label: {
                                    HStack(spacing: 10) {
                                        thumbnail(clip, size: 30)
                                        Text(title(clip)).font(.system(size: 14)).lineLimit(1).truncationMode(.tail)
                                        Spacer(minLength: 8)
                                        let metadata = detail(clip)
                                        if !metadata.isEmpty {
                                            Text(metadata).font(.system(size: 11)).lineLimit(1)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(.primary.opacity(selected ? 0.12 : 0.06)).cornerRadius(5)
                                        }
                                    }.padding(.horizontal, 10).frame(height: 42)
                                        .contentShape(Rectangle())
                                        .foregroundStyle(selected ? Color.white : Color.primary)
                                        .background {
                                            if selected {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(LinearGradient(colors: selectionColors, startPoint: .leading, endPoint: .trailing))
                                            }
                                        }.cornerRadius(8)
                                }.buttonStyle(.plain).id(clip.id)
                                    .accessibilityLabel(title(clip) + ", " + detail(clip))
                                    .accessibilityAddTraits(selected ? .isSelected : [])
                                    .contextMenu {
                                        Button("Copy Only") { store.copy(clip) }
                                        Button("Delete", role: .destructive) { store.remove(clip.id) }
                                    }
                            }
                        }.padding(.horizontal, 6).padding(.vertical, 4)
                    }.onChange(of: store.selectedID) { id in if let id { proxy.scrollTo(id) } }
                }
            }
            Divider()
            HStack(spacing: 12) {
                Text("\(store.history.items.count) \(store.history.items.count == 1 ? "item" : "items")").foregroundStyle(.secondary)
                Spacer()
                Text(store.prefs.bool("PasteAutomatically") ? "↑↓ select · release ⌘" : "↑↓ select · release ⌘ to copy").foregroundStyle(.secondary)
                Button(store.paused ? "Resume" : "Pause") { store.paused.toggle() }
                Button { settings() } label: { Image(systemName: "gearshape") }.help("Settings (⌘,)")
            }.font(.caption).buttonStyle(.plain).padding(12)
        }.frame(width: 600, height: store.pickerHeight)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }
}

/// Own the entire bezel so AppKit's standard control height cannot crop the glyph.
private struct PasteButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(red: 0.22, green: 0.08, blue: 0.12))
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.76, blue: 0.25), Color(red: 1, green: 0.39, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.30), lineWidth: 1))
            .shadow(color: .orange.opacity(enabled ? 0.25 : 0), radius: 5, y: 2)
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

enum SettingsPane: String, CaseIterable {
    case general = "General", history = "History", privacy = "Privacy", shortcuts = "Shortcuts"
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .history: return "clipboard"
        case .privacy: return "hand.raised"
        case .shortcuts: return "keyboard"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: Store
    let pane: SettingsPane
    @State private var excludedDraft = ""
    private func binding<T>(_ key: String, fallback: T) -> Binding<T> {
        Binding(get: { store.prefs.value(key) as? T ?? fallback }, set: { store.update(key, $0) })
    }
    private func label(_ title: String, _ key: String) -> String { title + (store.prefs.forced(key) ? " 🔒" : "") }
    var body: some View {
        VStack(spacing: 0) {
            Form {
                switch pane {
                case .general:
                    Section("Appearance") {
                        Toggle(label("Show icon in menu bar", "ShowMenuBarIcon"), isOn: binding("ShowMenuBarIcon", fallback: true))
                            .disabled(store.prefs.forced("ShowMenuBarIcon"))
                        Text("ClipBar runs without a Dock icon. With the menu bar icon hidden, use your keyboard shortcut to open history, then ⌘, to open Settings.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Access") {
                        Text("You can always open ClipBar again from Finder or Spotlight to bring up history. If the shortcut is unavailable, the menu bar icon reappears automatically.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Quit ClipBar") { NSApp.terminate(nil) }
                    }
                case .history:
                    Section("Clipboard history") {
                        Toggle(label("Enable clipboard history", "CaptureEnabled"), isOn: binding("CaptureEnabled", fallback: true)).disabled(store.prefs.forced("CaptureEnabled"))
                        Stepper(label("Keep \(store.prefs.limit) items", "HistoryLimit"), value: binding("HistoryLimit", fallback: 50), in: 1...500).disabled(store.prefs.forced("HistoryLimit"))
                        HStack {
                            Text(label("Expire items after", "RetentionHours"))
                            Spacer()
                            TextField("Hours", value: Binding(get: { store.prefs.hours }, set: { store.update("RetentionHours", max(0, min(8760, $0))) }), format: .number).labelsHidden().textFieldStyle(.roundedBorder).frame(width: 65)
                            Text("hours")
                        }.disabled(store.prefs.forced("RetentionHours"))
                        Text("Use 0 to keep items until the history limit is reached or you clear them.").font(.caption).foregroundStyle(.secondary)
                        Toggle(label("Preserve history across restarts", "PersistHistory"), isOn: binding("PersistHistory", fallback: false)).disabled(store.prefs.forced("PersistHistory"))
                        Text("Off by default. When enabled, history is encrypted on this Mac using a key in your login Keychain.").font(.caption).foregroundStyle(.secondary)
                        Button("Clear History", role: .destructive) { store.clear() }.disabled(store.history.items.isEmpty)
                    }
                case .privacy:
                    Section("Automatic clearing") {
                        Toggle(label("Clear history when the Mac locks or sleeps", "ClearOnLock"), isOn: binding("ClearOnLock", fallback: true)).disabled(store.prefs.forced("ClearOnLock"))
                    }
                    Section("Ignored applications") {
                        Text(label("App bundle IDs, one per line", "ExcludedBundleIDs")).font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $excludedDraft).font(.system(.body, design: .monospaced)).frame(height: 85)
                            .disabled(store.prefs.forced("ExcludedBundleIDs"))
                            .accessibilityLabel("Ignored application bundle identifiers")
                        HStack {
                            Text("Changes take effect when you click Apply.").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Apply") {
                                store.update("ExcludedBundleIDs", excludedDraft.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
                            }.disabled(store.prefs.forced("ExcludedBundleIDs") || excludedDraft == store.prefs.excluded.joined(separator: "\n"))
                        }
                        Text("Concealed and transient copies are skipped. Unmarked secrets cannot be recognized reliably.").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Clear History and System Clipboard", role: .destructive) { store.clearClipboard() }
                case .shortcuts:
                    Section("Pasting") {
                        Toggle(label("Paste automatically after selection", "PasteAutomatically"), isOn: binding("PasteAutomatically", fallback: true))
                            .disabled(store.prefs.forced("PasteAutomatically"))
                        HStack {
                            Text(store.accessibilityGranted ? "Accessibility access is enabled." : "Accessibility access is needed to paste into other apps.").font(.caption).foregroundStyle(.secondary)
                            if !store.accessibilityGranted { Button("Open Accessibility Settings…") { PasteController.requestPermission() } }
                        }
                    }
                    Section("Permission troubleshooting") {
                        if let notice = store.pasteNotice { Text(notice).font(.caption).foregroundStyle(.secondary) }
                        Text("Automatic paste needs Accessibility permission, separate from Clipboard access. Enable this copy of ClipBar in System Settings. If it still shows as unavailable, restart ClipBar. Unsaved history is cleared on restart.").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("Show This App in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
                            Button("Restart ClipBar…") { PasteController.restart() }
                        }
                    }
                    Section("Global shortcut") {
                        Picker(label("Show clipboard history", "Shortcut"), selection: binding("Shortcut", fallback: "command-backslash")) {
                            Text("⌘\\").tag("command-backslash"); Text("⌘/").tag("command-slash"); Text("⌘⇧V").tag("command-shift-v")
                        }.disabled(store.prefs.forced("Shortcut"))
                        if let error = store.shortcutError { Text(error).foregroundStyle(.red).font(.caption) }
                    }
                    Section("While history is open") {
                        shortcutRow("Open Settings", "⌘,")
                        shortcutRow("Select an item", "↑  ↓")
                        shortcutRow("Paste selection into your app", "Return")
                        shortcutRow("Paste after navigating with ⌘ held", "Release ⌘")
                        shortcutRow("Close history", "Esc")
                        Text("Hold the shortcut, choose a row, then release Command. Selection always copies and closes; automatic paste additionally requires Accessibility.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.formStyle(.grouped).toggleStyle(.checkbox).padding(.horizontal, 20).padding(.vertical, 12)
            if ["PasteAutomatically", "ShowMenuBarIcon", "CaptureEnabled", "HistoryLimit", "RetentionHours", "PersistHistory", "ClearOnLock", "ExcludedBundleIDs", "Shortcut"].contains(where: store.prefs.forced) {
                Label("Locked settings are managed by your organization.", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.secondary).padding(.bottom, 12)
            }
        }.frame(width: 560, height: 440)
        .onAppear { excludedDraft = store.prefs.excluded.joined(separator: "\n") }
    }
    private func shortcutRow(_ title: String, _ keys: String) -> some View {
        HStack { Text(title); Spacer(); Text(keys).foregroundStyle(.secondary) }
    }
}
