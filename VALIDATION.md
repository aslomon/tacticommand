# TactiCommand Validation

Validation date: 2026-09-11

## Installed build

- App: TactiCommand 0.2.5 (9)
- Path: `/Applications/TactiCommand.app`
- Bundle identifier: `com.creatormicro.control` (retained for migration)
- Executable: universal `arm64` + `x86_64`
- Local signature: `Creator Micro Control Local Development`
- Installed code signature: valid on disk and satisfies its designated requirement
- Gatekeeper distribution assessment: rejected, as expected for the local
  self-signed identity
- Public binary release: intentionally withheld until Developer ID signing,
  Hardened Runtime, notarization, stapling, and checksums are available

The previous `/Applications/Creator Micro Control.app` was moved to the user's
Trash after TactiCommand launched successfully. It remains recoverable.

## Configuration migration proof

The configuration SHA-256 was identical before and after installing and
launching the renamed app:

```text
e68730b8275c0f546be4eea686f77c7aae9e7954ef4e53e7a5f85c2a523a32ac
```

The legacy-compatible Application Support path and bundle identifier remain
unchanged, so existing mappings, automation clients, and TCC identity are
preserved.

## Automated verification

`./Scripts/verify.sh` passed after the feature and rename work:

- strict `swift-format` lint
- strict-concurrency build with warnings treated as errors
- 384 tests, 0 failures
- signing-contract tests
- release Xcode build through XcodeGen
- generated multi-resolution ICNS from the new TactiCommand master icon
- Info.plist and version checks
- universal architecture verification
- App Intents metadata presence
- bundled FreeMicro notice
- deep strict code-signature verification

## Live runtime proof

The installed app process answered its same-user Unix-domain RPC endpoint:

```text
isReady: true
connection: connected
activeLayer: Desktop (index 1)
layerSource: launchDefault
firmware: v0.4.1
transport: Bluetooth Low Energy (observed through IOHID)
profile: Host 1
battery: 98%, not charging
```

The live layer list returned Codex, Desktop, Agents, Windows, Meetings, and
Snippets in the configured order. IORegistry exposed the compatible device as
`Codex Micro #1`; its serial value is intentionally omitted from this document.

## Feature evidence

- Malformed hardware payloads resolve to a transient plain-language message;
  decoding types and coding paths are not exposed.
- Layer changes are deduplicated and create one non-activating active/next HUD
  presentation.
- The menu-bar surface is an `NSStatusItem` with a 392 pt native `NSPopover`,
  transient dismissal, and an AppKit-provided status-item arrow.
- Copy, Paste, Paste as Plain Text, Slash Command, custom shortcut, safe action
  sequence, and next-agent-attention actions round-trip through configuration.
- Input/output mute, dictation-toggle state, volume, dual actions, and sequences
  resolve deterministic semantic key state. Agent keys map that state to tested
  RGB payloads.
- Joystick settings are collapsed by default and expose explicit mode cards.
- The device sheet reads matching live IOHID devices, remembers up to eight
  previously observed devices locally, and delegates HID pairing to macOS.

## Remaining distribution boundary

Source publication is ready. A public downloadable app is not claimed ready:
this machine has no Developer ID Application identity, and the locally signed
bundle is not notarized. The repository documentation states this explicitly.
