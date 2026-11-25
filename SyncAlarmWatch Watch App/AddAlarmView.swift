//
//  AddAlarmView.swift
//  SyncAlarmWatch Watch App
//
//  Created by Manikandan Sundararajan on 9/17/24.
//

import SwiftUI

struct AddAlarmView: View {
    @State private var time = Date()
    @State private var isShared = true
    @State private var alertOnPhone = false
    @State private var alertOnWatch = true
    @Environment(\.dismiss) private var dismiss
    let onSave: (Alarm) -> Void

    var body: some View {
        Form {
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
            Toggle("Sync with iPhone", isOn: $isShared)
            if isShared {
                Toggle("Alert on iPhone", isOn: $alertOnPhone)
                Toggle("Alert on Watch", isOn: $alertOnWatch)
                Text("Settings sync when connected. Phone alerts require delivery and permission on iPhone. iPhone system alarms may also appear on this watch.").font(.caption)
            } else {
                Text("Only on this watch.").font(.caption)
            }
            Button("Save") {
                var devices: Set<Alarm.DeviceType> = []
                if isShared && alertOnPhone { devices.insert(.iPhone) }
                if !isShared || alertOnWatch { devices.insert(.Watch) }
                onSave(Alarm(title: "", time: time, deviceTypes: devices, isShared: isShared))
                dismiss()
            }
            .disabled(isShared && !alertOnPhone && !alertOnWatch)
            .tint(.orange)
        }
    }
}
