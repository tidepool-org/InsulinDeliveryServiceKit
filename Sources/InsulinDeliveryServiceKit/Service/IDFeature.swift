//
//  IDFeature.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-18.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//
//
//  This is based on version 1.0 of the Insulin Delivery Service: https://www.bluetooth.com/specifications/specs/insulin-delivery-service-1-0/

import Foundation
import CoreBluetooth
import BluetoothCommonKit
import os.log

//MARK: - Support Server Implementation
public class IDFeatureCharacteristic: E2EProtection {
    public var e2eCounter: UInt8 = 0
    public weak var e2eDelegate: E2EProtectionDelegate?
    public var insulinConcentration: Double
    public var flags: IDFeatureFlag = IDFeatureFlag([.supportedE2EProtection, .supportedBasalRate, .supportedTBRAbsolute, .supportedBolusFast, .supportedBolusActivationType])

    var messageQueue: MessagingQueue

    public init(messageQueue: MessagingQueue,
                insulinConcentration: Double = 100) {
        self.messageQueue = messageQueue
        self.insulinConcentration = insulinConcentration
    }

    public func createData() -> Data {
        if e2eDelegate?.isE2EProtectionSupported ?? false {
            incrementE2ECounter()
        }
        var characteristicValue = Data(e2eCounter)
        characteristicValue.append(insulinConcentration.sfloat)
        characteristicValue.append(flags.data)
        if e2eDelegate?.isE2EProtectionSupported ?? false {
            characteristicValue = characteristicValue.appendingCRCPrefix()
        } else {
            characteristicValue.insert(contentsOf: Data(UInt16(0xffff)), at: 0)
        }

        ConsoleOut.shared.logMessage(message: "\(#function) Insulin Delivery Feature characteristic value: \(characteristicValue.hexadecimalString)")
        
        return characteristicValue
    }

    public func onRead() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading Insulin Delivery Feature characteristic")
        return (CBATTError.Code.success, self.createData())
    }
}

// MARK: - Support Client Implementation
public struct IDFeatureDataHandler {
    static private let log = OSLog(category: "IDFeature")
    
    public static func handleData(_ data: Data) -> DeviceCommResult<
        (insulinConcentration: Double,
        flags: IDFeatureFlag)>
    {
        guard data.count == 8 else {
            log.error("feature charactersitic is an unexpected size: (expect 8, actual, %d", data.count)
            return .failure(.invalidFormat)
        }
        
        var index = 3
        let insulinConcentration = Data(data[data.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
        index += 2
        
        let flagPart1 = data[data.startIndex.advanced(by: index)...].to(UInt16.self)
        index += 2
        let flagPart2 = data[data.startIndex.advanced(by: index)...].to(UInt8.self)
        
        var flag = IDFeatureFlag(rawValue: UInt32(flagPart1))
        if (flagPart2 & 0x01) != 0 {
            flag.insert(.supportedIOB)
        }
        
        if flag.contains(.supportedE2EProtection),
           !data.isCRCPrefixValid
        {
            return .failure(.invalidCRC)
        }
        
        log.debug("%{public}@ insulin concentration: %{public}f flags: %{public}@", #function, insulinConcentration, String(describing: flag))
        return .success((insulinConcentration, flag))
    }
}

//MARK: - Option sets
public struct IDFeatureFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt32
    
    var data: Data {
        // the flags field is only 24-bit
        Data(self.rawValue).dropLast(1)
    }
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    static public let supportedE2EProtection = IDFeatureFlag(rawValue: 1 << 0)
    static public let supportedBasalRate = IDFeatureFlag(rawValue: 1 << 1)
    static public let supportedTBRAbsolute = IDFeatureFlag(rawValue: 1 << 2)
    static public let supportedTBRRelative = IDFeatureFlag(rawValue: 1 << 3)
    static public let supportedTBRTemplate = IDFeatureFlag(rawValue: 1 << 4)
    static public let supportedBolusFast = IDFeatureFlag(rawValue: 1 << 5)
    static public let supportedBolusExtended = IDFeatureFlag(rawValue: 1 << 6)
    static public let supportedBolusMultiwave = IDFeatureFlag(rawValue: 1 << 7)
    static public let supportedBolusDelayTime = IDFeatureFlag(rawValue: 1 << 8)
    static public let supportedBolusTemplate = IDFeatureFlag(rawValue: 1 << 9)
    static public let supportedBolusActivationType = IDFeatureFlag(rawValue: 1 << 10)
    static public let supportedMultipleBond = IDFeatureFlag(rawValue: 1 << 11)
    static public let supportedProfileISF = IDFeatureFlag(rawValue: 1 << 12)
    static public let supportedProfileI2CHO = IDFeatureFlag(rawValue: 1 << 13)
    static public let supportedProfileTargetGlucoseRange = IDFeatureFlag(rawValue: 1 << 14)
    static public let supportedIOB = IDFeatureFlag(rawValue: 1 << 15)
    static public let allZeros = IDFeatureFlag([])
    
    static let debugDescriptions: [IDFeatureFlag: String] = {
        var descriptions = [IDFeatureFlag: String]()
        descriptions[.supportedE2EProtection] = "supportedE2EProtection"
        descriptions[.supportedBasalRate] = "supportedBasalRate"
        descriptions[.supportedTBRAbsolute] = "supportedTBRAbsolute"
        descriptions[.supportedTBRRelative] = "supportedTBRRelative"
        descriptions[.supportedTBRTemplate] = "supportedTBRTemplate"
        descriptions[.supportedBolusFast] = "supportedBolusFast"
        descriptions[.supportedBolusExtended] = "supportedBolusExtended"
        descriptions[.supportedBolusMultiwave] = "supportedBolusMultiwave"
        descriptions[.supportedBolusDelayTime] = "supportedBolusDelayTime"
        descriptions[.supportedBolusTemplate] = "supportedBolusTemplate"
        descriptions[.supportedBolusActivationType] = "supportedBolusActivationType"
        descriptions[.supportedMultipleBond] = "supportedMultipleBond"
        descriptions[.supportedProfileISF] = "supportedProfileISF"
        descriptions[.supportedProfileI2CHO] = "supportedProfileI2CHO"
        descriptions[.supportedProfileTargetGlucoseRange] = "supportedProfileTargetGlucoseRange"
        descriptions[.supportedIOB] = "supportedIOB"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in IDFeatureFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "IDFeatureFlag(rawValue: \(rawValue)) \(result)"
    }
}
