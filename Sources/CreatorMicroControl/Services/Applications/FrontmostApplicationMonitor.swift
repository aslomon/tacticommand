import AppKit
import Foundation

@MainActor
protocol FrontmostApplicationMonitoring: AnyObject {
    func bundleIdentifiers() -> AsyncStream<String?>
}

@MainActor
final class FrontmostApplicationMonitor: FrontmostApplicationMonitoring {
    private struct Subscription: @unchecked Sendable {
        let observer: NSObjectProtocol
        let continuation: AsyncStream<String?>.Continuation
    }

    private let notificationCenter: NotificationCenter
    private let notificationName: Notification.Name
    private let currentBundleIdentifier: @MainActor @Sendable () -> String?
    private var subscriptions: [UUID: Subscription] = [:]

    init(
        notificationCenter: NotificationCenter =
            NSWorkspace.shared.notificationCenter,
        notificationName: Notification.Name =
            NSWorkspace.didActivateApplicationNotification,
        currentBundleIdentifier: @escaping @MainActor @Sendable () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }
    ) {
        self.notificationCenter = notificationCenter
        self.notificationName = notificationName
        self.currentBundleIdentifier = currentBundleIdentifier
    }

    var activeSubscriptionCount: Int {
        subscriptions.count
    }

    func bundleIdentifiers() -> AsyncStream<String?> {
        let subscriptionID = UUID()
        let pair = AsyncStream<String?>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        pair.continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.removeSubscription(subscriptionID)
            }
        }
        let observer = notificationCenter.addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.yieldCurrentIdentifier(to: subscriptionID)
            }
        }
        subscriptions[subscriptionID] = Subscription(
            observer: observer,
            continuation: pair.continuation
        )
        pair.continuation.yield(currentBundleIdentifier())
        return pair.stream
    }

    func stop() {
        let activeSubscriptions = subscriptions.values
        subscriptions.removeAll()
        for subscription in activeSubscriptions {
            notificationCenter.removeObserver(subscription.observer)
            subscription.continuation.finish()
        }
    }

    private func yieldCurrentIdentifier(to subscriptionID: UUID) {
        subscriptions[subscriptionID]?.continuation.yield(
            currentBundleIdentifier()
        )
    }

    private func removeSubscription(_ subscriptionID: UUID) {
        guard
            let subscription = subscriptions.removeValue(
                forKey: subscriptionID
            )
        else {
            return
        }
        notificationCenter.removeObserver(subscription.observer)
    }

    deinit {
        for subscription in subscriptions.values {
            notificationCenter.removeObserver(subscription.observer)
            subscription.continuation.finish()
        }
    }
}
