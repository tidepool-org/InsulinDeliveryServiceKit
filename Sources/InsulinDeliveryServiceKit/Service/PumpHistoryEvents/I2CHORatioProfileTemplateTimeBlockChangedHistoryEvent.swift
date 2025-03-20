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

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var templateNumber: Int {
        Int(auxData[auxData.startIndex...].to(UInt8.self))
    }

    var timeBlockNumber: Int {
        Int(auxData[auxData.startIndex.advanced(by: 1)...].to(UInt8.self))
    }

    var duration: TimeInterval {
        .minutes(Int(auxData[auxData.startIndex.advanced(by: 2)...].to(UInt16.self)))
    }

    var ratio: Double {
        Data(auxData[auxData.startIndex.advanced(by: 4)...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension I2CHORatioProfileTemplateTimeBlockChangedHistoryEvent {
    public var description: String {
        "I2CHORatioProfileTemplateTimeBlockChangedHistoryEvent templateNumber: \(templateNumber), timeBlockNumber: \(timeBlockNumber), duration: \(duration), ratio: \(ratio), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
