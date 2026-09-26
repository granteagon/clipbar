# Product decisions

**Intent Read**
The useful outcome is a clipboard utility that a workplace can inspect and constrain, with a small enough feature surface that its data handling is understandable.

**Blind Spots**
1. Source availability does not grant permission to use clipboard history at work. Employer policy and review remain decisive; provide explicit retention controls and a pilot profile.
2. ClipBar is already used by multiple macOS clipboard projects. This implementation keeps the requested working name locally; choose a public name before publishing to reduce confusion.
3. Current macOS already exposes clipboard history in Spotlight. The reason to build this app is independently configurable retention, managed settings, and a dedicated shortcut, including on older supported Macs.

**The Call**
Build a small native Swift app: memory-only by default, no networking code or dependencies, optional encrypted persistence, configurable history limits, and forced preferences through MDM. Automatic paste is now the default interaction, with an explicit Accessibility setup path and optional copy-only mode. Synthetic paste is targeted to the previous app only after it regains focus and modifier keys are released.

**Level 2 — what breaks next**
1. Public installation introduces signing and notarization requirements. Prepare the universal artifact and personal Homebrew tap, but ship a notarized archive after Developer ID setup and integration testing.
2. Enterprise rollout exposes differences in lock notifications, OS permissions, keyboard layouts, and MDM delivery. Validate on an enrolled pilot Mac before fleet deployment and maintain an explicit OS integration checklist.

Sources: [existing Clipbar](https://github.com/this-fifo/clipbar), [Spotlight clipboard history](https://support.apple.com/en-il/guide/mac-help/mchl40d5b86b/mac), [managed preferences](https://developer.apple.com/documentation/devicemanagement/managedpreferences), [Homebrew cask requirements](https://docs.brew.sh/Acceptable-Casks).
