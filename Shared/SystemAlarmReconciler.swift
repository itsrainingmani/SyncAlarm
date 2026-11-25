import Foundation

/// Only configuration that changes an OS alarm. Sync acknowledgements never affect it.
struct SystemAlarmDefinition: Codable, Equatable {
    var id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var configurationVersion = 1
    init(_ alarm: Alarm) {
        id = alarm.id; title = alarm.title; hour = alarm.hour; minute = alarm.minute
    }
}

@MainActor
protocol SystemAlarmClient: AnyObject {
    var isAuthorized: Bool { get }
    func scheduledIDs() throws -> Set<UUID>
    func configuration(for id: UUID) -> SystemAlarmDefinition?
    func schedule(_ definition: SystemAlarmDefinition) async throws
    func cancel(_ id: UUID) throws
}

struct SystemAlarmResult {
    var statuses: [UUID: AlarmSchedulingState] = [:]
    /// Remove a legacy notification only after its replacement exists.
    var migratedIDs: Set<UUID> = []
    var error: String?
}

@MainActor
struct SystemAlarmReconciler {
    let client: any SystemAlarmClient
    func reconcile(_ alarms: [Alarm]) async -> SystemAlarmResult {
        var result = SystemAlarmResult()
        let desired = alarms.filter { $0.isEnabled && $0.deviceTypes.contains(.iPhone) }
        let desiredIDs = Set(desired.map(\.id))
        for alarm in alarms {
            if !alarm.isEnabled { result.statuses[alarm.id] = .off }
            else if !alarm.deviceTypes.contains(.iPhone) { result.statuses[alarm.id] = .otherDevice }
            else if !client.isAuthorized { result.statuses[alarm.id] = .blocked }
        }
        let existing: Set<UUID>
        do { existing = try client.scheduledIDs() }
        catch {
            result.error = "Could not read system alarms: \(error.localizedDescription)"
            for alarm in desired where client.isAuthorized { result.statuses[alarm.id] = .failed(error.localizedDescription) }
            return result
        }
        for id in existing.subtracting(desiredIDs) {
            do { try client.cancel(id) }
            catch {
                result.statuses[id] = .failed(error.localizedDescription)
                result.error = "Could not cancel a system alarm: \(error.localizedDescription)"
            }
        }
        guard client.isAuthorized else { return result }
        for alarm in desired {
            let definition = SystemAlarmDefinition(alarm)
            do {
                // Do not reset a ringing or snoozed alarm on foreground/repeated sync.
                if !existing.contains(alarm.id) || client.configuration(for: alarm.id) != definition {
                    // AlarmKit exposes creation and cancellation, not an atomic configuration update.
                    // Cancel only real edits; unchanged ringing/snoozed alarms stay untouched.
                    if existing.contains(alarm.id) { try client.cancel(alarm.id) }
                    try await client.schedule(definition)
                }
                result.statuses[alarm.id] = .scheduled
                result.migratedIDs.insert(alarm.id)
            } catch {
                result.statuses[alarm.id] = .failed(error.localizedDescription)
                result.error = "Could not schedule a system alarm: \(error.localizedDescription)"
            }
        }
        return result
    }
}
