import SwiftUI

@main
struct SyncAlarmApp: App {
    init() {
        if !NotificationManager.shared.usesSystemAlarms {
            NotificationManager.shared.requestAuthorization { _ in }
        }
        ConnectivityManager.shared.activateSession()
        AlarmManager.shared.reconcile()
    }
    var body: some Scene {
        WindowGroup { AlarmListView() }
    }
}
