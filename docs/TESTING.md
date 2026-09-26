# Validation

## Automated

`swift test` checks deduplication, count limits, expiry boundaries, no-expiry mode, per-item rejection, total history memory eviction, policy reduction, and clearing. Encrypted-file tests also verify round-trip decoding, absence of plaintext, file permissions, deletion, and rejection of tampered ciphertext using an injected test key. These tests do not validate OS clipboard APIs, actual Keychain access, hotkeys, or MDM delivery.

Local validation on 2026-09-25: six tests pass; universal arm64/x86_64 build and ad-hoc signature verification pass; both slices declare macOS 13.0 minimum. First-launch history and Settings were inspected through native accessibility and the history panel screenshot. Global hotkey automation timed out; end-to-end copy/paste, Keychain interaction, and managed-device enforcement remain manual release checks.

## Manual before public release

- Start the bundled app. Verify no Dock icon and a visible clipboard menu bar icon.
- Copy two text entries and one PNG/TIFF. Open history with Command-backslash. Search, select with arrows, Return to copy, and paste in another app.
- Verify Command-comma opens Settings from history; switching General, History, Privacy, and Shortcuts preserves the selected pane on reopening.
- Hide the menu bar icon in General, confirm no Dock icon, close windows and reopen from Finder/Spotlight, then restore the default. Verify shortcut failure restores the icon even in hidden mode.
- Verify Escape and outside clicks dismiss the panel. Test alternate shortcuts and a deliberately conflicting hotkey.
- Confirm duplicates move to the top, Clear removes history, and Settings' combined clear empties the system clipboard.
- Pause capture, copy text, resume, and confirm paused copies were not retained.
- Copy a concealed entry or from an excluded password manager; confirm it is skipped. Test app-switch timing and document any missed attribution.
- With persistence off, quit/restart and verify history is empty and the persistence file is absent.
- Turn persistence on, capture an entry, quit/restart, and verify it returns. Verify the file is encrypted and contains no plaintext copy. Disable persistence and confirm deletion.
- Lock, sleep, and switch users; verify capture stops and default history clears. Test clearing disabled as well.
- Apply the example profile on an enrolled pilot Mac. Confirm forced controls lock, history trims, capture disable clears memory/disk, and changes are picked up within two seconds. Remove it and verify local settings become editable.
- Deny Keychain/file access and verify visible errors without logging clipboard contents.
- Test on both Intel and Apple Silicon, macOS 13 and current macOS. Test keyboard layouts beyond US ANSI; shortcut keys currently use physical ANSI key positions.
- Inspect the signed, notarized release with Gatekeeper and test Homebrew install/uninstall from the tap.

Preferences update validation: Command-comma opens the native toolbar settings window; General, History, and Privacy panes were inspected visually. Hiding the icon, closing Settings, reopening the app, and opening Settings again succeeded; the previously selected pane was retained. The menu bar preference was restored to on after testing. Shortcut-conflict fallback remains a manual check.


## Automatic paste and compact picker

Nine automated tests pass, including quick-tap versus held-selection release, one-shot commit, and cancellation. Manual checks required on a permission-enabled Mac:

- Enable Accessibility for the final installed app; copy test entries from TextEdit. Hold the shortcut, navigate with arrows, release Command, and verify exactly one paste into the original selection. Also test Return and row-click selection.
- Quick-tap the shortcut and verify the picker stays open. Escape, outside clicks, and Command-comma must cancel release-to-paste.
- Deny/revoke Accessibility and verify the copy-and-explain fallback, then grant permission and retry.
- Change focus during return to the target, hold extra modifiers, or terminate the target. Verify no paste goes to another process.
- Disable PasteAutomatically and verify both Return and release selection only copy.
- Verify metadata for older saved entries without a source app, multi-line text, and image dimensions.

Local UI validation on 2026-09-26: compact selected row and metadata inspected; native Command-A/Command-C in the filter field work; Return without Accessibility permission copies and displays the permission setup banner. Actual cross-app paste remains unverified until the user grants Accessibility permission to the installed build.
