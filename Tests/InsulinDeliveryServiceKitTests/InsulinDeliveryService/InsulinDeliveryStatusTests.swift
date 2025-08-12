//
//  IDStatusDataHandlerTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-07-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

class IDStatusDataHandlerTests: XCTestCase {

    private var testE2EProtection = TestE2EProtection()

    func testIDStatusFlag() {
        let reservoirAttached: UInt8 = 0x01
        let statusFlags = IDStatusFlag(rawValue: reservoirAttached)
        XCTAssertTrue(statusFlags.contains(.reservoirAttached))
    }

    func testInsulinTherapyControlState() {
        XCTAssertEqual(InsulinTherapyControlState(rawValue: 0x0f), InsulinTherapyControlState.undetermined)
        XCTAssertEqual(InsulinTherapyControlState(rawValue: 0x33), InsulinTherapyControlState.stop)
        XCTAssertEqual(InsulinTherapyControlState(rawValue: 0x3c), InsulinTherapyControlState.pause)
        XCTAssertEqual(InsulinTherapyControlState(rawValue: 0x55), InsulinTherapyControlState.run)
    }

    func testPumpOperationalState() {
        XCTAssertEqual(PumpOperationalState(rawValue: 0x0f), PumpOperationalState.undetermined)
        XCTAssertEqual(PumpOperationalState(rawValue: 0x33), PumpOperationalState.off)
        XCTAssertEqual(PumpOperationalState(rawValue: 0x3c), PumpOperationalState.standby)
        XCTAssertEqual(PumpOperationalState(rawValue: 0x55), PumpOperationalState.preparing)
        XCTAssertEqual(PumpOperationalState(rawValue: 0x5a), PumpOperationalState.priming)
        XCTAssertEqual(PumpOperationalState(rawValue: 0x66), PumpOperationalState.waiting)
        XCTAssertEqual(PumpOperationalState(rawValue: 0x96), PumpOperationalState.ready)
    }
    
    func testHandleIDStatusDataHandlerData() {
        let therapyState = InsulinTherapyControlState.stop
        let operationalState = PumpOperationalState.standby
        let remainingReservoir = 100.0
        let statusFlags = IDStatusFlag.reservoirAttached
        var data = Data(therapyState.rawValue)
        data.append(operationalState.rawValue)
        data.append(remainingReservoir.sfloat)
        data.append(statusFlags.rawValue)
        let dataWithE2EProtection = testE2EProtection.appendingE2EProtection(data)
        
        let result = IDStatusDataHandler.handleData(dataWithE2EProtection, e2eProtectionSupported: true)
        switch result {
        case .failure(_):
            XCTAssert(false)
        case .success((let resultTherapyControlState, let resultOperationalState, let resultRemainingReservoir, let resultFlags)):
            XCTAssertEqual(resultTherapyControlState, therapyState)
            XCTAssertEqual(resultOperationalState, operationalState)
            XCTAssertEqual(resultRemainingReservoir, remainingReservoir)
            XCTAssertEqual(resultFlags, statusFlags)
        }
    }
    
    func testHandleIDStatusDataHandlerDataInvalidFormat() {
        let therapyState = InsulinTherapyControlState.stop
        let operationalState = PumpOperationalState.standby
        let statusFlags = IDStatusFlag.reservoirAttached
        var data = Data(therapyState.rawValue)
        data.append(operationalState.rawValue)
        data.append(statusFlags.rawValue)
        let dataWithE2EProtection = testE2EProtection.appendingE2EProtection(data)
        let result = IDStatusDataHandler.handleData(dataWithE2EProtection, e2eProtectionSupported: true)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidFormat)
        default:
            XCTAssert(false)
        }
    }
    
    func testHandleIDStatusDataHandlerDataInvalidCRC() {
        let therapyState = InsulinTherapyControlState.stop
        let operationalState = PumpOperationalState.standby
        let remainingReservoir = UInt16(100)
        let statusFlags = IDStatusFlag.reservoirAttached
        var data = Data(therapyState.rawValue)
        data.append(operationalState.rawValue)
        data.append(remainingReservoir)
        data.append(statusFlags.rawValue)
        var dataWithE2EProtection = testE2EProtection.appendingE2EProtection(data)
        dataWithE2EProtection = dataWithE2EProtection.dropLast(2)
        dataWithE2EProtection.append(UInt16(0x0000))
        let result = IDStatusDataHandler.handleData(dataWithE2EProtection, e2eProtectionSupported: true)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidCRC)
        default:
            XCTAssert(false)
        }
    }
    
    func testHandleIDStatusDataHandlerDataInvalidTherapyState() {
        let therapyState: UInt8 = 0x12
        let operationalState = PumpOperationalState.standby
        let remainingReservoir = UInt16(100)
        let statusFlags = IDStatusFlag.reservoirAttached
        var data = Data(therapyState)
        data.append(operationalState.rawValue)
        data.append(remainingReservoir)
        data.append(statusFlags.rawValue)
        let dataWithE2EProtection = testE2EProtection.appendingE2EProtection(data)
        let result = IDStatusDataHandler.handleData(dataWithE2EProtection, e2eProtectionSupported: true)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .parameterOutOfRange)
        default:
            XCTAssert(false)
        }
    }
    
    func testHandleIDStatusDataHandlerDataInvalidOperationalState() {
        let therapyState = InsulinTherapyControlState.stop
        let operationalState: UInt8 = 0x13
        let remainingReservoir = UInt16(100)
        let statusFlags = IDStatusFlag.reservoirAttached
        var data = Data(therapyState.rawValue)
        data.append(operationalState)
        data.append(remainingReservoir)
        data.append(statusFlags.rawValue)
        let dataWithE2EProtection = testE2EProtection.appendingE2EProtection(data)
        let result = IDStatusDataHandler.handleData(dataWithE2EProtection, e2eProtectionSupported: true)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .parameterOutOfRange)
        default:
            XCTAssert(false)
        }
    }
}
