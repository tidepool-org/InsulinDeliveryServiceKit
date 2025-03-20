//
//  DataCorruptionHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public struct DataCorruptionHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .dataCorruption

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }
    
    public var description: String {
        return "DataCorruptionHistoryEvent sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

public struct PointerHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .pointerEvent

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }
    
    public var description: String {
        return "PointerHistoryEvent sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

// can be used when the history event is not known (likely manufacturer specific)
public struct GenericHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .generic

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }
    
    public var description: String {
        return "GenericHistoryEvent sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
