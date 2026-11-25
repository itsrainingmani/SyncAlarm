import XCTest
@testable import AlarmCore

final class SchedulingTests: XCTestCase {
    func testRemovingDeviceCancelsRegularAndSnooze() {
        let alarm = Alarm(title: "Watch only", time: Date(), deviceTypes: [.Watch])
        let ids = [AlarmSchedulePlan.regularID(alarm.id), AlarmSchedulePlan.snoozeID(alarm.id)]
        let plan = AlarmSchedulePlan(alarms: [alarm], device: .iPhone, managedPendingIDs: ids)
        XCTAssertTrue(plan.desired.isEmpty)
        XCTAssertEqual(Set(plan.cancelIDs), Set(ids))
    }
    func testDeleteAndDisableRemoveAllOccurrencesButPreserveOtherAlarmSnooze() {
        let deleted = Alarm(title: "Deleted", time: Date())
        var disabled = Alarm(title: "Disabled", time: Date()); disabled.isEnabled = false
        let enabled = Alarm(title: "Enabled", time: Date())
        let ids = [deleted, disabled, enabled].flatMap { [AlarmSchedulePlan.regularID($0.id), AlarmSchedulePlan.snoozeID($0.id)] }
        let plan = AlarmSchedulePlan(alarms: [disabled, enabled], device: .iPhone, managedPendingIDs: ids)
        XCTAssertEqual(plan.cancelIDs.count, 4)
        XCTAssertEqual(plan.desired, [enabled])
        XCTAssertFalse(plan.cancelIDs.contains(AlarmSchedulePlan.snoozeID(enabled.id)))
    }
    func testTitleEditsAlwaysProduceReplacementAndInvalidateSnooze() {
        var alarm = Alarm(title: "New title", time: Date())
        alarm.hour = 7; alarm.minute = 30
        let snooze = AlarmSchedulePlan.snoozeID(alarm.id)
        let plan = AlarmSchedulePlan(alarms: [alarm], device: .iPhone, managedPendingIDs: [snooze], invalidatedSnoozes: [alarm.id])
        XCTAssertEqual(plan.desired.first?.title, "New title")
        XCTAssertEqual(plan.cancelIDs, [snooze])
    }
    func testLegacyMigrationAndNamespacedIdentifiers() {
        let alarm = Alarm(title: "Legacy", time: Date())
        let regular = AlarmSchedulePlan.regularID(alarm.id)
        let snooze = AlarmSchedulePlan.snoozeID(alarm.id)
        XCTAssertNotEqual(regular, snooze)
        XCTAssertEqual(AlarmSchedulePlan.alarmID(from: snooze), alarm.id)
        let plan = AlarmSchedulePlan(alarms: [alarm], device: .iPhone, managedPendingIDs: [alarm.id.uuidString, regular])
        XCTAssertEqual(plan.cancelIDs, [alarm.id.uuidString])
    }
}
