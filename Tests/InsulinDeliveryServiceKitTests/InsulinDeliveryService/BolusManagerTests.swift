//
//  BolusManagerTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-07-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

class BolusManagerTests: XCTestCase {

    private var bolusManager: BolusManager!
    private var bolusDeliveryStatus: BolusDeliveryStatus?
    private var reportedActiveBolusDeliveryStatus: BolusDeliveryStatus?

    override func setUp() {
        bolusManager = BolusManager()
    }

    func testInitialization() {
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus, .noActiveBolus)

        let activeBolusDeliveryStatus = BolusDeliveryStatus(id: 1, progressState: .inProgress, type: .fast, insulinProgrammed: 2, insulinDelivered: 0.8)
        bolusManager = BolusManager(activeBolusDeliveryStatus: activeBolusDeliveryStatus)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus, activeBolusDeliveryStatus)
    }

    func testUpdateActiveBolusDeliveryStatus() {
        bolusManager.delegate = self
        bolusManager.activeBolusDeliveryUpdateHandler = { self.bolusDeliveryStatus = $0 }
        var activeBolusDeliveryStatus = BolusDeliveryStatus(id: 1, progressState: .inProgress, type: .fast, insulinProgrammed: 2, insulinDelivered: 0.5)
        bolusManager.activeBolusDeliveryStatus = activeBolusDeliveryStatus
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus, reportedActiveBolusDeliveryStatus)

        bolusManager.startEstimatingBolusProgress()
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus, reportedActiveBolusDeliveryStatus)

        let now = Date()
        activeBolusDeliveryStatus.progressState = .canceled
        activeBolusDeliveryStatus.endTime = now
        bolusManager.activeBolusDeliveryCanceled(canceledBolusDeliveryStatus: activeBolusDeliveryStatus)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus, reportedActiveBolusDeliveryStatus)
        XCTAssertEqual(bolusDeliveryStatus?.endTime, now)
    }

    func testBolusFlags() {
        let bolusFlagRawValue: UInt8 = 0x1f
        let bolusFlags = BolusFlag(rawValue: bolusFlagRawValue)
        XCTAssertTrue(bolusFlags.contains(.delayTimePresent))
        XCTAssertTrue(bolusFlags.contains(.templateNumberPresent))
        XCTAssertTrue(bolusFlags.contains(.activationTypePresent))
        XCTAssertTrue(bolusFlags.contains(.deliveryReasonCorrection))
        XCTAssertTrue(bolusFlags.contains(.deliveryReasonMeal))
    }
    
    func testBolusType() {
        XCTAssertEqual(BolusType(rawValue: 0x0f), .undetermined)
        XCTAssertEqual(BolusType(rawValue: 0x33), .fast)
        XCTAssertEqual(BolusType(rawValue: 0x3c), .extended)
        XCTAssertEqual(BolusType(rawValue: 0x55), .multiwave)
        XCTAssertNil(BolusType(rawValue: 0x00))
    }
    
    func testBolusActivationType() {
        XCTAssertEqual(IDBolusActivationType(rawValue: 0x0f), .undetermined)
        XCTAssertEqual(IDBolusActivationType(rawValue: 0x33), .manualBolus)
        XCTAssertEqual(IDBolusActivationType(rawValue: 0x3c), .recommendedBolus)
        XCTAssertEqual(IDBolusActivationType(rawValue: 0x55), .manuallyChangedRecommendedBolus)
        XCTAssertEqual(IDBolusActivationType(rawValue: 0x5a), .aidController)
        XCTAssertNil(IDBolusActivationType(rawValue: 0x00))
    }
        
    func testIsBolusActive() {
        XCTAssertFalse(bolusManager.isBolusActive)
        bolusManager.activeBolusDeliveryStatus.progressState = .inProgress
        XCTAssertTrue(bolusManager.isBolusActive)
    }

    func testIsDeliveryestimatingProgress() {
        XCTAssertFalse(bolusManager.isDeliveryEstimatingProgress)
        bolusManager.activeBolusDeliveryStatus.progressState = .estimatingProgress
        XCTAssertTrue(bolusManager.isDeliveryEstimatingProgress)
    }
    
    func testCreateSetBolusRequestFast() {
        let request = bolusManager.createFastBolusRequest(for: 10.5, activationType: .recommendedBolus)
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDCommandControlPointOpcode.RawValue.self)), .setBolus)
        index += 2
        XCTAssertEqual(BolusFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(BolusFlag.RawValue.self)), .activationTypePresent)
        index += 1
        XCTAssertEqual(BolusType(rawValue: request[request.startIndex.advanced(by: index)...].to(BolusType.RawValue.self)), .fast)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 10.5)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 0)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), 0)
        index += 2
        XCTAssertEqual(IDBolusActivationType(rawValue: request[request.startIndex.advanced(by: index)...].to(IDBolusActivationType.RawValue.self)), .recommendedBolus)
    }
    
    func testCreateSetBolusRequestDelayedFast() {
        let request = bolusManager.createDelayedFastBolusRequest(for: 8.5, delayInMinutes: 5)
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .setBolus)
        index += 2
        XCTAssertEqual(BolusFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .delayTimePresent)
        index += 1
        XCTAssertEqual(BolusType(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .fast)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 8.5)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 0)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), 0)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), 5)
    }

    func testCreateSetBolusRequestExtended() {
        let request = bolusManager.createExtendedBolusRequest(for: 6.5, durationInMinutes: 10)
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .setBolus)
        index += 2
        XCTAssertEqual(BolusFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .allZeros)
        index += 1
        XCTAssertEqual(BolusType(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .extended)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 0)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 6.5)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), 10)
    }
    
    func testCreateSetBolusRequestMultiwave() {
        let request = bolusManager.createMultiwaveBolusRequest(fastAmount: 4.5, extendedAmount: 12.5, durationInMinutes: 30)
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .setBolus)
        index += 2
        XCTAssertEqual(BolusFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .allZeros)
        index += 1
        XCTAssertEqual(BolusType(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .multiwave)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 4.5)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 12.5)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), 30)
    }
    
    func testHandleSetBolusResponse() {
        let bolusID: BolusID = 123
        let opcode = IDCommandControlPointOpcode.setBolusResponse
        var response = Data(opcode.rawValue)
        response.append(bolusID)
        response.append(UInt8(1)) // E2ECounter
        response = response.appendingCRC()

        XCTAssertNil(bolusManager.activeBolusDeliveryStatus.id)
        let result = bolusManager.handleResponse(response, with: opcode)
        switch result {
        case .success(_):
            XCTAssertNotNil(bolusManager.activeBolusDeliveryStatus.id)
            XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.progressState, .inProgress)
        default:
            XCTAssert(false)
        }
    }
    
    func testCreateCancelBolusRequestForID() {
        let bolusID: BolusID = 1

        let request = bolusManager.createCancelBolusRequest(for: bolusID)
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .cancelBolus)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), bolusID)
    }
    
    func testCreateCancelCurrentBolusRequest() {
        let bolusID: BolusID = 1
        bolusManager.activeBolusDeliveryStatus.id = bolusID
        
        let request = bolusManager.createCancelCurrentBolusRequest()!
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .cancelBolus)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), bolusID)

        bolusManager.activeBolusDeliveryStatus.progressState = .estimatingProgress
        var nilRequest = bolusManager.createCancelCurrentBolusRequest()
        XCTAssertNil(nilRequest)

        bolusManager.activeBolusDeliveryStatus = .noActiveBolus
        nilRequest = bolusManager.createCancelCurrentBolusRequest()
        XCTAssertNil(nilRequest)
    }

    func testHandleCancelBolusResponse() {
        let bolusID: BolusID = 123
        bolusManager.activeBolusDeliveryStatus.id = bolusID
        let opcode = IDCommandControlPointOpcode.cancelBolusResponse
        var response = Data(opcode.rawValue)
        response.append(bolusID)
        response.append(UInt8(1)) // E2ECounter
        response = response.appendingCRC()

        var bolusDeliveryStatus: BolusDeliveryStatus?
        bolusManager.activeBolusDeliveryUpdateHandler = { bolusDeliveryStatus = $0 }
        let result = bolusManager.handleResponse(response, with: opcode)
        switch result {
        case .success(_):
            XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.id, 123)
            XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.progressState, .canceled)
            XCTAssertEqual(bolusDeliveryStatus?.progressState, .canceled)
            XCTAssertNotNil(bolusDeliveryStatus?.endTime)
        default:
            XCTAssert(false)
        }
    }
    
    func testCreateGetActiveBolusDeliveredDetailsRequest() {
        let bolusID: BolusID = 1
        bolusManager.activeBolusDeliveryStatus.id = bolusID
        
        let request = bolusManager.createGetActiveBolusDeliveryRequest(bolusValueSelection: .delivered)!
        var index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .getActiveBolusDelivery)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), bolusID)
        index += 2
        XCTAssertEqual(BolusValueSelection(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .delivered)
    }

    func testCreateGetActiveBolusProgrammedDetailsRequest() {
        let bolusID: BolusID = 1
        bolusManager.activeBolusDeliveryStatus.id = bolusID

        let request = bolusManager.createGetActiveBolusDeliveryRequest(bolusValueSelection: .programmed)!
        var index = 0
        XCTAssertEqual(IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .getActiveBolusDelivery)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), bolusID)
        index += 2
        XCTAssertEqual(BolusValueSelection(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt8.self)), .programmed)
    }
    
    func testHandleGetActiveBolusDeliveryNotApplicable() {
        // no active bolus test
        bolusManager.activeBolusDeliveryStatus = BolusDeliveryStatus.noActiveBolus
        bolusManager.activeBolusDeliveryUpdateHandler = bolusDeliveryUpdateHandler

        var result = bolusManager.handleGetActiveBolusDeliveryNotApplicable()
        switch result {
        case .success(_):
            XCTAssertNil(bolusDeliveryStatus?.progressState)
            XCTAssertNil(bolusDeliveryStatus?.endTime)
            XCTAssertNil(bolusManager.activeBolusDeliveryUpdateHandler)
        default:
            XCTAssert(false)
        }

        // active bolus test
        bolusManager.activeBolusDeliveryStatus = BolusDeliveryStatus(id: 123,
                                                                     progressState: .inProgress,
                                                                     type: .fast,
                                                                     insulinProgrammed: 2,
                                                                     insulinDelivered: 1)
        bolusManager.activeBolusDeliveryUpdateHandler = bolusDeliveryUpdateHandler
        
        result = bolusManager.handleGetActiveBolusDeliveryNotApplicable()
        switch result {
        case .success(_):
            XCTAssertNil(bolusManager.activeBolusDeliveryStatus.id)
            XCTAssertEqual(bolusDeliveryStatus?.progressState, .completed)
            XCTAssertEqual(bolusDeliveryStatus?.insulinDelivered, 2)
            XCTAssertNotNil(bolusDeliveryStatus?.endTime)
            XCTAssertNil(bolusManager.activeBolusDeliveryUpdateHandler)
        default:
            XCTAssert(false)
        }
    }
    
    func testHandleGetActiveBolusDeliveredDetailsResponse() {
        let opcode = IDStatusReaderOpcode.getActiveBolusDeliveryResponse
        let bolusID: BolusID = 123
        let insulinDelivered: Double = 2.3
        bolusManager.activeBolusDeliveryStatus.id = bolusID
        bolusManager.activeBolusDeliveryStatus.progressState = .estimatingProgress
        bolusManager.activeBolusDeliveryUpdateHandler = bolusDeliveryUpdateHandler
        _ = bolusManager.createGetActiveBolusDeliveryRequest(bolusValueSelection: .delivered)
        bolusManager.sendingActiveBolusRequest(.delivered)
        
        var response = Data(opcode.rawValue)
        response.append(UInt8(0x00)) // flags
        response.append(bolusID)
        response.append(BolusType.fast.rawValue)
        response.append(insulinDelivered.sfloat)
        response.append(0.sfloat) // extended bolus is 0 for fast
        response.append(UInt8(1)) // E2ECounter
        response = response.appendingCRC()
        
        let result = bolusManager.handleResponse(response, with: opcode)
        switch result {
        case .success(_):
            XCTAssertEqual(bolusDeliveryStatus?.progressState, .inProgress)
            XCTAssertEqual(bolusDeliveryStatus?.insulinDelivered, insulinDelivered)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGetActiveBolusProgrammedDetailsResponse() {
        let opcode = IDStatusReaderOpcode.getActiveBolusDeliveryResponse
        let bolusID: BolusID = 123
        let insulinDelivered: Double = 2.3
        bolusManager.activeBolusDeliveryStatus.id = bolusID
        bolusManager.activeBolusDeliveryStatus.progressState = .estimatingProgress
        bolusManager.activeBolusDeliveryUpdateHandler = bolusDeliveryUpdateHandler
        _ = bolusManager.createGetActiveBolusDeliveryRequest(bolusValueSelection: .programmed)
        bolusManager.sendingActiveBolusRequest(.programmed)

        var response = Data(opcode.rawValue)
        response.append(UInt8(0x00)) // flags
        response.append(bolusID)
        response.append(BolusType.fast.rawValue)
        response.append(insulinDelivered.sfloat)
        response.append(0.sfloat) // extended bolus is 0 for fast
        response.append(UInt8(1)) // E2ECounter
        response = response.appendingCRC()

        let result = bolusManager.handleResponse(response, with: opcode)
        switch result {
        case .success(_):
            XCTAssertEqual(bolusDeliveryStatus?.progressState, .inProgress)
            XCTAssertEqual(bolusDeliveryStatus?.insulinProgrammed, insulinDelivered)
        default:
            XCTAssert(false)
        }
    }

    func testStartEstimatingBolusProgress() {
        // no active bolus
        var bolusDeliveryStatus: BolusDeliveryStatus?
        bolusManager.activeBolusDeliveryUpdateHandler = { bolusDeliveryStatus = $0 }
        bolusManager.startEstimatingBolusProgress()
        XCTAssertEqual(bolusDeliveryStatus, .noActiveBolus)

        // active bolus
        bolusManager.activeBolusDeliveryStatus = BolusDeliveryStatus(id: 1, progressState: .inProgress, type: .fast, insulinProgrammed: 2.0, insulinDelivered: 0.5, startTime: Date())
        bolusManager.startEstimatingBolusProgress()
        XCTAssertEqual(bolusDeliveryStatus?.progressState, .estimatingProgress)
    }

    func testActiveBolusDeliveryCanceled() {
        var bolusDeliveryStatus: BolusDeliveryStatus?
        bolusManager.activeBolusDeliveryUpdateHandler = { bolusDeliveryStatus = $0 }
        let expectedCanceledBolusDeliveryStatus = BolusDeliveryStatus(id: 123,
                                                                      progressState: .canceled,
                                                                      type: .fast,
                                                                      insulinProgrammed: 2,
                                                                      insulinDelivered: 1)
        bolusManager.activeBolusDeliveryCanceled(canceledBolusDeliveryStatus: expectedCanceledBolusDeliveryStatus)
        XCTAssertEqual(bolusDeliveryStatus, expectedCanceledBolusDeliveryStatus)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus, .noActiveBolus)
    }

    func testHandleResponseInvalidFormat() {
        let bolusID: BolusID = 123
        bolusManager.activeBolusDeliveryStatus.id = bolusID
        let opcode = IDCommandControlPointOpcode.cancelBolusResponse
        var responseInvalidFormat = Data(opcode.rawValue)
        responseInvalidFormat.append(bolusID)
        responseInvalidFormat = responseInvalidFormat.appendingCRC()

        let result = bolusManager.handleResponse(responseInvalidFormat, with: opcode)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidFormat)
        default:
            XCTAssert(false)
        }
    }

    func testCreateActiveBolusDeliveryStatus() {
        let bolusID: BolusID = 2
        let insulinProgrammed = 1.2
        bolusManager.createActiveBolusDeliveryStatus(withID: bolusID, insulinProgrammed: insulinProgrammed)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.progressState, .inProgress)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.id, bolusID)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.insulinProgrammed, insulinProgrammed)
        XCTAssertNotNil(bolusManager.activeBolusDeliveryStatus.startTime)
    }

    func testHandleGetActiveBolusIDs() {
        let opcode = IDStatusReaderOpcode.getActiveBolusIDsResponse
        var numberOfActiveBoluses: UInt8 = 0
        let bolusID: BolusID = 123

        var response = Data(opcode.rawValue)
        response.append(numberOfActiveBoluses)
        response.append(UInt8(1)) // E2ECounter
        response = response.appendingCRC()

        var result = bolusManager.handleResponse(response, with: opcode)
        switch result {
        case .success(_):
            XCTAssertNil(bolusManager.activeBolusDeliveryStatus.id)
        default:
            XCTAssert(false)
        }

        numberOfActiveBoluses = 1
        response = Data(opcode.rawValue)
        response.append(numberOfActiveBoluses)
        response.append(bolusID)
        response.append(UInt8(2)) // E2ECounter
        response = response.appendingCRC()

        result = bolusManager.handleResponse(response, with: opcode)
        switch result {
        case .success(_):
            XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.id, bolusID)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGetActiveBolusIDsNoIDsResetActiveBolus() {
        bolusManager.activeBolusDeliveryStatus = BolusDeliveryStatus(id: 123, progressState: .inProgress, type: .fast, insulinProgrammed: 1, insulinDelivered: 0, startTime: Date())

        let opcode = IDStatusReaderOpcode.getActiveBolusIDsResponse
        let numberOfActiveBoluses: UInt8 = 0

        var response = Data(opcode.rawValue)
        response.append(numberOfActiveBoluses)
        response.append(UInt8(1)) // E2ECounter
        response = response.appendingCRC()

        let result = bolusManager.handleResponse(response, with: opcode)
        switch result {
        case .success(_):
            XCTAssertNil(bolusManager.activeBolusDeliveryStatus.id)
        default:
            XCTAssert(false)
        }
    }

    func testResetActiveBolus() {
        let activeBolus = BolusDeliveryStatus(id: 3, progressState: .inProgress, type: .fast, insulinProgrammed: 2, insulinDelivered: 0.5)
        bolusManager = BolusManager(activeBolusDeliveryStatus: activeBolus)
        bolusManager.resetActiveBolus()
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus, .noActiveBolus)
    }

    func testCompleteBolusForID() {
        let activeBolus = BolusDeliveryStatus(id: 3, progressState: .inProgress, type: .fast, insulinProgrammed: 2, insulinDelivered: 0.5)
        bolusManager = BolusManager(activeBolusDeliveryStatus: activeBolus)
        bolusManager.completeBolus(for: 1, insulinProgrammed: 1, insulinDelivered: 0.1, startTime: Date().addingTimeInterval(-1), duration: 1)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.progressState, .inProgress)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.id, 3)

        bolusManager.completeBolus(for: 3, insulinProgrammed: 2, insulinDelivered: 0.5, startTime: Date().addingTimeInterval(-20), duration: 20)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus, .noActiveBolus)
    }

    func testHandleTherapyControlState() {
        let activeBolus = BolusDeliveryStatus(id: 3, progressState: .inProgress, type: .fast, insulinProgrammed: 2, insulinDelivered: 0.5)
        bolusManager = BolusManager(activeBolusDeliveryStatus: activeBolus)
        bolusManager.activeBolusDeliveryUpdateHandler = bolusDeliveryUpdateHandler

        // therapy control state run
        bolusManager.handleTherapyControlState(.run)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus, activeBolus)
        XCTAssertNil(bolusDeliveryStatus)

        // therapy control state stop
        bolusManager.handleTherapyControlState(.stop)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.progressState, .canceled)
        XCTAssertEqual(bolusDeliveryStatus?.progressState, .canceled)
    }
}

extension BolusManagerTests {
    func bolusDeliveryUpdateHandler(bolusDeliveryStatus: BolusDeliveryStatus) {
        self.bolusDeliveryStatus = bolusDeliveryStatus
    }
}

extension BolusManagerTests: BolusManagerDelegate {
    func estimatedBolusDelivery(for elapsedTime: TimeInterval) -> Double? {
        2.5 / TimeInterval.minutes(1)
    }
    
    func bolusManagerDidUpdateActiveBolusDeliveryStatus(_ bolusManager: BolusManager) {
        reportedActiveBolusDeliveryStatus = bolusManager.activeBolusDeliveryStatus
    }
}
