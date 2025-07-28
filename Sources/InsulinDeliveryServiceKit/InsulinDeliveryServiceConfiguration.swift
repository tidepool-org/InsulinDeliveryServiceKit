//
//  InsulinDeliveryServiceConfiguration.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import BluetoothCommonKit

extension PeripheralManager.Configuration {
    public static var insulinDeliveryServiceConfiguration: PeripheralManager.Configuration {
        return PeripheralManager.Configuration(
            serviceCharacteristics: [
                InsulinDeliveryCharacteristicUUID.service.cbUUID: [
                    InsulinDeliveryCharacteristicUUID.statusChanged.cbUUID,
                    InsulinDeliveryCharacteristicUUID.status.cbUUID,
                    InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID,
                    InsulinDeliveryCharacteristicUUID.features.cbUUID,
                    InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID,
                    InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID,
                    InsulinDeliveryCharacteristicUUID.commandData.cbUUID,
                    InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID,
                    InsulinDeliveryCharacteristicUUID.historyData.cbUUID
                ],
                DeviceInfoCharacteristicUUID.service.cbUUID: [
                    DeviceInfoCharacteristicUUID.manufacturerNameString.cbUUID,
                    DeviceInfoCharacteristicUUID.modelNumberString.cbUUID,
                    DeviceInfoCharacteristicUUID.systemID.cbUUID,
                    DeviceInfoCharacteristicUUID.firmwareRevisionString.cbUUID
                ],
            ],
            notifyingCharacteristics: [
                InsulinDeliveryCharacteristicUUID.service.cbUUID: [
                    InsulinDeliveryCharacteristicUUID.statusChanged.cbUUID,
                    InsulinDeliveryCharacteristicUUID.status.cbUUID,
                    InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID,
                    InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID,
                    InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID,
                    InsulinDeliveryCharacteristicUUID.commandData.cbUUID,
                    InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID,
                    InsulinDeliveryCharacteristicUUID.historyData.cbUUID
                ],
            ],
            valueUpdateMacros: [:]
        )
    }
}
