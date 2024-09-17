//
//  NotificationManager.swift
//  SyncAlarm
//
//  Created by Manikandan Sundararajan on 9/15/24.
//

import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        setupNotificationCategories()
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func setupNotificationCategories() {
        let category = UNNotificationCategory(identifier: "ALARM_CATEGORY",
                                              actions: [],
                                              intentIdentifiers: [],
                                              options: .customDismissAction)
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error requesting notification permission: \(error.localizedDescription)")
                }
                completion(granted)
            }
        }
    }
    
    func scheduleNotification(for alarm: Alarm) {
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = alarm.title
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.interruptionLevel = UNNotificationInterruptionLevel.timeSensitive
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled successfully for alarm: \(alarm.id.uuidString)")
            }
        }
    }
    
    func cancelNotification(for alarm: Alarm) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])
        print("Canceled Notification: \(alarm.id.uuidString)")
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings:")
            print("Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("Alert Setting: \(settings.alertSetting.rawValue)")
            print("Badge Setting: \(settings.badgeSetting.rawValue)")
            print("Sound Setting: \(settings.soundSetting.rawValue)")
            print("Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
            print("Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
            print("Critical Alert Setting: \(settings.criticalAlertSetting.rawValue)")
            print("Alert Style: \(settings.alertStyle.rawValue)")
        }
    }
    
    #if os(iOS)
    func scheduleNotificationsForDevice(_ deviceType: Alarm.DeviceType) {
        let alarms = AlarmManager.shared.loadAlarms()
        for alarm in alarms where alarm.isEnabled && alarm.deviceTypes.contains(deviceType) {
            scheduleNotification(for: alarm)
        }
    }
    #endif
    
    #if os(watchOS)
    func scheduleNotificationsForWatch() {
        let alarms = AlarmManager.shared.loadAlarms()
        for alarm in alarms where alarm.isEnabled && alarm.deviceTypes.contains(.Watch) {
            scheduleNotification(for: alarm)
        }
    }
    #endif
}
