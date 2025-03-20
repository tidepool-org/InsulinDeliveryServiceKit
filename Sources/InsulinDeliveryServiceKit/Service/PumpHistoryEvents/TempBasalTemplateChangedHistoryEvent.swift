//
//  TempBasalTemplateChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct TempBasalTemplateChangedHistoryEvent: PumpHistoryEvent {

    let type: IDHistoryEventType = .tempBasalRateTemplateChanged

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var templateNumber: Int {
        Int(auxData[auxData.startIndex...].to(UInt8.self))
    }

    var tempBasalType: TempBasalType {
        TempBasalType(rawValue: auxData[auxData.startIndex.advanced(by: 1)...].to(TempBasalType.RawValue.self)) ?? .undetermined
    }

    var adjustmentValue: Double {
        Data(auxData[auxData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var duration: TimeInterval {
        .minutes(Int(auxData[auxData.startIndex.advanced(by: 4)...].to(UInt16.self)))
    }
}

extension TempBasalTemplateChangedHistoryEvent {
    var description: String {
        "TempBasalTemplateChangedHistoryEvent templateNumber: \(templateNumber), tempBasalType: \(tempBasalType), adjustmentValue: \(adjustmentValue), duration: \(duration), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
