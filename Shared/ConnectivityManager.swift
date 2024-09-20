//
//  ConnectivityManager.swift
//  SyncAlarm
//
//  Created by Manikandan Sundararajan on 9/20/24.
//


//
//  ConnectivityManager.swift
//  SyncAlarm
//
//  Created by Manikandan Sundararajan on 9/15/24.
//

import SwiftUI
import Foundation
import WatchConnectivity

class ConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = ConnectivityManager()
    @State static var companionState = false

    private override init() {
        super.init()
    }
    
    func activateSession() {
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession Deactivated")
        WCSession.default.activate()
    }
    #endif

    func sendAlarmsToCounterpart() {
        let alarms = AlarmManager.shared.loadAlarms()
        let alarmsData = try? JSONEncoder().encode(alarms)
        
        if WCSession.default.activationState == .activated && WCSession.default.isReachable {
            WCSession.default.sendMessage(["alarms": alarmsData as Any], replyHandler: nil) { error in
                print("Error sending alarms: \(error.localizedDescription)")
            }
        } else if WCSession.default.activationState == .activated && !WCSession.default.isReachable {
            // Send the user info dictionary in the background instead
            WCSession.default.transferUserInfo(["alarms": alarmsData as Any])
        } else {
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let alarmsData = message["alarms"] as? Data,
           let receivedAlarms = try? JSONDecoder().decode([Alarm].self, from: alarmsData) {
            DispatchQueue.main.async {
                AlarmManager.shared.saveAlarms(receivedAlarms)
                NotificationCenter.default.post(name: .alarmsUpdated, object: nil)
                #if os(iOS)
                NotificationManager.shared.scheduleNotificationsForDevice(.iPhone)
                #endif
                
                #if os(watchOS)
                NotificationManager.shared.scheduleNotificationsForDevice(.Watch)
                #endif
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let alarmsData = userInfo["alarms"] as? Data,
           let receivedAlarms = try? JSONDecoder().decode([Alarm].self, from: alarmsData) {
            DispatchQueue.main.async {
                AlarmManager.shared.saveAlarms(receivedAlarms)
                NotificationCenter.default.post(name: .alarmsUpdated, object: nil)
                #if os(iOS)
                NotificationManager.shared.scheduleNotificationsForDevice(.iPhone)
                #endif
                
                #if os(watchOS)
                NotificationManager.shared.scheduleNotificationsForDevice(.Watch)
                #endif
            }
        }
    }
}

extension Notification.Name {
    static let alarmsUpdated = Notification.Name("alarmsUpdated")
}
