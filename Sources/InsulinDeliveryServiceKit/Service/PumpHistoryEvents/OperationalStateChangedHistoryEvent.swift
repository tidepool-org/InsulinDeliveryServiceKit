//
//  OperationalStateChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public struct OperationalStateChangedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .operationalStateChanged

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var oldState: PumpOperationalState {
        PumpOperationalState(rawValue: eventData[eventData.startIndex...].to(PumpOperationalState.RawValue.self)) ?? .undetermined
    }

    var newState: PumpOperationalState {
        PumpOperationalState(rawValue: eventData[eventData.startIndex.advanced(by: 1)...].to(PumpOperationalState.RawValue.self)) ?? .undetermined
    }
}

extension OperationalStateChangedHistoryEvent {
    public var description: String {
        "OperationalStateChangedHistoryEvent oldState: \(oldState), newState: \(newState), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}
