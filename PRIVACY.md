# Privacy

TactiCommand is local-first. It has no account system, telemetry, analytics,
cloud sync, advertising SDK, or network listener. The app does not transmit
configuration or session data.

## Data processed locally

To provide its features, TactiCommand may read:

- its configuration in `~/Library/Application Support/CreatorMicroControl/`;
- connected HID device metadata and status reported by the controller;
- a short local history of observed controller names, transports, and serial
  identifiers so previously seen devices can be identified;
- installed, running, and frontmost macOS applications;
- CoreAudio mute and output-volume state;
- bounded portions of recent Codex session JSONL files under
  `~/.codex/sessions`;
- bounded portions of recent Claude project JSONL files under
  `~/.claude/projects`;
- local process and open-file metadata through `ps` and `lsof` for agent
  liveness and focus detection.

Agent session content is used only to derive local labels, lifecycle state,
timestamps, and focus targets. It is not uploaded by TactiCommand.

## Sensitive configuration

Custom text, Slash Commands, shell commands, AppleScript, application paths,
and recorded shortcuts may be sensitive. The configuration file is created
with mode `0600`. Do not post it in public issues or attach it to screenshots
without reviewing and redacting it.

## Permissions

- Accessibility: sends configured keyboard, pointer, and application actions.
- Input Monitoring: receives vendor HID events from the controller.
- Automation: focuses applications and windows when a configured action needs it.

TactiCommand does not record microphone audio. Dictation is triggered through
the selected provider's shortcut; that provider owns its microphone permission
and privacy behavior.
