//
//  IDStatusReaderControlPointDataHandlerTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-07-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import BluetoothCommonKit
@testable import InsulinDeliveryServiceKit

class IDStatusReaderControlPointDataHandlerTests: XCTestCase, E2EProtectionDelegate {
    var isE2EProtectionSupported: Bool = true

    private var bolusManager: BolusManager!
    private var statusReaderControlPointDataHandler: IDStatusReaderControlPointDataHandler!

    override func setUp() {
        bolusManager = BolusManager()
        statusReaderControlPointDataHandler = IDStatusReaderControlPointDataHandler(bolusManager: bolusManager, basalManager: BasalManager(), e2eCounter: 1)
        statusReaderControlPointDataHandler.e2eDelegate = self
    }

    func testIDStatusReaderOpcode() {
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x0303), IDStatusReaderOpcode.responseCode)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x030c), IDStatusReaderOpcode.resetStatus)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x330), IDStatusReaderOpcode.getActiveBolusIDs)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x033f), IDStatusReaderOpcode.getActiveBolusIDsResponse)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x0356), IDStatusReaderOpcode.getActiveBolusDelivery)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x0359), IDStatusReaderOpcode.getActiveBolusDeliveryResponse)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x0365), IDStatusReaderOpcode.getActiveBasalRateDelivery)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x036a), IDStatusReaderOpcode.getActiveBasalRateDeliveryResponse)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x0395), IDStatusReaderOpcode.getTotalDailyInsulinStatus)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x039a), IDStatusReaderOpcode.getTotalDailyInsulinStatusResponse)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x03a6), IDStatusReaderOpcode.getCounter)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x03a9), IDStatusReaderOpcode.getCounterResponse)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x3c0), IDStatusReaderOpcode.getDeliveredInsulin)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x03cf), IDStatusReaderOpcode.getDeliveredInsulinResponse)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x03f3), IDStatusReaderOpcode.getInsulinOnBoard)
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: 0x03fc), IDStatusReaderOpcode.getInsulinOnBoardResponse)
    }

    func testIDStatusReaderResponseCode() {
        XCTAssertEqual(IDStatusReaderResponseCode(rawValue: 0x0f), IDStatusReaderResponseCode.success)
        XCTAssertEqual(IDStatusReaderResponseCode(rawValue: 0x70), IDStatusReaderResponseCode.opcodeNotSupported)
        XCTAssertEqual(IDStatusReaderResponseCode(rawValue: 0x71), IDStatusReaderResponseCode.invalidOperand)
        XCTAssertEqual(IDStatusReaderResponseCode(rawValue: 0x72), IDStatusReaderResponseCode.procedureNotCompleted)
        XCTAssertEqual(IDStatusReaderResponseCode(rawValue: 0x73), IDStatusReaderResponseCode.parameterOutOfRange)
        XCTAssertEqual(IDStatusReaderResponseCode(rawValue: 0x74), IDStatusReaderResponseCode.procedureNotApplicable)
    }

    func testBolusValueSelection() {
        XCTAssertEqual(BolusValueSelection(rawValue: 0x0f), BolusValueSelection.programmed)
        XCTAssertEqual(BolusValueSelection(rawValue: 0x33), BolusValueSelection.remaining)
        XCTAssertEqual(BolusValueSelection(rawValue: 0x3c), BolusValueSelection.delivered)
    }

    func testCreateGetActiveBolusDeliveredDetailsRequest() {
        bolusManager.activeBolusDeliveryStatus = BolusDeliveryStatus.noActiveBolus
        var request = statusReaderControlPointDataHandler.createGetActiveBolusDeliveredDetailsRequest()
        XCTAssertNil(request)
        
        let bolusID: BolusID = 123
        bolusManager.activeBolusDeliveryStatus.id = bolusID
        request = statusReaderControlPointDataHandler.createGetActiveBolusDeliveredDetailsRequest()
        guard let actualRequest = request else {
            XCTAssert(false, "get active bolus delivered details request cannot be nil")
            return
        }
        
        var index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: actualRequest[actualRequest.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self)), .getActiveBolusDelivery)
        index += 2
        XCTAssertEqual(actualRequest[actualRequest.startIndex.advanced(by: index)...].to(BolusID.self), bolusID)
        index += 2
        XCTAssertEqual(BolusValueSelection(rawValue: actualRequest[actualRequest.startIndex.advanced(by: index)...].to(BolusValueSelection.RawValue.self)), .delivered)
    }

    func testCreateGetActiveBolusProgrammedDetailsRequest() {
        bolusManager.activeBolusDeliveryStatus = BolusDeliveryStatus.noActiveBolus
        var request = statusReaderControlPointDataHandler.createGetActiveBolusProgrammedDetailsRequest()
        XCTAssertNil(request)

        let bolusID: BolusID = 123
        bolusManager.activeBolusDeliveryStatus.id = bolusID
        request = statusReaderControlPointDataHandler.createGetActiveBolusProgrammedDetailsRequest()
        guard let actualRequest = request else {
            XCTAssert(false, "get active bolus programmed details request cannot be nil")
            return
        }

        var index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: actualRequest[actualRequest.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self)), .getActiveBolusDelivery)
        index += 2
        XCTAssertEqual(actualRequest[actualRequest.startIndex.advanced(by: index)...].to(BolusID.self), bolusID)
        index += 2
        XCTAssertEqual(BolusValueSelection(rawValue: actualRequest[actualRequest.startIndex.advanced(by: index)...].to(BolusValueSelection.RawValue.self)), .programmed)
    }
    
    func testHandleResponseCodeResponse() {
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.getActiveBolusDelivery.rawValue)
        response.append(IDStatusReaderResponseCode.success.rawValue)
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()
        
        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }

    func testHandleResponseCodeResponseInvalidOperand() {
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.getActiveBolusDelivery.rawValue)
        response.append(IDStatusReaderResponseCode.invalidOperand.rawValue)
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidOperand)
        default:
            XCTAssert(false)
        }
    }

    func testHandleResponseCodeResponseOpcodeNotSupported() {
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.getActiveBolusDelivery.rawValue)
        response.append(IDStatusReaderResponseCode.opcodeNotSupported.rawValue)
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .opcodeNotSupported)
        default:
            XCTAssert(false)
        }
    }

    func testHandleResponseCodeResponseParameterOutOfRange() {
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.getActiveBolusDelivery.rawValue)
        response.append(IDStatusReaderResponseCode.parameterOutOfRange.rawValue)
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .parameterOutOfRange)
        default:
            XCTAssert(false)
        }
    }

    func testHandleResponseCodeResponseProcedureNotApplicable() {
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.getActiveBasalRateDelivery.rawValue)
        response.append(IDStatusReaderResponseCode.procedureNotApplicable.rawValue)
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .procedureNotApplicable)
        default:
            XCTAssert(false)
        }
    }

    func testHandleResponseCodeResponseProcedureNotCompleted() {
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.getActiveBolusDelivery.rawValue)
        response.append(IDStatusReaderResponseCode.procedureNotCompleted.rawValue)
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .procedureNotCompleted)
        default:
            XCTAssert(false)
        }
    }

    func testResponseOpcode() {
        let expectedResponseOpcode: IDStatusReaderOpcode = .getActiveBolusDeliveryResponse
        let response = Data(expectedResponseOpcode.rawValue)
        let responseOpcode: IDStatusReaderOpcode? = statusReaderControlPointDataHandler.responseOpcode(response)
        XCTAssertEqual(responseOpcode, expectedResponseOpcode)
    }

    func testHandleGetActiveBolusDeliveryResponse() {
        let opcode = IDStatusReaderOpcode.getActiveBolusDeliveryResponse
        let bolusID: BolusID = 123
        let insulinDelivered: Double = 2.3
        
        var response = Data(opcode.rawValue)
        response.append(UInt8(0x00)) // flags
        response.append(bolusID)
        response.append(BolusType.fast.rawValue)
        response.append(insulinDelivered.sfloat)
        response.append(0.sfloat) // extended bolus is 0 for fast
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()
        
        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }

    func testHandleResponseInvalidCRC() {
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.getActiveBolusDelivery.rawValue)
        response.append(IDStatusReaderResponseCode.procedureNotApplicable.rawValue)
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response.append(0x0000)

        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidCRC)
        default:
            XCTAssert(false)
        }
    }

    func testProcedureIDForResponse() {
        for opcode in IDStatusReaderOpcode.responseOpcodes {
            if opcode == .responseCode {
                let requestOpcode = IDStatusReaderOpcode.getActiveBolusDelivery
                var response = Data(opcode.rawValue)
                response.append(requestOpcode.rawValue)
                let procedureID = statusReaderControlPointDataHandler.procedureIDForResponse(response)
                XCTAssertEqual(procedureID, requestOpcode.procedureID)
            } else {
                let response = Data(opcode.rawValue)
                let procedureID = statusReaderControlPointDataHandler.procedureIDForResponse(response)
                switch opcode {
                case .getActiveBolusIDsResponse: XCTAssertEqual(procedureID, IDStatusReaderOpcode.getActiveBolusIDs.procedureID)
                case .getActiveBolusDeliveryResponse: XCTAssertEqual(procedureID, IDStatusReaderOpcode.getActiveBolusDelivery.procedureID)
                case .getActiveBasalRateDeliveryResponse: XCTAssertEqual(procedureID, IDStatusReaderOpcode.getActiveBasalRateDelivery.procedureID)
                case .getTotalDailyInsulinStatusResponse: XCTAssertEqual(procedureID, IDStatusReaderOpcode.getTotalDailyInsulinStatus.procedureID)
                case .getCounterResponse: XCTAssertEqual(procedureID, IDStatusReaderOpcode.getCounter.procedureID)
                case .getDeliveredInsulinResponse: XCTAssertEqual(procedureID, IDStatusReaderOpcode.getDeliveredInsulin.procedureID)
                case .getInsulinOnBoardResponse: XCTAssertEqual(procedureID, IDStatusReaderOpcode.getInsulinOnBoard.procedureID)
                default:
                    XCTAssert(false)
                }
            }
        }
    }

    func testCreateResetAllStatusChangedFlags() {
        let request = statusReaderControlPointDataHandler.createResetStatusChangedRequest(for:                                                                                    .allFlags)

        var index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self)), .resetStatus)
        index += 2
        XCTAssertEqual(IDStatusChangedFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusChangedFlag.RawValue.self)), .allFlags)
    }

    func testCreateResetActiveBolusStatusChangedRequest() {
        let request = statusReaderControlPointDataHandler.createResetStatusChangedRequest(for: .activeBolusStatusChanged)

        var index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self)), .resetStatus)
        index += 2
        XCTAssertEqual(IDStatusChangedFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusChangedFlag.RawValue.self)), .activeBolusStatusChanged)
    }

    func testCreateResetHistoryEventRecordedStatusChangedRequest() {
        let request = statusReaderControlPointDataHandler.createResetStatusChangedRequest(for: .historyEventRecordedChanged)

        var index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self)), .resetStatus)
        index += 2
        XCTAssertEqual(IDStatusChangedFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusChangedFlag.RawValue.self)), .historyEventRecordedChanged)
    }

    func testHandleGetActiveBolusIDsResponse() {
        let numberOfActiveBoluses: UInt8 = 1
        let bolusIDs: [BolusID] = [1]
        var response = Data(IDStatusReaderOpcode.getActiveBolusIDsResponse.rawValue)
        response.append(numberOfActiveBoluses)
        response.append(bolusIDs[0])
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }

    func testCreateResetAnnunciationStatusChangedRequest() {
        let request = statusReaderControlPointDataHandler.createResetStatusChangedRequest(for: .annunciationStatusChanged)

        var index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self)), .resetStatus)
        index += 2
        XCTAssertEqual(IDStatusChangedFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusChangedFlag.RawValue.self)), .annunciationStatusChanged)
    }

    func testCreateGetRemainingLifetimeRequest() {
        let request = statusReaderControlPointDataHandler.createGetRemainingLifetimeRequest()

        var index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self)), .getCounter)
        index += 2
        XCTAssertEqual(CounterType(rawValue: request[request.startIndex.advanced(by: index)...].to(CounterType.RawValue.self)), .lifetime)
        index += 1
        XCTAssertEqual(CounterValueSelection(rawValue: request[request.startIndex.advanced(by: index)...].to(CounterType.RawValue.self)), .remaining)
    }

    func testRemainingLifetimeResponse() {
        let testExpectation = expectation(description: #function)

        let remainingLifetime = TimeInterval.days(4)
        var response = Data(IDStatusReaderOpcode.getCounterResponse.rawValue)
        response.append(CounterType.lifetime.rawValue)
        response.append(CounterValueSelection.remaining.rawValue)
        response.append(Int32(remainingLifetime.minutes))
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        statusReaderControlPointDataHandler.lifetimeRemainingHandler = { remainingLifetimeReceived in
            XCTAssertEqual(remainingLifetimeReceived, remainingLifetime)
            testExpectation.fulfill()
        }

        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)

        wait(for: [testExpectation], timeout: 30)
        switch result {
        case .failure:
            XCTAssert(false)
        default:
            break
        }
    }

    func testElaspedLifetimeResponse() {
        let testExpectation = expectation(description: #function)
        testExpectation.isInverted = true

        let remainingLifetime = TimeInterval.days(4)
        var response = Data(IDStatusReaderOpcode.getCounterResponse.rawValue)
        response.append(CounterType.lifetime.rawValue)
        response.append(CounterValueSelection.elasped.rawValue)
        response.append(Int32(remainingLifetime.minutes))
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        statusReaderControlPointDataHandler.lifetimeRemainingHandler = { remainingLifetimeReceived in
            XCTAssertEqual(remainingLifetimeReceived, remainingLifetime)
            testExpectation.fulfill()
        }

        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)

        wait(for: [testExpectation], timeout: 1)
        switch result {
        case .failure:
            XCTAssert(false)
        default:
            break
        }
    }

    func testRemainingLifetimeResponseInvalidFormat() {
        let remainingLifetime = TimeInterval.days(4)
        var response = Data(IDStatusReaderOpcode.getCounterResponse.rawValue)
        response.append(CounterType.lifetime.rawValue)
        response.append(Int32(remainingLifetime.minutes))
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = statusReaderControlPointDataHandler.handleResponse(response)

        switch result {
        case .success:
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .invalidFormat)
        }
    }

    func testRemainingLifetimeResponseParameterOutOfRange() {
        let remainingLifetime = TimeInterval.days(4)
        var response = Data(IDStatusReaderOpcode.getCounterResponse.rawValue)
        response.append(CounterType.lifetime.rawValue)
        response.append(UInt8(0x11))
        response.append(Int32(remainingLifetime.minutes))
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        var (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .success:
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .parameterOutOfRange)
        }

        response = Data(IDStatusReaderOpcode.getCounterResponse.rawValue)
        response.append(UInt8(0x11))
        response.append(CounterValueSelection.remaining.rawValue)
        response.append(Int32(remainingLifetime.minutes))
        response.append(statusReaderControlPointDataHandler.e2eCounter)
        response = response.appendingCRC()

        (result, _) = statusReaderControlPointDataHandler.handleResponse(response)
        switch result {
        case .success:
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .parameterOutOfRange)
        }
    }

    func testCreateGetDeliveredInsulinRequest() {
        let request = statusReaderControlPointDataHandler.createGetDeliveredInsulinRequest()

        let index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self)), .getDeliveredInsulin)
    }
    
    func testCreateGetActiveBasalRateDeliveryRequest() {
        let request = statusReaderControlPointDataHandler.createGetActiveBasalRateDeliveryRequest()

        let index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self)), .getActiveBasalRateDelivery)
    }
    
    func testCreateResetActiveBasalRateStatusChangedRequest() {
        let request = statusReaderControlPointDataHandler.createResetStatusChangedRequest(for: .activeBasalRateStatusChanged)
        
        var index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self)), .resetStatus)
        index += 2
        XCTAssertEqual(IDStatusChangedFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusChangedFlag.RawValue.self)), .activeBasalRateStatusChanged)
    }
}
