import SwiftUI

struct AlarmListView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var store = AlarmManager.shared
    @State private var alarms: [Alarm] = []
    @State private var showingAddAlarm = false
    @State private var currentFilter: Alarm.DeviceType?
    @State private var editingAlarm: Alarm?
    @State private var isNotificationPermissionGranted: Bool = true
    @State private var showingPermissionDialog = false

    var filteredAlarms: [Alarm] {
        let filtered = currentFilter == nil ? alarms : alarms.filter { $0.deviceTypes.contains(currentFilter!) }
        return filtered
    }
    
    func refreshData() {
        self.alarms = AlarmManager.shared.loadAlarms()
    }
    
    var body: some View {
        NavigationStack {
            if filteredAlarms.isEmpty {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .center) {
                            Text("No alarms present").font(.custom("HostGrotesk-Bold", size: 30)).foregroundStyle(.secondary).bold()
                        }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, idealHeight: geometry.size.height, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)
                    }
                }
            }
            List {
                AlarmHealthView()
                Section {
                    Text("Sync confirms saved settings on both devices. Alert destinations are separate.").font(.caption).foregroundStyle(.secondary)
                    Button("Retry sync and scheduling") {
                        store.reconcile()
                        ConnectivityManager.shared.sendAlarmsToCounterpart()
                    }
                    if NotificationManager.shared.usesSystemAlarms {
                        Text("iPhone system alarms may also appear on a paired watch. The Watch destination adds an independent notification.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(filteredAlarms) { alarm in
                    AlarmRow(alarm: alarm, onToggle: toggleAlarm, filterType: currentFilter)
                    .swipeActions(edge: .leading) {
                        if !alarm.isShared {
                            Button("Sync this alarm") {
                                var shared = alarm
                                shared.isShared = true
                                updateAlarm(shared)
                            }.tint(.green)
                        }
                        Button {
                            editingAlarm = alarm
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.indigo)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteAlarms(alarm)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                    .onLongPressGesture {
                        toggleAlarm(alarm)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(Color.secondary)
                }
            }
            .refreshable {
                ConnectivityManager.shared.sendAlarmsToCounterpart()
                refreshData()
            }
            .navigationTitle("Sync Alarms")
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                checkNotificationPermission()
                store.reconcile()
                ConnectivityManager.shared.sendAlarmsToCounterpart()
            }
        }
        .onAppear {
            store.reconcile()
            checkNotificationPermission()
            loadAlarms()
        }
        .alert(NotificationManager.shared.usesSystemAlarms ? "Enable Alarms" : "Enable Notifications",
               isPresented: Binding(
                get: { !isNotificationPermissionGranted && showingPermissionDialog },
                set: { showingPermissionDialog = $0 }
               ),
               actions: {
                   Button("Allow alerts") { NotificationManager.shared.requestAuthorization { _ in } }
                   Button("Open Settings") {
                       if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                           UIApplication.shared.open(settingsURL)
                       }
                   }
                   Button("Later", role: .cancel) {
                       showingPermissionDialog = false
                   }
               },
               message: {
                   Text(NotificationManager.shared.usesSystemAlarms ? "Allow this app to schedule system alarms. Alarm permission is separate from notification permission." : "To receive alarm alerts, enable notifications and sounds in Settings.")
               }
        )
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
        Task {
            let granted = await NotificationManager.shared.authorizationGranted()
            isNotificationPermissionGranted = granted
            showingPermissionDialog = !granted && alarms.contains { $0.isEnabled && $0.deviceTypes.contains(.iPhone) }
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
    
    private func deleteAlarms(_ alarm: Alarm) {
        AlarmManager.shared.deleteAlarm(alarm)
        loadAlarms()
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
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text(self.timeInfo)
                        .font(.custom("InnovatorGrotesk-Bold", size: alarm.isEnabled ? 55 : 40))
                    Text(self.ampm)
                        .font(.custom("InnovatorGrotesk-Regular", size: alarm.isEnabled ? 25 : 20))
                }
                AlarmSyncStatusView(alarm: alarm)
                AlarmDeliveryStatusView(alarm: alarm)
                Text(alarm.title.count > 0 ? alarm.title : "Alarm")
                    .font(.custom("HostGrotesk-Regular", size: 20))
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
        }.padding(.vertical, 8).padding(.trailing, 8)
    }
}

#Preview {
    AlarmListView()
}
