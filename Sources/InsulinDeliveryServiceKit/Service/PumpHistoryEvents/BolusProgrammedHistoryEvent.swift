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

    var sequenceNumbers: [HistoryEventSequenceNumber] {
        [part1.sequenceNumber, part2.sequenceNumber]
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

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var bolusID: BolusID {
        auxData[auxData.startIndex...].to(BolusID.self)
    }

    var bolusType: BolusType {
        BolusType(rawValue: auxData[auxData.startIndex.advanced(by: 2)...].to(BolusType.RawValue.self)) ?? .undetermined
    }

    var fastAmount: Double {
        Data(auxData[auxData.startIndex.advanced(by: 3)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var extendedAmount: Double {
        Data(auxData[auxData.startIndex.advanced(by: 5)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var duration: TimeInterval {
        .minutes(Int(auxData[auxData.startIndex.advanced(by: 7)...].to(UInt16.self)))
    }
}

extension BolusProgrammedPart1HistoryEvent {
    public var description: String {
        "BolusProgrammedPart1HistoryEvent bolusID: \(bolusID), bolusType: \(bolusType), fastAmount: \(fastAmount), extendedAmount: \(extendedAmount), duration: \(duration), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

public struct BolusProgrammedPart2HistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .bolusProgrammedPart2

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var flags: BolusFlag {
        BolusFlag(rawValue: auxData[auxData.startIndex...].to(UInt8.self))
    }

    var delayTime: TimeInterval {
        .minutes(Int(auxData[auxData.startIndex.advanced(by: 1)...].to(UInt16.self)))
    }
}

extension BolusProgrammedPart2HistoryEvent {
    public var description: String {
        "BolusProgrammedPart2HistoryEvent delayTime: \(delayTime), flags: \(flags), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
