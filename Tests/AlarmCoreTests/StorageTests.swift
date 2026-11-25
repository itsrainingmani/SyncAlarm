import XCTest
@testable import AlarmCore

final class StorageTests: XCTestCase {
    func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("alarms.json") }
    func testRoundTripAndDeletionSurviveRelaunch() throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try AlarmRepository(url: url)
        let alarm = Alarm(title: "Morning", time: Date())
        try store.upsert(alarm)
        XCTAssertEqual(try AlarmRepository(url: url).alarms, [alarm])
        try store.upsert(alarm, deleted: true)
        let reloaded = try AlarmRepository(url: url)
        XCTAssertTrue(reloaded.alarms.isEmpty)
        XCTAssertTrue(reloaded.database.records[0].isDeleted)
        XCTAssertEqual(reloaded.database.records[0].revision.counter, 2)
    }
    func testCorruptStoreIsNotOverwritten() throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data("broken".utf8)
        try bytes.write(to: url)
        XCTAssertThrowsError(try AlarmRepository(url: url))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    func testLegacyDateMigration() throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let date = Date()
        let data = try JSONSerialization.data(withJSONObject: [["id": UUID().uuidString, "title": "Legacy", "time": date.timeIntervalSinceReferenceDate, "isEnabled": true, "deviceTypes": ["iPhone"]]])
        let store = try AlarmRepository(url: url, legacyData: data)
        XCTAssertEqual(store.alarms.first?.hour, Calendar.current.component(.hour, from: date))
        XCTAssertEqual(store.alarms.first?.minute, Calendar.current.component(.minute, from: date))
    }
    func testFailedWriteDoesNotMutateMemory() throws {
        let url = location()
        let store = try AlarmRepository(url: url)
        try FileManager.default.removeItem(at: url.deletingLastPathComponent())
        try Data().write(to: url.deletingLastPathComponent())
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try store.upsert(Alarm(title: "Fail", time: Date())))
        XCTAssertTrue(store.alarms.isEmpty)
    }
}
