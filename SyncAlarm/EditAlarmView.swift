//
//  EditAlarmView.swift
//  SyncAlarm
//
//  Created by Manikandan Sundararajan on 9/16/24.
//

import SwiftUI

struct EditAlarmView: View {
    @State private var title: String
    @State private var time: Date
    @State private var selectedDevices: Set<Alarm.DeviceType>
    @Environment(\.presentationMode) var presentationMode
    
    let alarm: Alarm
    let onSave: (Alarm) -> Void
    
    init(alarm: Alarm, onSave: @escaping (Alarm) -> Void) {
        self.alarm = alarm
        self.onSave = onSave
        _title = State(initialValue: alarm.title)
        _time = State(initialValue: alarm.time)
        _selectedDevices = State(initialValue: alarm.deviceTypes)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Label", text: $title)
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                
                Section(header: Text("Devices")) {
                    ForEach(Alarm.DeviceType.allCases, id: \.self) { deviceType in
                        Toggle(deviceType.rawValue, isOn: Binding(
                            get: { selectedDevices.contains(deviceType) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDevices.insert(deviceType)
                                } else {
                                    selectedDevices.remove(deviceType)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Edit Alarm")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }.tint(.orange),
                trailing: Button("Save") {
                    let updatedAlarm = Alarm(id: alarm.id, title: title, time: time, isEnabled: alarm.isEnabled, deviceTypes: selectedDevices)
                    onSave(updatedAlarm)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedDevices.isEmpty)
            )
        }
    }
}
