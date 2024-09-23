//
//  SyncAlarmApp.swift
//  SyncAlarm
//
//  Created by Manikandan Sundararajan on 9/14/24.
//

import SwiftUI
import SwiftData
import AVFoundation

@main
struct SyncAlarmApp: App {
    let center = UNUserNotificationCenter.current()
    
    init() {
        let center : UNUserNotificationCenter = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.sound, .alert, .badge], completionHandler: { (granted, error) in
            if let error = error {
                print("Error: \(error)")
            }
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        })
        
        ConnectivityManager.shared.activateSession()
                
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AlarmListView()
        }
    }
}
