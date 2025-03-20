//
//  ISFProfileTemplateTimeBlockChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct ISFProfileTemplateTimeBlockChangedHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .isfProfileTemplateTimeBlockChanged

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var templateNumber: Int {
        Int(auxData[auxData.startIndex...].to(UInt8.self))
    }

    var timeBlockNumber: Int {
        Int(auxData[auxData.startIndex.advanced(by: 1)...].to(UInt8.self))
    }

    var duration: TimeInterval {
        .minutes(Int(auxData[auxData.startIndex.advanced(by: 2)...].to(UInt16.self)))
    }

    var isf: Double {
        Data(auxData[auxData.startIndex.advanced(by: 4)...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension ISFProfileTemplateTimeBlockChangedHistoryEvent {
    var description: String {
        "ISFProfileTemplateTimeBlockChangedHistoryEvent templateNumber: \(templateNumber), timeBlockNumber: \(timeBlockNumber), duration: \(duration), ISF: \(isf), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
