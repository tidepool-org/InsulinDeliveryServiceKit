//
//  BolusDeliveredHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct BolusDeliveredHistoryEvent {
    let part1: BolusDeliveredPart1HistoryEvent

    let part2: BolusDeliveredPart2HistoryEvent

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

    var flags: BolusDeliveredFlag { part2.flags }

    var startTimeOffset: TimeInterval { part2.startTimeOffset }

    var endReason: BolusEndReason { part2.endReason }

    var progressState: BolusProgressState {
        endReason == .programmedAmountDelivered ? .completed : .canceled
    }

    init?(part1: BolusDeliveredPart1HistoryEvent, part2: BolusDeliveredPart2HistoryEvent) {
        guard part1.relativeOffset == part2.relativeOffset else { return nil }
        self.part1 = part1
        self.part2 = part2
    }
}

struct BolusDeliveredPart1HistoryEvent: PumpHistoryEvent {

    let type: IDHistoryEventType = .bolusDeliveredPart1

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

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

extension BolusDeliveredPart1HistoryEvent {
    var description: String {
        "BolusDeliveredPart1HistoryEvent bolusID: \(bolusID), bolusType: \(bolusType), fastAmount: \(fastAmount), extendedAmount: \(extendedAmount), duration: \(duration), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

struct BolusDeliveredPart2HistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .bolusDeliveredPart2

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var flags: BolusDeliveredFlag {
        BolusDeliveredFlag(rawValue: auxData[auxData.startIndex...].to(UInt8.self))
    }

    var startTimeOffset: TimeInterval {
        .seconds(Int(auxData[auxData.startIndex.advanced(by: 1)...].to(UInt32.self)))
    }

    var endReason: BolusEndReason {
        BolusEndReason(rawValue: auxData[auxData.startIndex.advanced(by: 5)...].to(BolusEndReason.RawValue.self)) ?? .undetermined
    }
}

extension BolusDeliveredPart2HistoryEvent {
    var description: String {
        "BolusDeliveredPart2HistoryEvent startTimeOffset: \(startTimeOffset), endReason: \(endReason), flags: \(flags), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

//MARK: - Enumerations

struct BolusDeliveredFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8

    static let activationTypePresent = BolusDeliveredFlag(rawValue: 1 << 0)
    static let endReasonPresent = BolusDeliveredFlag(rawValue: 1 << 1)
    static let annunciationIDPresent  = BolusDeliveredFlag(rawValue: 1 << 2)
    static let allZeros = BolusDeliveredFlag([])

    static let debugDescriptions: [BolusDeliveredFlag:String] = {
        var descriptions = [BolusDeliveredFlag:String]()
        descriptions[.activationTypePresent] = "activationTypePresent"
        descriptions[.endReasonPresent] = "endReasonPresent"
        descriptions[.annunciationIDPresent] = "annunciationIDPresent"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in BolusDeliveredFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "\(result)"
    }
}

enum BolusEndReason: UInt8, CustomStringConvertible {
    case undetermined = 0x0f
    case programmedAmountDelivered = 0x33
    case canceled = 0x3c
    case errorAbort = 0x55
    
    var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .programmedAmountDelivered: return "programmedAmountDelivered"
        case .canceled: return "canceled"
        case .errorAbort: return "errorAbort"
        }
    }
}
