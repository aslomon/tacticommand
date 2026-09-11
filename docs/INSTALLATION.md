# Installation

## Requirements

- macOS 14 or later
- Xcode 16 or later with Command Line Tools selected
- Swift 6
- XcodeGen 2.46 or later

## Build

```bash
brew install xcodegen
git clone https://github.com/aslomon/tacticommand.git
cd tacticommand
./Scripts/verify.sh
open build/TactiCommand.app
```

To copy the app into `/Applications`, quit an existing instance first and use
`ditto` so bundle metadata is preserved.

## Local signing

`./Scripts/setup-local-signing.sh` creates a code-signing-only self-signed
identity for local development. It is not a Developer ID identity and does not
make a build suitable for public binary distribution.

The bundle identifier intentionally remains `com.creatormicro.control` so the
TactiCommand rename preserves existing local permissions and configuration.

## Permissions

Grant Accessibility and Input Monitoring from macOS Privacy & Security. The
app never edits the TCC database. If permissions do not take effect, quit and
reopen the exact signed app bundle after enabling them.
