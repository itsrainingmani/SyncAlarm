import XCTest
@testable import AlarmCore

final class SyncTests: XCTestCase {
    private var directories: [URL] = []
    override func tearDown() { directories.forEach { try? FileManager.default.removeItem(at: $0) }; super.tearDown() }
    func store() throws -> AlarmRepository {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        directories.append(directory)
        return try AlarmRepository(url: directory.appendingPathComponent("alarms.json"))
    }
    func testConcurrentEditsConvergeRegardlessOfDeliveryOrder() throws {
        let phone = try store(), watch = try store()
        var alarm = Alarm(title: "Initial", time: Date())
        try phone.upsert(alarm)
        try watch.merge(phone.sharedRecords, peerID: phone.database.deviceID)
        alarm.title = "Phone"; try phone.upsert(alarm)
        alarm.title = "Watch"; try watch.upsert(alarm)
        let phoneEdit = phone.sharedRecords, watchEdit = watch.sharedRecords
        try phone.merge(watchEdit, peerID: watch.database.deviceID)
        try watch.merge(phoneEdit, peerID: phone.database.deviceID)
        XCTAssertEqual(phone.sharedRecords, watch.sharedRecords)
        try phone.merge(watchEdit, peerID: watch.database.deviceID)
        XCTAssertEqual(phone.sharedRecords, watch.sharedRecords)
    }
    func testOldSnapshotCannotResurrectDeletion() throws {
        let phone = try store(), watch = try store()
        let alarm = Alarm(title: "Delete", time: Date())
        try phone.upsert(alarm)
        let stale = phone.sharedRecords
        try phone.upsert(alarm, deleted: true)
        try watch.merge(phone.sharedRecords, peerID: phone.database.deviceID)
        try watch.merge(stale, peerID: phone.database.deviceID)
        XCTAssertTrue(watch.alarms.isEmpty)
    }
    func testOnlyExactAcknowledgementClearsPendingRevision() throws {
        let phone = try store(), watch = try store()
        var alarm = Alarm(title: "First", time: Date())
        try phone.upsert(alarm)
        let original = phone.sharedRecords
        try watch.merge(original, peerID: phone.database.deviceID)
        let receipt = watch.receipt(for: original)
        alarm.title = "Second"; try phone.upsert(alarm)
        try phone.acknowledge(receipt, peerID: watch.database.deviceID)
        XCTAssertEqual(phone.pendingRecords.count, 1)
        try watch.merge(phone.sharedRecords, peerID: phone.database.deviceID)
        try phone.acknowledge(watch.receipt(for: phone.sharedRecords), peerID: watch.database.deviceID)
        XCTAssertTrue(phone.pendingRecords.isEmpty)
        try phone.acknowledge([], peerID: "replacement-watch")
        XCTAssertEqual(phone.pendingRecords.count, 1)
    }
    func testLocalAlarmsNeverLeaveDeviceOrGetOverwrittenByPeer() throws {
        let phone = try store(), watch = try store()
        var local = Alarm(title: "Private", time: Date(), isShared: false)
        try phone.upsert(local)
        XCTAssertTrue(phone.sharedRecords.isEmpty)
        XCTAssertTrue(phone.pendingRecords.isEmpty)
        local.isShared = true
        try watch.upsert(local)
        try phone.merge(watch.sharedRecords, peerID: watch.database.deviceID)
        XCTAssertFalse(try XCTUnwrap(phone.alarms.first).isShared)
        XCTAssertTrue(phone.receipt(for: watch.sharedRecords).isEmpty)
    }
    func testOutboxAndReceiptsSurviveRestart() throws {
        let phone = try store(), watch = try store()
        let alarm = Alarm(title: "Offline", time: Date())
        try phone.upsert(alarm)
        let url = directories[0].appendingPathComponent("alarms.json")
        XCTAssertEqual(try AlarmRepository(url: url).pendingRecords.count, 1)
        try watch.merge(phone.sharedRecords, peerID: phone.database.deviceID)
        try phone.acknowledge(watch.receipt(for: phone.sharedRecords), peerID: watch.database.deviceID)
        XCTAssertTrue(try AlarmRepository(url: url).pendingRecords.isEmpty)
    }
}
