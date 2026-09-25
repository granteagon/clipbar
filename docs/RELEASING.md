# Release checklist

1. Settle the public name; update the app name, bundle identifier, profile, Keychain service, build scripts, and documentation together before first publication.
2. Run `swift test` using full Xcode (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` if command-line tools are selected). Complete the manual integration checks.
3. Obtain a **Developer ID Application** certificate through the Apple Developer Program. Apple Development and Apple Distribution certificates do not replace it for direct-download notarized apps.
4. Build the universal app with `SIGNING_IDENTITY='Developer ID Application: …' ./scripts/build.sh --universal`.
5. Archive with `ditto -c -k --keepParent dist/ClipBar.app dist/ClipBar-notarization.zip`.
6. Submit with `xcrun notarytool submit dist/ClipBar-notarization.zip --keychain-profile YOUR_PROFILE --wait`. Only proceed if accepted.
7. Run `xcrun stapler staple dist/ClipBar.app`, `xcrun stapler validate dist/ClipBar.app`, and `spctl --assess --type execute --verbose dist/ClipBar.app`.
8. Create the final archive **after stapling**, calculate its SHA-256, and attach it to a versioned GitHub release. Preserve versioned URLs.
9. Create a personal `homebrew-tap` repository and generate `Casks/clipbar.rb` with `scripts/make-cask.sh VERSION ARCHIVE`. Inspect the generated cask, run Homebrew audit and installation checks, then publish the tap. Update the provisional repository URL if renamed.

Do not publish a cask pointing to a nonexistent release or bypass Gatekeeper. Central `homebrew/cask` inclusion is a separate maintainer decision, not guaranteed by creating a tap. See [Homebrew's cask requirements](https://docs.brew.sh/Acceptable-Casks) and [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook).

This repository currently contains a development build workflow. It does not contain signing secrets or automatically publish releases.
