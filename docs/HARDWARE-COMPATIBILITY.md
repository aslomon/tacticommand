# Hardware Compatibility

TactiCommand currently targets the Codex Micro / Creator Micro 2 identity:

| Property | Value |
| --- | --- |
| Vendor ID | `0x303A` |
| Product ID | `0x8360` |
| Vendor usage page | `0xFF00` |
| Report ID | `0x06` |
| USB output report | 63 bytes |
| Bluetooth LE output report | 64 bytes including report ID |

Bluetooth LE has been observed with firmware 0.4.1. USB framing and reconnect
are implemented and covered by simulated transport tests; every public hardware
claim should continue to distinguish observed evidence from simulation.

The six Agent keys accept individual RGB payloads. Action-key backlight and
underglow are shared firmware zones. The three narrow indicators and haptic
control select Bluetooth host profiles and are not software layer controls.

Protocol facts were independently implemented using the source pinned in
[`ThirdPartyNotices/FreeMicro.md`](../ThirdPartyNotices/FreeMicro.md).
