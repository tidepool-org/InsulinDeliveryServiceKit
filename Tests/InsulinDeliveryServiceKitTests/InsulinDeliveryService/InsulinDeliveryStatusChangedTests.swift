//
//  IDStatusChangedDataHandlerTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-07-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

class IDStatusChangedDataHandlerTests: XCTestCase {

    private var testE2EProtection = TestE2EProtection()

    func testIDStatusChangedFlag() {
        let flags: UInt16 = 0x0036
        let statusChangedFlags = IDStatusChangedFlag(rawValue: flags)
        XCTAssertTrue(statusChangedFlags.contains(.operationalStateChanged))
        XCTAssertTrue(statusChangedFlags.contains(.reservoirStatusChanged))
        XCTAssertTrue(statusChangedFlags.contains(.totalDailyInsulinStatusChanged))
        XCTAssertTrue(statusChangedFlags.contains(.activeBasalRateStatusChanged))
    }

    func testHandleIDStatusChangedDataHandlerData() {
        let flags: UInt16 = 0x00C9
        let expectedStatusChangedFlags = IDStatusChangedFlag(rawValue: flags)
        let data = Data(expectedStatusChangedFlags.rawValue)
        let dataWithE2EProtection = testE2EProtection.appendingE2EProtection(data)

        let result = IDStatusChangedDataHandler.handleData(dataWithE2EProtection, e2eProtectionSupported: true)
        switch result {
        case .success(let statusChangedFlags):
            XCTAssertEqual(expectedStatusChangedFlags, statusChangedFlags)
        case .failure(_):
            XCTAssert(false)
        }
    }

    func testHandleIDStatusChangedDataHandlerDataInvalidFormat() {
        let data = Data(0x10)
        let dataWithE2EProtection = testE2EProtection.appendingE2EProtection(data)
        let result = IDStatusChangedDataHandler.handleData(dataWithE2EProtection, e2eProtectionSupported: true)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .invalidFormat)
        }
    }

    func testHandleIDStatusChangedDataHandlerDataInvalidCRC() {
        let flags: UInt16 = 0x00C9
        let statusChangedFlags = IDStatusChangedFlag(rawValue: flags)
        let data = Data(statusChangedFlags.rawValue)
        var dataWithE2EProtection = testE2EProtection.appendingE2EProtection(data)
        dataWithE2EProtection = dataWithE2EProtection.dropLast(2)
        dataWithE2EProtection.append(UInt16(0x0000))
        let result = IDStatusChangedDataHandler.handleData(dataWithE2EProtection, e2eProtectionSupported: true)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .invalidCRC)
        }
    }
}
