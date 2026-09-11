# Changelog

All notable changes to TactiCommand are documented here.

## 0.3.0 - 2026-09-11

- Added ten active software layers for Desktop, Claude Code CLI, Claude App,
  Codex CLI, Codex App, Cursor, Meetings, Agent Focus, Window Management, and
  Snippets, plus optional Browser and Writing presets.
- Added optional names for recorded keyboard shortcuts and surfaced those names
  directly on assigned keys.
- Fixed Claude Code CLI keys incorrectly showing Agent Focus session names, and
  show each slash command directly on its assigned key.
- Moved Launch at Login into Settings and reduced the popover Quit action to a
  compact accessible power control.
- Preserved the user's Desktop chassis when applying a preset and added
  conservative configuration migrations through schema version eight with a
  private pre-migration backup.
- Added explicit layer renaming plus a preset replacement confirmation in the
  rail, without focusing an editable field when Settings opens.
- Redesigned the layer HUD around the four-dot brand mark, stronger hierarchy,
  and a fully opaque surface.
- Fixed first-open menu-bar popover contrast and focus behavior.
- Reduced the Dock and in-app icon to a minimal four-dot control surface.
- Added repository search positioning, a social preview, and a launch kit.

## 0.2.5 - 2026-09-11

- Renamed the app to TactiCommand while preserving the existing bundle identity
  and local configuration path.
- Added a native, wider menu-bar popover with a status-item arrow.
- Added active/next layer HUD feedback and clearer layer navigation help.
- Added Copy, Paste, Paste as Plain Text, Slash Command, custom shortcut, safe
  action sequence, and next-agent-attention actions.
- Added observed mute, dictation-toggle, and volume state inside key visuals and
  on individually addressable Agent-key LEDs.
- Reworked joystick settings into a collapsed, readable section.
- Added connected-device inventory and an honest macOS Bluetooth pairing path.
- Replaced raw Swift decoder failures with a transient plain-language warning.
- Added the new TactiCommand Dock icon.

## 0.2.4 - 2026-09-10

- Initial local hardware, layer, dictation, audio, agent, and automation build.
