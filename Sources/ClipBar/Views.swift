import SwiftUI
import ClipBarCore

struct HistoryView: View {
    @ObservedObject var store: Store
    var choose: (Clip) -> Void
    var settings: () -> Void
    @State private var query = ""
    @State private var selection: UUID?
    @FocusState private var searching: Bool
    private var filtered: [Clip] { store.history.items.filter { query.isEmpty || ($0.text ?? "Image").localizedCaseInsensitiveContains(query) } }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clipboard").font(.title2).foregroundStyle(.tint)
                Text("ClipBar").font(.title2.bold())
                Spacer()
                Text(!store.prefs.bool("CaptureEnabled") ? "Capture disabled" : store.paused ? "Paused" : "Local history").font(.caption).foregroundStyle(.secondary)
            }.padding()
            TextField("Search clipboard history", text: $query).textFieldStyle(.roundedBorder).focused($searching)
                .padding(.horizontal).padding(.bottom, 10)
                .onSubmit { if let item = filtered.first(where: { $0.id == selection }) ?? filtered.first { choose(item) } }
            if let error = store.error { Text(error).font(.caption).foregroundColor(.red).padding(.horizontal) }
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: query.isEmpty ? "doc.on.clipboard" : "magnifyingglass").font(.system(size: 36)).foregroundStyle(.secondary)
                    Text(query.isEmpty ? "Your next copy starts here" : "No matching items").font(.headline)
                    Text(query.isEmpty ? "Copy text or an image in another app.\nHistory stays on this Mac." : "Try another search.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(filtered) { clip in
                        HStack(spacing: 12) {
                            if let data = clip.image, let image = NSImage(data: data) {
                                Image(nsImage: image).resizable().scaledToFit().frame(width: 40, height: 40)
                            } else { Image(systemName: "text.alignleft").foregroundStyle(.secondary).frame(width: 40) }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(clip.text ?? "Image").lineLimit(2).font(.system(size: 13))
                                Text(clip.date, style: .time).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { choose(clip) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless).help("Copy and close")
                        }.padding(.vertical, 5).tag(clip.id)
                            .contextMenu { Button("Copy") { choose(clip) }; Button("Delete", role: .destructive) { store.remove(clip.id) } }
                    }
                }.listStyle(.inset).onSubmit { if let item = filtered.first(where: { $0.id == selection }) { choose(item) } }
            }
            Divider()
            HStack {
                Text("\(store.history.items.count) / \(store.prefs.limit)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(store.paused ? "Resume" : "Pause") { store.paused.toggle() }
                Button("Clear") { store.clear() }.disabled(store.history.items.isEmpty)
                Button { settings() } label: { Image(systemName: "gearshape") }.help("Settings (⌘,)")
            }.controlSize(.small).padding(12)
            Text("Return copies · ⌘V pastes in your app · ⌘, Settings · Esc closes").font(.caption2).foregroundStyle(.secondary).padding(.bottom, 10)
        }.frame(width: 480, height: 480)
        .onAppear { searching = true; selection = filtered.first?.id }
        .onChange(of: query) { _ in selection = filtered.first?.id }
        .onReceive(NotificationCenter.default.publisher(for: .init("ClipBar.navigation"))) { event in
            guard let key = event.object as? Int, !filtered.isEmpty else { return }
            let index = filtered.firstIndex(where: { $0.id == selection }) ?? 0
            if key == 125 { selection = filtered[min(index + 1, filtered.count - 1)].id }
            if key == 126 { selection = filtered[max(index - 1, 0)].id }
            if key == 36 || key == 76 { choose(filtered[index]) }
        }
        .onMoveCommand { direction in
            guard !filtered.isEmpty else { return }
            let index = filtered.firstIndex(where: { $0.id == selection }) ?? 0
            if direction == .down { selection = filtered[min(index + 1, filtered.count - 1)].id }
            if direction == .up { selection = filtered[max(index - 1, 0)].id }
        }
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
                    Section("Global shortcut") {
                        Picker(label("Show clipboard history", "Shortcut"), selection: binding("Shortcut", fallback: "command-backslash")) {
                            Text("⌘\\").tag("command-backslash"); Text("⌘/").tag("command-slash"); Text("⌘⇧V").tag("command-shift-v")
                        }.disabled(store.prefs.forced("Shortcut"))
                        if let error = store.shortcutError { Text(error).foregroundStyle(.red).font(.caption) }
                    }
                    Section("While history is open") {
                        shortcutRow("Open Settings", "⌘,")
                        shortcutRow("Select an item", "↑  ↓")
                        shortcutRow("Copy selection and return to your app", "Return")
                        shortcutRow("Close history", "Esc")
                        Text("After choosing an item, press ⌘V in your app to paste it.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.formStyle(.grouped).toggleStyle(.checkbox).padding(.horizontal, 20).padding(.vertical, 12)
            if ["ShowMenuBarIcon", "CaptureEnabled", "HistoryLimit", "RetentionHours", "PersistHistory", "ClearOnLock", "ExcludedBundleIDs", "Shortcut"].contains(where: store.prefs.forced) {
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
