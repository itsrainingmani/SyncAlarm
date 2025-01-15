//
//  AlarmListView.swift
//  SyncAlarmWatch Watch App
//
//  Created by Manikandan Sundararajan on 9/17/24.
//

import SwiftUI

struct AlarmListView: View {
    @State private var alarms: [Alarm] = []
    @State private var showingAddAlarm = false
    
    var filteredAlarms: [Alarm] {
        return alarms.filter { $0.deviceTypes.contains(.Watch) }
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(filteredAlarms) { alarm in
                    AlarmRow(alarm: alarm, toggleAlarm: toggleAlarm)
                }
                .onDelete(perform: deleteAlarms)
                Button(action: { showingAddAlarm = true }) {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.darkGray)) // You can change the color to whatever you prefer
                            .frame(width: 50, height: 50) // Adjust the size of the circle
                        Image(systemName: "plus")
                            .foregroundColor(.white) // Change the color of the plus icon
                            .font(.system(size: 22)) // Adjust the size of the plus icon
                    }
                    .frame(maxWidth: .infinity) // Center the button in the row
                }
                .listRowInsets(EdgeInsets()) // Remove default padding to center the button
                .listRowBackground(Color.clear) // Make the row background transparent
            }
        }
        .navigationTitle("Sync Alarms")
        .onAppear {
            loadAlarms()
        }
        .sheet(isPresented: $showingAddAlarm) {
            AddAlarmView(onSave: addAlarm)
        }
        .onReceive(NotificationCenter.default.publisher(for: .alarmsUpdated)) { _ in
            loadAlarms()
        }
    }
    
    private func loadAlarms() {
        alarms = AlarmManager.shared.loadAlarms()
    }
    
    private func addAlarm(_ alarm: Alarm) {
        AlarmManager.shared.addAlarm(alarm)
        loadAlarms()
        ConnectivityManager.shared.sendAlarmsToCounterpart()
    }
    
    private func toggleAlarm(_ alarm: Alarm) {
        var updatedAlarm = alarm
        updatedAlarm.isEnabled.toggle()
        AlarmManager.shared.updateAlarm(updatedAlarm)
        loadAlarms()
        ConnectivityManager.shared.sendAlarmsToCounterpart()
    }
    
    private func deleteAlarms(at offsets: IndexSet) {
        offsets.forEach { index in
            AlarmManager.shared.deleteAlarm(filteredAlarms[index])
        }
        loadAlarms()
        ConnectivityManager.shared.sendAlarmsToCounterpart()
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    let toggleAlarm: (Alarm) -> Void
    
    var body: some View {
        HStack {
            Text(alarm.time, style: .time).fontDesign(.monospaced)
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in toggleAlarm(alarm) }
            ))
        }
    }
}


#Preview {
    AlarmListView()
}
