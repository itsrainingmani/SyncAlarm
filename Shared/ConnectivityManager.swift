import Foundation
import Combine
import WatchConnectivity

/// The persistent revisioned records are the outbox. Transport retries are safe.
@MainActor
final class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ConnectivityManager()
    @Published private(set) var lastError: String?
    private var activationObservation: NSKeyValueObservation?
    private var pendingObservation: NSKeyValueObservation?
    private var backgroundWaiters: [CheckedContinuation<Void, Never>] = []
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func activateSession() {
        guard let session else { return }
        session.delegate = self
        if activationObservation == nil {
            activationObservation = session.observe(\.activationState) { _, _ in
                DispatchQueue.main.async { self.completeBackgroundDeliveryIfReady() }
            }
            pendingObservation = session.observe(\.hasContentPending) { _, _ in
                DispatchQueue.main.async { self.completeBackgroundDeliveryIfReady() }
            }
        }
        session.activate()
    }

    /// SwiftUI owns completion of the watch background task after this returns.
    func finishBackgroundDelivery() async {
        guard session != nil else { return }
        if session?.activationState != .activated { activateSession() }
        await withCheckedContinuation { continuation in
            backgroundWaiters.append(continuation)
            DispatchQueue.main.async { self.completeBackgroundDeliveryIfReady() }
        }
        await NotificationManager.shared.waitUntilIdle()
    }
    private func completeBackgroundDeliveryIfReady(force: Bool = false) {
        guard force || (session?.activationState == .activated && session?.hasContentPending == false) else { return }
        let waiters = backgroundWaiters
        backgroundWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func sendAlarmsToCounterpart() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let session, let repository = AlarmManager.shared.repository else { return }
        guard session.activationState == .activated else {
            activateSession() // activation completion flushes the durable records
            return
        }
        let envelope = AlarmEnvelope(senderID: repository.database.deviceID, records: repository.sharedRecords, receipts: [], requestsAcknowledgement: true)
        do {
            let payload = ["alarmEnvelope": try JSONEncoder().encode(envelope)]
            // Always retain the latest snapshot for eventual delivery, even if a live send fails.
            try session.updateApplicationContext(payload)
            if session.isReachable {
                session.sendMessage(payload, replyHandler: { response in
                    DispatchQueue.main.async { self.receive(response) }
                }, errorHandler: { error in
                    DispatchQueue.main.async { self.lastError = "Waiting for companion: \(error.localizedDescription)" }
                })
            }
            lastError = nil
        } catch { lastError = "Could not queue sync: \(error.localizedDescription)" }
    }

    /// Return a receipt only after a successful persistent merge.
    @discardableResult
    private func receive(_ payload: [String: Any]) -> [String: Any] {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let repository = AlarmManager.shared.repository else { return [:] }
        do {
            guard let data = payload["alarmEnvelope"] as? Data else { return [:] }
            let envelope = try JSONDecoder().decode(AlarmEnvelope.self, from: data)
            guard envelope.protocolVersion == 1 else {
                lastError = "Update both apps to use the same sync version."
                return [:]
            }
            guard envelope.senderID != repository.database.deviceID else { return [:] }
            try repository.merge(envelope.records, peerID: envelope.senderID)
            try repository.acknowledge(envelope.receipts, peerID: envelope.senderID)
            let receipts = repository.receipt(for: envelope.records)
            AlarmManager.shared.objectWillChange.send()
            AlarmManager.shared.reconcile()
            NotificationCenter.default.post(name: .alarmsUpdated, object: nil)
            lastError = nil
            guard envelope.requestsAcknowledgement else { return [:] }
            let acknowledgement = AlarmEnvelope(senderID: repository.database.deviceID, records: repository.sharedRecords, receipts: receipts, requestsAcknowledgement: false)
            return ["alarmEnvelope": try JSONEncoder().encode(acknowledgement)]
        } catch {
            lastError = "Sync could not be saved: \(error.localizedDescription)"
            return [:]
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error {
                self.lastError = error.localizedDescription
                self.completeBackgroundDeliveryIfReady(force: true)
            }
            else if state == .activated { self.sendAlarmsToCounterpart() }
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable { DispatchQueue.main.async { self.sendAlarmsToCounterpart() } }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { replyHandler(self.receive(message)) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receiveInBackground(message)
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receiveInBackground(applicationContext)
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receiveInBackground(userInfo)
    }
    nonisolated private func receiveInBackground(_ payload: [String: Any]) {
        DispatchQueue.main.async {
            let receipt = self.receive(payload)
            if !receipt.isEmpty { self.session?.transferUserInfo(receipt) }
        }
    }
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}

extension Notification.Name {
    static let alarmsUpdated = Notification.Name("alarmsUpdated")
}
