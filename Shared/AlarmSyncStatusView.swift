import SwiftUI

struct AlarmSyncStatusView: View {
    let alarm: Alarm
    @ObservedObject private var store = AlarmManager.shared
    private var state: AlarmSyncState { store.repository?.syncState(for: alarm) ?? .unavailable }
    private var label: String {
        switch state {
        case .localOnly: return "Settings only on this device"
        case .pending: return "Waiting to sync"
        case .synced: return "Synced with companion"
        case .unavailable: return "Sync status unavailable"
        }
    }
    private var symbol: String {
        switch state {
        case .localOnly: return "internaldrive"
        case .pending: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud"
        case .unavailable: return "exclamationmark.triangle"
        }
    }
    var body: some View {
        Label(label, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(state == .synced ? Color.green : state == .pending ? Color.orange : Color.secondary)
            .accessibilityLabel(label)
    }
}

struct AlarmHealthView: View {
    @ObservedObject private var store = AlarmManager.shared
    @ObservedObject private var notifications = NotificationManager.shared
    @ObservedObject private var connection = ConnectivityManager.shared
    var body: some View {
        if let error = store.errorMessage ?? connection.lastError ?? notifications.lastError {
            Text(error).font(.caption).foregroundStyle(.red)
        }
        if notifications.statuses.values.contains(.blocked) {
            Button(notifications.usesSystemAlarms ? "Enable system alarms" : "Enable notifications") {
                notifications.requestAuthorization { _ in }
            }
            #if os(iOS)
            Button("Open alert settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            #endif
        }
    }
}

struct AlarmDeliveryStatusView: View {
    let alarm: Alarm
    @ObservedObject private var notifications = NotificationManager.shared
    private var label: String {
        switch notifications.statuses[alarm.id] {
        case .scheduled: return notifications.usesSystemAlarms ? "System alarm scheduled" : "Notification scheduled here"
        case .off: return "Alarm off"
        case .otherDevice:
            #if os(watchOS)
            return "Targets iPhone; its scheduling status is unverified here"
            #else
            return "Independent watch notification"
            #endif
        case .blocked: return "Alert permission required: check settings"
        case .failed: return "Alert scheduling failed"
        case nil: return "Checking local alert…"
        }
    }
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption2)
            if case .failed(let message) = notifications.statuses[alarm.id] {
                Text(message).font(.caption2).foregroundStyle(.red)
            }
        }.foregroundStyle(.secondary)
    }
}
