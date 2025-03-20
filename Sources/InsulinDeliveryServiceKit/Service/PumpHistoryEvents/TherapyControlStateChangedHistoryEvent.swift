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

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var oldState: InsulinTherapyControlState {
        InsulinTherapyControlState(rawValue:  auxData[auxData.startIndex...].to(InsulinTherapyControlState.RawValue.self)) ?? .undetermined
    }

    var newState: InsulinTherapyControlState {
        InsulinTherapyControlState(rawValue:  auxData[auxData.startIndex.advanced(by: 1)...].to(InsulinTherapyControlState.RawValue.self)) ?? .undetermined
    }
}

extension TherapyControlStateChangedHistoryEvent {
    public var description: String {
        "TherapyControlStateChangedHistoryEvent oldState: \(oldState), newState: \(newState), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
