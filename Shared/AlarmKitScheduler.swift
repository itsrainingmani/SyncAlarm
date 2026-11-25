#if os(iOS)
import AlarmKit
import SwiftUI

@available(iOS 26.0, *)
@MainActor
final class AlarmKitScheduler: SystemAlarmClient {
    static let shared = AlarmKitScheduler()
    private let manager = AlarmKit.AlarmManager.shared
    private let defaults = UserDefaults.standard
    private let cacheKey = "alarmKitConfigurations.v1"
    private var configurations: [UUID: SystemAlarmDefinition]
    private init() {
        configurations = defaults.data(forKey: cacheKey).flatMap { try? JSONDecoder().decode([UUID: SystemAlarmDefinition].self, from: $0) } ?? [:]
    }
    var isAuthorized: Bool { manager.authorizationState == .authorized }
    func requestAuthorization() async throws -> Bool {
        try await manager.requestAuthorization() == .authorized
    }
    func scheduledIDs() throws -> Set<UUID> { Set(try manager.alarms.map(\.id)) }
    func configuration(for id: UUID) -> SystemAlarmDefinition? { configurations[id] }

    func schedule(_ definition: SystemAlarmDefinition) async throws {
        let title = definition.title.isEmpty ? "Alarm" : definition.title
        let snooze = AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz")
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = .init(title: LocalizedStringResource(stringLiteral: title), secondaryButton: snooze, secondaryButtonBehavior: .countdown)
        } else {
            alert = .init(title: LocalizedStringResource(stringLiteral: title), stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill"), secondaryButton: snooze, secondaryButtonBehavior: .countdown)
        }
        let presentation = AlarmPresentation(alert: alert, countdown: .init(title: "Snoozed"))
        let attributes = AlarmAttributes(presentation: presentation, metadata: SyncAlarmMetadata(title: title), tintColor: .orange)
        let schedule = AlarmKit.Alarm.Schedule.relative(.init(time: .init(hour: definition.hour, minute: definition.minute), repeats: .weekly([.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])))
        let configuration = AlarmKit.AlarmManager.AlarmConfiguration(countdownDuration: .init(preAlert: nil, postAlert: 9 * 60), schedule: schedule, attributes: attributes, stopIntent: StopSystemAlarmIntent(id: definition.id))
        _ = try await manager.schedule(id: definition.id, configuration: configuration)
        configurations[definition.id] = definition
        persistCache()
    }
    func cancel(_ id: UUID) throws {
        try manager.cancel(id: id)
        configurations.removeValue(forKey: id)
        persistCache()
    }
    private func persistCache() {
        // This cache is an optimization. Missing/invalid data causes safe rescheduling.
        if let data = try? JSONEncoder().encode(configurations) { defaults.set(data, forKey: cacheKey) }
    }
    func observeAlarms(_ action: @escaping @MainActor () -> Void) async {
        for await _ in manager.alarmUpdates { action() }
    }
    func observeAuthorization(_ action: @escaping @MainActor () -> Void) async {
        for await _ in manager.authorizationUpdates { action() }
    }
}
#endif
