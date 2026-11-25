#if os(iOS)
import AlarmKit
import AppIntents

@available(iOS 26.0, *)
struct SyncAlarmMetadata: AlarmMetadata {
    var title: String
}

@available(iOS 26.0, *)
struct StopSystemAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop alarm"
    @Parameter(title: "Alarm ID") var alarmID: String
    init() {}
    init(id: UUID) { alarmID = id.uuidString }
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        try AlarmKit.AlarmManager.shared.stop(id: id)
        return .result()
    }
}
#endif
