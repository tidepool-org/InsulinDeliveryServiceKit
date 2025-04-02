//
//  DeliveredBasalRateChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct DeliveredBasalRateChangedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .deliveredBasalRateChanged

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var flag: DeliveredBasalRateChangedFlag {
        DeliveredBasalRateChangedFlag(rawValue: auxData[auxData.startIndex...].to(DeliveredBasalRateChangedFlag.RawValue.self))
    }

    var oldRate: Double {
        Data(auxData[auxData.startIndex.advanced(by: 1)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var newRate: Double {
        Data(auxData[auxData.startIndex.advanced(by: 3)...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension DeliveredBasalRateChangedHistoryEvent {
    public var description: String {
        "DeliveredBasalRateChangedHistoryEvent oldRate: \(oldRate), newRate: \(newRate), flag: \(flag), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

//MARK: - Enumerations

public struct DeliveredBasalRateChangedFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    static public let deliveryContentPresent = DeliveredBasalRateChangedFlag(rawValue: 1 << 0)
    static public let allZeros = DeliveredBasalRateChangedFlag([])

    static let debugDescriptions: [DeliveredBasalRateChangedFlag:String] = {
        var descriptions = [DeliveredBasalRateChangedFlag:String]()
        descriptions[.deliveryContentPresent] = "deliveryContentPresent"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in DeliveredBasalRateChangedFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "\(result)"
    }
}

// MARK: - Support Server Implementation
extension DeliveredBasalRateChangedHistoryEvent {
    static func createHistoryEvent(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval) -> DeliveredBasalRateChangedHistoryEvent {
        let flag: DeliveredBasalRateChangedFlag = [.deliveryContentPresent]
        let oldRate = 2
        let newRate = 1
        let deliveryContext = BasalDeliveryContext.aidController
        var auxData = Data(flag.rawValue)
        auxData.append(oldRate.sfloat)
        auxData.append(newRate.sfloat)
        auxData.append(deliveryContext.rawValue)
        return DeliveredBasalRateChangedHistoryEvent(
            sequenceNumber: sequenceNumber,
            relativeOffset: relativeOffset,
            auxData: auxData
        )
    }
}
