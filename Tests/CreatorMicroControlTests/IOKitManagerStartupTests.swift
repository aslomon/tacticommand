import IOKit.hid
import XCTest

@testable import CreatorMicroControl

final class IOKitManagerStartupTests: XCTestCase {
    func testDeniedOpenNeverConfiguresDispatchState() {
        var events: [StartupEvent] = []
        var startup = IOKitManagerStartup()

        let result = startup.run(
            open: {
                events.append(.open)
                return kIOReturnNotPermitted
            },
            configureDispatch: { events.append(.configureDispatch) },
            activate: { events.append(.activate) }
        )

        XCTAssertEqual(result, kIOReturnNotPermitted)
        XCTAssertEqual(events, [.open])
        XCTAssertEqual(startup.state, .created)
    }

    func testSuccessfulOpenSchedulesBeforeActivation() {
        var events: [StartupEvent] = []
        var startup = IOKitManagerStartup()

        let result = startup.run(
            open: {
                events.append(.open)
                return kIOReturnSuccess
            },
            configureDispatch: { events.append(.configureDispatch) },
            activate: { events.append(.activate) }
        )

        XCTAssertEqual(result, kIOReturnSuccess)
        XCTAssertEqual(events, [.open, .configureDispatch, .activate])
        XCTAssertEqual(startup.state, .active)
    }
}

private enum StartupEvent: Equatable {
    case open
    case configureDispatch
    case activate
}
