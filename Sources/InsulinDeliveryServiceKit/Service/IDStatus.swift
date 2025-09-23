//
//  IDStatus.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//
//
//  This is based on version 1.0 of the Insulin Delivery Service: https://www.bluetooth.com/specifications/specs/insulin-delivery-service-1-0/

import Foundation
import CoreBluetooth
import BluetoothCommonKit
import os.log

//MARK: - Support Server Implementation
public protocol IDStatusCharacteristicDelegate: AnyObject {
    var therapyState: InsulinTherapyControlState { get }
    var operationalState: PumpOperationalState { get }
    var reservoirRemaining: Double { get }
}

open class IDStatusCharacteristic: ReadableCharacteristic, IndicativeCharacertistic, E2EProtection {
    public var e2eCounter: UInt8 = 0
    public weak var e2eDelegate: E2EProtectionDelegate?
    public weak var delegate: IDStatusCharacteristicDelegate?
    public var flags: IDStatusFlag = [.reservoirAttached]
    public var messageQueue: MessagingQueue

    public required init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }

    open func createData() -> Data {
        var characteristicValue = Data((delegate?.therapyState ?? .undetermined).rawValue)
        characteristicValue.append((delegate?.operationalState ?? .undetermined).rawValue)
        characteristicValue.append((delegate?.reservoirRemaining ?? 0).sfloat)
        characteristicValue.append(flags.rawValue)
        if e2eDelegate?.isE2EProtectionSupported ?? false {
            incrementE2ECounter()
            characteristicValue = appendingE2EProtection(characteristicValue)
        }
        
        ConsoleOut.shared.logMessage(message: "\(#function) ID status characteristic value: \(characteristicValue.hexadecimalString)")

        return characteristicValue
    }

    open func onRead() -> (CBATTError.Code, Data) {
        ConsoleOut.shared.logMessage(message: "\(#function): reading ID status characteristic")
        return (CBATTError.Code.success, self.createData())
    }
    
    open func triggerIndication() {
        indicateResponse(createData())
    }
    
    public func indicateResponse(_ response: Data) {
        if messageQueue.gattServer.isCharacteristicSubscribed(InsulinDeliveryCharacteristicUUID.status.cbUUID) == true {
            let valuepair = UUIDValuePair(
                uuid: InsulinDeliveryCharacteristicUUID.status.cbUUID,
                value: response
            )
            ConsoleOut.shared.logMessage(message: "\(#function): \(valuepair.description)")
            messageQueue.addQueueItem(valuepair)
        } else {
            ConsoleOut.shared.logMessage(message: "\(#function): ID status characteristic is not configured for indications")
        }
    }
}

//MARK: - Support Client Implementation
public struct IDStatusDataHandler {
    static private let log = OSLog(category: "IDStatus")
    
    public static func handleData(_ data: Data, e2eProtectionSupported: Bool) -> DeviceCommResult<
        (therapyControlState: InsulinTherapyControlState,
        operationalState: PumpOperationalState,
        remainingReservoir: Double,
        flags: IDStatusFlag)>
    {
        guard data.count == (e2eProtectionSupported ? 8 : 5) else {
            log.error("status charactersitic is an unexpected size: (expect 8, actual, %d", data.count)
            return .failure(.invalidFormat)
        }
        
        guard !e2eProtectionSupported || data.isCRCValid else {
            log.error("status characteristic CRC is invalid")
            return .failure(.invalidCRC)
        }
        
        var index = 0
        guard let therapyControlState = InsulinTherapyControlState(rawValue: data[data.startIndex.advanced(by: index)...].to(InsulinTherapyControlState.RawValue.self)),
              let operationalState = PumpOperationalState(rawValue: data[data.startIndex.advanced(by: index+1)...].to(PumpOperationalState.RawValue.self)) else
        {
            log.error("could not parse therapy control state and operational state")
            return .failure(.parameterOutOfRange)
        }
        
        index += 2
        let remainingReservoirData = Data(data[data.startIndex.advanced(by: index)...].to(SFLOAT.self))
        let remainingReservoir = remainingReservoirData.sfloatToDouble()
        guard !remainingReservoir.isNaN else {
            log.error("could not convert reservoir level from sFloat to Double")
            return .failure(.parameterOutOfRange)
        }
        index += 2
        
        let flags = IDStatusFlag(rawValue: data[data.startIndex.advanced(by: index)...].to(IDStatusFlag.RawValue.self))
        log.debug("%{public}@ %{public}@ %{public}@ reservoir remaining: %{public}f %{public}@", #function, String(describing: therapyControlState), String(describing: operationalState), remainingReservoir, String(describing: flags))
        
        return .success((therapyControlState, operationalState, remainingReservoir, flags))
    }
}

//MARK: - Option sets
public struct IDStatusFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    static public let reservoirAttached  = IDStatusFlag(rawValue: 1 << 0)
    static public let allZeros = IDStatusFlag([])
    
    static let debugDescriptions: [IDStatusFlag: String] = {
        var descriptions = [IDStatusFlag: String]()
        descriptions[.reservoirAttached] = "reservoirAttached"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in IDStatusFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "InsulinDeliveryStatusFlag(rawValue: \(rawValue)) \(result)"
    }
}

//MARK: - Enumerations
public enum InsulinTherapyControlState: UInt8, Codable, CaseIterable, CustomStringConvertible {
    case undetermined = 0x0f
    case stop = 0x33
    case pause = 0x3c
    case run = 0x55
    
    public var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .stop: return "stop"
        case .pause: return "pause"
        case .run: return "run"
        }
    }
    
    public var localizedDescription: String {
        switch self {
        case .undetermined:
            return LocalizedString("Unknown", comment: "Description when insulin therapy control state is undetermined")
        case .stop:
            return LocalizedString("Suspended", comment: "Description when insulin therapy control state is stop")
        case .pause:
            return LocalizedString("Suspended", comment: "Description when insulin therapy control state is pause")
        case .run:
            return LocalizedString("Delivering", comment: "Description when insulin therapy control state is run")
        }
    }
}

public enum PumpOperationalState: UInt8, Codable {
    case undetermined = 0x0f
    case off = 0x33
    case standby = 0x3c
    case preparing = 0x55
    case priming = 0x5a
    case waiting = 0x66
    case ready = 0x96
    
    public var localizedDescription: String {
        switch self {
        case .undetermined:
            return LocalizedString("Unknown", comment: "Description when pump operational state is undetermined")
        case .off:
            return LocalizedString("Off", comment: "Description when pump operational state is off")
        case .standby:
            return LocalizedString("Standby", comment: "Description when pump operational state is standby")
        case .preparing:
            return LocalizedString("Preparing", comment: "Description when pump operational state is preparing")
        case .priming:
            return LocalizedString("Priming", comment: "Description when pump operational state is priming")
        case .waiting:
            return LocalizedString("Waiting", comment: "Description when pump operational state is waiting")
        case .ready:
            return LocalizedString("Ready", comment: "Description when pump operational state is ready")
        }
    }
    
    public var isAnActivePumpState: Bool {
        switch self {
        case .ready: return true
        case .priming: return true // this state is allowed for an active pump, since it is needed to remove air bubbles during everyday use
        default: return false
        }
    }
}
