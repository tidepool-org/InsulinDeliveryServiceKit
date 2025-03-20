//
//  ReservoirRemainingAmountChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct ReservoirRemainingAmountChangedHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .reservoirRemainingAmountChanged

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var remainingAmount: Double {
        Data(auxData[auxData.startIndex...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension ReservoirRemainingAmountChangedHistoryEvent {
    var description: String {
        "ReservoirRemainingAmountChangedHistoryEvent remainingAmount: \(remainingAmount), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
