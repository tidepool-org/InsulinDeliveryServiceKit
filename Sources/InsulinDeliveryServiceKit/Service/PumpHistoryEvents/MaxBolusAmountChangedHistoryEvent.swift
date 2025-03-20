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

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var oldAmount: Double {
        Data(auxData[auxData.startIndex...].to(SFLOAT.self)).sfloatToDouble()
    }

    var newAmount: Double {
        Data(auxData[auxData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension MaxBolusAmountChangedHistoryEvent {
    public var description: String {
        "MaxBolusAmountChangedHistoryEvent oldAmount: \(oldAmount), newAmount: \(newAmount), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
