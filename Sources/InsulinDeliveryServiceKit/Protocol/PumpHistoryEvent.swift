//
//  PumpHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public protocol PumpHistoryEvent: CustomStringConvertible {

    /// type of the history event
    var type: IDHistoryEventType { get }

    /// pump unique identifier for each event
    var recordNumber: RecordNumber { get }

    /// seconds since the last reference time event
    var relativeOffset: TimeInterval { get }

    /// data specific to the event type
    var eventData: Data { get }

    init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data)
}

extension PumpHistoryEvent {
    public var description: String {
        "type: \(type), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), auxData: \(eventData.hexadecimalString)"
    }
    
    var data: Data {
        var data = Data(type.rawValue)
        data.append(recordNumber)
        data.append(UInt16(relativeOffset.seconds))
        data.append(eventData)
        return data
    }
}

/// A history event in a form a host can encode; the pump's persisted history is a list of these.
public struct StorablePumpHistoryEvent: PumpHistoryEvent, Equatable, Codable {

    public let type: IDHistoryEventType

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data

    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.type = .generic
        self.relativeOffset = relativeOffset
        self.recordNumber = recordNumber
        self.eventData = eventData
    }

    public init?(pumpHistoryEvent: PumpHistoryEvent?) {
        guard let pumpHistoryEvent = pumpHistoryEvent else { return nil }
        self.type = pumpHistoryEvent.type
        self.recordNumber = pumpHistoryEvent.recordNumber
        self.relativeOffset = pumpHistoryEvent.relativeOffset
        self.eventData = pumpHistoryEvent.eventData
    }
}
