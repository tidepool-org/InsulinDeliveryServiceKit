//
//  MaxBolusAmountChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct MaxBolusAmountChangedHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .maxBolusAmountChanged

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var oldAmount: Double {
        Data(auxData[auxData.startIndex...].to(SFLOAT.self)).sfloatToDouble()
    }

    var newAmount: Double {
        Data(auxData[auxData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension MaxBolusAmountChangedHistoryEvent {
    var description: String {
        "MaxBolusAmountChangedHistoryEvent oldAmount: \(oldAmount), newAmount: \(newAmount), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
