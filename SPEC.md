# TactiCommand - Product Specification

## Objective

Deliver a standalone, local-first macOS menu bar app named TactiCommand that turns a Codex Micro /
Creator Micro 2 into a configurable system control surface without modifying or
depending on the rede application.

## Required capabilities

1. Detect the pad over USB and Bluetooth LE and reconnect without relaunching.
2. Route every physical key, dial event, and joystick movement through a
   configurable ten-layer binding model.
3. Offer exactly three first-class dictation providers: rede, ChatGPT/Codex,
   and Apple Dictation. Show newly installed applications in a custom provider
   picker and retain provider-specific hold or toggle behavior.
4. Support the two microphone switches as either one deduplicated wide key or
   two independent bindings. Default the left switch to dictation and the right
   switch to input-mute toggle so its live red/green state remains visible.
5. Provide actions for Return, Escape, backward Delete, terminal, Finder,
   application/window switching, text snippets, volume, output mute, input mute,
   pointer movement, clicks, scrolling, AppleScript, shell commands, and agent
   focus.
6. Render true state on the six individually addressable RGB Agent keys and use
   global backlight/underglow for device, mute, and dictation state.
7. Normalize up to six Codex, Claude, or terminal agent sessions with honest
   working, waiting, complete, error, and unavailable states.
8. Expose local automation through App Intents and a versioned local RPC
   contract. Never expose microphone or shell actions through an unauthenticated
   network listener.
9. Surface and diagnose Input Monitoring, Accessibility, Microphone, Automation,
   hardware ownership, and competing-app conflicts.
10. Expose a menu bar utility, remain a regular Dock/App Switcher process so it
    is available in macOS Force Quit, support launch at login, and install as a
    normal application in `/Applications`.
11. Make layer changes explicit in the editor and assignable to physical keys;
    support next, previous, and direct layer selection without confusing the
    haptic Bluetooth-profile control with a software layer switch.
12. Give real press/release keys an optional long-press action while preserving
    the normal short-press action. Encoder rotation pulses are never eligible.
13. Let every layer choose Arrow Keys, Mouse Pointer, or Off for the joystick.
    Desktop defaults to Arrow Keys. Pointer mode remains fast at full deflection
    with a fine-control response through the center and middle of its range.
    Default pointer clicks to primary click only; secondary and middle click
    remain optional actions.
14. Always expose a visible Quit command with `Command-Q`; termination cleanup
    must be bounded so a stalled device or automation service cannot trap the app.
15. Record global shortcuts from the active macOS keyboard layout while retaining
    every exact physical key code. Modifier chords, including `fn`, and ordered
    multi-main-key chords must replay without assuming an ANSI-US layout.
16. Keep dedicated input mute, output mute, volume-down, and volume-up controls
    available in every default layer, including Codex.
17. Apply per-app layer rules only while the configured application is
    frontmost, then restore the exact previous manual layer and selection source.
18. Confirm every actual software-layer change with a short-lived, non-activating
    system-wide pill that names the active layer and the layer selected by Next.
19. Offer first-class Copy, Paste, and configurable Slash Command actions in
    addition to free-form text entry. Slash Commands may optionally submit with
    Return after insertion.
20. Never expose raw Swift decoding internals in the interface. A malformed
    device message is reported in plain language and the warning clears after
    the next valid device event.
21. Show observed microphone mute, output mute, active dictation, and output
    volume inside every matching on-screen key using color, symbol, and text.
    Mirror the state to an assigned physical Agent key where individual RGB is
    supported; never imply that Action keys are individually addressable.
22. Keep joystick configuration collapsed until requested, then present
    Arrow Keys, Mouse Pointer, and Off as readable mode cards with explicit
    inherited-versus-layer-specific state.
23. List compatible HID devices currently available to the app and provide
    real reconnect controls. Delegate pairing and nearby Bluetooth HID discovery
    to macOS System Settings and explain that boundary.
24. Provide a user-recorded keyboard shortcut, Paste as Plain Text, safe 2–6-step
    action sequences, and automatic focus of the next agent needing attention.
    Agent attention priority is waiting, then error, then complete.
25. Ship ten active software layers in this order: Desktop, Claude Code CLI,
    Claude App, Codex CLI, Codex App, Cursor, Meetings, Agent Focus, Window
    Management, and Snippets. Applying an editable workflow preset to a slot
    must reuse the current Desktop chassis and require an explicit user action.
    Browser and Writing remain available as optional swap-in presets.
26. Render the menu-bar popover on an opaque native surface on first open,
    activate it for immediate interaction, and keep all status labels readable.
27. Offer an explicit Setup Guide that inspects a Creator Micro 2's firmware
    keymap and, only after a separate confirmation naming the active physical
    layer by index and name, provisions TactiCommand's dedicated physical
    layer while preserving every other physical layer and backing up the
    original keymap first. Restoring that backup requires its own separate
    confirmation and only runs on the exact connection that produced it.
    Codex Micro and unrecognized models never receive automatic firmware
    writes; Codex gets a read-only readiness check and configurator guidance.

## Default layers

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

## Dictation routing

- rede is invoked as an external application through its configured global
  shortcut; this app never reads rede settings or private data.
- ChatGPT/Codex uses its supported application shortcut and is marked as
  application-scoped rather than system-wide.
- Apple Dictation uses the user's configured macOS shortcut.
- Custom providers select an installed application and a recorded shortcut.
- Provider selection can be global, per layer, or per frontmost application.

## Hardware constraints

- VID `0x303A`, Codex PID `0x8360`, Creator Micro 2 PIDs `0x8297` / `0x8298`,
  vendor collection `0xFF00:0x01`, report id `0x06`. PIDs are model identifiers,
  independent of transport.
- USB output reports are 63 bytes; Bluetooth LE output reports are 64 bytes and
  include the report id prefix. The IOKit output adapter also prefixes Creator
  USB buffers with the report id; Codex USB retains its verified bare buffer.
- A successful `device.status` response, not an IOKit return code, proves that
  the output path works. A correlated 404 fails verification with official
  firmware update guidance; a version-only response is not a substitute.
- Send standard `method` / `params` envelopes, while accepting both standard
  and compact incoming messages. Creator `AG06`–`AG12` map to Action controls;
  a dedicated TactiCommand device layer uses `AG13` / `AG14` / `AG15` for dial
  clockwise / counter-clockwise / press. `kb.radial` is a joystick alias;
  its hide operation releases the stick even if the last distance is nonzero.
- Lighting capability is model-driven: Creator Micro 2 individually addresses
  all 13 LED positions (the wide microphone switch spans two of them); Codex
  individually addresses its six Agent keys and uses one shared zone for the
  rest. An unrecognized model gets the conservative Agent-only addressing and
  no assumed full-RGB layout.
- The wide microphone cap may actuate both `ACT10` and `ACT11`; linked mode must
  emit one logical action.
- Creator firmware's `device.status.layer_index` is one-based and selects the
  onboard keymap layer for explicit setup. It does not select an app software
  layer. The meaning of that value for unrelated firmware is not assumed.
- The haptic control beside the three white indicators selects one of three
  Bluetooth host profiles and is not a bindable software-layer control.
- Keys report distinct down/up events, so short/long press routing is supported;
  encoder rotation reports momentary pulses and cannot use long press.
- Firmware keymap writes always re-read the device immediately before writing
  and verify identity, profile, physical layer, and keymap content; the write
  aborts and the existing backup is kept if anything changed. A readback
  mismatch after writing keeps the backup and does not retry automatically.
- Firmware backups are written to local disk and persist across app restarts
  and device reconnects; restoring one still requires the exact original
  connection.

## Acceptance criteria

- A simulated transport proves parsing, framing, reconnection, layer routing,
  microphone deduplication, and LED rendering without touching real hardware.
- A user can select rede, ChatGPT/Codex, or Apple Dictation without editing a
  configuration file.
- A newly installed app is visible in the custom-provider picker after refresh.
- Linked microphone switches trigger once; split switches trigger independently.
- Every shortcut, control binding, layer joystick option, microphone layout,
  application rule, and successful Launch at Login change starts an atomic local
  save immediately. Rapid slider changes may coalesce, but the newest complete
  configuration must win and persist across launches.
- A configured Delete action emits one macOS backward-delete key tap on press and
  emits nothing on release.
- The Desktop joystick defaults to the four native macOS arrow keys; each other
  layer can independently select Arrow Keys, Mouse Pointer, or Off. Its adjacent
  key is primary click only, the key below the dial is Escape, and the key below
  the joystick is backward Delete.
- Arrow mode emits one key-down for a direction, system-rate repeat events while
  held, and one matching key-up on centre. Direction changes release before
  pressing, and stale input, mode/layer changes, permission loss, disconnect,
  and termination perform bounded best-effort release before rearming at centre.
- The layer rail explains every switching route, and a physical key can select
  the next, previous, or a specific software layer.
- Changing to another software layer shows a non-activating pill above the
  frontmost app with the active layer and the exact next layer. Re-selecting the
  already active layer does not show duplicate feedback.
- Copy emits `Command-C`, Paste emits `Command-V`, and Slash Command types its
  configured text with an optional trailing Return. Existing Type Text bindings
  remain decodable and editable.
- Paste as Plain Text emits `Option-Shift-Command-V`. A custom shortcut replays
  without rewriting its captured chord. A safe sequence stops on the first
  failed step and rejects scripts, dictation, layers, nested sequences, and
  agent-focus steps during configuration validation.
- The device sheet displays the observed product name and transport for every
  matching connected HID device. It never labels an unpaired nearby device as
  directly connectable by TactiCommand.
- Provisioning a Creator Micro 2 only proceeds after the user confirms the
  exact active physical layer being replaced; restoring only proceeds after a
  separate confirmation and only on the connection that created the backup.
  Neither happens automatically from detecting a connection, and inspecting
  never writes anything by itself.
- Malformed hardware JSON never exposes `DecodingError`, coding paths, or raw
  parser details to the user. A later valid device event clears that transient
  diagnostic without clearing an unrelated action failure.
- Mute-key state reflects the latest CoreAudio snapshot for toggle, mute, and
  unmute actions. Input mute is red, output mute is orange, unmuted is green,
  and mixed/unavailable states are explicitly labelled.
- An application rule temporarily selects its layer only while its application
  is frontmost. Leaving it restores the exact prior layer and source; an unknown
  frontmost app never changes a manual selection.
- A short press fires only its primary action; crossing the long-press threshold
  fires only the configured hold action and releases it correctly.
- Default Desktop and workflow mappings do not consume keys for secondary or
  middle click; primary click is immediately available beside the joystick.
- Mid-travel joystick input moves more slowly than the previous quadratic curve
  while full deflection retains the configured maximum speed.
- Migrating an existing Desktop mapping changes the three affected physical
  keys and the enabled Desktop joystick mode to Arrow Keys while preserving its
  calibration and every unrelated binding. An explicitly disabled joystick
  remains Off.
- Quitting from the menu or with `Command-Q` completes no later than the bounded
  shutdown deadline even if an asynchronous cleanup operation never returns.
- The installed TactiCommand app is visible in the Dock, App Switcher, and macOS Force Quit
  while retaining its menu bar control.
- Recording a shortcut on a German layout labels `Y`, `Z`, and punctuation as
  typed, preserves physical codes for main keys, and captures modifier-only
  chords or modifiers plus ordered main keys such as `Command + J + K`; older
  shortcut configuration remains decodable. Left/right modifier variants share
  one semantic modifier identity.
- Shortcut recording passes `Command-Q` and `Option-Command-Escape` through to
  macOS after cancelling its own recording session.
- Every default layer maps the dedicated mute key and all three dial gestures to
  input mute, volume down/up, and output mute. Migration recognizes the exact
  legacy Codex default and never infers audio bindings in a customized layer.
- No unavailable agent or provider is shown as healthy.
- Exact untouched version-five workflow layers migrate to the recommended
  presets while Desktop, customized layers, app rules, and preferences remain
  unchanged. A preset can replace any one slot without changing another.
- Layer names are editable, trimmed, persisted immediately, and remain within
  the existing configuration-validation limit. Renaming starts only after an
  explicit user action; opening Settings never focuses the layer-name editor.
- Claude Code CLI displays only its configured CLI actions. Agent-session titles
  and colors are restricted to Agent Focus, and assigned slash-command keys show
  their exact command text.
- The menu-bar popover is opaque and keyboard-ready on its first presentation;
  its device, layer, and provider chips use primary text plus semantic icons.
- `swift build`, `swift test`, app-bundle verification, and code review pass.
- Final hardware acceptance verifies USB, Bluetooth, the raw internal layer
  diagnostic, every input, six RGB keys, ChatGPT coexistence, and reconnect
  behavior.
