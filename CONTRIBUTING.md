# Contributing

Thanks for helping make TactiCommand better.

## Before opening a change

Use an issue for substantial behavior or protocol changes. Never attach a real
configuration, session file, terminal history, device serial number, or
unredacted screenshot.

## Local workflow

Requirements are macOS 14+, Xcode 16+, Swift 6, and XcodeGen 2.46+.

```bash
brew install xcodegen
swift test
./Scripts/verify.sh
```

Keep code, comments, commits, and documentation in English. Add tests before
implementation, keep functions focused, and preserve strict-concurrency
correctness. Do not add network services or analytics without an explicit
architecture and privacy review.

## Pull requests

- Explain the user problem and the observable result.
- Add or update tests and documentation.
- Confirm `./Scripts/verify.sh` passes.
- Call out hardware behavior that was simulated but not observed on a device.
- Keep generated build products and personal configuration out of the commit.
