//
//  MockInsulinDeliveryPump.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-04-07.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import BluetoothCommonKit

public protocol MockInsulinDeliveryPumpDelegate: AnyObject {
    func mockPumpDidUpdate(_ pump: MockInsulinDeliveryPump)
}

public class MockInsulinDeliveryPump {
    let gattServer: GATTService
    public weak var delegate: MockInsulinDeliveryPumpDelegate?
    let messageQueue: MessagingQueue
    
    // characteristics
    public let featureCharacteristic: IDFeatureCharacteristic
    public let statusCharacteristic: IDStatusCharacteristic
    public let statusChangedCharacteristic: IDStatusChangedCharacteristic
    public let annunciationStatusCharacteristic: IDAnnunciationStatusCharacteristic
    public let statusReaderControlPoint: IDStatusReaderControlPointCharacteristic
    public let commandControlPoint: IDCommandControlPointCharacteristic
    public let recordAccessControlPoint: IDRecordAccessControlPointCharacteristic
    public let batteryLevelCharacteristic: BatteryLevelCharacteristic
    public let deviceInformationCharacteristics: DeviceInformationCharacteristics
    public let deviceTimeFeatureCharacteristic: DTFeaturesCharacteristic
    public let deviceTimeParameterCharacteristic: DTParametersCharacteristic
    public let deviceTimeCharacteristic: DeviceTimeCharacteristic
    public let deviceTimeControlPoint: DTControlPointCharacteristic
    public let alertLevelCharacteristic: AlertLevelCharacteristic
    public let authorizationStatusCharacteristic: ACStatusCharacteristic
    public let authorizationControlPoint: ACControlPointCharacteristic
    public let authorizationDataCharacteristic: ACDataCharacteristic
    
    var characteristicsInsulinDelivery: [CallbackCharacteristic] = []
    var characteristicsBattery: [CallbackCharacteristic] = []
    var characteristicsDeviceInformation: [CallbackCharacteristic] = []
    var characteristicsDeviceTime: [CallbackCharacteristic] = []
    var characteristicsImmediateAlert: [CallbackCharacteristic] = []
    var characteristicsAuthorizationControl: [CallbackCharacteristic] = []
    
    var status: MockInsulinDeliveryPumpStatus {
        didSet {
            if oldValue != status {
                delegate?.mockPumpDidUpdate(self)
            }
        }
    }
    
    var deliveryTimer: Timer?
    
    public var isPumpBehaviourEnabled: Bool = true
    
    public var isAuthorizationControlEnabled: Bool = false
    var isSecurityEstablished: Bool {
        get {
            authorizationStatusCharacteristic.isSecurityEstablished
        }
        set {
            authorizationStatusCharacteristic.isSecurityEstablished = newValue
        }
    }
    public var securityManager: SecurityManager
    public var sharedKeyData: Data?
    
    var restrictionMapID: RestrictionMapID = 1
    var securityConfigurationID: SecurityConfigurationID = 1
    public var ecdhKeyID: KeyID {
        securityManager.configuration.ecdhKeyID
    }
    
    public var algorithmKeyID: KeyID {
        securityManager.configuration.algorithmKeyID
    }
    
    public init(gattServer: GATTService,
                messageQueue: MessagingQueue,
                status: MockInsulinDeliveryPumpStatus? = nil)
    {
        let status = status ?? MockInsulinDeliveryPumpStatus.withoutBasalProfile
        self.gattServer = gattServer
        self.messageQueue = messageQueue
        self.status = status
        self.securityManager = SecurityManager()
        securityManager.configuration.oobRandomNumber = "42".data(using: .utf8)!
        let maxRequesSize = 19
        
        featureCharacteristic = IDFeatureCharacteristic(messageQueue: messageQueue)
        statusCharacteristic = IDStatusCharacteristic(messageQueue: messageQueue)
        statusChangedCharacteristic = IDStatusChangedCharacteristic(messageQueue: messageQueue)
        annunciationStatusCharacteristic = IDAnnunciationStatusCharacteristic(messageQueue: messageQueue)
        statusReaderControlPoint = IDStatusReaderControlPointCharacteristic(messageQueue: messageQueue,
                                                                            statusChangedCharacteristic: statusChangedCharacteristic)
        recordAccessControlPoint = IDRecordAccessControlPointCharacteristic(messageQueue: messageQueue)
        commandControlPoint = IDCommandControlPointCharacteristic(messageQueue: messageQueue)
        
        batteryLevelCharacteristic = BatteryLevelCharacteristic(messageQueue: messageQueue)
        deviceInformationCharacteristics = DeviceInformationCharacteristics(messageQueue: messageQueue)
        
        deviceTimeFeatureCharacteristic = DTFeaturesCharacteristic(messageQueue: messageQueue)
        deviceTimeParameterCharacteristic = DTParametersCharacteristic(messageQueue: messageQueue)
        deviceTimeCharacteristic = DeviceTimeCharacteristic(messageQueue: messageQueue)
        deviceTimeControlPoint = DTControlPointCharacteristic(messageQueue: messageQueue)
        
        alertLevelCharacteristic = AlertLevelCharacteristic(messageQueue: messageQueue)
        
        authorizationStatusCharacteristic = ACStatusCharacteristic(messageQueue: messageQueue)
        authorizationControlPoint = ACControlPointCharacteristic(messageQueue: messageQueue, securityManager: securityManager, maxRequestSize: maxRequesSize)
        authorizationDataCharacteristic = ACDataCharacteristic(messageQueue: messageQueue, securityManager: securityManager, status: authorizationStatusCharacteristic, maxRequestSize: maxRequesSize)
        
        featureCharacteristic.e2eDelegate = self
        statusCharacteristic.e2eDelegate = self
        statusCharacteristic.delegate = self
        statusChangedCharacteristic.e2eDelegate = self
        annunciationStatusCharacteristic.e2eDelegate = self
        statusReaderControlPoint.e2eDelegate = self
        statusReaderControlPoint.delegate = self
        commandControlPoint.e2eDelegate = self
        commandControlPoint.delegate = self
        recordAccessControlPoint.e2eDelegate = self
        
        deviceTimeFeatureCharacteristic.e2eDelegate = self
        deviceTimeParameterCharacteristic.e2eDelegate = self
        deviceTimeCharacteristic.e2eDelegate = self
        deviceTimeControlPoint.e2eDelegate = self
        
        authorizationControlPoint.delegate = self
        authorizationDataCharacteristic.delegate = self
        
        securityManager.delegate = self
     
        // Insulin Delivery service
        
        let charFeature = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.features.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.isAuthorizationControlEnabled ? (CBATTError.Code.insufficientAuthorization, Data()) : self.featureCharacteristic.onRead() }
        )
        
        let charStatus = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.status.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.isAuthorizationControlEnabled ? (CBATTError.Code.insufficientAuthorization, Data()) : self.statusCharacteristic.onRead() }
        )
        
        let charStatusChanged = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.statusChanged.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.isAuthorizationControlEnabled ? (CBATTError.Code.insufficientAuthorization, Data()) : self.statusChangedCharacteristic.onRead() }
        )

        let charAnnunciationStatus = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.isAuthorizationControlEnabled ? (CBATTError.Code.insufficientAuthorization, Data()) : self.annunciationStatusCharacteristic.onRead() }
        )
        
        let charStatuReaderControlPoint = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.write),
            permissions: CBAttributePermissions.writeable,
            _onWrite: { (data, _) in return self.isAuthorizationControlEnabled ? CBATTError.Code.insufficientAuthorization : self.statusReaderControlPoint.onWrite(data) },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        let charCommandControlPoint = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.write),
            permissions: CBAttributePermissions.writeable,
            _onWrite: { (data, _) in return self.isAuthorizationControlEnabled ? CBATTError.Code.insufficientAuthorization : self.commandControlPoint.onWrite(data) },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        let charCommandData = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.commandData.cbUUID,
            properties: CBCharacteristicProperties.notify,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        let charRACP = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.write),
            permissions: CBAttributePermissions.writeable,
            _onWrite: { (data, _) in return self.isAuthorizationControlEnabled ? CBATTError.Code.insufficientAuthorization : self.recordAccessControlPoint.onWrite(data) },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )

        let charHistoryData = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.historyData.cbUUID,
            properties: CBCharacteristicProperties.notify,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )

        characteristicsInsulinDelivery = [
            charFeature,
            charStatus,
            charStatusChanged,
            charAnnunciationStatus,
            charStatuReaderControlPoint,
            charCommandControlPoint,
            charCommandData,
            charRACP,
            charHistoryData
        ]

        self.gattServer.createService(InsulinDeliveryCharacteristicUUID.service.cbUUID, primary: true, withCharacteristics: characteristicsInsulinDelivery)
        
        // Battery service

        let charBatteryLevel = CallbackCharacteristic(
            uuid: BatteryCharacteristicUUID.batteryLevel.cbUUID,
            properties: CBCharacteristicProperties.notify.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.batteryLevelCharacteristic.onRead() }
        )

        characteristicsBattery = [
            charBatteryLevel
        ]

        self.gattServer.createService(BatteryCharacteristicUUID.batteryLevel.cbUUID, primary: true, withCharacteristics: characteristicsBattery)
        
        // Device Information Service

        let charManufacturerName = CallbackCharacteristic(
            uuid: DeviceInfoCharacteristicUUID.manufacturerNameString.cbUUID,
            properties: CBCharacteristicProperties.read,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.deviceInformationCharacteristics.onReadManufacturerName() }
        )

        let charModelNumber = CallbackCharacteristic(
            uuid: DeviceInfoCharacteristicUUID.modelNumberString.cbUUID,
            properties: CBCharacteristicProperties.read,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.deviceInformationCharacteristics.onReadModelNumber() }
        )

        let charSerialNumber = CallbackCharacteristic(
            uuid: DeviceInfoCharacteristicUUID.serialNumberString.cbUUID,
            properties: CBCharacteristicProperties.read,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.deviceInformationCharacteristics.onReadSerialNumber() }
        )

        let charFirmwareRevision = CallbackCharacteristic(
            uuid: DeviceInfoCharacteristicUUID.firmwareRevisionString.cbUUID,
            properties: CBCharacteristicProperties.read,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.deviceInformationCharacteristics.onReadFirmwareRevision() }
        )

        let charHardwareRevision = CallbackCharacteristic(
            uuid: DeviceInfoCharacteristicUUID.hardwareRevisionString.cbUUID,
            properties: CBCharacteristicProperties.read,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.deviceInformationCharacteristics.onReadHardwareRevision() }
        )

        let charSoftwareRevision = CallbackCharacteristic(
            uuid: DeviceInfoCharacteristicUUID.softwareRevisionString.cbUUID,
            properties: CBCharacteristicProperties.read,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.deviceInformationCharacteristics.onReadSoftwareRevision() }
        )

        let charUniqueDeviceIdentifier = CallbackCharacteristic(
            uuid: DeviceInfoCharacteristicUUID.uniqueDeviceIdentifierString.cbUUID,
            properties: CBCharacteristicProperties.read,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.deviceInformationCharacteristics.onReadUniqueDeviceIdentifier() }
        )

        characteristicsDeviceInformation = [
            charManufacturerName,
            charModelNumber,
            charSerialNumber,
            charFirmwareRevision,
            charHardwareRevision,
            charSoftwareRevision,
            charUniqueDeviceIdentifier
        ]
        
        self.gattServer.createService(DeviceInfoCharacteristicUUID.service.cbUUID, primary: true, withCharacteristics: characteristicsDeviceInformation)
        
        // Device Time
        let charDTFeature = CallbackCharacteristic(
            uuid: DeviceTimeCharacteristicUUID.feature.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.isAuthorizationControlEnabled ? (CBATTError.Code.insufficientAuthorization, Data()) : self.deviceTimeFeatureCharacteristic.onRead() }
        )
        
        let charParameter = CallbackCharacteristic(
            uuid: DeviceTimeCharacteristicUUID.parameters.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.deviceTimeParameterCharacteristic.onRead() }
        )
        
        let charDeviceTime = CallbackCharacteristic(
            uuid: DeviceTimeCharacteristicUUID.deviceTime.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.deviceTimeCharacteristic.onRead() }
        )
        
        let charDeviceTimeControlPoint = CallbackCharacteristic(
            uuid: DeviceTimeCharacteristicUUID.controlPoint.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.write),
            permissions: CBAttributePermissions.writeable,
            _onWrite: { (data, _) in return self.isAuthorizationControlEnabled ? CBATTError.Code.insufficientAuthorization : self.deviceTimeControlPoint.onWrite(data) },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        characteristicsDeviceTime = [
            charDTFeature,
            charParameter,
            charDeviceTime,
            charDeviceTimeControlPoint
        ]

        self.gattServer.createService(DeviceTimeCharacteristicUUID.service.cbUUID, primary: true, withCharacteristics: characteristicsDeviceTime)
        
        // Authorization Control
        let charACStatus = CallbackCharacteristic(
            uuid: ACCharacteristicUUID.status.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.authorizationStatusCharacteristic.onRead() }
        )
        
        let charACControlPoint = CallbackCharacteristic(
            uuid: ACCharacteristicUUID.controlPoint.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.write),
            permissions: CBAttributePermissions.writeable,
            _onWrite: { (data, _) in return self.authorizationControlPoint.onWrite(data) },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        let charACDataIn = CallbackCharacteristic(
            uuid: ACCharacteristicUUID.dataIn.cbUUID,
            properties: CBCharacteristicProperties.write,
            permissions: CBAttributePermissions.writeable,
            _onWrite: { (data, _) in return self.authorizationDataCharacteristic.onWrite(data) },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        let charACDataOutNotify = CallbackCharacteristic(
            uuid: ACCharacteristicUUID.dataOutNotify.cbUUID,
            properties: CBCharacteristicProperties.notify,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        let charACDataOutIndicate = CallbackCharacteristic(
            uuid: ACCharacteristicUUID.dataOutIndicate.cbUUID,
            properties: CBCharacteristicProperties.indicate,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
                
        characteristicsAuthorizationControl = [
            charACStatus,
            charACControlPoint,
            charACDataIn,
            charACDataOutNotify,
            charACDataOutIndicate
        ]

        self.gattServer.createService(ACCharacteristicUUID.service.cbUUID, primary: true, withCharacteristics: characteristicsAuthorizationControl)
        
        // Immediate Alert
        let charAlertLevel = CallbackCharacteristic(
            uuid: ImmediateAlertCharacteristicUUID.alertLevel.cbUUID,
            properties: CBCharacteristicProperties.writeWithoutResponse,
            permissions: CBAttributePermissions.writeable,
            _onWrite: { (data, _) in return self.alertLevelCharacteristic.onWrite(data) },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        characteristicsImmediateAlert = [
            charAlertLevel
        ]
        
        self.gattServer.createService(ImmediateAlertCharacteristicUUID.service.cbUUID, primary: true, withCharacteristics: characteristicsImmediateAlert)
        
        self.gattServer.addService()
        self.gattServer.startAdvertising()
        
        deliveryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            guard self.status.pumpState.deviceInformation?.therapyControlState == .run else {
                guard self.operationalState == .priming else { return }
                
                self.status.updatePriming()
                if self.operationalState != .priming {
                    self.triggerStatusIndications(for: [.operationalStateChanged])
                    self.delegate?.mockPumpDidUpdate(self)
                }
                return
            }
            
            let reservoirRemainingOld = self.status.reservoirRemaining
            let bolusDeliverdOld = self.status.bolusDelivered
            let basalDeliverdOld = self.status.basalDelivered
            let activeBasalRateOld = self.status.activeBasalRate
            let activeBolusDeliveryStatus = self.status.activeBolusDeliveryStatus
            
            self.status.updateDeliveryIfNeeded()
            var statusChanges = IDStatusChangedFlag.allZeros
            if reservoirRemainingOld != self.status.reservoirRemaining {
                statusChanges.insert(.reservoirStatusChanged)
            }
            if bolusDeliverdOld != self.status.bolusDelivered {
                statusChanges.insert(.activeBolusStatusChanged)
                statusChanges.insert(.totalDailyInsulinStatusChanged)
            }
            if basalDeliverdOld != self.status.basalDelivered {
                statusChanges.insert(.totalDailyInsulinStatusChanged)
            }
            if activeBasalRateOld != self.status.activeBasalRate {
                statusChanges.insert(.activeBasalRateStatusChanged)
            }
            if activeBolusDeliveryStatus != self.status.activeBolusDeliveryStatus {
                statusChanges.insert(.activeBolusStatusChanged)
            }
            
            self.triggerStatusIndications(for: statusChanges)
        }
    }
    
    func triggerStatusIndications(for statusChanges: IDStatusChangedFlag) {
        guard statusChanges != .allZeros,
              statusChanges != statusChangedCharacteristic.flags
        else { return }
        
        if statusChanges.contains(.therapyControlStateChanged) ||
            statusChanges.contains(.operationalStateChanged) ||
            statusChanges.contains(.reservoirStatusChanged)
        {
            statusCharacteristic.triggerIndication()
        }
        
        if statusChanges.contains(.annunciationStatusChanged) {
            annunciationStatusCharacteristic.triggerAnnunciation(for: status.currentAnnunciation)
        }
        
        statusChangedCharacteristic.triggerIndication(for: statusChanges)
    }
}

// MARK: - E2E Protecdtion Delegate

extension MockInsulinDeliveryPump: E2EProtectionDelegate {
    public var isE2EProtectionSupported: Bool {
        featureCharacteristic.flags.contains(.supportedE2EProtection)
    }
}

// MARK: - Status Characteristic Delegate

extension MockInsulinDeliveryPump: IDStatusCharacteristicDelegate {
    public var therapyState: InsulinTherapyControlState {
        status.therapyState
    }
    
    public var operationalState: PumpOperationalState {
        status.operationalState
    }
    
    public var reservoirRemaining: Double {
        status.reservoirRemaining
    }
}

// MARK: - Status Reader Control Point Delegate

extension MockInsulinDeliveryPump: IDStatusReaderControlPointCharacteristicDelegate {
    public func getActiveBolusIDs() -> [BolusID] {
        guard let bolusID = status.activeBolusDeliveryStatus.id else {
            return []
        }
        return [bolusID]
    }
    
    public func isBolusIDActive(_ bolusID: BolusID) -> Bool {
        bolusID == status.activeBolusDeliveryStatus.id
    }
    
    public var activeBolusDeliveryStatus: BolusDeliveryStatus {
        status.activeBolusDeliveryStatus
    }
    
    public func getActiveBolusDelivery(for bolusID: BolusID, bolusValueSelection: BolusValueSelection) -> (bolusType: BolusType, fastAmount: Double, extendedAmount: Double, duration: TimeInterval, delay: TimeInterval?, templateNumber: UInt8?, activationType: IDBolusActivationType?, isMeal: Bool, isCorrection: Bool) {
        status.updateDelivery()
        
        guard status.activeBolusDeliveryStatus != .noActiveBolus else {
            return (bolusType: .undetermined, fastAmount: 0, extendedAmount: 0, duration: 0, delay: nil, templateNumber: nil, activationType: nil, isMeal: false, isCorrection: false)
        }
        
        let duration = Date().timeIntervalSince(status.activeBolusDeliveryStatus.startTime ?? Date().addingTimeInterval(-TimeInterval.seconds(10)))
        let amount: Double
        switch bolusValueSelection {
        case .programmed:
            amount = status.activeBolusDeliveryStatus.insulinProgrammed
        case .delivered:
            amount = min(duration * status.estimatedDeliveryRate, status.activeBolusDeliveryStatus.insulinProgrammed)
        case .remaining:
            let amountDelivered = min(duration * status.estimatedDeliveryRate, status.activeBolusDeliveryStatus.insulinProgrammed)
            amount = max(status.activeBolusDeliveryStatus.insulinProgrammed - amountDelivered, 0)
        }
        return (bolusType: .fast, fastAmount: amount, extendedAmount: 0, duration: 0, delay: nil, templateNumber: nil, activationType: .manualBolus, isMeal: false, isCorrection: false)
    }
    
    public var activeBasalRate: Double? {
        status.activeBasalRate
    }
    
    public var isTempBasal: Bool {
        status.tempBasal != nil
    }
    
    public func getActiveBasalDelivery() -> (profileNumber: UInt8, rate: Double, tempBasalType: TempBasalType?, tempBasalRate: Double?, tempBasalDurationProgrammed: TimeInterval?, tempBasalDurationRemaining: TimeInterval?, tempBasalTemplateNumber: UInt8?, basalDeliveryContext: BasalDeliveryContext?) {
        status.updateDelivery()
        let basalRate = status.basalProfile?.rate(at: Date())
        
        var tempBasalType: TempBasalType? = nil
        var tempBasalRate: Double? = nil
        var tempBasalDurationProgrammed: TimeInterval? = nil
        var tempBasalDurationRemaining: TimeInterval? = nil
        var basalDeliveryContext: BasalDeliveryContext = .remoteControl
        if let tempBasal = status.tempBasal {
            tempBasalType = .absolute
            basalDeliveryContext = .aidController
            tempBasalRate = tempBasal.rate
            tempBasalDurationProgrammed = tempBasal.duration
            tempBasalDurationRemaining = min(tempBasal.endTime?.timeIntervalSince(Date()) ?? 0, 0)
        }
        return (profileNumber: 1, rate: basalRate ?? 0, tempBasalType: tempBasalType, tempBasalRate: tempBasalRate, tempBasalDurationProgrammed: tempBasalDurationProgrammed, tempBasalDurationRemaining: tempBasalDurationRemaining, tempBasalTemplateNumber: nil, basalDeliveryContext: basalDeliveryContext)
    }
    
    public func getTotalDailyInsulin() -> (bolusDelivered: Double, basalDelivered: Double) {
        status.updateDelivery()
        return (bolusDelivered: 15.5, basalDelivered: 8.2)
    }
    
    public func getCounterDuration(for counterType: CounterType, counterValueSelection: CounterValueSelection) -> TimeInterval {
        let remaining: TimeInterval
        let elasped: TimeInterval
        switch counterType {
        case .lifetime:
            remaining = .days(4)
            elasped = .days(6)
        case .loanerTime:
            remaining = .days(60)
            elasped = .days(180)
        case .reservoirInsulinOperationTime:
            remaining = .hours(12)
            elasped = .hours(70)
        case .warrantyTime:
            remaining = .days(10)
            elasped = .days(90)
        }
        
        return counterValueSelection == .elasped ? elasped : remaining
    }
    
    public func getDeliveredInsulin() -> (bolusDelivered: Double, basalDelivered: Double) {
        status.updateDelivery()
        return (status.bolusDelivered, status.basalDelivered)
    }
    
    public func getInsulinOnBoard() -> (amount: Double, duration: TimeInterval?) {
        status.updateDelivery()
        return (amount: 2.4, duration: .minutes(60))
    }
}

// MARK: - Command Control Point Delegate
extension MockInsulinDeliveryPump: IDCommandControlPointCharacteristicDelegate {
    
    public var basalProfileTemplateNumber: TemplateNumber {
        1
    }
    
    public var basalProfile: [BasalSegment] {
        status.basalProfile ?? []
    }

    public var basalProfileConfigured: Bool {
        !(basalProfile.isEmpty)
    }
    
    public var basalProfileComplete: Bool {
        basalProfile.isComplete
    }

    public var basalRateProfileActivated: Bool {
        status.basalRateProfileActivated
    }
    
    public var maxBolusAmount: Double {
        status.maxBolusAmount
    }

    public var isBolusActive: Bool {
        status.bolus != nil && !status.bolus!.isFinished(at: Date())
    }

    public func setTherapyControlState(_ state: InsulinTherapyControlState) -> Bool {
        guard operationalState == .ready,
              basalProfileComplete,
              basalRateProfileActivated
        else {
            return false
        }
        
        let oldState = status.pumpState.deviceInformation?.therapyControlState ?? .undetermined
        status.pumpState.deviceInformation?.therapyControlState = state
        let eventData = TherapyControlStateChangedHistoryEvent.createEventData(from: oldState, to: state)
        recordAccessControlPoint.createHistoryEvent(for: .therapyControlStateChanged, eventData: eventData)
        triggerStatusIndications(for: [.therapyControlStateChanged, .historyEventRecordedChanged])
        return true
    }
    
    public func issueGeneralAnnunciation(annunciationType: AnnunciationType, auxiliaryData: Data? = nil) {
        guard let annunciation = annunciationStatusCharacteristic.generateAnnunciation(for: annunciationType, auxiliaryData: auxiliaryData) else { return }
        status.addAnnunciation(annunciation)
        let eventData = AnnunciationStatusChangedHistoryEvent.createEventDataPart1(identifier: annunciation.identifier, type: annunciation.type, status: .pending)
        recordAccessControlPoint.createHistoryEvent(for: .annunciationStatusChangedPart1, eventData: eventData)
        triggerStatusIndications(for: [.annunciationStatusChanged, .historyEventRecordedChanged])
    }
    
    public func issueBolusCancelledAnnunciation(for bolusDeliveryStatus: BolusDeliveryStatus) {
        issueGeneralAnnunciation(annunciationType: .bolusCanceled, auxiliaryData:bolusDeliveryStatus.auxiliaryData)
    }

    public func changeAnnunciationStatus(_ annunciationStatus: AnnunciationStatus, for identifier: AnnunciationIdentifier) -> Bool {
        guard let annunciation = status.annunciation(with: identifier) else { return false }
        
        let eventData = AnnunciationStatusChangedHistoryEvent.createEventDataPart1(identifier: identifier, type: annunciation.type, status: annunciationStatus)
        recordAccessControlPoint.createHistoryEvent(for: .annunciationStatusChangedPart1, eventData: eventData)
        var statusChanges: IDStatusChangedFlag = [.historyEventRecordedChanged]
        
        if annunciationStatus == .confirmed {
            status.confirmAnnunciation(annunciation)
            statusChanges.insert(.annunciationStatusChanged)
        } else if annunciationStatus == .snoozed {
            status.snoozeAnnunciation(annunciation)
            statusChanges.insert(.annunciationStatusChanged)
        }

        triggerStatusIndications(for: statusChanges)
        return true
    }
    
    public func updateBasalProfile(basalSegment: BasalSegment) {
        if status.basalProfile == nil {
            status.basalProfile = []
        }
        
        if basalSegment.index <= status.basalProfile!.count  {
            status.basalProfile![Int(basalSegment.index-1)] = basalSegment
        } else {
            status.basalProfile!.append(basalSegment)
        }
        let eventData = BasalRateProfileTimeBlockChangedHistoryEvent.createEventData(templateNumber: basalProfileTemplateNumber, timeBlockNumber: basalSegment.index, duration: basalSegment.duration, rate: basalSegment.rate)
        recordAccessControlPoint.createHistoryEvent(for: .basalRateProfileTimeBlockChanged, eventData: eventData)
        triggerStatusIndications(for: [.activeBasalRateStatusChanged, .historyEventRecordedChanged])
    }
    
    public func resetBasalProfile() {
        status.basalProfile?.removeAll()
    }
    
    public func setTempBasal(rate: Double, duration: TimeInterval, deliveryContext: BasalDeliveryContext, now: Date, changeTempBasal: Bool) -> Bool {
        guard (status.tempBasal == nil && !changeTempBasal) ||
                (status.tempBasal != nil && changeTempBasal) ||
                (status.tempBasal?.isFinished(at: now) ?? false && !changeTempBasal)
        else { return false }
        
        let tempBasal = status.tempBasal
        
        status.setTempBasal(unitsPerHour: rate, duration: duration)
        var eventData = TempBasalAdjustmentStartedHistoryEvent.createEventData(type: .absolute, rate: rate, duration: duration)
        recordAccessControlPoint.createHistoryEvent(for: .tempBasalRateAdjustmentStarted, eventData: eventData)
        
        if let tempBasal {
            eventData = DeliveredBasalRateChangedHistoryEvent.createEventData(oldRate: tempBasal.rate, newRate: rate)
        } else if let basalRate = basalProfile.rate(at: Date()) {
            eventData = DeliveredBasalRateChangedHistoryEvent.createEventData(oldRate: basalRate, newRate: rate)
        }
        recordAccessControlPoint.createHistoryEvent(for: .deliveredBasalRateChanged, eventData: eventData)
        
        triggerStatusIndications(for: [.activeBasalRateStatusChanged, .historyEventRecordedChanged])

        return true
    }
    
    public func cancelTempBasal() -> Bool {
        let now = Date()
        guard let tempBasal = status.tempBasal,
              !tempBasal.isFinished(at: now)
        else { return false }
        
        let duration = now.timeIntervalSince(tempBasal.startTime)
        status.cancelTempBasal(at: now) { _ in }
        var eventData = TempBasalAdjustmentEndedHistoryEvent.createEventData(type: .absolute, effectiveDuration: duration, endReason: .canceled)
        recordAccessControlPoint.createHistoryEvent(for: .tempBasalRateAdjustmentEnded, eventData: eventData)
        
        if let basalRate = basalProfile.rate(at: Date()) {
            eventData = DeliveredBasalRateChangedHistoryEvent.createEventData(oldRate: tempBasal.rate, newRate: basalRate)
            recordAccessControlPoint.createHistoryEvent(for: .deliveredBasalRateChanged, eventData: eventData)
        }
        
        issueGeneralAnnunciation(annunciationType: .tempBasalCanceled)
        
        triggerStatusIndications(for: [.activeBasalRateStatusChanged, .historyEventRecordedChanged])
        
        return true
    }
    
    public func setBolus(_ amount: Double, activationType: IDBolusActivationType) -> BolusID {
        let activeBolusDeliveryStatus = status.setBolus(amount)
        
        var eventData = BolusProgrammedHistoryEvent.createEventDataPart1(id: activeBolusDeliveryStatus.id!, type: .fast, fastAmount: amount, extendedAmount: 0, duration: 0)
        recordAccessControlPoint.createHistoryEvent(for: .bolusProgrammedPart1, eventData: eventData)
        
        eventData = BolusProgrammedHistoryEvent.createEventDataPart2()
        recordAccessControlPoint.createHistoryEvent(for: .bolusProgrammedPart2, eventData: eventData)
        
        triggerStatusIndications(for: [.activeBolusStatusChanged, .historyEventRecordedChanged])
        
        return activeBolusDeliveryStatus.id!
    }
    
    public func cancelBolus(for bolusID: BolusID) -> Bool {
        let now = Date()
        guard status.activeBolusDeliveryStatus.id == bolusID,
              let bolus = status.bolus,
              !bolus.isFinished(at: now)
        else {
            return false
        }
        status.cancelBolus(at: now, completion: { result in
            switch result {
            case .success(let activeBolusDeliveryStatus):
                var eventData = BolusDeliveredHistoryEvent.createEventDataPart1(id: activeBolusDeliveryStatus.id!, type: .fast, fastAmount: activeBolusDeliveryStatus.insulinDelivered, extendedAmount: 0, duration: 0)
                self.recordAccessControlPoint.createHistoryEvent(for: .bolusDeliveredPart1, eventData: eventData)
                eventData = BolusDeliveredHistoryEvent.createEventDataPart2(timeOffset: 0, endReason: .canceled)
                self.recordAccessControlPoint.createHistoryEvent(for: .bolusDeliveredPart2, eventData: eventData)
                self.issueBolusCancelledAnnunciation(for: activeBolusDeliveryStatus)
                self.triggerStatusIndications(for: [.activeBolusStatusChanged, .historyEventRecordedChanged])
            default:
                break
            }
        })
        return true
    }
    
    public func activateBasalRateProfile() {
        guard status.basalRateProfileActivated == false else { return }
        let eventData = ProfileTemplateActivatedHistoryEvent.createEventData(type: .basalRate, oldTemplateNumber: 0, newTemplateNumber: basalProfileTemplateNumber)
        recordAccessControlPoint.createHistoryEvent(for: .profileTemplateActivated, eventData: eventData)
        status.basalRateProfileActivated = true
        triggerStatusIndications(for: [.activeBasalRateStatusChanged, .historyEventRecordedChanged])
    }
    
    public func startPriming(_ amount: Double) -> Bool {
        guard status.therapyState != .run else { return false }

        status.startPriming(amount)
        let eventData = PrimingStartedHistoryEvent.createEventData(amount: amount)
        recordAccessControlPoint.createHistoryEvent(for: .primingStarted, eventData: eventData)
        triggerStatusIndications(for: [.operationalStateChanged, .historyEventRecordedChanged])
        return true
    }
    
    public func stopPriming() -> Bool {
        guard status.priming != nil,
              let deliveredAmount = status.stopPriming()
        else { return false }
        
        let eventData = PrimingDoneHistoryEvent.createEventData(deliveredAmount: deliveredAmount, terminationReason: .abortedByUser)
        recordAccessControlPoint.createHistoryEvent(for: .primingDone, eventData: eventData)
        triggerStatusIndications(for: [.operationalStateChanged, .historyEventRecordedChanged])
        return true
    }
    
    public func setMaxBolusAmount(_ amount: Double) {
        status.maxBolusAmount = amount
        let eventData = MaxBolusAmountChangedHistoryEvent.createEventData(oldAmount: maxBolusAmount, newAmount: amount)
        recordAccessControlPoint.createHistoryEvent(for: .maxBolusAmountChanged, eventData: eventData)
        triggerStatusIndications(for: [.historyEventRecordedChanged])
    }
    
    public func updateInitialReservoirFillLevel(_ fillLevel: Double) {
        status.pumpState.deviceInformation?.reservoirLevel = fillLevel
        status.initialReservoirLevel = Int(fillLevel)
    }
}

// MARK: - Authorization Control Point Delegate
extension MockInsulinDeliveryPump: ACControlPointDelegate {
    public var currentKeyID: KeyID? {
        guard isSecurityEstablished else { return nil }
        return ecdhKeyID
    }
    
    public func getAuthorizationFeatures() -> Data {
        let qualityOfProtection : QualityOfProtection = [.confidentiality, .integrity, .authentication]
        var flags : FeaturesFlag = [.descriptorsSupported, .resourceHandleToUUIDMapSupported, .initiatePairingSupported, .keyExchangeECDHSupported, .keyExchangeKDFSupported, .invalidateEstablishedSecuritySupported, .protectedResourceWriteSupported, .protectedResourceReadSupported, .protectedResourceNotificationSupported, .protectedResourceIndicationSupported , .keyFormatServerUncompressedPlainSupported, .keyFormatClientUncompressedPlainSupported]
        let oobKeyExchangeCapabilities : OOBCapability = [.string, .onPaper]
        let confirmationStaticOOBNumberCapabilities : OOBCapability = [.string, .onPaper]
        let confirmationInputNumberMaxValue : UInt32 = 0
        let confirmationInputCapabilities : ConfirmationInputCapability = []
        let confirmationOutputNumberMaxValue : UInt32 = 1000
        let confirmationOutputCapabilities : ConfirmationOutputCapability = [.outputNumeric]
                
        var features = Data(flags.rawValue)
        features.append(qualityOfProtection.rawValue)
        features.append(oobKeyExchangeCapabilities.rawValue)
        features.append(confirmationStaticOOBNumberCapabilities.rawValue)
        features.append(confirmationInputNumberMaxValue)
        features.append(confirmationInputCapabilities.rawValue)
        features.append(confirmationOutputNumberMaxValue)
        features.append(confirmationOutputCapabilities.rawValue)

        return features
    }
    
    public func getRestrictionMap(for restrictionMapID: RestrictionMapID, handleFilter: ResourceHandle) -> Data {
        let dataSizeZero: UInt8 = 0
        
        var restrictionMapRecordRestrictionMapID = Data(RecordTypeRestrictionMap.restrictionMapID.rawValue)
        restrictionMapRecordRestrictionMapID.append(restrictionMapID)
        restrictionMapRecordRestrictionMapID.append(dataSizeZero)
                
        let defaultSecurityConfiguration: SecurityConfigurationID = 1
        var restrictionMapRecordDefaultSecurityConfiguration = Data(RecordTypeRestrictionMap.defaultInformationSecurityConfiguration.rawValue)
        restrictionMapRecordDefaultSecurityConfiguration.append(defaultSecurityConfiguration)
        restrictionMapRecordRestrictionMapID.append(dataSizeZero)
        
        var restrictionMap = restrictionMapRecordRestrictionMapID
        restrictionMap.append(contentsOf: restrictionMapRecordDefaultSecurityConfiguration)
        
        return restrictionMap
    }
    
    public func getRestrictionMapIDList() -> Data {
        var restrictionMapIDList = Data(restrictionMapID)
        restrictionMapIDList.append(securityConfigurationID)
        return restrictionMapIDList
    }
    
    public func resourceHandleToUUIDMap() -> [[CBUUID: ResourceHandle]] {
        return [
            [InsulinDeliveryCharacteristicUUID.service.cbUUID: 1,
             InsulinDeliveryCharacteristicUUID.features.cbUUID: 2,
             InsulinDeliveryCharacteristicUUID.status.cbUUID: 3,
             InsulinDeliveryCharacteristicUUID.statusChanged.cbUUID: 4,
             InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID: 5,
             InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID: 6,
             InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID: 7,
             InsulinDeliveryCharacteristicUUID.commandData.cbUUID: 8,
             InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID: 9,
             InsulinDeliveryCharacteristicUUID.historyData.cbUUID: 10],
            [DeviceTimeCharacteristicUUID.service.cbUUID: 11,
             DeviceTimeCharacteristicUUID.controlPoint.cbUUID: 12]
        ]
    }
    
    public func uuidForResourceHandle(_ resourceHandle: ResourceHandle) -> CBUUID? {
        let map = resourceHandleToUUIDMap()
        for entry in map {
            for (uuid, mapResourceHandle) in entry {
                if mapResourceHandle == resourceHandle {
                    return uuid
                }
            }
        }
        return nil
    }
    
    public func getInformationSecurityConfiguration(filter: SecurityConfigurationID) -> Data {
        let config1DataSize: UInt8 = 6
        let config1NumControls: UInt8 = 3

        var securityConfiguration = Data(RecordTypeSecurityConfiguration.informationSecurityConfigurationID.rawValue)
        securityConfiguration.append(securityConfigurationID)
        securityConfiguration.append(config1DataSize)
        securityConfiguration.append(config1NumControls)
        securityConfiguration.append(SecurityControlType.nonce.rawValue)
        securityConfiguration.append(SecurityControlType.mac.rawValue)
        securityConfiguration.append(SecurityControlType.authenticatedEncryptedATTPacket.rawValue)
        securityConfiguration.append(ecdhKeyID)
        
        return securityConfiguration
    }
    
    public func getKeyDescriptor(filter: KeyID) -> Data {
        // ECDH Record
        let ecdhKeyID: KeyID = 1
        let ecdhKeyRecordDataSize: UInt8 = 4
        
        var keyDescriptor = Data(KeyType.ecdh.rawValue)
        keyDescriptor.append(ecdhKeyID)
        keyDescriptor.append(ecdhKeyRecordDataSize)
        keyDescriptor.append(KeyFormat.plain.rawValue)
        keyDescriptor.append(KeyFormat.plain.rawValue)
        keyDescriptor.append(EllipticCurve.p256.rawValue)
        keyDescriptor.append(KeyDerivationFunction.hkdfSHA256.rawValue)
        
        // GCM Record
        let ivFixedField = Data(bigEndian: UInt32(0xcafeaffe))
        securityManager.configuration.generatedIVFixedField = ivFixedField
        let ivFixedFieldLittleEndian = Data(ivFixedField.reversed())
        let gcMKeyID: KeyID = 2
        let gcmRecordDataSize: UInt8 = 11
        let gcmRecordMACSize: UInt8 = 8
        let gcmRecordNonceSizeVariable: UInt8 = 8
        let gcmRecordNonceSizeFixed: UInt8 = UInt8(ivFixedField.count)
        let gcmRecordIVFixedField: UInt32 = ivFixedFieldLittleEndian[ivFixedFieldLittleEndian.startIndex...].to(UInt32.self)

        keyDescriptor.append(KeyType.aesGCM.rawValue)
        keyDescriptor.append(gcMKeyID)
        keyDescriptor.append(gcmRecordDataSize)
        keyDescriptor.append(ecdhKeyID)
        keyDescriptor.append(MessageType.protectedResourceValue.rawValue)
        keyDescriptor.append(gcmRecordMACSize)
        keyDescriptor.append(NonceType.sequenceNumberDifferentFixedParts.rawValue)
        keyDescriptor.append(gcmRecordNonceSizeVariable)
        keyDescriptor.append(gcmRecordNonceSizeFixed)
        keyDescriptor.append(gcmRecordIVFixedField)
        
        return keyDescriptor
    }
    
    public func invalidateKey() {
        isSecurityEstablished = false
        sharedKeyData?.removeAll()
    }

    public func sendSecureIndication(_ message: Data, to resourceHandle: ResourceHandle) {
        authorizationDataCharacteristic.sendSecureIndication(message, to: resourceHandle)
    }
    
    public func sendSecureNotification(_ message: Data, to resourceHandle: ResourceHandle) {
        authorizationDataCharacteristic.sendSecureNotification(message, to: resourceHandle)
    }
}

// MARK: - Authorization Control Point Delegate
extension MockInsulinDeliveryPump: ACDataCharacteristicDelegate {
    public func processRequest(_ request: Data, for resourceHandle: BluetoothCommonKit.ResourceHandle) {
        let uuid = uuidForResourceHandle(resourceHandle)
        let response: Data?
        switch uuid {
        case InsulinDeliveryCharacteristicUUID.features.cbUUID:
            response = featureCharacteristic.createData()
        case InsulinDeliveryCharacteristicUUID.status.cbUUID:
            response = statusCharacteristic.createData()
        case InsulinDeliveryCharacteristicUUID.statusChanged.cbUUID:
            response = statusChangedCharacteristic.createData()
        case InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID:
            response = annunciationStatusCharacteristic.createDataForCurrentAnnunciation()
        case InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID:
            response = statusReaderControlPoint.responseForRequest(request)
        case InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID:
            response = commandControlPoint.responseForRequest(request)
        case InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID:
            response = recordAccessControlPoint.responseForRequest(request)
        case DeviceTimeCharacteristicUUID.controlPoint.cbUUID:
            response = deviceTimeControlPoint.responseForRequest(request)
        case DeviceTimeCharacteristicUUID.feature.cbUUID:
            response = deviceTimeFeatureCharacteristic.createData()
        default:
            fatalError("Unsupported UUID: \(String(describing: uuid))")
        }
        
        guard let response else {
            ConsoleOut.shared.logMessage(message: "\(#function): No response to send to secure request")
            return
        }
        
        let result = authorizationDataCharacteristic.prepareSecureMessageSegments(response, resourceHandle: resourceHandle)
        switch result {
        case .success(let segmentedSecureResponse):
            sendSegmentedSecureResponse(segmentedSecureResponse)
        case .failure(let error):
            ConsoleOut.shared.logMessage(message: "\(#function): Failed to prepare secure message segments: \(error)")
        }
    }
    
    func sendSegmentedSecureResponse(_ segmentedSecureResponse: [Data], indicate: Bool = true) {
        let uuid: CBUUID?
        if indicate,
           gattServer.isCharacteristicSubscribed(ACCharacteristicUUID.dataOutIndicate.cbUUID) == true
        {
            uuid = ACCharacteristicUUID.dataOutIndicate.cbUUID
        } else if !indicate,
                  gattServer.isCharacteristicSubscribed(ACCharacteristicUUID.dataOutNotify.cbUUID) == true
        {
            uuid = ACCharacteristicUUID.dataOutNotify.cbUUID
        } else {
            uuid = nil
            ConsoleOut.shared.logMessage(message: "\(#function): AC data out is not configured for indications or notifications")
        }
        
        guard let uuid else { return }
        
        for secureResponse in segmentedSecureResponse {
            let valuepair = UUIDValuePair(
                uuid: uuid,
                value: secureResponse
            )
            ConsoleOut.shared.logMessage(message: "\(#function): \(valuepair.description) (uuid: \(uuid))")
            messageQueue.addQueueItem(valuepair)
        }
    }
}

// MARK: - Security Manager Delegate
extension MockInsulinDeliveryPump: SecurityManagerDelegate {
    public func securityManagerDidEstablishedSecurity(_ securityManager: BluetoothCommonKit.SecurityManager) {
        isSecurityEstablished = true
    }
    
    public func securityManagerDidUpdateConfiguration(_ securityManager: BluetoothCommonKit.SecurityManager) {
        // nop
    }
}
