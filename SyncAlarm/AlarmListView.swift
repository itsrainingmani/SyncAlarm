import SwiftUI

struct AlarmListView: View {
    @State private var alarms: [Alarm] = []
    @State private var showingAddAlarm = false
    @State private var currentFilter: Alarm.DeviceType?
    @State private var editingAlarm: Alarm?
    @State private var isNotificationPermissionGranted: Bool = false

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
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.indigo)
                    }
                    .onLongPressGesture {
                        toggleAlarm(alarm)
                    }
                }
                .onDelete(perform: deleteAlarms)
            }
            .navigationTitle("Synchro")
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
            loadAlarms()
        }
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
        ConnectivityManager.shared.sendAlarmsToCounterpart()
    }
    
    private func updateAlarm(_ updatedAlarm: Alarm) {
        AlarmManager.shared.updateAlarm(updatedAlarm)
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
            AlarmManager.shared.deleteAlarm(alarms[index])
        }
        loadAlarms()
        ConnectivityManager.shared.sendAlarmsToCounterpart()
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    let onToggle: (Alarm) -> Void
    let filterType: Alarm.DeviceType?
    private let timeInfo: String
    private let ampm: String
    
    init(alarm: Alarm, onToggle: @escaping (Alarm) -> Void, filterType: Alarm.DeviceType?) {
        self.alarm = alarm
        self.onToggle = onToggle
        self.filterType = filterType
        let (timeString, periodString) = alarm.time.extractTimeComponents()
        self.timeInfo = timeString
        self.ampm = periodString
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text(self.timeInfo)
                        .font(.system(size: 40)).bold()
                    Text(self.ampm)
                        .font(.system(size: 22))
                }.monospacedDigit()
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
                .font(.title3)
            }.foregroundColor(alarm.isEnabled ? .primary : .secondary)
            Spacer(minLength: 0.1)
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
