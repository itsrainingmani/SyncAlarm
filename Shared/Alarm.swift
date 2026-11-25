//
//  Alarm.swift
//  SyncAlarm
//
//  Created by Manikandan Sundararajan on 9/15/24.
//

import Foundation

struct Alarm: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    // Persist wall-clock components, rather than an arbitrary date from the picker.
    var hour: Int
    var minute: Int
    var time: Date {
        get { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date() }
        set {
            hour = Calendar.current.component(.hour, from: newValue)
            minute = Calendar.current.component(.minute, from: newValue)
        }
    }
    var isShared: Bool
    var isEnabled: Bool
    var deviceTypes: Set<DeviceType>
    
    enum DeviceType: String, Codable, CaseIterable {
        case iPhone
        case Watch
    }
    
    init(id: UUID = UUID(), title: String, time: Date, isEnabled: Bool = true, deviceTypes: Set<DeviceType> = [.iPhone], isShared: Bool = true) {
        self.isShared = isShared
        self.id = id
        self.title = title
        self.hour = Calendar.current.component(.hour, from: time)
        self.minute = Calendar.current.component(.minute, from: time)
        self.isEnabled = isEnabled
        self.deviceTypes = deviceTypes
    }
    private enum CodingKeys: String, CodingKey { case id, title, time, hour, minute, isEnabled, deviceTypes, isShared }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isShared = try values.decodeIfPresent(Bool.self, forKey: .isShared) ?? true
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        isEnabled = try values.decode(Bool.self, forKey: .isEnabled)
        deviceTypes = try values.decode(Set<DeviceType>.self, forKey: .deviceTypes)
        if let hour = try values.decodeIfPresent(Int.self, forKey: .hour) {
            self.hour = hour
            minute = try values.decode(Int.self, forKey: .minute)
        } else {
            let legacy = try values.decode(Date.self, forKey: .time)
            hour = Calendar.current.component(.hour, from: legacy)
            minute = Calendar.current.component(.minute, from: legacy)
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw DecodingError.dataCorruptedError(forKey: .hour, in: values, debugDescription: "Invalid alarm time")
        }
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(isShared, forKey: .isShared)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try values.encode(hour, forKey: .hour)
        try values.encode(minute, forKey: .minute)
        try values.encode(isEnabled, forKey: .isEnabled)
        try values.encode(deviceTypes, forKey: .deviceTypes)
    }

}

extension Date {
    func extractTimeComponents() -> (timeString: String, periodString: String) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm"
        
        let periodFormatter = DateFormatter()
        periodFormatter.dateFormat = "a"
        
        let timeString = timeFormatter.string(from: self)
        let periodString = periodFormatter.string(from: self)
        
        return (timeString, periodString)
    }
}
