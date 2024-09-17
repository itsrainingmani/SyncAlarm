//
//  AlarmManager.swift
//  SyncAlarm
//
//  Created by Manikandan Sundararajan on 9/15/24.
//

import Foundation

class AlarmManager {
    static let shared = AlarmManager()
    private let userDefaults = UserDefaults.standard
    private let alarmsKey = "savedAlarms"
    
    private init() {}
    
    func saveAlarms(_ alarms: [Alarm]) {
        let encodedData = try? JSONEncoder().encode(alarms)
        userDefaults.set(encodedData, forKey: alarmsKey)
    }
    
    func loadAlarms() -> [Alarm] {
        guard let encodedData = userDefaults.data(forKey: alarmsKey),
              let alarms = try? JSONDecoder().decode([Alarm].self, from: encodedData) else {
            return []
        }
        return alarms
    }
    
    func addAlarm(_ alarm: Alarm) {
        var alarms = loadAlarms()
        alarms.append(alarm)
        alarms = alarms.sorted { $0.time < $1.time }
        saveAlarms(alarms)
        
        if alarm.isEnabled {
            #if os(iOS)
            if alarm.deviceTypes.contains(.iPhone) {
                NotificationManager.shared.scheduleNotification(for: alarm)
            }
            #elseif os(watchOS)
            if alarm.deviceTypes.contains(.Watch) {
                NotificationManager.shared.scheduleNotification(for: alarm)
            }
            #endif
        }
    }
    
    func updateAlarm(_ alarm: Alarm) {
        var alarms = loadAlarms()
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            let prevAlarmEnabled = alarms[index].isEnabled
            alarms[index] = alarm
            saveAlarms(alarms)
            
            if prevAlarmEnabled && !alarm.isEnabled {
                NotificationManager.shared.cancelNotification(for: alarm)
            }
            if alarm.isEnabled {
                #if os(iOS)
                if alarm.deviceTypes.contains(.iPhone) {
                    NotificationManager.shared.scheduleNotification(for: alarm)
                }
                #elseif os(watchOS)
                if alarm.deviceTypes.contains(.Watch) {
                    NotificationManager.shared.scheduleNotification(for: alarm)
                }
                #endif
            }
        }
    }
    
    func deleteAlarm(_ alarm: Alarm) {
        var alarms = loadAlarms()
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms(alarms)
        NotificationManager.shared.cancelNotification(for: alarm)
    }
}
