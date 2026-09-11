# Troubleshooting

## The controller is not shown

1. Open TactiCommand's **Devices** sheet and select **Refresh**.
2. For Bluetooth, open **Bluetooth Settings** and connect the controller there.
3. Confirm Input Monitoring access for the exact TactiCommand bundle.
4. Quit other controller utilities that may own the vendor HID interface.
5. Select **Reconnect App**.

Nearby Bluetooth HID discovery and pairing belong to macOS; TactiCommand can
only list compatible HID devices made available to the app.

## A device message was ignored

TactiCommand deliberately replaces raw JSON/Swift decoder details with a short
warning. Control remains active, and the warning clears after the next valid
device event. Repeated warnings usually indicate a firmware/protocol mismatch;
include firmware and transport in a redacted bug report.

## A key does nothing

- Check that the expected software layer is active.
- Confirm the key is assigned on that layer.
- Grant Accessibility for keyboard, pointer, app, and window actions.
- For dictation, use **Test Shortcut** and verify the provider reacts.

## The wrong layer is active

Next and Previous operate on the six software layers. The three hardware host
indicators are Bluetooth profiles, not layers. A frontmost-app rule can
temporarily override the manual layer and restores it when the app is left.

## Reporting safely

Never attach a real configuration, session file, terminal history, device
serial number, personal path, or unredacted screenshot to a public issue.
