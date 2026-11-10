//
//  MockGATTService.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2026-11-05.
//  Copyright © 2026 Tidepool Project. All rights reserved.
//

import Foundation
import CoreBluetooth
import BluetoothCommonKit
@testable import InsulinDeliveryServiceKit

/// Records service construction and lets a test flip CCCD state without CoreBluetooth.
final class MockGATTService: GATTService {
    var delegate: GATTServiceDelegate?
    var observers: GATTServiceObservers?

    private(set) var services: [(uuid: CBUUID, primary: Bool, characteristics: [CallbackCharacteristic])] = []
    private(set) var updates: [(data: Data?, uuid: CBUUID)] = []
    var subscribed: Set<CBUUID> = []

    func preWriteConstrain(_ preWriteConstrain: @escaping ([CallbackCharacteristic]) -> CBATTError.Code) { }

    func createService(_ serviceUUID: CBUUID, primary: Bool, withCharacteristics characteristics: [CallbackCharacteristic]) {
        services.append((serviceUUID, primary, characteristics))
    }

    func addService() { }

    func update(_ data: Data?, forUUID: CBUUID, onSubscribedCentrals: [CBCentral]?) {
        updates.append((data, forUUID))
    }

    func startAdvertising(advertisementDataHandler: @escaping () -> [String: Any]?) { }

    func isCharacteristicSubscribed(_ forUUID: CBUUID) -> Bool? {
        subscribed.contains(forUUID)
    }
}

/// Captures queued indications instead of sending them.
final class MockMessageQueue: InspectableMessagingQueue {
    var gattServer: GATTService!
    private(set) var items: [UUIDValuePair] = []

    var queuedItems: [UUIDValuePair] { items }

    init(gattServer: GATTService) {
        self.gattServer = gattServer
    }

    var hasMessagesInQueue: Bool { !items.isEmpty }

    func addQueueItem(_ update: UUIDValuePair) {
        items.append(update)
    }

    func emptyQueue() {
        items.removeAll()
    }
}
