import CoreGraphics
import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class MacShortcutEventPlannerTests: XCTestCase {
    func testChordPressesInOrderAndReleasesInReverseOrder() {
        let shortcut = KeyShortcut(
            mainKeys: [
                KeyShortcutKey(key: "j", virtualKeyCode: 38),
                KeyShortcutKey(key: "k", virtualKeyCode: 40),
            ],
            modifiers: [.command]
        )
        let planner = MacShortcutEventPlanner()

        XCTAssertEqual(
            keyCodes(in: planner.tapEvents(for: shortcut)),
            [55, 38, 40, 40, 38, 55]
        )

        XCTAssertEqual(
            planner.events(for: shortcut, phase: .pressed),
            [
                MacShortcutEventDescriptor(
                    key: .modifier(.command),
                    phase: .pressed,
                    activeModifiers: [.command]
                ),
                MacShortcutEventDescriptor(
                    key: .main(shortcut.mainKeys[0]),
                    phase: .pressed,
                    activeModifiers: [.command]
                ),
                MacShortcutEventDescriptor(
                    key: .main(shortcut.mainKeys[1]),
                    phase: .pressed,
                    activeModifiers: [.command]
                ),
            ]
        )
        XCTAssertEqual(
            planner.events(for: shortcut, phase: .released),
            [
                MacShortcutEventDescriptor(
                    key: .main(shortcut.mainKeys[1]),
                    phase: .released,
                    activeModifiers: [.command]
                ),
                MacShortcutEventDescriptor(
                    key: .main(shortcut.mainKeys[0]),
                    phase: .released,
                    activeModifiers: [.command]
                ),
                MacShortcutEventDescriptor(
                    key: .modifier(.command),
                    phase: .released,
                    activeModifiers: []
                ),
            ]
        )
    }

    func testFunctionShiftChordBalancesEveryModifierFlag() {
        let shortcut = KeyShortcut(
            key: "fn",
            modifiers: [.shift],
            virtualKeyCode: 63
        )
        let events = MacShortcutEventPlanner().tapEvents(for: shortcut)

        XCTAssertEqual(
            events,
            [
                MacShortcutEventDescriptor(
                    key: .modifier(.shift),
                    phase: .pressed,
                    activeModifiers: [.shift]
                ),
                MacShortcutEventDescriptor(
                    key: .main(shortcut.mainKeys[0]),
                    phase: .pressed,
                    activeModifiers: [.function, .shift]
                ),
                MacShortcutEventDescriptor(
                    key: .main(shortcut.mainKeys[0]),
                    phase: .released,
                    activeModifiers: [.shift]
                ),
                MacShortcutEventDescriptor(
                    key: .modifier(.shift),
                    phase: .released,
                    activeModifiers: []
                ),
            ]
        )
        XCTAssertEqual(keyCodes(in: events), [56, 63, 63, 56])
    }

    func testModifierOnlyChordBalancesFlagsInReverseReleaseOrder() {
        let shortcut = KeyShortcut(
            mainKeys: [],
            modifiers: [.control, .shift]
        )
        let events = MacShortcutEventPlanner().tapEvents(for: shortcut)

        XCTAssertEqual(
            events,
            [
                MacShortcutEventDescriptor(
                    key: .modifier(.control),
                    phase: .pressed,
                    activeModifiers: [.control]
                ),
                MacShortcutEventDescriptor(
                    key: .modifier(.shift),
                    phase: .pressed,
                    activeModifiers: [.control, .shift]
                ),
                MacShortcutEventDescriptor(
                    key: .modifier(.shift),
                    phase: .released,
                    activeModifiers: [.control]
                ),
                MacShortcutEventDescriptor(
                    key: .modifier(.control),
                    phase: .released,
                    activeModifiers: []
                ),
            ]
        )
        XCTAssertEqual(keyCodes(in: events), [59, 56, 56, 59])
    }

    func testLegacyModifierStoredAsMainKeyCarriesItsActiveFlag() {
        let shortcut = KeyShortcut(
            key: "shift",
            modifiers: [.shift],
            virtualKeyCode: 56
        )

        XCTAssertEqual(
            MacShortcutEventPlanner().tapEvents(for: shortcut),
            [
                MacShortcutEventDescriptor(
                    key: .main(shortcut.mainKeys[0]),
                    phase: .pressed,
                    activeModifiers: [.shift]
                ),
                MacShortcutEventDescriptor(
                    key: .main(shortcut.mainKeys[0]),
                    phase: .released,
                    activeModifiers: []
                ),
            ]
        )
    }

    private func keyCodes(
        in events: [MacShortcutEventDescriptor]
    ) -> [CGKeyCode] {
        events.compactMap { event in
            switch event.key {
            case .modifier(let modifier): MacVirtualKeyMap.keyCode(for: modifier)
            case .main(let key): MacVirtualKeyMap.keyCode(for: key)
            }
        }
    }
}
