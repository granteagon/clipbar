/// A quick shortcut tap opens the picker. Hold, navigate, and release commits once.
public struct SelectionSession {
    public private(set) var releaseArmed = false
    public init() {}
    public mutating func begin() { releaseArmed = false }
    public mutating func navigate(modifiersHeld: Bool) { releaseArmed = modifiersHeld }
    public mutating func release() -> Bool {
        let commit = releaseArmed
        releaseArmed = false
        return commit
    }
    public mutating func cancel() { releaseArmed = false }
}
