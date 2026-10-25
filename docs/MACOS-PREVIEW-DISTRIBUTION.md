# macOS preview distribution

The preview uses `icons/icon.icns` for Finder and the Dock before launch, and
`assets/logo/icon-window.png` for the running window. Packaging removes the
runtime's `CFBundleIconName` asset-catalog override, installs `GameIcon.icns`,
and checks the icon bytes in the final ZIP. Change the source artwork through
`tools/make_icons.py`.

Without Apple credentials the build remains ad-hoc signed. That verifies bundle
integrity locally but does not remove Gatekeeper's unidentified-developer block
on downloaded copies. For a trusted download, Apple's per-app approval is in
System Settings → Privacy & Security → Open Anyway after attempting to open it.
The exception is local to the approved application; future builds can require
another approval. Do not disable Gatekeeper globally.

## Notarized GitHub releases

An Apple Developer Program membership, a **Developer ID Application** certificate
with its private key, and notarization credentials are required. An Apple
Development certificate or an ad-hoc identity is insufficient.

Configure these repository Actions secrets through GitHub's encrypted settings:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | Base64-encoded exported Developer ID Application `.p12`, including private key |
| `MACOS_CERTIFICATE_PASSWORD` | Export password for that `.p12` |
| `APPLE_ID` | Apple account authorized for notarization |
| `APPLE_APP_PASSWORD` | App-specific password for that account |
| `APPLE_TEAM_ID` | Developer team identifier |

Do not commit or send these values in issues, PRs or chat. The hosted runner
imports them into a dedicated temporary keychain, never logs certificate
subjects or credentials, deletes the temporary `.p12`, and removes the keychain
in an `always()` cleanup step.

Enable `notarize_macos` for one preview run. To require it for every subsequent
preview, set the repository **variable** `NATIVE_MACOS_NOTARIZE=true` after
configuring the secrets. Missing or rejected credentials fail the build;
there is no fallback to ad-hoc signing when notarization is requested.

The build signs nested native code from inside out with secure timestamps and
the hardened runtime, then signs the app with the existing LuaJIT entitlements.
It requires an `Accepted` notary submission, staples and validates the ticket,
verifies the code signature and runs Gatekeeper assessment. Only then does it
create the distribution ZIP and its final checksums. Publication independently
requires the signing/notarization receipts when notarization was requested.

`build-manifest.json` records `macosDistribution`: signing mode, icon SHA-256,
notarization acceptance, stapling, Gatekeeper assessment and submission ID.
Build, launch and gameplay evidence remain separate. A notarized application
can still receive macOS's ordinary first-open Internet-download confirmation.

## Local packaging

Use an already installed Developer ID identity and an existing notarytool
keychain profile. Supply `--macos-signing-identity` and `--macos-notary-profile`
to `tools/package_native_release.py`; optionally supply
`--macos-signing-keychain` for a dedicated keychain. Both signing arguments are
required together. The corresponding environment variables are
`MACOS_SIGNING_IDENTITY`, `MACOS_NOTARY_PROFILE` and `MACOS_SIGNING_KEYCHAIN`.
No command-line password argument is needed for packaging.

References: [Apple notarization workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution),
[customizing notarization and stapling](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow),
[per-app approval](https://support.apple.com/102445).
