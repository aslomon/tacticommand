# Security Policy

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do
not open a public issue for a security problem and do not include credentials,
configuration files, session files, terminal history, personal paths, or
unredacted screenshots.

Include the affected version, macOS version, device/transport, a minimal
reproduction, and the expected impact. You should receive an acknowledgement
within seven days.

## Trust boundaries

TactiCommand runs locally with the permissions granted by the signed-in macOS
user. User-configured shell commands and AppleScript therefore run with that
user's rights. Review every script before assigning it to a physical key.

The local automation API uses a Unix-domain socket in a mode-`0700` directory,
sets the socket to mode `0600`, validates peer UID, limits frames to 16 KiB, and
rejects shell and AppleScript bindings over RPC.

## Supported versions

Security fixes target the latest source revision. There is no notarized public
binary release yet.
