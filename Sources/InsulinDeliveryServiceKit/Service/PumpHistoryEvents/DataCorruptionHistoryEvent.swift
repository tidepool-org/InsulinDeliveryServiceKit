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

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }
    
    public var description: String {
        return "DataCorruptionHistoryEvent recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}

public struct PointerHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .pointerEvent

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }
    
    public var description: String {
        return "PointerHistoryEvent recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}

// can be used when the history event is not known (likely manufacturer specific)
public struct GenericHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .generic

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }
    
    public var description: String {
        return "GenericHistoryEvent recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}
