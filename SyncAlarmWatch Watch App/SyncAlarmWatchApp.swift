//
//  SyncAlarmWatchApp.swift
//  SyncAlarmWatch Watch App
//
//  Created by Manikandan Sundararajan on 9/17/24.
//

import SwiftUI

@main
struct SyncAlarmWatch_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            NavigationView {
                AlarmListView()
            }
        }
    }
}

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        NotificationManager.shared.requestAuthorization { granted in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
        
        ConnectivityManager.shared.activateSession()
    }
}
