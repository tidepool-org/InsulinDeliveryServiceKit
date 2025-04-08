//
//  BolusProgrammedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct BolusProgrammedHistoryEvent {
    let part1: BolusProgrammedPart1HistoryEvent

    let part2: BolusProgrammedPart2HistoryEvent

    var recordNumbers: [RecordNumber] {
        [part1.recordNumber, part2.recordNumber]
    }

    var relativeOffset: TimeInterval {
        // the relative offset is the same for part 1 and part 2
        part1.relativeOffset
    }

    var bolusID: BolusID { part1.bolusID }

    var bolusType: BolusType { part1.bolusType }

    var fastAmount: Double { part1.fastAmount }

    var extendedAmount: Double { part1.extendedAmount }

    var duration: TimeInterval { part1.duration }

    var flags: BolusFlag { part2.flags }

    var delayTime: TimeInterval { part2.delayTime }

    init?(part1: BolusProgrammedPart1HistoryEvent, part2: BolusProgrammedPart2HistoryEvent) {
        guard part1.relativeOffset == part2.relativeOffset else { return nil }
        self.part1 = part1
        self.part2 = part2
    }
}

public struct BolusProgrammedPart1HistoryEvent: PumpHistoryEvent {

    public let type: IDHistoryEventType = .bolusProgrammedPart1

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var bolusID: BolusID {
        eventData[eventData.startIndex...].to(BolusID.self)
    }

    var bolusType: BolusType {
        BolusType(rawValue: eventData[eventData.startIndex.advanced(by: 2)...].to(BolusType.RawValue.self)) ?? .undetermined
    }

    var fastAmount: Double {
        Data(eventData[eventData.startIndex.advanced(by: 3)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var extendedAmount: Double {
        Data(eventData[eventData.startIndex.advanced(by: 5)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var duration: TimeInterval {
        .minutes(Int(eventData[eventData.startIndex.advanced(by: 7)...].to(UInt16.self)))
    }
}

extension BolusProgrammedPart1HistoryEvent {
    public var description: String {
        "BolusProgrammedPart1HistoryEvent bolusID: \(bolusID), bolusType: \(bolusType), fastAmount: \(fastAmount), extendedAmount: \(extendedAmount), duration: \(duration), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}

public struct BolusProgrammedPart2HistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .bolusProgrammedPart2

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var flags: BolusFlag {
        BolusFlag(rawValue: eventData[eventData.startIndex...].to(UInt8.self))
    }

    var delayTime: TimeInterval {
        .minutes(Int(eventData[eventData.startIndex.advanced(by: 1)...].to(UInt16.self)))
    }
}

extension BolusProgrammedPart2HistoryEvent {
    public var description: String {
        "BolusProgrammedPart2HistoryEvent delayTime: \(delayTime), flags: \(flags), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}
