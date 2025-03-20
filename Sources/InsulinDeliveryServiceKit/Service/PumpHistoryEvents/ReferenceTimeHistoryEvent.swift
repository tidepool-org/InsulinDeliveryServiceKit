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

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data

    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }
    
    var recordingReason: RecordingReason {
        guard let recordingReason = RecordingReason(rawValue: auxData[auxData.startIndex...].to(RecordingReason.RawValue.self))
        else {
            return .undetermined
        }
        return recordingReason
    }

    func date(using timeZone: TimeZone) -> Date? {
        Date(gattDateTime: auxData[auxData.startIndex.advanced(by: 1)...7], timeZone: timeZone)
    }
    
    var date: Date? {
        // This date is always reported with UTC time zone
        Date(gattDateTime: auxData[auxData.startIndex.advanced(by: 1)...7], timeZone: .utc)
    }
    
    var timeZone: TimeZone? {
        let timeZone15MinIncrements = Int(auxData[auxData.startIndex.advanced(by: 8)...].to(Int8.self))
        let timeZoneSecondsFromGMT = (timeZone15MinIncrements * 15 * 60)
        guard let timeZone = TimeZone(secondsFromGMT: timeZoneSecondsFromGMT) else { return nil }
        return timeZone
    }

    var dstOffset: TimeInterval? {
        guard let offset = DSTOffset(rawValue: auxData[auxData.startIndex.advanced(by: 9)...].to(UInt8.self)) else { return nil }
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
        "ReferenceTimeHistoryEvent date: \(String(describing: date)), timeZone: \(String(describing: timeZone)), dstOffset: \(String(describing: dstOffset)), recordingReason: \(recordingReason), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}


//MARK: - Enumerations

enum RecordingReason: UInt8, CustomStringConvertible {
    case undetermined = 0x0f
    case setDateTime = 0x33
    case periodicRecording = 0x3c
    case dateTimeLoss = 0x55
    
    var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .setDateTime: return "setDateTime"
        case .periodicRecording: return "periodicRecording"
        case .dateTimeLoss: return "dateTimeLoss"
        }
    }
}
