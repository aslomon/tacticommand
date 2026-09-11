# TactiCommand Validation

Validation date: 2026-09-11

## Installed build

- App: TactiCommand 0.3.0 (13)
- Path: `/Applications/TactiCommand.app`
- Bundle identifier: `com.creatormicro.control` (retained for migration)
- Executable: universal `arm64` + `x86_64`
- Local signature: `Creator Micro Control Local Development`
- Installed code signature: valid on disk and satisfies its designated requirement
- Public binary release: intentionally withheld until Developer ID signing,
  Hardened Runtime, notarization, stapling, and checksums are available

Replaced local app bundles were moved to the user's Trash and remain
recoverable.

## Configuration migration proof

The installed app migrated the real schema-seven configuration to schema eight,
kept the existing Desktop and customized Meetings mappings, and produced ten
ordered layers. Before writing the migration, it preserved the exact original
bytes in a private mode-`0600` backup:

```text
configuration.v7.backup.json
SHA-256 f7cfa4ab5d28e5cccc8392d6fefd30ebd8acf143d87f249236a5dc5a72eada21
```

The migrated configuration is also mode `0600`. Unchanged preset shortcuts gain
their new display names, while customized shortcut chords are left untouched.
The legacy-compatible Application Support path and bundle identifier remain
unchanged.

## Automated verification

`./Scripts/verify.sh` passed after the feature work:

- strict `swift-format` lint
- strict-concurrency build with warnings treated as errors
- 441 tests, 0 failures
- signing-contract tests
- release Xcode build through XcodeGen
- generated multi-resolution ICNS from the TactiCommand master icon
- Info.plist and version checks
- universal architecture verification
- App Intents metadata presence
- bundled FreeMicro notice
- deep strict code-signature verification

## Live runtime proof

The installed build answered its same-user Unix-domain RPC endpoint:

```text
isReady: true
connection: connected
activeLayer: Claude Code CLI
layerSource: editor
firmware: v0.4.1
profile: Host 1
battery: 92%, not charging
```

The live layer list returned this display order:

1. Desktop
2. Claude Code CLI
3. Claude App
4. Codex CLI
5. Codex App
6. Cursor
7. Meetings
8. Agent Focus
9. Window Management
10. Snippets

The Claude Code CLI layer contains no `agentFocus` action. Visual and
accessibility inspection of the installed app confirmed that its six round keys
show Escape, Permission Mode, Transcript, `/status`, `/context`, and `/tasks`.
Agent-session titles appear only in Agent Focus. Settings opens with the window,
not the layer-name control, focused.

## Feature evidence

- Malformed hardware payloads resolve to a transient plain-language message;
  decoding types and coding paths are not exposed.
- Layer changes are deduplicated and create one non-activating active/next HUD.
- The menu-bar surface is a 392 pt native, opaque `NSPopover` with an anchored
  arrow. Launch at Login is in Settings; the footer uses a compact accessible
  power and Quit control.
- Copy, Paste, Paste as Plain Text, exact Slash Commands, named custom shortcuts,
  safe action sequences, and next-agent-attention actions round-trip through
  configuration.
- Input/output mute, dictation-toggle state, volume, dual actions, and sequences
  resolve deterministic semantic key state. Supported Agent keys mirror that
  state through tested RGB payloads.
- Joystick settings are collapsed by default and expose explicit mode cards.
- The device sheet reads matching live IOHID devices, remembers previously
  observed devices locally, and delegates HID pairing to macOS.
- Current repository screenshots were captured from the installed build and do
  not expose serial numbers, paths, or private configuration content.

## Remaining distribution boundary

Source publication is ready. A public downloadable app is not claimed ready:
this machine has no Developer ID Application identity, and the locally signed
bundle is not notarized. The repository documentation states this explicitly.
