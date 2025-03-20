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

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var remainingAmount: Double {
        Data(auxData[auxData.startIndex...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension ReservoirRemainingAmountChangedHistoryEvent {
    public var description: String {
        "ReservoirRemainingAmountChangedHistoryEvent remainingAmount: \(remainingAmount), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
