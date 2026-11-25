import SwiftUI

@main
struct SyncAlarmApp: App {
    init() {
        NotificationManager.shared.requestAuthorization { _ in }
        ConnectivityManager.shared.activateSession()
        AlarmManager.shared.reconcile()
    }
    var body: some Scene {
        WindowGroup { AlarmListView() }
    }
}
