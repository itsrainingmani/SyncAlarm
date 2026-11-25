import XCTest
@testable import AlarmCore

final class StatusTests: XCTestCase {
    func testStatusRequiresCurrentRevisionAndLocalIsIndependentOfTargets() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AlarmRepository(url: directory.appendingPathComponent("alarms.json"))
        var alarm = Alarm(title: "Watch only but shared", time: Date(), deviceTypes: [.Watch])
        XCTAssertEqual(store.syncState(for: alarm), .unavailable)
        try store.upsert(alarm)
        XCTAssertEqual(store.syncState(for: alarm), .pending)
        try store.acknowledge(store.receipt(for: store.sharedRecords), peerID: "watch")
        XCTAssertEqual(store.syncState(for: alarm), .synced)
        alarm.isEnabled.toggle()
        try store.upsert(alarm)
        XCTAssertEqual(store.syncState(for: alarm), .pending)
        let local = Alarm(title: "Local", time: Date(), isShared: false)
        try store.upsert(local)
        XCTAssertEqual(store.syncState(for: local), .localOnly)
    }
}
