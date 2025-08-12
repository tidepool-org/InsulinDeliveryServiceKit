//
//  I2CHORatioProfileTemplateTimeBlockChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct I2CHORatioProfileTemplateTimeBlockChangedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .i2choProfileTemplateTimeBlockChanged

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

    var ratio: Double {
        Data(eventData[eventData.startIndex.advanced(by: 4)...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension I2CHORatioProfileTemplateTimeBlockChangedHistoryEvent {
    public var description: String {
        "I2CHORatioProfileTemplateTimeBlockChangedHistoryEvent templateNumber: \(templateNumber), timeBlockNumber: \(timeBlockNumber), duration: \(duration), ratio: \(ratio), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}
