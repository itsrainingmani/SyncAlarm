//
//  AddAlarmView.swift
//  SyncAlarm
//
//  Created by Manikandan Sundararajan on 9/16/24.
//

import SwiftUI

struct AddAlarmView: View {
    @State private var isShared = true
    @State private var title = ""
    @State private var time = Date()
    @State private var selectedDevices: Set<Alarm.DeviceType> = [.iPhone]
    @Environment(\.presentationMode) var presentationMode
    
    let onSave: (Alarm) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute).datePickerStyle(WheelDatePickerStyle()).frame(maxHeight: 400)
                TextField("Title", text: $title)
                Section {
                    Toggle("Sync with Apple Watch", isOn: $isShared)
                    Text(isShared ? "Saved on both devices once acknowledged. Choose where it alerts below." : "Stays on this iPhone and is never sent to your watch.").font(.caption)
                }
                Section(header: Text("Alert on")) {
                    ForEach(isShared ? Alarm.DeviceType.allCases : [.iPhone], id: \.self) { deviceType in
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
            .navigationTitle("Add Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }.tint(.orange),
                trailing: Button("Save") {
                    let newAlarm = Alarm(id: UUID(), title: title, time: time, isEnabled: true, deviceTypes: isShared ? selectedDevices : [.iPhone], isShared: isShared)
                    onSave(newAlarm)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(isShared && selectedDevices.isEmpty)
            )
        }
    }
}
