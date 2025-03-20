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

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var oldState: PumpOperationalState {
        PumpOperationalState(rawValue: auxData[auxData.startIndex...].to(PumpOperationalState.RawValue.self)) ?? .undetermined
    }

    var newState: PumpOperationalState {
        PumpOperationalState(rawValue: auxData[auxData.startIndex.advanced(by: 1)...].to(PumpOperationalState.RawValue.self)) ?? .undetermined
    }
}

extension OperationalStateChangedHistoryEvent {
    public var description: String {
        "OperationalStateChangedHistoryEvent oldState: \(oldState), newState: \(newState), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
