# Managed deployment

Preference domain: `com.granteagon.ClipBar` (provisional while product naming is pending).

Deploy a **forced** custom preferences payload through your MDM, using Apple's `com.apple.ManagedClient.preferences` payload. The example profile is unsigned and illustrative; change its identifiers and organization before deployment. Do not install it on a production fleet before testing on a managed pilot Mac.

| Key | Type | Default | Behavior |
| --- | --- | --- | --- |
| PasteAutomatically | boolean | true | Requests pasting into the previous app; requires Accessibility authorization. False selects copy-only mode |
| ShowMenuBarIcon | boolean | true | False hides menu bar icon; shortcut failure overrides hiding to preserve access |
| CaptureEnabled | boolean | true | False stops capture and clears history, including its persistence file |
| HistoryLimit | integer | 50 | Clamped to 1–500; older entries evicted |
| RetentionHours | real | 24 | 0 disables age expiry; maximum 8760 hours |
| PersistHistory | boolean | false | False removes saved history; true enables local encrypted storage |
| ClearOnLock | boolean | true | Clears on lock, sleep, or session resignation |
| ExcludedBundleIDs | string array | Common password managers | Replaces the list, not additive; use full bundle identifiers |
| Shortcut | string | command-backslash | command-backslash, command-slash, or command-shift-v |

Controls display a lock when CFPreferences reports a forced value. Policy refresh runs every two seconds; count and age constraints also run before history opens. Invalid values fall back or clamp to supported ranges. The persistence file is deleted when capture or persistence is disabled; a visible error is shown on failure. Disk removal cannot remove OS backups or snapshots.

MDM can disable clipboard collection but cannot make this app a complete security boundary. The same user may run other clipboard utilities. Automatic paste uses Accessibility-authorized synthetic Command-V events targeted to the previous app after focus and modifier release checks. Copy-only mode requires no Accessibility authorization. Input Monitoring is not requested. Configure Accessibility through your approved macOS PPPC deployment process or individual user authorization. New macOS clipboard privacy prompts and managed OS restrictions may still apply.

Lock detection uses macOS distributed lock notifications plus workspace sleep and session notifications. Validate those signals on every supported managed OS version. End-to-end MDM enforcement has not been verified on an enrolled device in this project.

References: [Apple managed preferences](https://developer.apple.com/documentation/devicemanagement/managedpreferences), [forced preferences](https://developer.apple.com/documentation/corefoundation/cfpreferencesappvalueisforced(_:_:)).
