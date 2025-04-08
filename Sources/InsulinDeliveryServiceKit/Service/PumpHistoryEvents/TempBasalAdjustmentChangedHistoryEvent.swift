//
//  TempBasalAdjustmentChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct TempBasalAdjustmentChangedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .tempBasalRateAdjustmentChanged

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var flags: TempBasalFlag {
        TempBasalFlag(rawValue: eventData[eventData.startIndex...].to(TempBasalFlag.RawValue.self))
    }

    var tempBasalType: TempBasalType {
        TempBasalType(rawValue: eventData[eventData.startIndex.advanced(by: 1)...].to(TempBasalType.RawValue.self)) ?? .undetermined
    }

    var rate: Double {
        Data(eventData[eventData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var programmedDuration: TimeInterval {
        .minutes(Int(eventData[eventData.startIndex.advanced(by: 4)...].to(UInt16.self)))
    }

    var elapsedDuration: TimeInterval {
        .minutes(Int(eventData[eventData.startIndex.advanced(by: 6)...].to(UInt16.self)))
    }
}

extension TempBasalAdjustmentChangedHistoryEvent {
    public var description: String {
        "TempBasalAdjustmentChangedHistoryEvent rate: \(rate), programmedDuration: \(programmedDuration), elapsedDuration: \(elapsedDuration), tempBasalType: \(tempBasalType), flags: \(flags), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}

public struct TempBasalAdjustmentEndedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .tempBasalRateAdjustmentEnded

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var flags: TempBasalEndedFlag {
        TempBasalEndedFlag(rawValue: eventData[eventData.startIndex...].to(TempBasalEndedFlag.RawValue.self))
    }

    var lastSetType: TempBasalType {
        TempBasalType(rawValue: eventData[eventData.startIndex.advanced(by: 1)...].to(TempBasalType.RawValue.self)) ?? .undetermined
    }

    var effectiveDuration: TimeInterval {
        .minutes(Int(eventData[eventData.startIndex.advanced(by: 2)...].to(UInt16.self)))
    }

    var endReason: TempBasalEndReason {
        TempBasalEndReason(rawValue: eventData[eventData.startIndex.advanced(by: 4)...].to(TempBasalEndReason.RawValue.self)) ?? .undetermined
    }
}

extension TempBasalAdjustmentEndedHistoryEvent {
    public var description: String {
        "TempBasalAdjustmentEndedHistoryEvent effectiveDuration: \(effectiveDuration), endReason: \(endReason), lastSetType: \(lastSetType), flags: \(flags), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}

public struct TempBasalAdjustmentStartedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .tempBasalRateAdjustmentStarted

    public var recordNumber: RecordNumber

    public var relativeOffset: TimeInterval

    public var eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var flags: TempBasalFlag {
        TempBasalFlag(rawValue: eventData[eventData.startIndex...].to(TempBasalFlag.RawValue.self))
    }

    var tempBasalType: TempBasalType {
        TempBasalType(rawValue: eventData[eventData.startIndex.advanced(by: 1)...].to(TempBasalType.RawValue.self)) ?? .undetermined
    }

    var rate: Double {
        Data(eventData[eventData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var programmedDuration: TimeInterval {
        .minutes(Int(eventData[eventData.startIndex.advanced(by: 4)...].to(UInt16.self)))
    }
}

extension TempBasalAdjustmentStartedHistoryEvent {
    public var description: String {
        "TempBasalAdjustmentStartedHistoryEvent rate: \(rate), programmedDuration: \(programmedDuration), tempBasalType: \(tempBasalType), flags: \(flags), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}

//MARK: - Enumerations

struct TempBasalEndedFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8

    static let lastSetTemplateNumberPresent = TempBasalEndedFlag(rawValue: 1 << 0)
    static let annunciationIDPresent = TempBasalEndedFlag(rawValue: 1 << 1)
    static let allZeros = TempBasalEndedFlag([])

    static let debugDescriptions: [TempBasalEndedFlag:String] = {
        var descriptions = [TempBasalEndedFlag:String]()
        descriptions[.lastSetTemplateNumberPresent] = "lastSetTemplateNumberPresent"
        descriptions[.annunciationIDPresent] = "annunciationIDPresent"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in TempBasalEndedFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "\(result)"
    }
}

public enum TempBasalEndReason: UInt8, CustomStringConvertible {
    case undetermined = 0x0f
    case programmedDurationOver = 0x33
    case canceled = 0x3c
    case errorAbort = 0x55
    
    public var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .programmedDurationOver: return "programmedDurationOver"
        case .canceled: return "canceled"
        case .errorAbort: return "errorAbort"
        }
    }
}
