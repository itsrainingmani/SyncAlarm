//
//  Alarm.swift
//  SyncAlarm
//
//  Created by Manikandan Sundararajan on 9/15/24.
//

import Foundation

struct Alarm: Codable, Identifiable {
    let id: UUID
    var title: String
    var time: Date
    var isEnabled: Bool
    var deviceTypes: Set<DeviceType>
    
    enum DeviceType: String, Codable, CaseIterable {
        case iPhone
        case Watch
    }
    
    init(id: UUID = UUID(), title: String, time: Date, isEnabled: Bool = true, deviceTypes: Set<DeviceType> = [.iPhone]) {
        self.id = id
        self.title = title
        self.time = time
        self.isEnabled = isEnabled
        self.deviceTypes = deviceTypes
    }
}
