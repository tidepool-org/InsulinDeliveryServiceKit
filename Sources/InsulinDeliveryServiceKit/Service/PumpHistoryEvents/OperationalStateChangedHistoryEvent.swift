//
//  OperationalStateChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

struct OperationalStateChangedHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .operationalStateChanged

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var oldState: PumpOperationalState {
        PumpOperationalState(rawValue: auxData[auxData.startIndex...].to(PumpOperationalState.RawValue.self)) ?? .undetermined
    }

    var newState: PumpOperationalState {
        PumpOperationalState(rawValue: auxData[auxData.startIndex.advanced(by: 1)...].to(PumpOperationalState.RawValue.self)) ?? .undetermined
    }
}

extension OperationalStateChangedHistoryEvent {
    var description: String {
        "OperationalStateChangedHistoryEvent oldState: \(oldState), newState: \(newState), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
