//
//  PumpHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public protocol PumpHistoryEvent: CustomStringConvertible {

    /// type of the history event
    var type: IDHistoryEventType { get }

    /// pump unique identifier for each event
    var sequenceNumber: HistoryEventSequenceNumber { get }

    /// seconds since the last reference time event
    var relativeOffset: TimeInterval { get }

    /// data specific to the event type
    var auxData: Data { get }

    init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data)
}

extension PumpHistoryEvent {
    var description: String {
        "type: \(type), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

struct StorablePumpHistoryEvent: PumpHistoryEvent, Equatable, Codable {

    let type: IDHistoryEventType

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.type = .generic
        self.relativeOffset = relativeOffset
        self.sequenceNumber = sequenceNumber
        self.auxData = auxData
    }

    init?(pumpHistoryEvent: PumpHistoryEvent?) {
        guard let pumpHistoryEvent = pumpHistoryEvent else { return nil }
        self.type = pumpHistoryEvent.type
        self.sequenceNumber = pumpHistoryEvent.sequenceNumber
        self.relativeOffset = pumpHistoryEvent.relativeOffset
        self.auxData = pumpHistoryEvent.auxData
    }
}
