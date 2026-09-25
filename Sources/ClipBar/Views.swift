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
                Button { settings() } label: { Image(systemName: "gearshape") }.help("Settings")
            }.controlSize(.small).padding(12)
            Text("Return copies · ⌘V pastes in your app · Esc closes").font(.caption2).foregroundStyle(.secondary).padding(.bottom, 10)
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

struct SettingsView: View {
    @ObservedObject var store: Store
    private func binding<T>(_ key: String, fallback: T) -> Binding<T> {
        Binding(get: { store.prefs.value(key) as? T ?? fallback }, set: { store.update(key, $0) })
    }
    private func label(_ title: String, _ key: String) -> String { title + (store.prefs.forced(key) ? " 🔒" : "") }
    var body: some View {
        Form {
            Section("History") {
                Stepper(label("Keep \(store.prefs.limit) items", "HistoryLimit"), value: binding("HistoryLimit", fallback: 50), in: 1...500).disabled(store.prefs.forced("HistoryLimit"))
                HStack {
                    Text(label("Retention (hours; 0 = no expiry)", "RetentionHours"))
                    TextField("Hours", value: Binding(get: { store.prefs.hours }, set: { store.update("RetentionHours", max(0, min(8760, $0))) }), format: .number).frame(width: 70)
                }.disabled(store.prefs.forced("RetentionHours"))
                Toggle(label("Save history across restarts", "PersistHistory"), isOn: binding("PersistHistory", fallback: false)).disabled(store.prefs.forced("PersistHistory"))
                Text("Off by default. Saved history is encrypted on this Mac with a key in your login Keychain.").font(.caption).foregroundStyle(.secondary)
                Toggle(label("Clear history when the Mac locks or sleeps", "ClearOnLock"), isOn: binding("ClearOnLock", fallback: true)).disabled(store.prefs.forced("ClearOnLock"))
            }
            Section("Capture") {
                Toggle(label("Capture clipboard changes", "CaptureEnabled"), isOn: binding("CaptureEnabled", fallback: true)).disabled(store.prefs.forced("CaptureEnabled"))
                Text(label("Excluded app bundle IDs (one per line)", "ExcludedBundleIDs"))
                TextEditor(text: Binding(get: { store.prefs.excluded.joined(separator: "\n") }, set: { store.update("ExcludedBundleIDs", $0.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }) })).font(.system(.caption, design: .monospaced)).frame(height: 70).disabled(store.prefs.forced("ExcludedBundleIDs"))
                Text("Apps that mark copies as concealed or transient are skipped. Unmarked secrets cannot be identified reliably.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Keyboard") {
                Picker(label("Show history", "Shortcut"), selection: binding("Shortcut", fallback: "command-backslash")) {
                    Text("⌘\\").tag("command-backslash"); Text("⌘/").tag("command-slash"); Text("⌘⇧V").tag("command-shift-v")
                }.disabled(store.prefs.forced("Shortcut"))
                if let shortcutError = store.shortcutError { Text(shortcutError).foregroundStyle(.red).font(.caption) }
            }
            HStack { Button("Clear history and system clipboard", role: .destructive) { store.clearClipboard() }; Spacer(); Button("Quit ClipBar") { NSApp.terminate(nil) } }
            Text("🔒 Managed settings are controlled by your organization. No network, analytics, or account.").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped).frame(width: 560, height: 630)
    }
}
