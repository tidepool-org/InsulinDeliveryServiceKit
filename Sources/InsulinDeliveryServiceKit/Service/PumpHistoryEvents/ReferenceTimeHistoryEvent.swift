//
//  ReferenceTimeHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct ReferenceTimeHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .referenceTime

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data

    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }
    
    var recordingReason: RecordingReason {
        guard let recordingReason = RecordingReason(rawValue: eventData[eventData.startIndex...].to(RecordingReason.RawValue.self))
        else {
            return .undetermined
        }
        return recordingReason
    }

    func date(using timeZone: TimeZone) -> Date? {
        Date(gattDateTime: eventData[eventData.startIndex.advanced(by: 1)...7], timeZone: timeZone)
    }
    
    var date: Date? {
        // This date is always reported with UTC time zone
        Date(gattDateTime: eventData[eventData.startIndex.advanced(by: 1)...7], timeZone: .utc)
    }
    
    var timeZone: TimeZone? {
        let timeZone15MinIncrements = Int(eventData[eventData.startIndex.advanced(by: 8)...].to(Int8.self))
        let timeZoneSecondsFromGMT = (timeZone15MinIncrements * 15 * 60)
        guard let timeZone = TimeZone(secondsFromGMT: timeZoneSecondsFromGMT) else { return nil }
        return timeZone
    }

    var dstOffset: TimeInterval? {
        guard let offset = DSTOffset(rawValue: eventData[eventData.startIndex.advanced(by: 9)...].to(UInt8.self)) else { return nil }
        switch offset {
        case .standardTime:
            return 0
        case .daylightHalfHour:
            return .minutes(30)
        case .daylight1Hour:
            return .hours(1)
        case .daylight2Hour:
            return .hours(2)
        case .unknown:
            return nil
        }
    }
}

extension ReferenceTimeHistoryEvent {
    public var description: String {
        "ReferenceTimeHistoryEvent date: \(String(describing: date)), timeZone: \(String(describing: timeZone)), dstOffset: \(String(describing: dstOffset)), recordingReason: \(recordingReason), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}


//MARK: - Enumerations

public enum RecordingReason: UInt8, CustomStringConvertible {
    case undetermined = 0x0f
    case setDateTime = 0x33
    case periodicRecording = 0x3c
    case dateTimeLoss = 0x55
    
    public var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .setDateTime: return "setDateTime"
        case .periodicRecording: return "periodicRecording"
        case .dateTimeLoss: return "dateTimeLoss"
        }
    }
}
