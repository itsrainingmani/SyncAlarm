import XCTest
@testable import AlarmCore

@MainActor
private final class FakeSystemAlarms: SystemAlarmClient {
    var isAuthorized = true
    var ids: Set<UUID> = []
    var configurations: [UUID: SystemAlarmDefinition] = [:]
    var scheduled: [SystemAlarmDefinition] = []
    var cancelled: [UUID] = []
    var failRead = false, failSchedule = false, failCancel = false
    enum Failure: Error { case unavailable }
    func scheduledIDs() throws -> Set<UUID> {
        if failRead { throw Failure.unavailable }
        return ids
    }
    func configuration(for id: UUID) -> SystemAlarmDefinition? { configurations[id] }
    func schedule(_ definition: SystemAlarmDefinition) async throws {
        if failSchedule { throw Failure.unavailable }
        scheduled.append(definition)
        ids.insert(definition.id)
        configurations[definition.id] = definition
    }
    func cancel(_ id: UUID) throws {
        if failCancel { throw Failure.unavailable }
        cancelled.append(id)
        ids.remove(id)
        configurations.removeValue(forKey: id)
    }
}

final class SystemAlarmTests: XCTestCase {
    @MainActor func testRepeatedReconcileDoesNotResetScheduledOrSnoozedAlarm() async {
        let client = FakeSystemAlarms(), alarm = Alarm(title: "Morning", time: Date())
        let reconciler = SystemAlarmReconciler(client: client)
        let first = await reconciler.reconcile([alarm])
        let second = await reconciler.reconcile([alarm])
        XCTAssertEqual(first.migratedIDs, [alarm.id])
        XCTAssertEqual(second.statuses[alarm.id], .scheduled)
        XCTAssertEqual(client.scheduled.count, 1)
    }
    @MainActor func testTitleAndTimeChangesReplaceSameSystemID() async {
        let client = FakeSystemAlarms()
        var alarm = Alarm(title: "First", time: Date())
        let reconciler = SystemAlarmReconciler(client: client)
        _ = await reconciler.reconcile([alarm])
        alarm.title = "Second"; alarm.hour = 7; alarm.minute = 30
        _ = await reconciler.reconcile([alarm])
        XCTAssertEqual(client.scheduled.count, 2)
        XCTAssertEqual(client.cancelled, [alarm.id])
        XCTAssertEqual(client.scheduled.last?.id, alarm.id)
        XCTAssertEqual(client.scheduled.last?.title, "Second")
        XCTAssertEqual(client.scheduled.last?.hour, 7)
        XCTAssertEqual(client.scheduled.last?.minute, 30)
    }
    @MainActor func testDisabledDeletedAndWatchOnlyAlarmsAreCancelled() async {
        let client = FakeSystemAlarms()
        var disabled = Alarm(title: "Disabled", time: Date()); disabled.isEnabled = false
        let watch = Alarm(title: "Watch", time: Date(), deviceTypes: [.Watch])
        let deleted = UUID()
        client.ids = [disabled.id, watch.id, deleted]
        let result = await SystemAlarmReconciler(client: client).reconcile([disabled, watch])
        XCTAssertEqual(Set(client.cancelled), [disabled.id, watch.id, deleted])
        XCTAssertTrue(client.scheduled.isEmpty)
        XCTAssertEqual(result.statuses[disabled.id], .off)
        XCTAssertEqual(result.statuses[watch.id], .otherDevice)
    }
    @MainActor func testDeniedAuthorizationDoesNotScheduleOrClaimMigration() async {
        let client = FakeSystemAlarms(); client.isAuthorized = false
        let alarm = Alarm(title: "Blocked", time: Date())
        let result = await SystemAlarmReconciler(client: client).reconcile([alarm])
        XCTAssertEqual(result.statuses[alarm.id], .blocked)
        XCTAssertTrue(result.migratedIDs.isEmpty)
        XCTAssertTrue(client.scheduled.isEmpty)
    }
    @MainActor func testFailedReplacementKeepsLegacyEligibleForRecovery() async {
        let client = FakeSystemAlarms(); client.failSchedule = true
        let alarm = Alarm(title: "Fail", time: Date())
        let result = await SystemAlarmReconciler(client: client).reconcile([alarm])
        XCTAssertNotNil(result.error)
        guard case .failed = result.statuses[alarm.id] else { return XCTFail("Must show scheduling failure") }
        XCTAssertTrue(result.migratedIDs.isEmpty)
    }
    @MainActor func testFailedEditCancellationDoesNotScheduleDuplicate() async {
        let client = FakeSystemAlarms()
        var alarm = Alarm(title: "Old", time: Date())
        let reconciler = SystemAlarmReconciler(client: client)
        _ = await reconciler.reconcile([alarm])
        client.failCancel = true
        alarm.title = "New"
        let result = await reconciler.reconcile([alarm])
        XCTAssertEqual(client.scheduled.count, 1)
        XCTAssertTrue(result.migratedIDs.isEmpty)
        XCTAssertNotNil(result.error)
    }
    @MainActor func testSystemReadFailureDoesNotCancelOrScheduleAnything() async {
        let client = FakeSystemAlarms(); client.failRead = true
        let alarm = Alarm(title: "Unknown", time: Date())
        let result = await SystemAlarmReconciler(client: client).reconcile([alarm])
        XCTAssertNotNil(result.error)
        XCTAssertTrue(client.cancelled.isEmpty)
        XCTAssertTrue(client.scheduled.isEmpty)
    }
    @MainActor func testMissingSystemAlarmIsRecreatedDespiteCachedConfiguration() async {
        let client = FakeSystemAlarms(), alarm = Alarm(title: "Restore", time: Date())
        client.configurations[alarm.id] = SystemAlarmDefinition(alarm)
        let result = await SystemAlarmReconciler(client: client).reconcile([alarm])
        XCTAssertEqual(client.scheduled.count, 1)
        XCTAssertEqual(result.statuses[alarm.id], .scheduled)
    }
    @MainActor func testSyncScopeDoesNotResetSystemAlarmAndCancellationFailureIsVisible() async {
        let client = FakeSystemAlarms()
        var alarm = Alarm(title: "Local", time: Date(), isShared: false)
        let reconciler = SystemAlarmReconciler(client: client)
        _ = await reconciler.reconcile([alarm])
        alarm.isShared = true
        _ = await reconciler.reconcile([alarm])
        XCTAssertEqual(client.scheduled.count, 1)
        client.failCancel = true
        let result = await reconciler.reconcile([])
        XCTAssertNotNil(result.error)
        XCTAssertTrue(client.ids.contains(alarm.id))
    }
}
