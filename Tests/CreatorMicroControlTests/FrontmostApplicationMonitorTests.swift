import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class FrontmostApplicationMonitorTests: XCTestCase {
    func testMonitorCanDeinitializeWithoutASubscription() {
        weak var monitor: FrontmostApplicationMonitor?
        autoreleasepool {
            let instance = FrontmostApplicationMonitor(
                notificationCenter: NotificationCenter(),
                notificationName: Notification.Name("test.application.activated"),
                currentBundleIdentifier: { nil }
            )
            monitor = instance
        }

        XCTAssertNil(monitor)
    }

    func testStreamEmitsCurrentAndActivatedBundleIdentifiers() async {
        let notificationCenter = NotificationCenter()
        let notificationName = Notification.Name("test.application.activated")
        let state = BundleIdentifierState(value: "com.example.initial")
        let monitor = FrontmostApplicationMonitor(
            notificationCenter: notificationCenter,
            notificationName: notificationName,
            currentBundleIdentifier: { state.value }
        )
        var iterator = monitor.bundleIdentifiers().makeAsyncIterator()

        let initial = await iterator.next()
        state.value = "com.example.next"
        notificationCenter.post(name: notificationName, object: nil)
        let activated = await iterator.next()

        XCTAssertEqual(initial, "com.example.initial")
        XCTAssertEqual(activated, "com.example.next")
    }

    func testCancellingConsumerRemovesObserverSubscription() async {
        let notificationCenter = NotificationCenter()
        let monitor = FrontmostApplicationMonitor(
            notificationCenter: notificationCenter,
            notificationName: Notification.Name("test.application.activated"),
            currentBundleIdentifier: { "com.example.initial" }
        )
        let stream = monitor.bundleIdentifiers()
        let consumer = Task {
            for await _ in stream {}
        }

        await Task.yield()
        XCTAssertEqual(monitor.activeSubscriptionCount, 1)
        consumer.cancel()
        await consumer.value
        await Task.yield()

        XCTAssertEqual(monitor.activeSubscriptionCount, 0)
    }

    func testStopFinishesEveryStreamAndRemovesSubscriptions() async {
        let monitor = FrontmostApplicationMonitor(
            notificationCenter: NotificationCenter(),
            notificationName: Notification.Name("test.application.activated"),
            currentBundleIdentifier: { "com.example.initial" }
        )
        var firstIterator = monitor.bundleIdentifiers().makeAsyncIterator()
        var secondIterator = monitor.bundleIdentifiers().makeAsyncIterator()
        _ = await firstIterator.next()
        _ = await secondIterator.next()

        monitor.stop()

        let firstEnd = await firstIterator.next()
        let secondEnd = await secondIterator.next()
        XCTAssertTrue(firstEnd == nil)
        XCTAssertTrue(secondEnd == nil)
        XCTAssertEqual(monitor.activeSubscriptionCount, 0)
    }
}

@MainActor
private final class BundleIdentifierState {
    var value: String?

    init(value: String?) {
        self.value = value
    }
}
