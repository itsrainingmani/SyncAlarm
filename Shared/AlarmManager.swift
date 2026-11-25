import Foundation
import Combine

/// All UI mutations and connectivity callbacks enter on the main queue.
final class AlarmManager: ObservableObject {
    static let shared = AlarmManager()
    @Published private(set) var errorMessage: String?
    private(set) var repository: AlarmRepository?

    private init() {
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            repository = try AlarmRepository(url: directory.appendingPathComponent("SyncAlarm/alarms-v1.json"), legacyData: UserDefaults.standard.data(forKey: "savedAlarms"))
        } catch {
            errorMessage = "Alarms could not be loaded. Your stored data has been preserved. \(error.localizedDescription)"
        }
    }

    func loadAlarms() -> [Alarm] { repository?.alarms ?? [] }
    func saveAlarms(_ alarms: [Alarm]) {
        perform {
            guard let repository else { return }
            for alarm in alarms { try repository.upsert(alarm) }
            for alarm in repository.alarms where !alarms.contains(where: { $0.id == alarm.id }) {
                try repository.upsert(alarm, deleted: true)
            }
        }
    }
    func addAlarm(_ alarm: Alarm) { mutate(alarm) }
    func updateAlarm(_ alarm: Alarm) { mutate(alarm) }
    func deleteAlarm(_ alarm: Alarm) { mutate(alarm, deleted: true) }

    private func mutate(_ alarm: Alarm, deleted: Bool = false) {
        perform {
            try repository?.upsert(alarm, deleted: deleted)
            if deleted { NotificationManager.shared.cancelNotification(for: alarm) }
            reconcile()
        }
    }
    func reconcile() {
        #if os(iOS)
        NotificationManager.shared.scheduleNotificationsForDevice(.iPhone)
        #elseif os(watchOS)
        NotificationManager.shared.scheduleNotificationsForDevice(.Watch)
        #endif
    }
    func perform(_ operation: () throws -> Void) {
        guard repository != nil else { return }
        do {
            try operation()
            errorMessage = nil
            NotificationCenter.default.post(name: .alarmsUpdated, object: nil)
        } catch {
            errorMessage = "Could not save alarm changes: \(error.localizedDescription)"
        }
    }
}
