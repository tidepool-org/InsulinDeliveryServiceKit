//
//  IDAnnunciationStatus.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth
import BluetoothCommonKit
import os.log

// MARK: - Support Server Implementation
open class IDAnnunciationStatusCharacteristic: E2EProtection {
    public var e2eCounter: UInt8 = 1
    public var annunciationID: UInt16 = 0
    var messageQueue: MessagingQueue

    public init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }

    open func createData(for type: AnnunciationType? = nil) -> Data {
        var value = annunciation(for: type)
        value = appendingE2EProtection(value)

        ConsoleOut.shared.logMessage(message: "\(#function) ID annunciation status characteristic value: \(value.hexadecimalString)")

        return value
    }

    open func onRead() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading annunciation status characteristic")
        let type: AnnunciationType = e2eCounter%3 == 0 ? .reservoirLow : e2eCounter%3 == 1 ? .bolusCanceled : .batteryLow
        return (CBATTError.Code.success, self.createData(for: type))
    }
    
    open func triggerAnnunciation(for type: AnnunciationType? = nil) {
        if messageQueue.gattServer.isCharacteristicSubscribed(InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID) == true {
            var value = annunciation(for: type)
            value = appendingE2EProtection(value)
            let valuepair = UUIDValuePair(
                uuid: InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID,
                value: value
            )
            ConsoleOut.shared.logMessage(message: "\(#function): \(valuepair.description)")
            messageQueue.addQueueItem(valuepair)
        } else {
            ConsoleOut.shared.logMessage(message: "\(#function): annunciation status characteristic is not configured for indications")
        }
    }
    
    public func triggerIndication() {
        triggerAnnunciation()
    }
    
    open func annunciation(for type: AnnunciationType? = nil) -> Data {
        var annunciationData: Data
        var flags: AnnunciationStatusFlag = .allZeros
        guard let type else {
            annunciationData = Data(flags.rawValue)
            return annunciationData
        }
                
        flags.insert(.presentAnnunciation)
        annunciationData = Data(flags.rawValue)
        annunciationID += 1
        annunciationData.append(annunciationID)
        annunciationData.append(type.rawValue)
        annunciationData.append(AnnunciationStatus.pending.rawValue)
        return annunciationData
    }
}

// MARK: - Suuport Client Implementation
private let log = OSLog(category: "IDAnnunciationStatus")

public struct IDAnnunciationStatus {
    static public func handleData(_ data: Data) -> DeviceCommResult<(identifier: AnnunciationIdentifier, type: AnnunciationType, status: AnnunciationStatus, auxiliaryData: Data)?> {
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
        
        let annunciationType = AnnunciationType(rawValue: data[data.startIndex.advanced(by: index)...].to(AnnunciationType.RawValue.self))
        guard let annunciationStatus = AnnunciationStatus(rawValue: data[data.startIndex.advanced(by: index+2)...].to(AnnunciationStatus.RawValue.self)) else
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
public struct AnnunciationType: RawRepresentable, CustomStringConvertible, Equatable, Hashable, Codable, Sendable {
    public var rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    public static let undetermined = AnnunciationType(rawValue: 0x0000)
    public static let airPressureOutOfRange = AnnunciationType(rawValue: 0x0303)
    public static let batteryEmpty = AnnunciationType(rawValue: 0x00aa)
    public static let batteryFull = AnnunciationType(rawValue: 0x00f0)
    public static let batteryLow = AnnunciationType(rawValue: 0x00c3)
    public static let batteryMedium = AnnunciationType(rawValue: 0x00cc)
    public static let bolusCanceled = AnnunciationType(rawValue: 0x030c)
    public static let dateTimeIssue = AnnunciationType(rawValue: 0x0359)
    public static let infusionSetDetached = AnnunciationType(rawValue: 0x0099)
    public static let infusionSetIncomplete = AnnunciationType(rawValue: 0x0096)
    public static let maxDelivery = AnnunciationType(rawValue: 0x0356)
    public static let mechanicalIssue = AnnunciationType(rawValue: 0x0033)
    public static let occlusionDetected = AnnunciationType(rawValue: 0x003c)
    public static let powerSourceInsufficient = AnnunciationType(rawValue: 0x00a5)
    public static let primingIssue = AnnunciationType(rawValue: 0x0069)
    public static let reservoirEmpty = AnnunciationType(rawValue: 0x005a)
    public static let reservoirLow = AnnunciationType(rawValue: 0x0066)
    public static let reservoirIssue = AnnunciationType(rawValue: 0x0055)
    public static let systemIssue = AnnunciationType(rawValue: 0x000f)
    public static let temperatureOutOfRange = AnnunciationType(rawValue: 0x00ff)
    public static let temperature = AnnunciationType(rawValue: 0x0365)
    public static let tempBasalCanceled = AnnunciationType(rawValue: 0x033f)
    public static let tempBasalOver = AnnunciationType(rawValue: 0x0330)
    
    public static let allCases: [AnnunciationType] = [
        .airPressureOutOfRange,
        .batteryEmpty,
        .batteryFull,
        .batteryLow,
        .batteryMedium,
        .bolusCanceled,
        .dateTimeIssue,
        .infusionSetDetached,
        .infusionSetIncomplete,
        .maxDelivery,
        .mechanicalIssue,
        .occlusionDetected,
        .powerSourceInsufficient,
        .primingIssue,
        .reservoirEmpty,
        .reservoirLow,
        .reservoirIssue,
        .systemIssue,
        .temperatureOutOfRange,
        .tempBasalCanceled,
        .tempBasalOver,
    ]

    public var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .airPressureOutOfRange: return "airPressureOutOfRange"
        case .batteryEmpty: return "batteryEmpty"
        case .batteryFull: return "batteryFull"
        case .batteryLow: return "batteryLow"
        case .batteryMedium: return "batteryMedium"
        case .bolusCanceled: return "bolusCanceled"
        case .dateTimeIssue: return "dateTimeIssue"
        case .infusionSetDetached: return "infusionSetDetached"
        case .infusionSetIncomplete: return "infusionSetIncomplete"
        case .maxDelivery: return "maxDelivery"
        case .mechanicalIssue: return "mechanicalIssue"
        case .occlusionDetected: return "occlusionDetected"
        case .powerSourceInsufficient: return "powerSourceInsufficient"
        case .primingIssue: return "primingIssue"
        case .reservoirEmpty: return "reservoirEmpty"
        case .reservoirLow: return "reservoirLow"
        case .reservoirIssue: return "reservoirIssue"
        case .systemIssue: return "systemIssue"
        case .temperatureOutOfRange: return "temperatureOutOfRange"
        case .tempBasalCanceled: return "tempBasalCanceled"
        case .tempBasalOver: return "tempBasalOver"
        default:
            return "manufacturerSpecificAnnunicationType(\(self.rawValue))"
        }
    }
}

public enum AnnunciationStatus: UInt8, CustomStringConvertible {
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
public struct AnnunciationStatusFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    static public let presentAnnunciation  = AnnunciationStatusFlag(rawValue: 1 << 0)
    static public let presentAuxInfo1 = AnnunciationStatusFlag(rawValue: 1 << 1)
    static public let presentAuxInfo2 = AnnunciationStatusFlag(rawValue: 1 << 2)
    static public let presentAuxInfo3 = AnnunciationStatusFlag(rawValue: 1 << 3)
    static public let presentAuxInfo4 = AnnunciationStatusFlag(rawValue: 1 << 4)
    static public let presentAuxInfo5 = AnnunciationStatusFlag(rawValue: 1 << 5)
    static public let allZeros = AnnunciationStatusFlag([])
    
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
