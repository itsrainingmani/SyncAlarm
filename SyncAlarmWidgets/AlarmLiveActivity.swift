import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

@main
struct SyncAlarmWidgetBundle: WidgetBundle {
    var body: some Widget { AlarmLiveActivity() }
}

struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<SyncAlarmMetadata>.self) { context in
            HStack {
                VStack(alignment: .leading) {
                    Text(context.attributes.metadata?.title ?? "Alarm").font(.headline)
                    countdown(context.state)
                }
                Spacer()
                Button(intent: StopSystemAlarmIntent(id: context.state.alarmID)) {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Stop alarm")
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(context.attributes.metadata?.title ?? "Alarm") }
                DynamicIslandExpandedRegion(.center) { countdown(context.state) }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: StopSystemAlarmIntent(id: context.state.alarmID)) { Image(systemName: "stop.fill") }
                        .accessibilityLabel("Stop alarm")
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                countdown(context.state).frame(maxWidth: 60)
            } minimal: {
                Image(systemName: "alarm.fill")
            }
        }
    }

    @ViewBuilder
    private func countdown(_ state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: countdown.startDate...countdown.fireDate, countsDown: true).monospacedDigit()
        case .paused:
            Text("Paused")
        case .alert:
            Text("Alarm")
        @unknown default:
            Text("Alarm")
        }
    }
}
