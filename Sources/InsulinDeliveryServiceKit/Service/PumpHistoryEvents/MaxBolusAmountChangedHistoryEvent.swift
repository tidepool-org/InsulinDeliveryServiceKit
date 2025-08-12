//
//  MaxBolusAmountChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct MaxBolusAmountChangedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .maxBolusAmountChanged

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var oldAmount: Double {
        Data(eventData[eventData.startIndex...].to(SFLOAT.self)).sfloatToDouble()
    }

    var newAmount: Double {
        Data(eventData[eventData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension MaxBolusAmountChangedHistoryEvent {
    public var description: String {
        "MaxBolusAmountChangedHistoryEvent oldAmount: \(oldAmount), newAmount: \(newAmount), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}
