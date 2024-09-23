//
//  SyncAlarmWatchApp.swift
//  SyncAlarmWatch Watch App
//
//  Created by Manikandan Sundararajan on 9/17/24.
//

import SwiftUI

@main
struct SyncAlarmWatch_Watch_AppApp: App {
    
    init() {
        NotificationManager.shared.requestAuthorization(completion: { granted in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        })
        
        ConnectivityManager.shared.activateSession()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                AlarmListView()
            }
        }
    }
}
