//
//  TherapyControlStateChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public struct TherapyControlStateChangedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .therapyControlStateChanged

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var oldState: InsulinTherapyControlState {
        InsulinTherapyControlState(rawValue:  eventData[eventData.startIndex...].to(InsulinTherapyControlState.RawValue.self)) ?? .undetermined
    }

    var newState: InsulinTherapyControlState {
        InsulinTherapyControlState(rawValue:  eventData[eventData.startIndex.advanced(by: 1)...].to(InsulinTherapyControlState.RawValue.self)) ?? .undetermined
    }
}

extension TherapyControlStateChangedHistoryEvent {
    public var description: String {
        "TherapyControlStateChangedHistoryEvent oldState: \(oldState), newState: \(newState), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}
