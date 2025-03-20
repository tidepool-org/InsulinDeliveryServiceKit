//
//  IDAnnunciationStatus.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit
import os.log

private let log = OSLog(category: "IDAnnunciationStatus")

struct IDAnnunciationStatus {
    static func handleData(_ data: Data) -> DeviceCommResult<(identifier: AnnunciationIdentifier, type: AnnunciationType, status: AnnunciationStatus, auxiliaryData: Data)?> {
        guard data.count >= 1 else {
            log.error("annunciation status characteristic has no data.")
            return .failure(.invalidFormat)
        }
        
        guard data.isCRCValid else {
            log.error("annunciation status CRC is invalid.")
            return .failure(.invalidCRC)
        }
        
        var index = 0
        let flags = AnnunciationStatusFlag(rawValue: data[data.startIndex.advanced(by: index)...].to(AnnunciationStatusFlag.RawValue.self))
        index += 1
        
        guard flags.contains(.presentAnnunciation) else {
            // there is no current annunciation
            return .success(nil)
        }
        
        let annunciationID = data[data.startIndex.advanced(by: index)...].to(AnnunciationIdentifier.self)
        index += 2
        
        guard let annunciationType = AnnunciationType(rawValue: data[data.startIndex.advanced(by: index)...].to(AnnunciationType.RawValue.self)),
              let annunciationStatus = AnnunciationStatus(rawValue: data[data.startIndex.advanced(by: index+2)...].to(AnnunciationStatus.RawValue.self)) else
        {
            return .failure(.parameterOutOfRange)
        }
        index += 3
        
        var auxiliaryData = data[data.startIndex.advanced(by: index)...]
        auxiliaryData.removeLast(3) // remove E2E-Counter and E2E-CRC
                
        return .success((annunciationID, annunciationType, annunciationStatus, auxiliaryData))
    }
}

extension PeripheralManager {
    func readIDAnnunciationStatus(timeout: TimeInterval) throws -> DeviceCommResult<
        (identifier: AnnunciationIdentifier,
        type: AnnunciationType,
        status: AnnunciationStatus,
        auxiliaryData: Data)?> {
        guard let characteristic = peripheral?.getInsulinDeliveryCharacteristicWithUUID(.annunciationStatus) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        
        do {
            guard let characteristicData = try readValue(for: characteristic, timeout: timeout) else {
                throw PeripheralManagerError.timeout
            }
            
            return IDAnnunciationStatus.handleData(characteristicData)
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
}

//MARK: - Enumerations
public enum AnnunciationType: UInt16, CustomStringConvertible, CaseIterable {
    case undetermined = 0x0000
    case airPressureOutOfRange = 0x0303
    case automaticOff = 0xf00f
    case batteryAttention = 0xf096
    case batteryEmpty = 0x00aa
    case batteryError = 0xf000
    case batteryFull = 0x00f0
    case batteryLow = 0x00c3
    case batteryMedium = 0x00cc
    case bolusCanceled = 0x030c
    case pumpNotConfigured = 0xf033
    case dateTimeIssue = 0x0359
    case endOfLifetime = 0xf066
    case endOfPumpLifetime = 0xf03c
    case endOfReservoirTime = 0xf05a
    case infusionSetDetached = 0x0099
    case infusionSetIncomplete = 0x0096
    case lowDeliveryRate = 0xf055
    case maxDelivery = 0x0356
    case mechanicalIssue = 0x0033
    case occlusionDetected = 0x003c
    case powerSourceInsufficient = 0x00a5
    case primingIssue = 0x0069
    case reservoirEmpty = 0x005a
    case reservoirLow = 0x0066
    case reservoirIssue = 0x0055
    case stopWarning = 0xf069
    case systemIssue = 0x000f
    case temperatureOutOfRange = 0x00ff
    case tempBasalCanceled = 0x033f
    case tempBasalOver = 0x0330

    public var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .airPressureOutOfRange: return "airPressureOutOfRange"
        case .automaticOff: return "automaticOff"
        case .batteryAttention: return "batteryAttention"
        case .batteryEmpty: return "batteryEmpty"
        case .batteryError: return "batteryError"
        case .batteryFull: return "batteryFull"
        case .batteryLow: return "batteryLow"
        case .batteryMedium: return "batteryMedium"
        case .bolusCanceled: return "bolusCanceled"
        case .pumpNotConfigured: return "pumpNotConfigured"
        case .dateTimeIssue: return "dateTimeIssue"
        case .endOfLifetime: return "endOfLifetime"
        case .endOfPumpLifetime: return "endOfPumpLifetime"
        case .endOfReservoirTime: return "endOfReservoirTime"
        case .infusionSetDetached: return "infusionSetDetached"
        case .infusionSetIncomplete: return "infusionSetIncomplete"
        case .lowDeliveryRate: return "lowDeliveryRate"
        case .maxDelivery: return "maxDelivery"
        case .mechanicalIssue: return "mechanicalIssue"
        case .occlusionDetected: return "occlusionDetected"
        case .powerSourceInsufficient: return "powerSourceInsufficient"
        case .primingIssue: return "primingIssue"
        case .reservoirEmpty: return "reservoirEmpty"
        case .reservoirLow: return "reservoirLow"
        case .reservoirIssue: return "reservoirIssue"
        case .stopWarning: return "stopWarning"
        case .systemIssue: return "systemIssue"
        case .temperatureOutOfRange: return "temperatureOutOfRange"
        case .tempBasalCanceled: return "tempBasalCanceled"
        case .tempBasalOver: return "tempBasalOver"
        }
    }
}

enum AnnunciationStatus: UInt8, CustomStringConvertible {
    case undetermined = 0x0f
    case pending = 0x33
    case snoozed = 0x3c
    case confirmed = 0x55

    public var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .pending: return "pending"
        case .snoozed: return "snoozed"
        case .confirmed: return "confirmed"
        }
    }
}

//MARK: - Option sets
struct AnnunciationStatusFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8
    
    static let presentAnnunciation  = AnnunciationStatusFlag(rawValue: 1 << 0)
    static let presentAuxInfo1 = AnnunciationStatusFlag(rawValue: 1 << 1)
    static let presentAuxInfo2 = AnnunciationStatusFlag(rawValue: 1 << 2)
    static let presentAuxInfo3 = AnnunciationStatusFlag(rawValue: 1 << 3)
    static let presentAuxInfo4 = AnnunciationStatusFlag(rawValue: 1 << 4)
    static let presentAuxInfo5 = AnnunciationStatusFlag(rawValue: 1 << 5)
    static let allZeros = AnnunciationStatusFlag([])
    
    static let debugDescriptions: [AnnunciationStatusFlag: String] = {
        var descriptions = [AnnunciationStatusFlag: String]()
        descriptions[.presentAnnunciation] = "presentAnnunciation"
        descriptions[.presentAuxInfo1] = "presentAuxInfo1"
        descriptions[.presentAuxInfo2] = "presentAuxInfo2"
        descriptions[.presentAuxInfo3] = "presentAuxInfo3"
        descriptions[.presentAuxInfo4] = "presentAuxInfo4"
        descriptions[.presentAuxInfo5] = "presentAuxInfo5"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for key in AnnunciationStatusFlag.debugDescriptions.keys {
            guard self.contains(key),
                let description = AnnunciationStatusFlag.debugDescriptions[key] else { continue }
            
            result.append(description)
        }
        return "AnnunciationStatusFlag(rawValue: \(rawValue)) \(result)"
    }
}
