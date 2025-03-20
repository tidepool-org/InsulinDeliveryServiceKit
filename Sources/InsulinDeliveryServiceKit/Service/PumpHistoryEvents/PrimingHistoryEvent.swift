//
//  PrimingHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct PrimingStartedHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .primingStarted

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var programmedAmount: Double {
        Data(auxData[auxData.startIndex...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension PrimingStartedHistoryEvent {
    var description: String {
        "PrimingStartedHistoryEvent programmedAmount: \(programmedAmount), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

struct PrimingDoneHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .primingDone

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var flag: PrimingDoneFlag {
        PrimingDoneFlag(rawValue: auxData[auxData.startIndex...].to(PrimingDoneFlag.RawValue.self))
    }

    var deliveredAmount: Double {
        Data(auxData[auxData.startIndex.advanced(by: 1)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var terminationReason: PrimingTerminationReason {
        PrimingTerminationReason(rawValue: auxData[auxData.startIndex.advanced(by: 3)...].to(PrimingTerminationReason.RawValue.self)) ?? .undetermined
    }
}

extension PrimingDoneHistoryEvent {
    var description: String {
        "PrimingDoneHistoryEvent deliveredAmount: \(deliveredAmount), terminationReason: \(terminationReason), flag: \(flag), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
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

enum PrimingTerminationReason: UInt8, CustomStringConvertible {
    case undetermined = 0x0f
    case abortedByUser = 0x33
    case programmedAmountReached = 0x3c
    case errorAbort = 0x55
    
    var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .abortedByUser: return "abortedByUser"
        case .programmedAmountReached: return "programmedAmountReached"
        case .errorAbort: return "errorAbort"
        }
    }
}
