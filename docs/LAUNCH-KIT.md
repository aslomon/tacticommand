# TactiCommand Launch Kit

Use these messages as a starting point, then adapt them to the norms of each
community. TactiCommand is independent and unofficial; never imply endorsement
by Work Louder, OpenAI, Anthropic, or Cursor.

## Canonical positioning

**Name:** TactiCommand

**Tagline:** A local-first command surface for your micro controller.

**Short description:** Open-source macOS control software for Creator Micro 2
and Codex Micro, with layers, voice triggers, shortcuts, audio controls, and
coding-agent status.

**Repository:** https://github.com/aslomon/tacticommand

## Search vocabulary

Use naturally where relevant:

- Creator Micro 2 macOS app
- Codex Micro controller
- Work Louder macropad
- OpenAI Codex hardware workflow
- Codex CLI and Codex App shortcuts
- Claude Code CLI and Claude App controller
- Cursor coding controller
- macOS menu bar automation
- SwiftUI HID controller
- open-source macropad software

## Show HN

**Title:** Show HN: TactiCommand – open-source macOS control for Creator Micro

I built TactiCommand, a native SwiftUI menu bar app for the Work Louder Creator
Micro 2 and Codex Micro. It provides ten configurable software layers, reusable
slash commands, recorded shortcuts, voice/dictation triggers, CoreAudio mute
state, joystick modes, and live Codex/Claude session status.

It is local-first: no account, telemetry, cloud backend, or network listener.
The same-user automation API is a permission-restricted Unix socket. The source,
tests, privacy boundary, hardware notes, and MIT license are here:

https://github.com/aslomon/tacticommand

There is no notarized binary yet, so this first release is source-build only. I
would especially value feedback on useful layer presets and safe automation
boundaries for tactile coding workflows.

## Reddit: macOS and hardware communities

**Title:** I built an open-source macOS controller app for Creator Micro 2 / Codex Micro

TactiCommand is a native SwiftUI menu bar app that makes the Micro a local-first
command surface. It supports ten layers, copy/paste and slash commands, custom
shortcuts, voice triggers, audio mute feedback, joystick control, and coding
agent status. Everything runs locally and the project is MIT licensed.

Source and setup: https://github.com/aslomon/tacticommand

This is an independent community project, not an official Work Louder or OpenAI
release. It is currently source-build only while proper Developer ID signing and
notarization are still pending. Feedback and hardware reports are welcome.

## Product Hunt

**Tagline:** Turn Creator Micro into a local-first macOS command surface.

**Description:** TactiCommand is an open-source SwiftUI app for Creator Micro 2
and Codex Micro. Configure tactile layers for desktop control and coding agents,
trigger voice or slash commands, monitor mute and agent state, and automate macOS
without an account, telemetry, or cloud backend.

## Indie Hackers / build in public

I wanted my small tactile controller to do more than replay fixed shortcuts, so
I built TactiCommand: an open-source native macOS app with ten contextual layers,
voice triggers, safe action sequences, joystick modes, and live coding-agent
state. The interesting constraint was keeping hardware integration and local
automation useful without turning the app into a telemetry-heavy cloud service.

The repository includes 441 automated tests, an explicit privacy boundary, and
reproducible source builds: https://github.com/aslomon/tacticommand

## Launch checklist

- Confirm the latest GitHub Actions run is green.
- Include one current app screenshot and the social preview image.
- State clearly that the project is independent and source-build only.
- Read each community's self-promotion rules before posting.
- Stay available for technical questions after posting.
- Do not cross-post identical copy to multiple subreddits at the same time.
