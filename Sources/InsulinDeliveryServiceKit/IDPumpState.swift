//
//  IDPumpState.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import BluetoothCommonKit

public struct IDPumpState: RawRepresentable, Equatable {
    
    public typealias RawValue = [String: Any]
    
    public static let version = 1
    
    private enum IDPumpStateKey: String {
        case activeBolusDeliveryStatus
        case activeTempBasalDeliveryStatus
        case authorizationControlRequired
        case deviceInformation
        case features
        case initialReservoirLevel
        case idCommandNextE2ECounter
        case idStatusReaderNextE2ECounter
        case lastCommsDate
        case lastTempBasalRate
        case pumpHistoryEventManagerConfiguration
        case recordAccessNextE2ECounter
        case securityManagerConfiguration
        case setupCompleted
        case totalBasalDelivered
        case uuidStringToHandleMap
    }
    
    public var deviceInformation: DeviceInformation?

    public var isAuthorizationControlRequired: Bool
    
    public var features: IDFeatureFlag
    
    public var uuidToHandleMap: [CBUUID: UInt16]
    
    public var idCommandNextE2ECounter: UInt8
    
    public var idStatusReaderNextE2ECounter: UInt8

    public var pumpHistoryEventManagerConfiguration: PumpHistoryEventManager.Configuration

    public var recordAccessNextE2ECounter: UInt8
    
    public var securityManagerConfiguration: SecurityManager.Configuration

    public var activeBolusDeliveryStatus: BolusDeliveryStatus
    
    public var activeTempBasalDeliveryStatus: TempBasalDeliveryStatus
    
    public var totalBasalDelivered: Double
    
    public var lastTempBasalRate: Double

    public var initialReservoirLevel: Int

    public var isDeliveringInsulin: Bool {
        deviceInformation?.therapyControlState == .run
    }

    public var setupCompleted: Bool

    public var lastCommsDate: Date?

    public init(deviceInformation: DeviceInformation? = nil,
                features: IDFeatureFlag = [],
                uuidToHandleMap: [CBUUID: UInt16] = [:],
                idCommandNextE2ECounter: UInt8? = nil,
                idStatusReaderNextE2ECounter: UInt8? = nil,
                pumpHistoryEventManagerConfiguration: PumpHistoryEventManager.Configuration = PumpHistoryEventManager.Configuration(),
                recordAccessNextE2ECounter: UInt8? = nil,
                securityManagerConfiguration: SecurityManager.Configuration = SecurityManager.Configuration(),
                activeBolusDeliveryStatus: BolusDeliveryStatus = .noActiveBolus,
                activeTempBasalDeliveryStatus: TempBasalDeliveryStatus = .noActiveTempBasal,
                totalBasalDelivered: Double = 0,
                lastTempBasalRate: Double = 0,
                initialReservoirLevel: Int = 100,
                setupCompleted: Bool = false,
                authorizationControlRequired: Bool = false,
                lastCommsDate: Date? = nil)
    {
        self.deviceInformation = deviceInformation
        self.features = features
        self.uuidToHandleMap = uuidToHandleMap
        self.idCommandNextE2ECounter = idCommandNextE2ECounter ?? IDCommandControlPointDataHandler.e2eCounterInitalValue
        self.idStatusReaderNextE2ECounter = idStatusReaderNextE2ECounter ?? IDStatusReaderControlPointDataHandler.e2eCounterInitalValue
        self.pumpHistoryEventManagerConfiguration = pumpHistoryEventManagerConfiguration
        self.recordAccessNextE2ECounter = recordAccessNextE2ECounter ?? IDRecordAccessControlPointDataHandler.e2eCounterInitalValue
        self.securityManagerConfiguration = securityManagerConfiguration
        self.activeBolusDeliveryStatus = activeBolusDeliveryStatus
        self.activeTempBasalDeliveryStatus = activeTempBasalDeliveryStatus
        self.totalBasalDelivered = totalBasalDelivered
        self.lastTempBasalRate = lastTempBasalRate
        self.initialReservoirLevel = initialReservoirLevel
        self.setupCompleted = setupCompleted
        self.isAuthorizationControlRequired = authorizationControlRequired
        self.lastCommsDate = lastCommsDate
    }
    
    public init?(rawValue: RawValue) {
        guard let rawUUIDStringToHandleMap = rawValue[IDPumpStateKey.uuidStringToHandleMap.rawValue] as? Data,
              let uuidStringToHandleMap = try? PropertyListDecoder().decode([String: UInt16].self, from: rawUUIDStringToHandleMap),
              let uuidToHandleMap = uuidStringToHandleMap.toCBUUIDKeys(),
              let idCommandNextE2ECounter = rawValue[IDPumpStateKey.idCommandNextE2ECounter.rawValue] as? UInt8,
              let idStatusReaderNextE2ECounter = rawValue[IDPumpStateKey.idStatusReaderNextE2ECounter.rawValue] as? UInt8,
              let recordAccessNextE2ECounter = rawValue[IDPumpStateKey.recordAccessNextE2ECounter.rawValue] as? UInt8,
              let rawSecurityManagerConfiguration = rawValue[IDPumpStateKey.securityManagerConfiguration.rawValue] as? SecurityManager.Configuration.RawValue,
              let securityManagerConfiguration = SecurityManager.Configuration(rawValue: rawSecurityManagerConfiguration),
              let rawActiveBolusDeliveryStatus = rawValue[IDPumpStateKey.activeBolusDeliveryStatus.rawValue] as? BolusDeliveryStatus.RawValue,
              var activeBolusDeliveryStatus = BolusDeliveryStatus(rawValue: rawActiveBolusDeliveryStatus),
              let rawActiveTempBasalDeliveryStatus = rawValue[IDPumpStateKey.activeTempBasalDeliveryStatus.rawValue] as? TempBasalDeliveryStatus.RawValue,
              let activeTempBasalDeliveryStatus = TempBasalDeliveryStatus(rawValue: rawActiveTempBasalDeliveryStatus),
              let totalBasalDelivered = rawValue[IDPumpStateKey.totalBasalDelivered.rawValue] as? Double,
              let lastTempBasalRate = rawValue[IDPumpStateKey.lastTempBasalRate.rawValue] as? Double,
              let initialReservoirLevel = rawValue[IDPumpStateKey.initialReservoirLevel.rawValue] as? Int,
              let setupCompleted = rawValue[IDPumpStateKey.setupCompleted.rawValue] as? Bool,
              let authorizationControlRequired = rawValue[IDPumpStateKey.authorizationControlRequired.rawValue] as? Bool,
              let rawFeatures = rawValue[IDPumpStateKey.features.rawValue] as? UInt32
        else {
            return nil
        }

        self.uuidToHandleMap = uuidToHandleMap
        self.idCommandNextE2ECounter = idCommandNextE2ECounter
        self.idStatusReaderNextE2ECounter = idStatusReaderNextE2ECounter
        self.recordAccessNextE2ECounter = recordAccessNextE2ECounter
        self.securityManagerConfiguration = securityManagerConfiguration
        self.initialReservoirLevel = initialReservoirLevel
        self.setupCompleted = setupCompleted
        self.isAuthorizationControlRequired = authorizationControlRequired
        self.lastCommsDate = rawValue[IDPumpStateKey.lastCommsDate.rawValue] as? Date
        self.features = IDFeatureFlag(rawValue: rawFeatures)
        
        if let rawPumpHistoryEventManagerConfiguration = rawValue [IDPumpStateKey.pumpHistoryEventManagerConfiguration.rawValue] as? PumpHistoryEventManager.Configuration.RawValue,
           let pumpHistoryEventManagerConfiguration = PumpHistoryEventManager.Configuration(rawValue: rawPumpHistoryEventManagerConfiguration)
        {
            self.pumpHistoryEventManagerConfiguration = pumpHistoryEventManagerConfiguration
        } else {
            self.pumpHistoryEventManagerConfiguration = PumpHistoryEventManager.Configuration()
        }

        if activeBolusDeliveryStatus.progressState == .inProgress {
            activeBolusDeliveryStatus.progressState = .estimatingProgress // when restoring, bolus delivery is estimatingProgress
        }
        self.activeBolusDeliveryStatus = activeBolusDeliveryStatus
        self.activeTempBasalDeliveryStatus = activeTempBasalDeliveryStatus
        self.totalBasalDelivered = totalBasalDelivered
        self.lastTempBasalRate = lastTempBasalRate
        
        if let rawDeviceInformation = rawValue[IDPumpStateKey.deviceInformation.rawValue] as? Data,
            let deviceInformation = try? PropertyListDecoder().decode(DeviceInformation.self, from: rawDeviceInformation)
        {
            self.deviceInformation = deviceInformation
        }
    }
    
    public var rawValue: RawValue {
        var raw: RawValue = [:]
             
        if let deviceInformation = deviceInformation {
            let rawDeviceInformation = try? PropertyListEncoder().encode(deviceInformation)
            raw[IDPumpStateKey.deviceInformation.rawValue] = rawDeviceInformation
        }

        let uuidStringToHandleMap: [String: UInt16] = uuidToHandleMap.toCBUUIDStringKeys()
        let rawUUIDStringToHandleMap = try? PropertyListEncoder().encode(uuidStringToHandleMap)
        raw[IDPumpStateKey.uuidStringToHandleMap.rawValue] = rawUUIDStringToHandleMap
        raw[IDPumpStateKey.activeBolusDeliveryStatus.rawValue] = activeBolusDeliveryStatus.rawValue
        raw[IDPumpStateKey.activeTempBasalDeliveryStatus.rawValue] = activeTempBasalDeliveryStatus.rawValue
        raw[IDPumpStateKey.totalBasalDelivered.rawValue] = totalBasalDelivered
        raw[IDPumpStateKey.lastTempBasalRate.rawValue] = lastTempBasalRate
        raw[IDPumpStateKey.initialReservoirLevel.rawValue] = initialReservoirLevel
        raw[IDPumpStateKey.idCommandNextE2ECounter.rawValue] = idCommandNextE2ECounter
        raw[IDPumpStateKey.idStatusReaderNextE2ECounter.rawValue] = idStatusReaderNextE2ECounter
        raw[IDPumpStateKey.pumpHistoryEventManagerConfiguration.rawValue] = pumpHistoryEventManagerConfiguration.rawValue
        raw[IDPumpStateKey.recordAccessNextE2ECounter.rawValue] = recordAccessNextE2ECounter
        raw[IDPumpStateKey.securityManagerConfiguration.rawValue] = securityManagerConfiguration.rawValue
        raw[IDPumpStateKey.setupCompleted.rawValue] = setupCompleted
        raw[IDPumpStateKey.authorizationControlRequired.rawValue] = isAuthorizationControlRequired
        raw[IDPumpStateKey.lastCommsDate.rawValue] = lastCommsDate
        raw[IDPumpStateKey.features.rawValue] = features.rawValue

        return raw
    }
}

extension IDPumpState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "* features: \(features)",
            "* activeBolusDeliveryStatus: \(activeBolusDeliveryStatus)",
            "* activeTempBasalDeliveryStatus: \(activeTempBasalDeliveryStatus)",
            "* deviceInformation: \(String(describing: deviceInformation))",
            "* initialReservoirLevel: \(initialReservoirLevel)",
            "* insulinDeliveryCommandNextE2ECounter: \(idCommandNextE2ECounter)",
            "* insulinDeliveryStatusReaderNextE2ECounter: \(idStatusReaderNextE2ECounter)",
            "* pumpHistoryEventManagerConfiguration: \(pumpHistoryEventManagerConfiguration)",
            "* recordAccessNextE2ECounter: \(recordAccessNextE2ECounter)",
            "* securityManagerConfiguration: \(securityManagerConfiguration)",
            "* setupCompleted: \(setupCompleted)",
            "* totalBasalDelivered: \(totalBasalDelivered)",
            "* lastTempBasalRate: \(lastTempBasalRate)",
            "* uuidStringToHandleMap: \(uuidToHandleMap.toCBUUIDStringKeys())",
            "* lastCommsDate: \(String(describing: lastCommsDate))",
            ].joined(separator: "\n")
    }
}
