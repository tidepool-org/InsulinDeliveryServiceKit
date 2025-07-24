//
//  BasalManagerTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-07-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

class BasalManagerTests: XCTestCase {
    
    private var totalBasalDelivered = 0.0
    private var activeTempBasalDeliveryStatus: TempBasalDeliveryStatus = .noActiveTempBasal
    private var basalManager: BasalManager!
    
    override func setUp() {
        basalManager = BasalManager()
        basalManager.delegate = self
    }
    
    func testTempBasalFlags() {
        let tempBasalFlagRawValue: UInt8 = 0x07
        let tempBasalFlags = TempBasalFlag(rawValue: tempBasalFlagRawValue)
        XCTAssertTrue(tempBasalFlags.contains(.templateNumberPresent))
        XCTAssertTrue(tempBasalFlags.contains(.deliveryContextPresent))
        XCTAssertTrue(tempBasalFlags.contains(.changeTempBasal))
    }
    
    func testActiveBasalRateFlag() {
        let activeBasalFlagRawValue: UInt8 = 0x07
        let activeBasalFlags = ActiveBasalRateFlag(rawValue: activeBasalFlagRawValue)
        XCTAssertTrue(activeBasalFlags.contains(.tbrPresent))
        XCTAssertTrue(activeBasalFlags.contains(.tbrTemplateNumberPresent))
        XCTAssertTrue(activeBasalFlags.contains(.deliveryContextPresent))
    }
    
    func testTempBasalType() {
        XCTAssertEqual(TempBasalType(rawValue: 0x0f), .undetermined)
        XCTAssertEqual(TempBasalType(rawValue: 0x33), .absolute)
        XCTAssertEqual(TempBasalType(rawValue: 0x3c), .relative)
        XCTAssertNil(TempBasalType(rawValue: 0x00))
    }
    
    func testTempBasalDeliveryContext() {
        XCTAssertEqual(BasalDeliveryContext(rawValue: 0x0f), .undetermined)
        XCTAssertEqual(BasalDeliveryContext(rawValue: 0x33), .deviceBased)
        XCTAssertEqual(BasalDeliveryContext(rawValue: 0x3c), .remoteControl)
        XCTAssertEqual(BasalDeliveryContext(rawValue: 0x55), .aidController)
        XCTAssertNil(BasalDeliveryContext(rawValue: 0x00))
    }
    
    func testCreateSetTempBasalAdjustmentRequest() {
        let request = basalManager.createSetTempBasalAdjustmentRequest(unitsPerHour: 1.2,
                                                                       durationInMinutes: 30,
                                                                       deliveryContext: .aidController)
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .setTempBasalAdjustment)
        index += 2
        XCTAssertEqual(TempBasalFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .deliveryContextPresent)
        index += 1
        XCTAssertEqual(TempBasalType(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .absolute)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 1.2)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), 30)
        index += 2
        XCTAssertEqual(BasalDeliveryContext(rawValue: request[request.startIndex.advanced(by: index)...].to(BasalDeliveryContext.RawValue.self)), .aidController)
    }
    
    func testCreateSetTempBasalAdjustmentRequestReplacement() {
        let request = basalManager.createSetTempBasalAdjustmentRequest(unitsPerHour: 2.5,
                                                                       durationInMinutes: 15,
                                                                       deliveryContext: .aidController,
                                                                       replaceExisting: true)
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .setTempBasalAdjustment)
        index += 2
        XCTAssertEqual(TempBasalFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), [.changeTempBasal, .deliveryContextPresent])
        index += 1
        XCTAssertEqual(TempBasalType(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .absolute)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 2.5)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), 15)
        index += 2
        XCTAssertEqual(BasalDeliveryContext(rawValue: request[request.startIndex.advanced(by: index)...].to(BasalDeliveryContext.RawValue.self)), .aidController)
    }
    
    func testCreateCancelTempBasalAdjustmentRequest() {
        let request = BasalManager.createCancelTempBasalAdjustmentRequest()
        
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex...].to(UInt16.self)), .cancelTempBasalAdjustment)
    }
    
    func testHandleGetDeliveredInsulinResponse() {
        let bolusAmount = 13.0
        let basalAmount = 4.0
        let opcode = IDStatusReaderOpcode.getDeliveredInsulinResponse
        var response = Data(opcode.rawValue)
        response.append(UInt32(bolusAmount))
        response.append(UInt32(basalAmount))
        response.append(UInt8(1))//E2E-counter
        response = response.appendingCRC()
        
        let result = basalManager.handleResponse(response, with: opcode)
        switch result {
        case .success:
            XCTAssertEqual(basalAmount, totalBasalDelivered)
        case .failure(_):
            XCTAssert(false)
        }
    }
    
    func testHandleGetActiveBasalRateDeliveryResponseScheduleBasalActive() {
        let opcode = IDStatusReaderOpcode.getActiveBasalRateDeliveryResponse
        let flags: ActiveBasalRateFlag = [.deliveryContextPresent]
        let basalProfile = 1
        let basalRate = 2.5
        var response = Data(opcode.rawValue)
        response.append(flags.rawValue)
        response.append(UInt8(basalProfile))
        response.append(basalRate.sfloat)
        response.append(BasalDeliveryContext.aidController.rawValue)
        response.append(UInt8(1))//E2E-counter
        response = response.appendingCRC()
        
        let result = basalManager.handleResponse(response, with: opcode)
        switch result {
        case .success:
            XCTAssertEqual(activeTempBasalDeliveryStatus, .noActiveTempBasal)
        case .failure(_):
            XCTAssert(false)
        }
    }
    
    func testHandleGetActiveBasalRateDeliveryResponseTempBasalActive() {
        let opcode = IDStatusReaderOpcode.getActiveBasalRateDeliveryResponse
        let flags: ActiveBasalRateFlag = [.deliveryContextPresent, .tbrPresent]
        let basalProfile = 1
        let basalRate = 2.5
        let tempBasalRate = 1.5
        let duration: UInt16 = 30
        let durationRemaining = TimeInterval.minutes(20)
        
        _ = basalManager.createSetTempBasalAdjustmentRequest(unitsPerHour: tempBasalRate, durationInMinutes: duration, deliveryContext: .aidController)

        var response = Data(opcode.rawValue)
        response.append(flags.rawValue)
        response.append(UInt8(basalProfile))
        response.append(basalRate.sfloat)
        response.append(TempBasalType.absolute.rawValue)
        response.append(tempBasalRate.sfloat)
        response.append(duration)
        response.append(UInt16(durationRemaining.minutes))
        response.append(BasalDeliveryContext.aidController.rawValue)
        response.append(UInt8(1))//E2E-counter
        response = response.appendingCRC()
                
        let result = basalManager.handleResponse(response, with: opcode)
        switch result {
        case .success:
            XCTAssertEqual(activeTempBasalDeliveryStatus.progressState, .inProgress)
            XCTAssertEqual(activeTempBasalDeliveryStatus.duration, TimeInterval(minutes: Double(duration)))
            XCTAssertEqual(activeTempBasalDeliveryStatus.rate, tempBasalRate)
        case .failure(_):
            XCTAssert(false)
        }
    }
}

extension BasalManagerTests: BasalManagerDelegate {
    func basalManagerDidUpdateStatus(_ basalManager: BasalManager) {
        activeTempBasalDeliveryStatus = basalManager.activeTempBasalDeliveryStatus
        totalBasalDelivered = basalManager.totalBasalDelivered
    }
    
    func isActiveBasalRate(_ activeBasalRate: Double) -> Bool {
        true
    }
}
