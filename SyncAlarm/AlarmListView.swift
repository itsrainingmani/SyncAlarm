import SwiftUI

struct AlarmListView: View {
    @State private var alarms: [Alarm] = []
    @State private var showingAddAlarm = false
    @State private var isNotificationPermissionGranted = false
    @State private var currentFilter: Alarm.DeviceType?
    @State private var editingAlarm: Alarm?

    var filteredAlarms: [Alarm] {
        let filtered = currentFilter == nil ? alarms : alarms.filter { $0.deviceTypes.contains(currentFilter!) }
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            if filteredAlarms.isEmpty {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .center) {
                            Text("No alarms present").font(.largeTitle).foregroundStyle(.secondary).italic()
                            if !isNotificationPermissionGranted {
                                Section {
                                    Text("Please enable notifications in Settings to receive alarm alerts.")
                                        .foregroundStyle(.red)
                                }
                            }
                        }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, idealHeight: geometry.size.height, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)
                    }
                }
            }
            List {
                ForEach(filteredAlarms) { alarm in
                    AlarmRow(alarm: alarm, onToggle: toggleAlarm, filterType: currentFilter)
                    .swipeActions(edge: .leading) {
                        Button {
                            editingAlarm = alarm
                        } label: {
                            Text("Edit")
                        }
                        .tint(.indigo)
                    }
                }
                .onDelete(perform: deleteAlarms)
            }
            .navigationTitle("SyncAlarms")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            currentFilter = nil
                        } label: {
                            Label("All", systemImage: "list.bullet")
                        }
                        ForEach(Alarm.DeviceType.allCases, id: \.self) { deviceType in
                            Button {
                                currentFilter = deviceType
                            } label: {
                                Label(deviceType.rawValue, systemImage: deviceType == .iPhone ? "iphone" : "applewatch")
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddAlarm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            checkNotificationPermission()
        }
        .onAppear(perform: loadAlarms)
        .sheet(isPresented: $showingAddAlarm) {
            AddAlarmView(onSave: addAlarm)
        }
        .sheet(item: $editingAlarm) { alarm in
            EditAlarmView(alarm: alarm, onSave: updateAlarm)
        }
        .onReceive(NotificationCenter.default.publisher(for: .alarmsUpdated)) { _ in
            loadAlarms()
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                isNotificationPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func loadAlarms() {
        alarms = AlarmManager.shared.loadAlarms()
    }
    
    private func addAlarm(_ alarm: Alarm) {
        AlarmManager.shared.addAlarm(alarm)
        loadAlarms()
    }
    
    private func updateAlarm(_ updatedAlarm: Alarm) {
        AlarmManager.shared.updateAlarm(updatedAlarm)
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
            AlarmManager.shared.deleteAlarm(alarms[index])
        }
        loadAlarms()
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    let onToggle: (Alarm) -> Void
    let filterType: Alarm.DeviceType?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.time, style: .time)
                    .font(.title.bold().monospaced())
                    .fontWeight(.semibold)
                Text(alarm.title)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HStack {
                    if alarm.deviceTypes.contains(.iPhone) {
                        Image(systemName: "iphone").foregroundStyle(filterType == .iPhone ? .green : alarm.isEnabled ? .primary : .secondary)
                    }
                    if alarm.deviceTypes.contains(.Watch) {
                        Image(systemName: "applewatch").foregroundStyle(filterType == .Watch ? .green : alarm.isEnabled ? .primary : .secondary)
                    }
                }
                .font(.subheadline)
            }.foregroundColor(alarm.isEnabled ? .primary : .secondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in onToggle(alarm) }
            ))
        }
    }
}

#Preview {
    AlarmListView()
}
