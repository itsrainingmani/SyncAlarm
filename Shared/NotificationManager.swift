import Foundation
import Combine
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    @Published private(set) var statuses: [UUID: AlarmSchedulingState] = [:]
    @Published private(set) var lastError: String?
    private let center = UNUserNotificationCenter.current()
    private var pending: ([Alarm], Alarm.DeviceType)?
    private var worker: Task<Void, Never>?
    private var previous: [UUID: Alarm] = [:]
    private var invalidatedSnoozes: Set<UUID> = []

    private override init() {
        super.init()
        center.delegate = self
        let snooze = UNNotificationAction(identifier: "SNOOZE_ACTION", title: "Snooze 9 minutes", options: [])
        let stop = UNNotificationAction(identifier: "STOP_ACTION", title: "Stop", options: [.destructive])
        center.setNotificationCategories([UNNotificationCategory(identifier: "ALARM_RINGING", actions: [snooze, stop], intentIdentifiers: [])])
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                completion(granted)
                AlarmManager.shared.reconcile()
            } catch {
                lastError = "Notification authorization failed: \(error.localizedDescription)"
                completion(false)
            }
        }
    }

    func scheduleNotificationsForDevice(_ device: Alarm.DeviceType) {
        let alarms = AlarmManager.shared.loadAlarms()
        let next = Dictionary(uniqueKeysWithValues: alarms.map { ($0.id, $0) })
        for (id, old) in previous where next[id] != old { invalidatedSnoozes.insert(id) }
        previous = next
        pending = (alarms, device)
        // One worker drains the latest snapshots. Older async requests cannot finish last.
        guard worker == nil else { return }
        worker = Task {
            while let (snapshot, target) = pending {
                pending = nil
                await reconcile(snapshot, device: target)
            }
            worker = nil
        }
    }

    func waitUntilIdle() async { await worker?.value }

    private func content(for alarm: Alarm) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? "Alarm" : alarm.title
        content.body = "Alarm for \(alarm.time.formatted(date: .omitted, time: .shortened))"
        content.categoryIdentifier = "ALARM_RINGING"
        content.userInfo = ["alarmID": alarm.id.uuidString]
        #if os(iOS)
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
        #else
        content.sound = .default
        #endif
        content.interruptionLevel = .timeSensitive
        return content
    }

    private func reconcile(_ alarms: [Alarm], device: Alarm.DeviceType) async {
        let settings = await center.notificationSettings()
        let requests = await center.pendingNotificationRequests()
        let managed = requests.filter { $0.content.categoryIdentifier == "ALARM_RINGING" }
        let plan = AlarmSchedulePlan(alarms: alarms, device: device, managedPendingIDs: managed.map(\.identifier), invalidatedSnoozes: invalidatedSnoozes)
        invalidatedSnoozes = []
        center.removePendingNotificationRequests(withIdentifiers: plan.cancelIDs)
        center.removeDeliveredNotifications(withIdentifiers: plan.cancelIDs)
        let canAlert = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional) && settings.soundSetting == .enabled
        var next: [UUID: AlarmSchedulingState] = [:]
        lastError = nil
        for alarm in alarms {
            if !alarm.isEnabled { next[alarm.id] = .off }
            else if !alarm.deviceTypes.contains(device) { next[alarm.id] = .otherDevice }
            else if !canAlert { next[alarm.id] = .blocked }
        }
        for alarm in plan.desired where canAlert {
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: alarm.hour, minute: alarm.minute), repeats: true)
            let request = UNNotificationRequest(identifier: AlarmSchedulePlan.regularID(alarm.id), content: content(for: alarm), trigger: trigger)
            do {
                // Adding the same ID updates time, title, sound, and actions without a cancel gap.
                try await center.add(request)
                next[alarm.id] = .scheduled
            } catch {
                next[alarm.id] = .failed(error.localizedDescription)
                lastError = "An alarm could not be scheduled: \(error.localizedDescription)"
            }
        }
        statuses = next
    }

    func cancelNotification(for alarm: Alarm) {
        let ids = [alarm.id.uuidString, AlarmSchedulePlan.regularID(alarm.id), AlarmSchedulePlan.snoozeID(alarm.id)]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            defer { completionHandler() }
            guard response.notification.request.content.categoryIdentifier == "ALARM_RINGING",
                  let id = AlarmSchedulePlan.alarmID(from: response.notification.request.identifier) else { return }
            let deliveredID = response.notification.request.identifier
            center.removeDeliveredNotifications(withIdentifiers: [deliveredID])
            switch response.actionIdentifier {
            case "SNOOZE_ACTION":
                guard let alarm = AlarmManager.shared.loadAlarms().first(where: { $0.id == id }), alarm.isEnabled else { return }
                #if os(iOS)
                guard alarm.deviceTypes.contains(.iPhone) else { return }
                #else
                guard alarm.deviceTypes.contains(.Watch) else { return }
                #endif
                let request = UNNotificationRequest(identifier: AlarmSchedulePlan.snoozeID(id), content: self.content(for: alarm), trigger: UNTimeIntervalNotificationTrigger(timeInterval: 9 * 60, repeats: false))
                do { try await center.add(request) }
                catch { self.lastError = "Snooze failed: \(error.localizedDescription)" }
            case "STOP_ACTION":
                // Dismiss this occurrence, leaving the daily recurrence enabled.
                center.removePendingNotificationRequests(withIdentifiers: [AlarmSchedulePlan.snoozeID(id)])
            default: break
            }
        }
    }
}
