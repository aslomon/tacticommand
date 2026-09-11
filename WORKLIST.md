# TactiCommand Worklist

This is the ordered implementation record for the current improvement pass.

## Active delivery

1. [x] Replace raw Swift/JSON decoder details with a plain-language transient
   device diagnostic that clears after valid input.
2. [x] Explain Next, Previous, and Select Layer and show a non-activating
   system-wide layer HUD with the active and next layer.
3. [x] Add first-class Copy, Paste, and configurable Slash Command actions.
4. [x] Replace the narrow menu-bar window with a wider native anchored popover
   that has a visible arrow to the status item.
5. [x] Show live mute and other useful action state inside the on-screen key;
   mirror semantic state to individually addressable physical Agent keys where
   the hardware supports it.
6. [x] Make joystick configuration collapsed by default and improve its mode
   choice, labels, hierarchy, and help.
7. [x] Add an honest device section that distinguishes connected, available,
   and previously known Creator Micro devices. Offer Connect only where the
   macOS device API provides a real connection operation; otherwise link to the
   correct Bluetooth system surface and explain the boundary.

## Additional actions

1. [x] Custom Keyboard Shortcut using the existing safe shortcut recorder.
2. [x] Paste as Plain Text without reading clipboard contents.
3. [x] Safe Action Sequence composed only of existing non-script actions.
4. [x] Focus Next Agent Needing Attention, prioritizing waiting then error states.

## Completion contract

- Preserve existing user configuration and signing identity.
- Update `SPEC.md`, `DESIGN.md`, `README.md`, and `VALIDATION.md` with shipped
  behavior and observed evidence.
- Run strict formatting, build, all tests, bundle/signature validation, and
  visual/runtime checks against the installed app.
- Publish the verified source as the public MIT-licensed `aslomon/tacticommand`
  repository, with binary downloads withheld until Developer ID notarization.
