//
//  AlarmListView.swift
//  SyncAlarmWatch Watch App
//
//  Created by Manikandan Sundararajan on 9/17/24.
//

import SwiftUI

struct AlarmListView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var store = AlarmManager.shared
    @State private var alarms: [Alarm] = []
    @State private var showingAddAlarm = false
    
    var filteredAlarms: [Alarm] {
        return alarms
    }
    
    var body: some View {
        VStack {
            List {
                AlarmHealthView()
                Button("Retry sync") { ConnectivityManager.shared.sendAlarmsToCounterpart() }
                Text("Sync confirms settings saved, not alert delivery.").font(.caption).foregroundStyle(.secondary)
                ForEach(filteredAlarms) { alarm in
                    AlarmRow(alarm: alarm, toggleAlarm: toggleAlarm)
                        .swipeActions(edge: .leading) {
                            if !alarm.isShared {
                                Button("Sync") {
                                    var shared = alarm
                                    shared.isShared = true
                                    store.updateAlarm(shared)
                                    loadAlarms()
                                }.tint(.green)
                            }
                        }
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.reconcile()
                ConnectivityManager.shared.sendAlarmsToCounterpart()
            }
        }
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
    }
    
    private func toggleAlarm(_ alarm: Alarm) {
        var updatedAlarm = alarm
        updatedAlarm.isEnabled.toggle()
        AlarmManager.shared.updateAlarm(updatedAlarm)
        loadAlarms()
    }
    
    private func deleteAlarms(at offsets: IndexSet) {
        offsets.forEach { index in
            AlarmManager.shared.deleteAlarm(filteredAlarms[index])
        }
        loadAlarms()
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    let toggleAlarm: (Alarm) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(alarm.time, style: .time).fontDesign(.monospaced)
                AlarmSyncStatusView(alarm: alarm)
                Text("Alerts: " + alarm.deviceTypes.map(\.rawValue).sorted().joined(separator: ", ")).font(.caption2)
            }
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
