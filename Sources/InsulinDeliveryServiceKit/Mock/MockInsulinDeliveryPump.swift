//
//  MockInsulinDeliveryPump.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-04-07.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import BluetoothCommonKit

// The Mock Insulin Delivery Pump is intended to support the integration of a pump that implements the Blueooth Insulin Delivery Service interface.
class MockInsulinDeliveryPump {
    let gattServer: GATTService
    var lockedStatus: Locked<MockInsulinDeliveryPumpStatus>
    
    // characteristics
    let featureCharacteristic: IDFeatureCharacteristic
    let statusCharacteristic: IDStatusCharacteristic
    let statusChangedCharacteristic: IDStatusChangedCharacteristic
    let annunciationStatusCharacteristic: IDAnnunciationStatusCharacteristic
    let statusReaderControlPoint: IDStatusReaderControlPoint
    let commandControlPoint: IDCommandControlPoint
//    let racp: IDRecordAccessControlPoint
    let batteryLevelCharacteristic: BatteryLevelCharacteristic
    let deviceInformationCharacteristics: DeviceInformationCharacteristics
    // TODO device time characteristics

    var characteristicsInsulinDelivery: [CallbackCharacteristic] = []
    var characteristicsBattery: [CallbackCharacteristic] = []
    var characteristicsDeviceInformation: [CallbackCharacteristic] = []
    
    var status: MockInsulinDeliveryPumpStatus {
        get {
            return lockedStatus.value
        }
        set {
            var oldStatus: MockInsulinDeliveryPumpStatus?
            lockedStatus.mutate { status in
                oldStatus = status
                status = newValue
            }
            // TODO add behaviour as needed
        }
    }
    
    init(gattServer: GATTService,
         messageQueue: MessagingQueue,
         status: MockInsulinDeliveryPumpStatus? = nil)
    {
        self.gattServer = gattServer
        let status = status ?? MockInsulinDeliveryPumpStatus()
        lockedStatus = Locked(status)
        
        featureCharacteristic = IDFeatureCharacteristic(messageQueue: messageQueue)
        statusCharacteristic = IDStatusCharacteristic(messageQueue: messageQueue)
        statusChangedCharacteristic = IDStatusChangedCharacteristic(messageQueue: messageQueue)
        annunciationStatusCharacteristic = IDAnnunciationStatusCharacteristic(messageQueue: messageQueue)
        statusReaderControlPoint = IDStatusReaderControlPoint(messageQueue: messageQueue)
        commandControlPoint = IDCommandControlPoint(messageQueue: messageQueue,
                                                    basalRateProfile: status.basalSegments ?? [],
                                                    basalRateProfileActivated: status.pumpState.deviceInformation?.pumpOperationalState == .ready)
        
        batteryLevelCharacteristic = BatteryLevelCharacteristic(messageQueue: messageQueue)
        deviceInformationCharacteristics = DeviceInformationCharacteristics(messageQueue: messageQueue)

        
        featureCharacteristic.e2eDelegate = self
        statusCharacteristic.e2eDelegate = self
        statusChangedCharacteristic.e2eDelegate = self
        statusReaderControlPoint.e2eDelegate = self
        annunciationStatusCharacteristic.e2eDelegate = self
        commandControlPoint.e2eDelegate = self
        
        // Insulin Delivery service
        
        let charFeature = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.features.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.featureCharacteristic.onRead() }
        )
        
        let charStatus = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.status.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.statusCharacteristic.onRead() }
        )
        
        let charStatusChanged = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.statusChanged.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.statusChangedCharacteristic.onRead() }
        )

        let charAnnunciationStatus = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.read),
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return self.annunciationStatusCharacteristic.onRead() }
        )
        
        let charStatuReaderControlPoint = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.write),
            permissions: CBAttributePermissions.writeable,
            _onWrite: { (data, _) in return self.statusReaderControlPoint.onWrite(data) },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        let charCommandControlPoint = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID,
            properties: CBCharacteristicProperties.indicate.symmetricDifference(.write),
            permissions: CBAttributePermissions.writeable,
            _onWrite: { (data, _) in return self.commandControlPoint.onWrite(data) },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        let charCommandData = CallbackCharacteristic(
            uuid: InsulinDeliveryCharacteristicUUID.commandData.cbUUID,
            properties: CBCharacteristicProperties.notify,
            permissions: CBAttributePermissions.readable,
            _onWrite: { (_,_) in return CBATTError.Code.writeNotPermitted },
            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        )
        
        //        let charRACP = CallbackCharacteristic(
        //            uuid: InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID,
        //            properties: CBCharacteristicProperties.indicate.symmetricDifference(.write),
        //            permissions: CBAttributePermissions.writeable,
        //            _onWrite: { (data, central) in return self.racp.onWrite(data, fromCentral: central) },
        //            _onRead: { return (CBATTError.Code.readNotPermitted, Data()) }
        //        )

        
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
            //            charRACP
            charHistoryData,
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
        
        // TODO Device Time Service
        
        
        self.gattServer.addService()
        self.gattServer.startAdvertising()
    }
    
}

extension MockInsulinDeliveryPump: E2EProtectionDelegate {
    var isE2EProtectionSupported: Bool {
        featureCharacteristic.flags.contains(.supportedE2EProtection)
    }
}
