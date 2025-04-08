//
//  PrimingHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct PrimingStartedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .primingStarted

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var programmedAmount: Double {
        Data(eventData[eventData.startIndex...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension PrimingStartedHistoryEvent {
    public var description: String {
        "PrimingStartedHistoryEvent programmedAmount: \(programmedAmount), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}

public struct PrimingDoneHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .primingDone

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var flag: PrimingDoneFlag {
        PrimingDoneFlag(rawValue: eventData[eventData.startIndex...].to(PrimingDoneFlag.RawValue.self))
    }

    var deliveredAmount: Double {
        Data(eventData[eventData.startIndex.advanced(by: 1)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var terminationReason: PrimingTerminationReason {
        PrimingTerminationReason(rawValue: eventData[eventData.startIndex.advanced(by: 3)...].to(PrimingTerminationReason.RawValue.self)) ?? .undetermined
    }
}

extension PrimingDoneHistoryEvent {
    public var description: String {
        "PrimingDoneHistoryEvent deliveredAmount: \(deliveredAmount), terminationReason: \(terminationReason), flag: \(flag), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}

//MARK: - Enumerations

struct PrimingDoneFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8

    static let annunciationIDPresent = PrimingDoneFlag(rawValue: 1 << 0)
    static let allZeros = PrimingDoneFlag([])

    static let debugDescriptions: [PrimingDoneFlag:String] = {
        var descriptions = [PrimingDoneFlag:String]()
        descriptions[.annunciationIDPresent] = "annunciationIDPresent"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in PrimingDoneFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "\(result)"
    }
}

public enum PrimingTerminationReason: UInt8, CustomStringConvertible {
    case undetermined = 0x0f
    case abortedByUser = 0x33
    case programmedAmountReached = 0x3c
    case errorAbort = 0x55
    
    public var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .abortedByUser: return "abortedByUser"
        case .programmedAmountReached: return "programmedAmountReached"
        case .errorAbort: return "errorAbort"
        }
    }
}
