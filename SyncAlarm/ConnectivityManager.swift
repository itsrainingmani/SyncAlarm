//
//  ConnectivityManager.swift
//  SyncAlarm
//
//  Created by Manikandan Sundararajan on 9/15/24.
//

import Foundation
import WatchConnectivity

class ConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = ConnectivityManager()
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func sendAlarmsToCounterpart() {
        let alarms = AlarmManager.shared.loadAlarms()
        let alarmsData = try? JSONEncoder().encode(alarms)
        
        WCSession.default.sendMessage(["alarms": alarmsData as Any], replyHandler: nil) { error in
            print("Error sending alarms: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession Deactivated")
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
            if let alarmsData = message["alarms"] as? Data,
               let receivedAlarms = try? JSONDecoder().decode([Alarm].self, from: alarmsData) {
                DispatchQueue.main.async {
                    AlarmManager.shared.saveAlarms(receivedAlarms)
                    NotificationCenter.default.post(name: .alarmsUpdated, object: nil)
                    
                    #if os(iOS)
                    NotificationManager.shared.scheduleNotificationsForDevice(.iPhone)
                    #elseif os(watchOS)
                    NotificationManager.shared.scheduleNotificationsForWatch()
                    #endif
                }
            }
        }
}

extension Notification.Name {
    static let alarmsUpdated = Notification.Name("alarmsUpdated")
}
