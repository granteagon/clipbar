/// Shortcut invocation arms the current row immediately; release commits once.
public struct SelectionSession {
    public private(set) var releaseArmed = false
    public init() {}
    public mutating func begin(modifiersHeld: Bool = false) { releaseArmed = modifiersHeld }
    public mutating func navigate(modifiersHeld: Bool) { releaseArmed = releaseArmed || modifiersHeld }
    public mutating func release() -> Bool {
        let commit = releaseArmed
        releaseArmed = false
        return commit
    }
    public mutating func cancel() { releaseArmed = false }
}
