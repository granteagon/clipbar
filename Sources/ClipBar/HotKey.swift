import Carbon

final class HotKey {
    var action: (() -> Void)?
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var current = ""
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue().action?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(_ name: String) -> Bool {
        if name == current, reference != nil { return true }
        if let reference { UnregisterEventHotKey(reference); self.reference = nil }
        current = name
        let key = name == "command-slash" ? kVK_ANSI_Slash : name == "command-shift-v" ? kVK_ANSI_V : kVK_ANSI_Backslash
        let modifiers = name == "command-shift-v" ? cmdKey | shiftKey : cmdKey
        let id = EventHotKeyID(signature: 0x434C5042, id: 1)
        return RegisterEventHotKey(UInt32(key), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &reference) == noErr
    }
    deinit { if let reference { UnregisterEventHotKey(reference) }; if let handler { RemoveEventHandler(handler) } }
}
