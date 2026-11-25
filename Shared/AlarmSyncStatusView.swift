import SwiftUI

struct AlarmSyncStatusView: View {
    let alarm: Alarm
    @ObservedObject private var store = AlarmManager.shared
    private var state: AlarmSyncState { store.repository?.syncState(for: alarm) ?? .unavailable }
    private var label: String {
        switch state {
        case .localOnly: return "Only on this device"
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
    @ObservedObject private var connection = ConnectivityManager.shared
    var body: some View {
        if let error = store.errorMessage ?? connection.lastError {
            Text(error).font(.caption).foregroundStyle(.red)
        }
    }
}
