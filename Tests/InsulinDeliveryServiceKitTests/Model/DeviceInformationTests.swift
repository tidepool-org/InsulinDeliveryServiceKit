//
//  DeviceInformationTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-19.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

class DeviceInformationTests: XCTestCase {
    
    private var lifespan = TimeInterval(days: 10)

    func testDeviceInformationExpirationDateCalculation() throws {
        let now = Date()
        var deviceInformation = DeviceInformation(identifier: UUID(), serialNumber: "abc123", reportedRemainingLifetime: lifespan)
        deviceInformation.updateExpirationDate(replacementDate: now, lifespan: lifespan, reportedAt: now)
        XCTAssertEqual(now + lifespan, deviceInformation.estimatedExpirationDate)
        
        lifespan = .days(180)
        deviceInformation = DeviceInformation(identifier: UUID(), serialNumber: "abc123", reportedRemainingLifetime: lifespan)
        deviceInformation.updateExpirationDate(replacementDate: now, lifespan: lifespan, reportedAt: now)
        XCTAssertEqual(now + lifespan, deviceInformation.estimatedExpirationDate)

        lifespan = .hours(23)
        deviceInformation = DeviceInformation(identifier: UUID(), serialNumber: "abc123", reportedRemainingLifetime: lifespan)
        deviceInformation.updateExpirationDate(replacementDate: now, lifespan: lifespan, reportedAt: now)
        XCTAssertEqual(now + lifespan, deviceInformation.estimatedExpirationDate)
    }
    
    func testBatteryLevelIndicator() throws {
        XCTAssertEqual(.full, DeviceInformation(identifier: UUID(), serialNumber: "abc123", batteryLevel: 100, reportedRemainingLifetime: lifespan).batteryLevelIndicator)
        XCTAssertEqual(.full, DeviceInformation(identifier: UUID(), serialNumber: "abc123", batteryLevel: 99, reportedRemainingLifetime: lifespan).batteryLevelIndicator)
        XCTAssertEqual(.full, DeviceInformation(identifier: UUID(), serialNumber: "abc123", batteryLevel: 80, reportedRemainingLifetime: lifespan).batteryLevelIndicator)
        XCTAssertEqual(.full, DeviceInformation(identifier: UUID(), serialNumber: "abc123", batteryLevel: 51, reportedRemainingLifetime: lifespan).batteryLevelIndicator)
        XCTAssertEqual(.medium, DeviceInformation(identifier: UUID(), serialNumber: "abc123", batteryLevel: 50, reportedRemainingLifetime: lifespan).batteryLevelIndicator)
        XCTAssertEqual(.medium, DeviceInformation(identifier: UUID(), serialNumber: "abc123", batteryLevel: 26, reportedRemainingLifetime: lifespan).batteryLevelIndicator)
        XCTAssertEqual(.low, DeviceInformation(identifier: UUID(), serialNumber: "abc123", batteryLevel: 25, reportedRemainingLifetime: lifespan).batteryLevelIndicator)
        XCTAssertEqual(.low, DeviceInformation(identifier: UUID(), serialNumber: "abc123", batteryLevel: 1, reportedRemainingLifetime: lifespan).batteryLevelIndicator)
        XCTAssertEqual(.empty, DeviceInformation(identifier: UUID(), serialNumber: "abc123", batteryLevel: 0, reportedRemainingLifetime: lifespan).batteryLevelIndicator)
        XCTAssertEqual(nil, DeviceInformation(identifier: UUID(), serialNumber: "abc123", batteryLevel: nil, reportedRemainingLifetime: lifespan).batteryLevelIndicator)
    }
    
    func testReservoirLevelEstimated() throws {
        XCTAssertEqual(false, DeviceInformation(identifier: UUID(), serialNumber: "abc123", reservoirLevel: nil, reportedRemainingLifetime: lifespan).isReservoirLevelEstimated(50))
        XCTAssertEqual(true, DeviceInformation(identifier: UUID(), serialNumber: "abc123", reservoirLevel: 50.nextUp, reportedRemainingLifetime: lifespan).isReservoirLevelEstimated(50))
        XCTAssertEqual(false, DeviceInformation(identifier: UUID(), serialNumber: "abc123", reservoirLevel: 50, reportedRemainingLifetime: lifespan).isReservoirLevelEstimated(50))
        XCTAssertEqual(false, DeviceInformation(identifier: UUID(), serialNumber: "abc123", reservoirLevel: 50.nextDown, reportedRemainingLifetime: lifespan).isReservoirLevelEstimated(50))
        XCTAssertEqual(false, DeviceInformation(identifier: UUID(), serialNumber: "abc123", reservoirLevel: 10, reportedRemainingLifetime: lifespan).isReservoirLevelEstimated(50))
        XCTAssertEqual(false, DeviceInformation(identifier: UUID(), serialNumber: "abc123", reservoirLevel: 0, reportedRemainingLifetime: lifespan).isReservoirLevelEstimated(50))
    }
}
