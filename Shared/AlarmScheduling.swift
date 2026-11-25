import Foundation

enum AlarmSchedulingState: Equatable {
    case scheduled, off, otherDevice, blocked, failed(String)
}

/// A pure plan separates desired alarms from OS scheduling side effects.
struct AlarmSchedulePlan {
    static let prefix = "syncalarm."
    let desired: [Alarm]
    let cancelIDs: [String]

    static func regularID(_ id: UUID) -> String { "\(prefix)alarm.\(id.uuidString)" }
    static func snoozeID(_ id: UUID) -> String { "\(prefix)snooze.\(id.uuidString)" }
    static func alarmID(from identifier: String) -> UUID? {
        if identifier.hasPrefix(prefix + "alarm.") || identifier.hasPrefix(prefix + "snooze.") {
            return UUID(uuidString: String(identifier.split(separator: ".").last ?? ""))
        }
        return UUID(uuidString: identifier) // legacy request identifier
    }

    /// managedPendingIDs must contain only this app's alarm-category requests.
    init(alarms: [Alarm], device: Alarm.DeviceType, managedPendingIDs: [String], invalidatedSnoozes: Set<UUID> = []) {
        desired = alarms.filter { $0.isEnabled && $0.deviceTypes.contains(device) }
        let eligible = Set(desired.map(\.id))
        cancelIDs = managedPendingIDs.filter { identifier in
            guard let id = Self.alarmID(from: identifier) else { return identifier.hasPrefix(Self.prefix) }
            if !eligible.contains(id) { return true }
            if identifier == id.uuidString { return true } // migrate to namespaced requests
            return identifier == Self.snoozeID(id) && invalidatedSnoozes.contains(id)
        }
    }
}
