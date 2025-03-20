//
//  DataCorruptionHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

struct DataCorruptionHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .dataCorruption

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data
}

struct PointerHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .pointerEvent

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data
}

// can be used when the history event is not known (likely manufacturer specific)
struct GenericHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .generic

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data
}
