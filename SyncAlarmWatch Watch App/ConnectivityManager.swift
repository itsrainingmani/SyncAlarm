//
//  ConnectivityManager.swift
//  SyncAlarmWatch Watch App
//
//  Created by Manikandan Sundararajan on 9/17/24.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func activateSession() {
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func sendAlarmsToCounterpart() {
        let alarms = AlarmManager.shared.loadAlarms()
        let alarmsData = try? JSONEncoder().encode(alarms)
        
        if WCSession.default.activationState == .activated {
            WCSession.default.sendMessage(["alarms": alarmsData as Any], replyHandler: nil) { error in
                print("Error sending alarms: \(error.localizedDescription)")
            }
        } else {
            WCSession.default.activate()
            WCSession.default.sendMessage(["alarms": alarmsData as Any], replyHandler: nil) { error in
                print("Error sending alarms: \(error.localizedDescription)")
            }
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let alarmsData = message["alarms"] as? Data,
           let receivedAlarms = try? JSONDecoder().decode([Alarm].self, from: alarmsData) {
            DispatchQueue.main.async {
                AlarmManager.shared.saveAlarms(receivedAlarms)
                NotificationCenter.default.post(name: .alarmsUpdated, object: nil)
                NotificationManager.shared.scheduleNotificationsForWatch()
            }
        }
    }
}

extension Notification.Name {
    static let alarmsUpdated = Notification.Name("alarmsUpdated")
}
