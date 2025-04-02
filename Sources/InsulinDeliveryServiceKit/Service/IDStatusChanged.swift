//
//  IDStatusChanged.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//
//
//  This is based on version 1.0 of the Insulin Delivery Service: https://www.bluetooth.com/specifications/specs/insulin-delivery-service-1-0/

import Foundation
import BluetoothCommonKit
import os.log

private let log = OSLog(category: "IDStatusChanged")

struct IDStatusChanged {
    static func handleData(_ data: Data) -> DeviceCommResult<IDStatusChangedFlag> {
        guard data.count == 5 else {
            log.error("status changed charactersitic is an unexpected size: (expect 5, actual, %d", data.count)
            return .failure(.invalidFormat)
        }

        guard data.isCRCValid else {
            log.error("status changed characteristic CRC is invalid")
            return .failure(.invalidCRC)
        }

        let flags = IDStatusChangedFlag(rawValue: data[data.startIndex.advanced(by: 0)...].to(UInt16.self))
        log.debug("%{public}@ %{public}@", #function, String(describing: flags))

        return .success(flags)
    }
}

extension PeripheralManager {
    func readInsulinDeliveryChangedStatus(timeout: TimeInterval) throws -> DeviceCommResult<IDStatusChangedFlag>  {
        guard let characteristic = peripheral?.getInsulinDeliveryCharacteristicWithUUID(.statusChanged) else {
            throw PeripheralManagerError.unknownCharacteristic
        }

        do {
            guard let characteristicData = try readValue(for: characteristic, timeout: timeout) else {
                throw PeripheralManagerError.timeout
            }

            return IDStatusChanged.handleData(characteristicData)
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
}

//MARK: - Option sets
public struct IDStatusChangedFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    static public let therapyControlStateChanged  = IDStatusChangedFlag(rawValue: 1 << 0)
    static public let operationalStateChanged  = IDStatusChangedFlag(rawValue: 1 << 1)
    static public let reservoirStatusChanged  = IDStatusChangedFlag(rawValue: 1 << 2)
    static public let annunciationStatusChanged  = IDStatusChangedFlag(rawValue: 1 << 3)
    static public let totalDailyInsulinStatusChanged  = IDStatusChangedFlag(rawValue: 1 << 4)
    static public let activeBasalRateStatusChanged  = IDStatusChangedFlag(rawValue: 1 << 5)
    static public let activeBolusStatusChanged  = IDStatusChangedFlag(rawValue: 1 << 6)
    static public let historyEventRecordedChanged  = IDStatusChangedFlag(rawValue: 1 << 7)
    static public let allZeros = IDStatusChangedFlag([])
    static public let allFlags = IDStatusChangedFlag([.therapyControlStateChanged, .operationalStateChanged, .reservoirStatusChanged, .annunciationStatusChanged, .totalDailyInsulinStatusChanged, .activeBasalRateStatusChanged, .activeBolusStatusChanged, .historyEventRecordedChanged])

    static let debugDescriptions: [IDStatusChangedFlag: String] = {
        var descriptions = [IDStatusChangedFlag: String]()
        descriptions[.therapyControlStateChanged] = "therapyControlStateChanged"
        descriptions[.operationalStateChanged] = "operationalStateChanged"
        descriptions[.reservoirStatusChanged] = "reservoirStatusChanged"
        descriptions[.annunciationStatusChanged] = "annunciationStatusChanged"
        descriptions[.totalDailyInsulinStatusChanged] = "totalDailyInsulinStatusChanged"
        descriptions[.activeBasalRateStatusChanged] = "activeBasalRateStatusChanged"
        descriptions[.activeBolusStatusChanged] = "activeBolusStatusChanged"
        descriptions[.historyEventRecordedChanged] = "historyEventRecordedChanged"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in IDStatusChangedFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "IDStatusChangedFlag(rawValue: \(rawValue)) \(result)"
    }
}
