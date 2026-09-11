# Architecture

TactiCommand separates deterministic domain behavior from macOS integration.

```text
IOHID reports
    -> CreatorMicroCore framing and parsing
    -> coordinator update streams
    -> AppModel routing and state
    -> action services / SwiftUI presentation / lighting payloads
```

## CreatorMicroCore

The core target owns protocol models, configuration and migration, validation,
layer and press routing, joystick state machines, agent normalization, lighting
payload construction, and the local automation contract. It has no SwiftUI or
AppKit dependency.

## CreatorMicroControl

The executable target owns IOHID, CoreAudio, event synthesis, application and
window focus, safe script execution, agent evidence adapters, menu-bar and
settings presentation, launch at login, and bounded shutdown.

## Safety boundaries

- External device/configuration data is parsed into typed models and validated.
- HID reconnection and joystick streams use generation and sequence boundaries.
- Long-running cleanup is bounded so Quit cannot hang indefinitely.
- RPC is same-user, size-limited, and cannot invoke shell or AppleScript.
- Bluetooth HID pairing is delegated to macOS.
- No component opens a network listener or uploads local state.

## Persistence compatibility

The product name changed to TactiCommand, but the bundle identifier,
configuration directory, and local automation path intentionally remain stable
to preserve mappings, permissions, and integrations from Creator Micro Control.
