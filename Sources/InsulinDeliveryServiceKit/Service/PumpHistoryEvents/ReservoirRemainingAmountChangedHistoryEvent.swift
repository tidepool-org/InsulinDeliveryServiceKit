//
//  ReservoirRemainingAmountChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct ReservoirRemainingAmountChangedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .reservoirRemainingAmountChanged

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var remainingAmount: Double {
        Data(eventData[eventData.startIndex...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension ReservoirRemainingAmountChangedHistoryEvent {
    public var description: String {
        "ReservoirRemainingAmountChangedHistoryEvent remainingAmount: \(remainingAmount), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}
