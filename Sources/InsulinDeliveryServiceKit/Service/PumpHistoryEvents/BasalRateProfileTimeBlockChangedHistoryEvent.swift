//
//  BasalRateProfileTimeBlockChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct BasalRateProfileTimeBlockChangedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .basalRateProfileTimeBlockChanged

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var templateNumber: Int {
        Int(eventData[eventData.startIndex...].to(UInt8.self))
    }

    var timeBlockNumber: Int {
        Int(eventData[eventData.startIndex.advanced(by: 1)...].to(UInt8.self))
    }

    var duration: TimeInterval {
        .minutes(Int(eventData[eventData.startIndex.advanced(by: 2)...].to(UInt16.self)))
    }

    var rate: Double {
        Data(eventData[eventData.startIndex.advanced(by: 4)...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension BasalRateProfileTimeBlockChangedHistoryEvent {
    public var description: String {
        "BasalRateProfileTimeBlockChangedHistoryEvent templateNumber: \(templateNumber), timeBlockNumber: \(timeBlockNumber), duration: \(duration), rate: \(rate), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}
