//
//  TotalDailyInsulinDeliveryHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct TotalDailyInsulinDeliveryHistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .totalDailyInsulinDelivery

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var flags: TotalDailyInsulinDeliveryFlag {
        TotalDailyInsulinDeliveryFlag(rawValue: auxData[auxData.startIndex...].to(TotalDailyInsulinDeliveryFlag.RawValue.self))
    }

    var totalBolusDelivered: Double {
        Data(auxData[auxData.startIndex.advanced(by: 1)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var totalBasalDelivered: Double {
        Data(auxData[auxData.startIndex.advanced(by: 3)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var forDate: Date? {
        let year = Int(auxData[auxData.startIndex.advanced(by: 5)...].to(UInt16.self))
        let month = Int(auxData[auxData.startIndex.advanced(by: 7)...].to(UInt8.self))
        let day = Int(auxData[auxData.startIndex.advanced(by: 8)...].to(UInt8.self))
        let dateComponents = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: dateComponents)
    }
}

extension TotalDailyInsulinDeliveryHistoryEvent {
    var description: String {
        "TotalDailyInsulinDeliveryHistoryEvent totalBolusDelivered: \(totalBolusDelivered), totalBasalDelivered: \(totalBasalDelivered), forDate: \(String(describing: forDate)), flags: \(flags), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

//MARK: - Enumerations

struct TotalDailyInsulinDeliveryFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8

    static let dateTimeChangedWarning = TotalDailyInsulinDeliveryFlag(rawValue: 1 << 0)
    static let allZeros = TotalDailyInsulinDeliveryFlag([])

    static let debugDescriptions: [TotalDailyInsulinDeliveryFlag:String] = {
        var descriptions = [TotalDailyInsulinDeliveryFlag:String]()
        descriptions[.dateTimeChangedWarning] = "dateTimeChangedWarning"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in TotalDailyInsulinDeliveryFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "\(result)"
    }
}
