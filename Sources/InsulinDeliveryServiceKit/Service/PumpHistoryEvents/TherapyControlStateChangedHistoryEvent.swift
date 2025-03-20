//
//  TherapyControlStateChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

struct TherapyControlStateChangedHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .therapyControlStateChanged

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var oldState: InsulinTherapyControlState {
        InsulinTherapyControlState(rawValue:  auxData[auxData.startIndex...].to(InsulinTherapyControlState.RawValue.self)) ?? .undetermined
    }

    var newState: InsulinTherapyControlState {
        InsulinTherapyControlState(rawValue:  auxData[auxData.startIndex.advanced(by: 1)...].to(InsulinTherapyControlState.RawValue.self)) ?? .undetermined
    }
}

extension TherapyControlStateChangedHistoryEvent {
    var description: String {
        "TherapyControlStateChangedHistoryEvent oldState: \(oldState), newState: \(newState), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
