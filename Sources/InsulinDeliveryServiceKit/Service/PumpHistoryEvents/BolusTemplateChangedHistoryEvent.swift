//
//  BolusTemplateChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct BolusTemplateChangedHistoryEvent {
    let part1: BolusTemplateChangedPart1HistoryEvent

    let part2: BolusTemplateChangedPart2HistoryEvent

    var sequenceNumbers: [HistoryEventSequenceNumber] {
        [part1.sequenceNumber, part2.sequenceNumber]
    }

    var relativeOffset: TimeInterval {
        // the relative offset is the same for part 1 and part 2
        part1.relativeOffset
    }

    var templateNumber: Int { part1.templateNumber }

    var bolusType: BolusType { part1.bolusType }

    var fastAmount: Double { part1.fastAmount }

    var extendedAmount: Double { part1.extendedAmount }

    var duration: TimeInterval { part1.duration }

    var flags: BolusTemplateFlag { part2.flags }

    var delayTime: TimeInterval? { part2.delayTime }

    init?(part1: BolusTemplateChangedPart1HistoryEvent, part2: BolusTemplateChangedPart2HistoryEvent) {
        guard part1.relativeOffset == part2.relativeOffset else { return nil }
        self.part1 = part1
        self.part2 = part2
    }
}

public struct BolusTemplateChangedPart1HistoryEvent: PumpHistoryEvent {

    public let type: IDHistoryEventType = .bolusTemplateChangedPart1

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var templateNumber: Int {
        Int(auxData[auxData.startIndex...].to(UInt8.self))
    }

    var bolusType: BolusType {
        BolusType(rawValue: auxData[auxData.startIndex.advanced(by: 1)...].to(BolusType.RawValue.self)) ?? .undetermined
    }

    var fastAmount: Double {
        Data(auxData[auxData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var extendedAmount: Double {
        Data(auxData[auxData.startIndex.advanced(by: 4)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var duration: TimeInterval {
        .minutes(Int(auxData[auxData.startIndex.advanced(by: 6)...].to(UInt16.self)))
    }
}

extension BolusTemplateChangedPart1HistoryEvent {
    public var description: String {
        "BolusTemplateChangedPart1HistoryEvent templateNumber: \(templateNumber), bolusType: \(bolusType), fastAmount: \(fastAmount), extendedAmount: \(extendedAmount), duration: \(duration), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

public struct BolusTemplateChangedPart2HistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .bolusTemplateChangedPart2

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var flags: BolusTemplateFlag {
        BolusTemplateFlag(rawValue: auxData[auxData.startIndex...].to(BolusTemplateFlag.RawValue.self))
    }

    var delayTime: TimeInterval? {
        guard flags.contains(.delayTimePresent) else {
            return nil
        }
        return TimeInterval.minutes(Int(auxData[auxData.startIndex.advanced(by: 1)...].to(UInt16.self)))
    }
}

extension BolusTemplateChangedPart2HistoryEvent {
    public var description: String {
        "BolusTemplateChangedPart2HistoryEvent flags: \(flags), delayTime: \(String(describing: delayTime)), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

//MARK: - Option set

struct BolusTemplateFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8

    static let delayTimePresent = BolusTemplateFlag(rawValue: 1 << 0)
    static let deliveryReasonCorrection = BolusTemplateFlag(rawValue: 1 << 1)
    static let deliveryReasonMeal  = BolusTemplateFlag(rawValue: 1 << 2)
    static let allZeros = BolusTemplateFlag([])

    static let debugDescriptions: [BolusTemplateFlag:String] = {
        var descriptions = [BolusTemplateFlag:String]()
        descriptions[.delayTimePresent] = "delayTimePresent"
        descriptions[.deliveryReasonCorrection] = "deliveryReasonCorrection"
        descriptions[.deliveryReasonMeal] = "deliveryReasonMeal"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in BolusTemplateFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "\(result)"
    }
}
