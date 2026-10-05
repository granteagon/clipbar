# Releasing ClipBar

## Source distribution through Homebrew

The initial release uses a source-built formula in [granteagon/homebrew-tap](https://github.com/granteagon/homebrew-tap). Users run:

```sh
brew install granteagon/tap/clipbar
clipbar
```

A personal tap does not need acceptance into Homebrew's central catalog. The formula builds the app with the user's local Swift toolchain and uses ad-hoc signing. It does not download an unsigned prebuilt application or disable Gatekeeper. This requires macOS 13+ and Swift 5.9+ Command Line Tools. Rebuilt versions may need Accessibility approval renewed.

For each release:

1. Update the version in `Resources/Info.plist` and the `--version` output in `App.swift`.
2. Run `swift test` with full Xcode selected. Build both architectures with `scripts/build.sh --universal` and inspect their minimum OS versions. Complete and record the relevant checks in `TESTING.md`.
3. Commit and push the source. Wait for GitHub Actions to pass, then create the version tag and GitHub release with honest validation notes.
4. Download the tagged source archive, calculate SHA-256, and update the formula's versioned URL and checksum in the tap.
5. Run `brew style`, `brew audit`, install from source, and `brew test`. Verify `clipbar --version`, then push the tap. Never point a formula at a nonexistent archive.

Unit tests do not replace real-device testing on each supported OS and architecture. Managed preference tests cover policy interpretation; enrolled-device MDM delivery needs a pilot Mac.

## Future prebuilt app / cask

A convenient downloadable `.app` needs a **Developer ID Application** certificate and notarization. Apple Development and Apple Distribution certificates are not substitutes.

1. Build with `SIGNING_IDENTITY='Developer ID Application: …' scripts/build.sh --universal`.
2. Archive using `ditto -c -k --keepParent dist/ClipBar.app dist/ClipBar-notarization.zip`.
3. Submit using `xcrun notarytool submit dist/ClipBar-notarization.zip --keychain-profile YOUR_PROFILE --wait`. Continue only if accepted.
4. Run `xcrun stapler staple dist/ClipBar.app`, `xcrun stapler validate dist/ClipBar.app`, and `spctl --assess --type execute --verbose dist/ClipBar.app`.
5. Create the final archive after stapling, attach it to a versioned release, and generate a cask using `scripts/make-cask.sh VERSION ARCHIVE`. Test it before publication. Migrate the formula deliberately so users do not get duplicate apps.

Homebrew's central cask repository has its own notability, compatibility, naming, and Gatekeeper requirements. Acceptance is discretionary; an open-source license alone does not guarantee it.

References: [Formula Cookbook](https://docs.brew.sh/Formula-Cookbook), [maintaining a tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap), [acceptable casks](https://docs.brew.sh/Acceptable-Casks).
