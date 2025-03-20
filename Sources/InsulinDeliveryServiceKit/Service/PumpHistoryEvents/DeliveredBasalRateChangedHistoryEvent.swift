//
//  DeliveredBasalRateChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct DeliveredBasalRateChangedHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .deliveredBasalRateChanged

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

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
    var description: String {
        "DeliveredBasalRateChangedHistoryEvent oldRate: \(oldRate), newRate: \(newRate), flag: \(flag), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

//MARK: - Enumerations

struct DeliveredBasalRateChangedFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8

    static let deliveryContentPresent = DeliveredBasalRateChangedFlag(rawValue: 1 << 0)
    static let allZeros = DeliveredBasalRateChangedFlag([])

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
