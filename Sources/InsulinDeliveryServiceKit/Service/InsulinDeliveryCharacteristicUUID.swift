//
//  InsulinDeliveryCharacteristicUUID.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//
//
//  This is based on version 1.0 of the Insulin Delivery Service: https://www.bluetooth.com/specifications/specs/insulin-delivery-service-1-0/

import CoreBluetooth
import BluetoothCommonKit

public enum InsulinDeliveryCharacteristicUUID: String, CBUUIDDetails {
    case service = "183a"
    
    // Read, Indicate
    case statusChanged = "2b20"
    
    // Read, Indicate
    case status = "2b21"
    
    // Read, Indicate
    case annunciationStatus = "2b22"
    
    // Read
    case features = "2b23"
    
    // Write, Indicate
    case statusReaderControlPoint = "2b24"
    
    // Write, Indicate
    case commandControlPoint = "2b25"
    
    // Notify
    case commandData = "2b26"
    
    // Write, Indicate
    case recordAccessControlPoint = "2b27"
    
    // Notify
    case historyData = "2b28"

    var serviceName: String { "insulinDelivery" }

    public var name: String {
        switch self {
        case .service: return serviceName
        case .statusChanged: return serviceName + ".statusChanged"
        case .status: return serviceName + ".status"
        case .annunciationStatus: return serviceName + ".annunciationStatus"
        case .features: return serviceName + ".features"
        case .statusReaderControlPoint: return serviceName + ".statusReaderControlPoint"
        case .commandControlPoint: return serviceName + ".commandControlPoint"
        case .commandData: return serviceName + ".commandData"
        case .recordAccessControlPoint: return serviceName + ".recordAccessControlPoint"
        case .historyData: return serviceName + ".historyData"
        }
    }

    public var properties: [CBUUIDProperties] {
        switch self {
        case .service:
            return []
        case .statusChanged, .status, .annunciationStatus:
            return [.read, .indicate]
        case .features:
            return [.read]
        case .statusReaderControlPoint, .commandControlPoint, .recordAccessControlPoint:
            return [.write, .indicate]
        case .commandData, .historyData:
            return [.notify]
        }
    }
}

extension CBPeripheral {
    func getInsulinDeliveryCharacteristicWithUUID(_ uuid: InsulinDeliveryCharacteristicUUID, serviceUUID: InsulinDeliveryCharacteristicUUID = .service) -> CBCharacteristic? {
        guard let service = services?.itemWithUUID(serviceUUID.cbUUID) else {
            return nil
        }

        return service.characteristics?.itemWithUUID(uuid.cbUUID)
    }
}
