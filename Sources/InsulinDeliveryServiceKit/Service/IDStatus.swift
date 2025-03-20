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
import BluetoothCommonKit
import os.log

struct IDStatus {
    static private let log = OSLog(category: "IDStatus")
    
    static func handleData(_ data: Data) -> DeviceCommResult<
        (therapyControlState: InsulinTherapyControlState,
        operationalState: PumpOperationalState,
        remainingReservoir: Double,
        flags: IDStatusFlag)>
    {
        guard data.count == 8 else {
            log.error("status charactersitic is an unexpected size: (expect 8, actual, %d", data.count)
            return .failure(.invalidFormat)
        }
        
        guard data.isCRCValid else {
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
struct IDStatusFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8
    
    static let reservoirAttached  = IDStatusFlag(rawValue: 1 << 0)
    static let allZeros = IDStatusFlag([])
    
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
public enum InsulinTherapyControlState: UInt8, Codable {
    case undetermined = 0x0f
    case stop = 0x33
    case pause = 0x3c
    case run = 0x55
    
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
