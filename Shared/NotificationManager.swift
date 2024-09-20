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
        let snoozeAction = UNNotificationAction(identifier: "SNOOZE_ACTION", title: "Snooze", options: [])
        let stopAction = UNNotificationAction(identifier: "STOP_ACTION", title: "Stop", options: [.destructive])
        let category = UNNotificationCategory(identifier: "ALARM_RINGING",
                                              actions: [snoozeAction, stopAction],
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
        let (timeStr, periodStr) = alarm.time.extractTimeComponents()
        let content = UNMutableNotificationContent()
        content.title = "Alarm for \(timeStr) \(periodStr)"
        content.body = alarm.title
        #if os(iOS)
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.wav"))
        #endif
        
        #if os(watchOS)
        content.sound = UNNotificationSound.defaultCritical
        #endif
        
        content.categoryIdentifier = "ALARM_RINGING"
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
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.categoryIdentifier == "ALARM_RINGING" {
            switch response.actionIdentifier {
            case "SNOOZE_ACTION":
                print("Snoozing alarm \(response.notification.request.identifier)")
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
                // We also need to set a new notification with a time set in the future for the same alarm
            case "STOP_ACTION":
                print("Stopping alarm \(response.notification.request.identifier)")
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
            default:
                break
            }
        }
        
        // Always call the completion handler when done
        completionHandler()
    }
    
    func cancelNotification(for alarm: Alarm) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])
        print("Canceled Notification: \(alarm.id.uuidString)")
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound])
    }
    
    func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings: \(settings)")
        }
    }
    
    func scheduleNotificationsForDevice(_ deviceType: Alarm.DeviceType) {
        // This is a hack. We shouldn't have to remove all pending notifications.
        // Instead, can we simply check all our existing notifications and match them against the
        // alarms that we have?
        // UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let alarms = AlarmManager.shared.loadAlarms()
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let pendingAlarmIds = Set(requests.map { $0.identifier })
            
            for alarm in alarms {
                if alarm.deviceTypes.contains(deviceType) && alarm.isEnabled {
                    let alarmId = alarm.id.uuidString
                    
                    if !pendingAlarmIds.contains(alarmId) {
                        // New alarm or updated time, schedule it
                        self.scheduleNotification(for: alarm)
                    } else {
                        // Existing alarm, check if time has changed
                        if let existingRequest = requests.first(where: { $0.identifier == alarmId }),
                           let trigger = existingRequest.trigger as? UNCalendarNotificationTrigger,
                           let triggerDate = trigger.nextTriggerDate() {
                            let alarmComponents = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
                            let triggerComponents = Calendar.current.dateComponents([.hour, .minute], from: triggerDate)
                            
                            if alarmComponents != triggerComponents {
                                // Time has changed, reschedule
                                self.cancelNotification(for: alarm)
                                self.scheduleNotification(for: alarm)
                            }
                        }
                    }
                } else {
                    // Alarm is disabled or not for this device, cancel if exists
                    self.cancelNotification(for: alarm)
                }
            }
            
            // Cancel notifications for deleted alarms
            let currentAlarmIds = Set(alarms.map { $0.id.uuidString })
            let deletedAlarmIds = pendingAlarmIds.subtracting(currentAlarmIds)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(deletedAlarmIds))
        }
    }
}
