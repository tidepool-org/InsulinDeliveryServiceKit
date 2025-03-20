//
//  ReferenceTimeBaseOffsetHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct ReferenceTimeBaseOffsetHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .referenceTimeBaseOffset

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var recordingReason: RecordingReason {
        guard let recordingReason = RecordingReason(rawValue: auxData[auxData.startIndex...].to(RecordingReason.RawValue.self))
        else {
            return .undetermined
        }
        return recordingReason
    }

    func baseTime(using timeZone: TimeZone) -> Date? {
        Date(gattDateTime: auxData[auxData.startIndex.advanced(by: 1)...7], timeZone: timeZone)
    }
    
    var baseTime: Date? {
        // This date is always reported with UTC time zone
        Date(gattDateTime: auxData[auxData.startIndex.advanced(by: 1)...7], timeZone: .utc)
    }
    
    var timeOffset: TimeInterval {
        TimeInterval(minutes: Int(auxData[auxData.startIndex.advanced(by: 8)...].to(Int16.self)))
    }
}

extension ReferenceTimeBaseOffsetHistoryEvent {
    var description: String {
        "ReferenceTimeBaseOffsetHistoryEvent baseTime: \(String(describing: baseTime)), timeOffset: \(String(describing: timeOffset)), recordingReason: \(recordingReason), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
