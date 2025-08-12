//
//  ReferenceTimeBaseOffsetHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct ReferenceTimeBaseOffsetHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .referenceTimeBaseOffset

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

    func baseTime(using timeZone: TimeZone) -> Date? {
        Date(gattDateTime: eventData[eventData.startIndex.advanced(by: 1)...7], timeZone: timeZone)
    }
    
    var baseTime: Date? {
        // This date is always reported with UTC time zone
        Date(gattDateTime: eventData[eventData.startIndex.advanced(by: 1)...7], timeZone: .utc)
    }
    
    var timeOffset: TimeInterval {
        TimeInterval(minutes: Int(eventData[eventData.startIndex.advanced(by: 8)...].to(Int16.self)))
    }
}

extension ReferenceTimeBaseOffsetHistoryEvent {
    public var description: String {
        "ReferenceTimeBaseOffsetHistoryEvent baseTime: \(String(describing: baseTime)), timeOffset: \(String(describing: timeOffset)), recordingReason: \(recordingReason), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}
