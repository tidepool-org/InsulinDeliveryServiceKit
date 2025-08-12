//
//  TotalDailyInsulinDeliveryHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct TotalDailyInsulinDeliveryHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .totalDailyInsulinDelivery

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var flags: TotalDailyInsulinDeliveryFlag {
        TotalDailyInsulinDeliveryFlag(rawValue: eventData[eventData.startIndex...].to(TotalDailyInsulinDeliveryFlag.RawValue.self))
    }

    var totalBolusDelivered: Double {
        Data(eventData[eventData.startIndex.advanced(by: 1)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var totalBasalDelivered: Double {
        Data(eventData[eventData.startIndex.advanced(by: 3)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var forDate: Date? {
        let year = Int(eventData[eventData.startIndex.advanced(by: 5)...].to(UInt16.self))
        let month = Int(eventData[eventData.startIndex.advanced(by: 7)...].to(UInt8.self))
        let day = Int(eventData[eventData.startIndex.advanced(by: 8)...].to(UInt8.self))
        let dateComponents = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: dateComponents)
    }
}

extension TotalDailyInsulinDeliveryHistoryEvent {
    public var description: String {
        "TotalDailyInsulinDeliveryHistoryEvent totalBolusDelivered: \(totalBolusDelivered), totalBasalDelivered: \(totalBasalDelivered), forDate: \(String(describing: forDate)), flags: \(flags), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
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
