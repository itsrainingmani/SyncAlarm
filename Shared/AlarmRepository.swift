import Foundation

/// A Lamport revision avoids depending on synchronized device clocks.
struct AlarmRevision: Codable, Equatable, Comparable {
    var counter: UInt64
    var deviceID: String
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.counter == rhs.counter ? lhs.deviceID < rhs.deviceID : lhs.counter < rhs.counter
    }
}

struct AlarmRecord: Codable, Equatable {
    var alarm: Alarm
    var revision: AlarmRevision
    var isDeleted = false
}

struct AlarmDatabase: Codable, Equatable {
    var schemaVersion = 1
    var deviceID: String = UUID().uuidString
    var peerID: String?
    var counter: UInt64 = 0
    var records: [AlarmRecord] = []
    // Acknowledgements are local metadata, never merged as remote truth.
    var acknowledged: [UUID: AlarmRevision] = [:]
}

/// Call through a single serialized owner. Writes replace the file atomically.
final class AlarmRepository {
    private(set) var database: AlarmDatabase
    private let url: URL

    init(url: URL, legacyData: Data? = nil) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            database = try JSONDecoder().decode(AlarmDatabase.self, from: Data(contentsOf: url))
            guard database.schemaVersion == 1 else { throw StoreError.unsupportedVersion }
        } else {
            database = AlarmDatabase()
            if let legacyData {
                let alarms = try JSONDecoder().decode([Alarm].self, from: legacyData)
                for alarm in alarms {
                    database.counter += 1
                    database.records.append(AlarmRecord(alarm: alarm, revision: .init(counter: database.counter, deviceID: database.deviceID)))
                }
            }
            try persist(database)
        }
    }

    enum StoreError: Error { case unsupportedVersion }
    var alarms: [Alarm] {
        database.records.filter { !$0.isDeleted }.map(\.alarm).sorted {
            ($0.hour, $0.minute, $0.id.uuidString) < ($1.hour, $1.minute, $1.id.uuidString)
        }
    }

    func upsert(_ alarm: Alarm, deleted: Bool = false) throws {
        var next = database
        next.counter += 1
        let record = AlarmRecord(alarm: alarm, revision: .init(counter: next.counter, deviceID: next.deviceID), isDeleted: deleted)
        next.records.removeAll { $0.alarm.id == alarm.id }
        next.records.append(record)
        next.acknowledged.removeValue(forKey: alarm.id)
        try commit(next)
    }

    var sharedRecords: [AlarmRecord] { database.records.filter { $0.alarm.isShared } }
    var pendingRecords: [AlarmRecord] {
        sharedRecords.filter { database.acknowledged[$0.alarm.id] != $0.revision }
    }

    /// Merge a snapshot atomically. Missing records never imply deletion.
    func merge(_ records: [AlarmRecord], peerID: String) throws {
        var next = database
        if next.peerID != peerID { next.acknowledged = [:]; next.peerID = peerID }
        for record in records where record.alarm.isShared {
            next.counter = max(next.counter, record.revision.counter)
            if let index = next.records.firstIndex(where: { $0.alarm.id == record.alarm.id }) {
                // A remote UUID must never overwrite a device-local alarm.
                guard next.records[index].alarm.isShared else { continue }
                if next.records[index].revision < record.revision {
                    next.records[index] = record
                    next.acknowledged.removeValue(forKey: record.alarm.id)
                }
            } else {
                next.records.append(record)
            }
            if next.records.first(where: { $0.alarm.id == record.alarm.id }) == record {
                // Receiving this exact revision is also evidence that the peer has it.
                next.acknowledged[record.alarm.id] = record.revision
            }
        }
        if next != database { try commit(next) }
    }

    func acknowledge(_ receipts: [AlarmReceipt], peerID: String) throws {
        var next = database
        if next.peerID != peerID { next.acknowledged = [:]; next.peerID = peerID }
        for receipt in receipts {
            if let record = next.records.first(where: { $0.alarm.id == receipt.id }),
               record.alarm.isShared, record.revision == receipt.revision {
                next.acknowledged[receipt.id] = receipt.revision
            }
        }
        if next != database { try commit(next) }
    }

    func receipt(for records: [AlarmRecord]) -> [AlarmReceipt] {
        records.compactMap { remote in
            guard let local = database.records.first(where: { $0.alarm.id == remote.alarm.id }),
                  local.alarm.isShared, local == remote else { return nil }
            return AlarmReceipt(id: remote.alarm.id, revision: remote.revision)
        }
    }

    private func persist(_ value: AlarmDatabase) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
    private func commit(_ value: AlarmDatabase) throws {
        try persist(value)
        database = value
    }
}

struct AlarmReceipt: Codable {
    var id: UUID
    var revision: AlarmRevision
}

struct AlarmEnvelope: Codable {
    var protocolVersion = 1
    var senderID: String
    var records: [AlarmRecord]
    var receipts: [AlarmReceipt]
    var requestsAcknowledgement: Bool
}
