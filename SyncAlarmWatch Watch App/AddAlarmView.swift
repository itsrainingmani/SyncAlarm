//
//  AddAlarmView.swift
//  SyncAlarmWatch Watch App
//
//  Created by Manikandan Sundararajan on 9/17/24.
//

import SwiftUI
import WatchDatePicker

struct AddAlarmView: View {
    @State private var time = Date()
    @Environment(\.presentationMode) var presentationMode
    
    let onSave: (Alarm) -> Void
    
    var body: some View {
        VStack {
            TimeInputView(selection: $time)
            Button("Save") {
                let newAlarm = Alarm(title: "", time: time, deviceTypes: [.Watch])
                onSave(newAlarm)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
