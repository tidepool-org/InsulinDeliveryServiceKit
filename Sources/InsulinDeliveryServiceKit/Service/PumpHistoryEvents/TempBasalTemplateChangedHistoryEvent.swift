//
//  TempBasalTemplateChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct TempBasalTemplateChangedHistoryEvent: PumpHistoryEvent {

    public let type: IDHistoryEventType = .tempBasalRateTemplateChanged

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
    public var description: String {
        "TempBasalTemplateChangedHistoryEvent templateNumber: \(templateNumber), tempBasalType: \(tempBasalType), adjustmentValue: \(adjustmentValue), duration: \(duration), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
