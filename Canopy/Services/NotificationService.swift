import Foundation
@preconcurrency import UserNotifications
import AppKit

extension Notification.Name {
    static let canopySelectSession = Notification.Name("canopySelectSession")
}

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func postSessionFinished(title: String, subtitle: String, sessionId: UUID) {
        let content = Self.makeContent(title: title, subtitle: subtitle, sessionId: sessionId)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
    }

    func postUpdateAvailable(version: String) {
        let content = UNMutableNotificationContent()
        content.title = "Canopy update available"
        content.body = "Version \(version) is now available."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "canopy.update.\(version)",
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
    }

    nonisolated static func makeContent(title: String, subtitle: String, sessionId: UUID) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = "Session finished"
        content.sound = .default
        content.threadIdentifier = sessionId.uuidString
        content.userInfo = ["sessionId": sessionId.uuidString]
        return content
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Self.routeResponseUserInfo(response.notification.request.content.userInfo)
        completionHandler()
    }

    /// Parses a notification's userInfo and, if it carries a valid sessionId,
    /// posts a `.canopySelectSession` NotificationCenter event on the main queue.
    /// Extracted so the routing logic is testable without constructing a real UNNotification.
    nonisolated static func routeResponseUserInfo(_ userInfo: [AnyHashable: Any]) {
        guard
            let idString = userInfo["sessionId"] as? String,
            let id = UUID(uuidString: idString)
        else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .canopySelectSession,
                object: nil,
                userInfo: ["sessionId": id]
            )
        }
    }
}
