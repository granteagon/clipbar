# Validation

## Automated

`swift test` checks deduplication, count limits, expiry boundaries, no-expiry mode, per-item rejection, total history memory eviction, policy reduction, and clearing. Encrypted-file tests also verify round-trip decoding, absence of plaintext, file permissions, deletion, and rejection of tampered ciphertext using an injected test key. These tests do not validate OS clipboard APIs, actual Keychain access, hotkeys, or MDM delivery.

Local validation on 2026-09-25: six tests pass; universal arm64/x86_64 build and ad-hoc signature verification pass; both slices declare macOS 13.0 minimum. First-launch history and Settings were inspected through native accessibility and the history panel screenshot. Global hotkey automation timed out; end-to-end copy/paste, Keychain interaction, and managed-device enforcement remain manual release checks.

## Manual before public release

- Start the bundled app. Verify no Dock icon and a visible clipboard menu bar icon.
- Copy two text entries and one PNG/TIFF. Open history with Command-backslash. Select with arrows while holding Command, then release to paste in the original app. Test Return and row clicks too.
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
- Invoke from the menu bar and verify the picker stays open until a selection is made. Escape, outside clicks, and Command-comma must cancel release-to-paste.
- Deny/revoke Accessibility and verify the copy-and-explain fallback, then grant permission and retry.
- Change focus during return to the target, hold extra modifiers, or terminate the target. Verify no paste goes to another process.
- Disable PasteAutomatically and verify both Return and release selection only copy.
- Verify metadata for older saved entries without a source app, multi-line text, and image dimensions.

Local UI validation on 2026-09-26: compact selected row and metadata inspected; native Command-A/Command-C in the filter field work; Return without Accessibility permission copies and displays the permission setup banner. Actual cross-app paste remains unverified until the user grants Accessibility permission to the installed build.


## Release-to-select correction

The picker is now borderless and search-free. Shortcut invocation arms the initial row; Command release is checked through both modifier events and a short-lived 16 ms timer in common run-loop modes. Selecting always copies and dismisses, including when Accessibility is denied. Menu-bar invocation does not arm release until navigation with Command held.

Additional regression tests cover initial-row commit without navigation and a missing modifier snapshot during navigation. Verify release with and without Accessibility, shortcut activation from a different app, Escape and outside-click cancellation, and permission recognition after signing-identity changes. The permission setup button opens the system pane directly; restart is an explicit user action because it discards memory-only history.

Live regression check: in a separate TextEdit test document, copied FIRST and SECOND entries, opened the picker, sent Command–Down, released Command, and pasted into the test document. The result was FIRST, confirming the selected older entry was copied on release while Accessibility was unavailable. Borderless layout with two rows was inspected. The Open Accessibility Settings button successfully navigated to Privacy & Security → Accessibility. System Settings showed an enabled ClipBar entry while the running app reported unavailable access, consistent with a stale signing identity or another copy; no privacy permissions were changed during testing. The new build's designated requirement uses the Apple Development certificate rather than per-build cdhashes.

Preferences visibility regression: invoking history (including reopening the app) explicitly orders Settings out before app activation. Settings hides when switching away from ClipBar. Command-comma cancels the release session and timer before opening Settings, so releasing Command leaves Settings open. Verify by opening Settings, switching apps, invoking history, then pressing Command-comma and releasing Command.

Live check: opened Preferences with Command-comma and confirmed it remained visible after key release. Reopened ClipBar while Preferences was open and confirmed only the picker was shown. Command-comma then reopened Preferences successfully. All 11 tests and the universal development-signed build pass.

2026-09-30 permission repair and end-to-end verification: automatic pasting was blocked by a stale Accessibility record, despite an enabled System Settings toggle. With user approval and user-completed macOS authentication, reset only com.granteagon.ClipBar's Accessibility record and re-added the current development-signed app. The existing process then reported enabled access without restart. In an isolated temporary TextEdit document, copied two distinct test entries, opened ClipBar without changing the target application, selected the older entry with Command–Down, and released Command. TextEdit's selected text was automatically replaced by the older entry; no Command-V was sent by the test operator. Existing history was retained. No paste-code change was needed.


## Version 0.1.0 release validation — September 30, 2026

20 automated tests pass on Apple Silicon with Xcode 27. Added coverage for concealed-type privacy markers, excluded apps and capture controls, managed preference write protection and bounds, private pasteboard text/image writes, duplicate metadata refresh, legacy optional source decoding, individual deletion, wrong encryption keys, and truncated ciphertext. Tests use isolated storage and pasteboards. The universal release build succeeds and both Mach-O slices declare macOS 13.0 minimum. Actual picker and settings screenshots use isolated sample data without reading user history.

Automatic text paste after Command release was verified in TextEdit after repairing the Accessibility grant (see above). Intel hardware, macOS 13 hardware, enrolled-device MDM delivery, lock/sleep integration, and broad third-party editor coverage remain unverified. These limits must accompany the initial release rather than be described as fully tested.
