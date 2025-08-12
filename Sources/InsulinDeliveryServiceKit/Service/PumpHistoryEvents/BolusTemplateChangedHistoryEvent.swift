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

    var recordNumbers: [RecordNumber] {
        [part1.recordNumber, part2.recordNumber]
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

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var templateNumber: Int {
        Int(eventData[eventData.startIndex...].to(UInt8.self))
    }

    var bolusType: BolusType {
        BolusType(rawValue: eventData[eventData.startIndex.advanced(by: 1)...].to(BolusType.RawValue.self)) ?? .undetermined
    }

    var fastAmount: Double {
        Data(eventData[eventData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var extendedAmount: Double {
        Data(eventData[eventData.startIndex.advanced(by: 4)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var duration: TimeInterval {
        .minutes(Int(eventData[eventData.startIndex.advanced(by: 6)...].to(UInt16.self)))
    }
}

extension BolusTemplateChangedPart1HistoryEvent {
    public var description: String {
        "BolusTemplateChangedPart1HistoryEvent templateNumber: \(templateNumber), bolusType: \(bolusType), fastAmount: \(fastAmount), extendedAmount: \(extendedAmount), duration: \(duration), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}

public struct BolusTemplateChangedPart2HistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .bolusTemplateChangedPart2

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var flags: BolusTemplateFlag {
        BolusTemplateFlag(rawValue: eventData[eventData.startIndex...].to(BolusTemplateFlag.RawValue.self))
    }

    var delayTime: TimeInterval? {
        guard flags.contains(.delayTimePresent) else {
            return nil
        }
        return TimeInterval.minutes(Int(eventData[eventData.startIndex.advanced(by: 1)...].to(UInt16.self)))
    }
}

extension BolusTemplateChangedPart2HistoryEvent {
    public var description: String {
        "BolusTemplateChangedPart2HistoryEvent flags: \(flags), delayTime: \(String(describing: delayTime)), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
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
