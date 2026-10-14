# TactiCommand - Design System

This document is the source of truth for every visual decision in the macOS app.

## Product character

**Quiet hardware console.** The interface should feel like a compact piece of
studio equipment: precise, calm, tactile, and immediately readable. It uses
native macOS controls and materials, with a distinctive cyan signal line rather
than decorative gradients or generic dashboard cards.

The menu bar popover is for status and one-click changes. The configuration
window is a focused visual editor for the physical pad.

## Color palette

| Token | Value | Use |
| --- | --- | --- |
| `signal` | `#24C8DB` | Selection, connected hardware, active layer |
| `signalSoft` | `signal` at 14% | Selected rows and key wells |
| `graphite` | `#17191D` | Dark-mode editor canvas |
| `surface` | system material | Popover and panels |
| `line` | primary at 10% | Dividers and hardware outlines |
| `idle` | system gray | Idle or unassigned |
| `working` | `#3478F6` | Agent working or transcription processing |
| `ready` | `#30D158` | Complete, microphone available |
| `attention` | `#FF9F0A` | Approval or user input required |
| `failure` | `#FF453A` | Error or muted microphone |
| `recording` | `#22D3A7` | Active dictation capture |

Status colors are semantic and must never be the only carrier of meaning.

## Typography

- Product title: SF Pro Rounded, 15 pt, semibold.
- Section title: SF Pro, 11 pt, semibold, uppercase, 0.6 tracking.
- Body and control labels: SF Pro, 13 pt, regular.
- Hardware key label: SF Pro Rounded, 11 pt, semibold.
- Technical values: SF Mono, 11 pt.
- Captions and inline help: SF Pro, 11 pt, regular, secondary color.

## Spacing

Use the 4 pt base scale: `4, 8, 12, 16, 24, 32`.

- Menu bar popover width: 392 pt.
- Configuration window minimum: 840 x 620 pt.
- Panel inset: 16 pt.
- Control row minimum height: 32 pt.
- Hardware diagram gaps mirror the real key spacing and remain at least 8 pt.

## Shape and depth

- Key wells: 9 pt continuous radius.
- Cards and panels: 12 pt continuous radius.
- Pills and status chips: capsule shape.
- Selected physical keys use a 2 pt signal outline and signal-soft fill.
- Use one subtle canvas shadow only: black at 14%, radius 18, y 8.
- Do not stack shadows or use glass effects inside glass effects.

## Motion

- Selection and status changes: 180 ms ease-out.
- Physical key press: 110 ms ease-out, 2 pt depression; Reduce Motion drops
  the displacement and cross-fades opacity instead.
- Layer changes: 220 ms spring, low bounce.
- Recording state: a restrained 1.4 s breathing signal ring.
- Error and approval states do not bounce; they use color plus an icon change.
- Respect Reduce Motion and replace animated transitions with cross-fades.

## Component patterns

- **Status strip:** device, active layer, dictation provider, and permissions.
- **Menu bar popover:** use a native anchored popover with a visible arrow to
  the status item. Keep the 392 pt content width and avoid narrow text wrapping.
- **Pad canvas:** proportionally accurate key, dial, stick, and touch layout.
  The AG0/AG1 top-row order follows the connected device's real physical
  input layout. Physical Creator Micro 2 verification places AG0 left of AG1,
  matching the historical Codex and unknown-model arrangement. LED wiring
  assumptions must not reverse input geometry or modify saved bindings.
- **Inspector:** action type first, then only fields relevant to that action.
- **Provider picker:** built-ins first, detected providers next, custom app last.
- **Layer rail:** ten numbered segments in workflow order with editable names
  and AppSense scope. The rail scrolls independently at the minimum window size
  so presets, status, and host guidance remain reachable.
- **Layer naming:** the selected name is read-only until the user activates its
  pencil control. Settings must never open with a text field focused, because
  hardware-triggered text and slash commands belong to the previously focused
  work app rather than the configuration editor.
- **Workflow presets:** the rail exposes a compact preset menu for the selected
  slot. Presets copy the user's Desktop chassis before applying only their
  environment-specific controls. Applying one is explicit, never automatic.
  Ten active slots are available at once; additional presets can replace any
  slot after confirmation.
- **Layer switching:** the rail pairs the current layer with a short explanation
  of manual key actions and automatic app rules. The menu bar popover exposes a
  direct software-layer picker, names the default physical cycle key, and names
  the exact local source: Default, Editor, Key, App rule, or Automation.
  Bluetooth host-profile status stays visually separate and is never labelled
  as a layer. A raw firmware `layer_index` may appear as a neutral diagnostic,
  but never as a confirmed or selectable software layer.
- **Layer change HUD:** every actual software-layer change presents one compact,
  non-activating, opaque capsule near the top center of the active screen. A
  four-dot mark anchors the left edge. `ACTIVE LAYER`, the active name, the
  selection source, and a monospaced `NEXT` line establish the hierarchy. It
  dismisses automatically, never steals focus, and cross-fades when Reduce
  Motion is enabled.
- **Text and clipboard actions:** Copy and Paste are separate action choices.
  Paste as Plain Text is visually distinct. Type Text accepts any fixed input.
  Slash Command uses a monospaced command field, explains its Codex/Claude
  purpose, offers an explicit Submit with Return toggle, and displays the exact
  command on its assigned hardware key.
- **Shortcut and sequence actions:** custom shortcuts reuse the safe physical
  recorder. An optional 128-byte plain-text name appears on the assigned key;
  unnamed shortcuts show their formatted chord. Action sequences show a numbered 2–6-step list, allow only safe
  built-in actions, and never hide scripts inside a generic macro label.
- **Application controls:** Launch at Login belongs in the configuration header,
  not the status popover. The popover footer ends with a compact power-labelled
  Quit control that retains `Command-Q` and a complete VoiceOver label.
- **Dual action:** eligible physical keys show `Short press` first and an optional
  `Long press` disclosure beneath it. The secondary action never hides the
  primary action or relies on color alone.
- **Permission row:** state, plain-language reason, and one settings button.
- **Shortcut recorder:** show the full captured chord, the active keyboard-layout
  label, and a clear recording state. Physical key identity is implementation
  detail and must not replace the user's localized key label. Copy explicitly
  permits modifier-only chords, including `fn`, or modifiers plus one or more
  simultaneous main keys. Left/right modifier variants share one displayed
  identity. System escape routes (`Command-Q` and `Option-Command-Escape`) cancel
  recording and visibly remain owned by macOS.
- **Activity row:** label, semantic icon, and timestamp; no raw log noise.
- **Device diagnostics:** malformed device messages use one plain-language,
  transient warning. Swift type names, coding paths, and decoder internals are
  never user-facing.
- **Auto Layer:** each layer may name one foreground application; matching is
  case-insensitive and changes the active mapping without altering the device.
  The label says that the change lasts only while the app is frontmost. Leaving
  the app restores the exact preceding manual layer and its selection source.
- **Dial editor:** the physical dial shows three compact, explicit selectors for
  counter-clockwise rotation, press, and clockwise rotation. Selection never
  requires physically rotating the dial.
- **Joystick mode:** the section is collapsed by default and its summary states
  whether behavior is inherited or layer-specific. Expanded mode cards offer
  Arrow Keys, Mouse Pointer, and Off with symbols and plain-language details.
  Dead zone appears for both active modes; maximum speed appears only for Mouse
  Pointer. Help copy describes held-key release behavior rather than exposing
  event-synthesis terminology.
- **Arrow joystick:** each cardinal direction holds one semantic arrow key and
  follows the user's macOS repeat timing. Diagonal-boundary hysteresis avoids
  visual and behavioral chatter. Centre, stale input, permission or connection
  loss, mode/layer changes, and termination release held state. After a forced
  stop, the stick must return to centre before rearming.
- **Pointer joystick:** fine travel uses a restrained cubic curve; full travel
  still reaches the configured maximum. The high-frequency motion loop exists
  only while a live deflection is active and stops on centre or stale input.
- **Desktop spatial mapping:** the joystick defaults to four-way Arrow Keys. Its
  adjacent key defaults to primary click only. The physical key below the dial
  is Escape; the physical key below the joystick is backward Delete. Labels and
  symbols make these spatial defaults visible without hiding configurability.
- **Pointer nudge:** directional button actions expose signed horizontal and
  vertical pixel distances; movement is never presented as a click action.
- **Live key state:** selection remains a cyan outline, press remains a physical
  offset, and observed action state uses the key interior plus a symbol and
  short label. Microphone mute is red, output mute is orange, unmuted audio is
  green, mixed state is orange, unavailable state is neutral, active dictation
  is teal, and current volume is cyan. The observed state never claims that a
  requested toggle succeeded before CoreAudio confirms it.
- **Physical key state:** individual-key RGB capability is model- and
  capability-driven, not a fixed Agent-only rule. Creator Micro backlights all
  13 LED positions individually — the wide action10/action11 switch is one
  physical cap spanning two of those positions, not two independent keys.
  Codex backlights its 6 Agent keys individually while the remaining action
  keys share one firmware backlight zone. When a key owns a stateful action
  on the active layer, that action state takes priority over its individual
  or shared-zone color. Agent-session titles and colors appear only while the
  dedicated Agent Focus layer is active. An unrecognized or undetected model
  gets honest unsupported lighting guidance rather than an assumed full-RGB
  layout.
- **Device management:** a dedicated sheet lists only HID devices that match the
  supported hardware identity and are currently available to the app. It names
  the observed product and transport. Pairing and nearby discovery link to
  macOS Bluetooth Settings instead of presenting a fake in-app Connect button.
- **Setup Guide:** a scrollable sheet reachable from the configuration header
  and from Device Management. It shows permission state (reusing the system
  access banner and its explicit request buttons), live connection and model,
  and inspected firmware/physical-layer readiness behind an explicit
  Inspect/Refresh — inspecting never writes anything by itself, and a live
  connection alone is never shown as success. Provisioning only appears for a
  Creator Micro 2 that isn't already prepared; confirming it names the active
  physical layer by index and name, states that every other physical layer is
  preserved, and backs up the complete original keymap first. Codex shows its
  own readiness check and points to its official configurator instead of
  writing anything; an unrecognized model gets honest unsupported guidance and
  no write controls at all. Restore is a separate confirmation, stays disabled
  outside the exact connection that produced its backup, and keeps that
  backup's path visible, copyable, and revealable in Finder even while restore
  is unavailable — the file itself survives app and device restarts. A
  dedicated note distinguishes the controller's onboard physical layer from
  TactiCommand's software layers. The Creator firmware release link is scoped
  to that model only and never implied to be the latest release for every
  device.

## Brand rules

- Product name is **TactiCommand**, from tactile plus command.
- Tagline is **A local-first command surface for your micro controller.**
- The menu bar remains the compact control surface, while the regular Dock icon
  keeps the process discoverable in App Switcher and macOS Force Quit.
- Menu bar symbol is a custom-feeling composition of `circle.grid.2x2.fill`
  and a small signal dot, rendered as a template image.
- Use SF Symbols throughout the UI; no emoji or illustrated stock assets.
- The Dock and in-app logo reduce the Creator Micro control surface to four
  warm-white circles on a graphite macOS squircle. It deliberately shares the
  geometry of the native `circle.grid.2x2.fill` status item while retaining a
  quiet app-icon surface. Keep it monochrome, spacious, and legible at 16 px.
- UI copy and code documentation are English.
- The app remains local-first: no account, telemetry, or cloud sync.
- Repository share artwork uses a 2:1 graphite canvas, the four-dot mark, one
  cyan signal line, the product name, and the canonical tagline. It must remain
  readable in compact social cards and must state no third-party affiliation.

## Signature detail

The pad canvas is live: pressing a physical key depresses the matching on-screen
key, while its semantic status appears as a narrow light bar. This is both the
primary configuration affordance and the hardware diagnostic, not decoration.

The three narrow hardware indicators always visualize the reported Bluetooth
  host profile. They never infer a software-layer value with modulo arithmetic. The
ambient zone is green when ready, cyan while dictation is active, and breathing
red while microphone input is muted. Agent keys retain their independent status
colors on top of that global signal.

Each key also carries a narrow bottom light bar echoing this ambient signal at
key scale: the key's live action tone when present, the signal color while
selected, or a quiet neutral line otherwise.

## Accessibility

- Every key exposes its physical id, label, action, and state to VoiceOver.
- Keyboard navigation reaches every binding and provider control.
- `Command-Q` and a visible text-labelled Quit command are always available from
  the menu bar popover.
- `Option-Command-Escape` must stay available even during shortcut recording.
- Minimum pointer target is 28 pt; primary buttons are at least 32 pt high.
- Status always combines color with text or an SF Symbol.
- Contrast follows system accessibility settings in light and dark mode.
