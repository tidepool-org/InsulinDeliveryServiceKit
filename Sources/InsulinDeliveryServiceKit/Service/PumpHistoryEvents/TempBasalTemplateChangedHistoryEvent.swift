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

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var templateNumber: Int {
        Int(eventData[eventData.startIndex...].to(UInt8.self))
    }

    var tempBasalType: TempBasalType {
        TempBasalType(rawValue: eventData[eventData.startIndex.advanced(by: 1)...].to(TempBasalType.RawValue.self)) ?? .undetermined
    }

    var adjustmentValue: Double {
        Data(eventData[eventData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var duration: TimeInterval {
        .minutes(Int(eventData[eventData.startIndex.advanced(by: 4)...].to(UInt16.self)))
    }
}

extension TempBasalTemplateChangedHistoryEvent {
    public var description: String {
        "TempBasalTemplateChangedHistoryEvent templateNumber: \(templateNumber), tempBasalType: \(tempBasalType), adjustmentValue: \(adjustmentValue), duration: \(duration), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}
