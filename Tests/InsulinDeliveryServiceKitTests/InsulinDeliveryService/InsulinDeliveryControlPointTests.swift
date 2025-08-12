//
//  InsulinDeliveryControlPointTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-07-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import BluetoothCommonKit
@testable import InsulinDeliveryServiceKit

class InsulinDeliveryControlPointTests: XCTestCase, E2EProtectionDelegate {
    var isE2EProtectionSupported: Bool = true
    
    private var bolusManager: BolusManager!
    private var basalManager: BasalManager!
    private var insulinDeliveryControlPoint: IDCommandControlPointDataHandler!

    override func setUp() {
        bolusManager = BolusManager()
        basalManager = BasalManager()
        insulinDeliveryControlPoint = IDCommandControlPointDataHandler(bolusManager: bolusManager, basalManager: basalManager, e2eCounter: 1)
        insulinDeliveryControlPoint.e2eDelegate = self
    }

    override func tearDown() {
        _ = insulinDeliveryControlPoint.getPendingProceduresAndReset()
    }
    
    func testOpcode() {
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0f55), IDCommandControlPointOpcode.responseCode)
        XCTAssertNil(IDCommandControlPointOpcode.responseCode.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0f5a), IDCommandControlPointOpcode.setTherapyControlState)
        XCTAssertNil(IDCommandControlPointOpcode.setTherapyControlState.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0f66), IDCommandControlPointOpcode.setFlightMode)
        XCTAssertNil(IDCommandControlPointOpcode.setFlightMode.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0f69), IDCommandControlPointOpcode.snoozeAnnunciation)
        XCTAssertNil(IDCommandControlPointOpcode.snoozeAnnunciation.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0f96), IDCommandControlPointOpcode.snoozeAnnunciationResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.snoozeAnnunciation, IDCommandControlPointOpcode.snoozeAnnunciationResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0f99), IDCommandControlPointOpcode.confirmAnnunciation)
        XCTAssertNil(IDCommandControlPointOpcode.confirmAnnunciation.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0fa5), IDCommandControlPointOpcode.confirmAnnunciationResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.confirmAnnunciation, IDCommandControlPointOpcode.confirmAnnunciationResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0faa), IDCommandControlPointOpcode.readBasalRateTemplate)
        XCTAssertNil(IDCommandControlPointOpcode.readBasalRateTemplate.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0fc3), IDCommandControlPointOpcode.readBasalRateTemplateResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.readBasalRateTemplate, IDCommandControlPointOpcode.readBasalRateTemplateResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0fcc), IDCommandControlPointOpcode.writeBasalRateTemplate)
        XCTAssertNil(IDCommandControlPointOpcode.writeBasalRateTemplate.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0ff0), IDCommandControlPointOpcode.writeBasalRateTemplateResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.writeBasalRateTemplate, IDCommandControlPointOpcode.writeBasalRateTemplateResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x0fff), IDCommandControlPointOpcode.setTempBasalAdjustment)
        XCTAssertNil(IDCommandControlPointOpcode.setTempBasalAdjustment.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1111), IDCommandControlPointOpcode.cancelTempBasalAdjustment)
        XCTAssertNil(IDCommandControlPointOpcode.cancelTempBasalAdjustment.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x111e), IDCommandControlPointOpcode.getTempBasalTemplate)
        XCTAssertNil(IDCommandControlPointOpcode.getTempBasalTemplate.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1122), IDCommandControlPointOpcode.getTempBasalTemplateResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.getTempBasalTemplate, IDCommandControlPointOpcode.getTempBasalTemplateResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x112d), IDCommandControlPointOpcode.setTempBasalTemplate)
        XCTAssertNil(IDCommandControlPointOpcode.setTempBasalTemplate.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1144), IDCommandControlPointOpcode.setTempBasalTemplateResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.setTempBasalTemplate, IDCommandControlPointOpcode.setTempBasalTemplateResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x114b), IDCommandControlPointOpcode.setBolus)
        XCTAssertNil(IDCommandControlPointOpcode.setBolus.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1177), IDCommandControlPointOpcode.setBolusResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.setBolus, IDCommandControlPointOpcode.setBolusResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1178), IDCommandControlPointOpcode.cancelBolus)
        XCTAssertNil(IDCommandControlPointOpcode.cancelBolus.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1187), IDCommandControlPointOpcode.cancelBolusResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.cancelBolus, IDCommandControlPointOpcode.cancelBolusResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1188), IDCommandControlPointOpcode.getAvailableBoluses)
        XCTAssertNil(IDCommandControlPointOpcode.getAvailableBoluses.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x11b4), IDCommandControlPointOpcode.getAvailableBolusesResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.getAvailableBoluses, IDCommandControlPointOpcode.getAvailableBolusesResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x11bb), IDCommandControlPointOpcode.getBolusTemplate)
        XCTAssertNil(IDCommandControlPointOpcode.getBolusTemplate.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x11d2), IDCommandControlPointOpcode.getBolusTemplateResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.getBolusTemplate, IDCommandControlPointOpcode.getBolusTemplateResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x11dd), IDCommandControlPointOpcode.setBolusTemplate)
        XCTAssertNil(IDCommandControlPointOpcode.setBolusTemplate.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x11e1), IDCommandControlPointOpcode.setBolusTemplateResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.setBolusTemplate, IDCommandControlPointOpcode.setBolusTemplateResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x11ee), IDCommandControlPointOpcode.getTemplateStatusAndDetails)
        XCTAssertNil(IDCommandControlPointOpcode.getTemplateStatusAndDetails.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1212), IDCommandControlPointOpcode.getTemplateStatusAndDetailsResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.getTemplateStatusAndDetails, IDCommandControlPointOpcode.getTemplateStatusAndDetailsResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x121d), IDCommandControlPointOpcode.resetTemplateStatus)
        XCTAssertNil(IDCommandControlPointOpcode.resetTemplateStatus.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1221), IDCommandControlPointOpcode.resetTemplateStatusResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.resetTemplateStatus, IDCommandControlPointOpcode.resetTemplateStatusResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x122e), IDCommandControlPointOpcode.activateProfileTemplates)
        XCTAssertNil(IDCommandControlPointOpcode.activateProfileTemplates.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1247), IDCommandControlPointOpcode.activateProfileTemplatesResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.activateProfileTemplates, IDCommandControlPointOpcode.activateProfileTemplatesResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1248), IDCommandControlPointOpcode.getActivatedProfileTemplates)
        XCTAssertNil(IDCommandControlPointOpcode.getActivatedProfileTemplates.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1274), IDCommandControlPointOpcode.getActivatedProfileTemplatesResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.getActivatedProfileTemplates, IDCommandControlPointOpcode.getActivatedProfileTemplatesResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x127b), IDCommandControlPointOpcode.startPriming)
        XCTAssertNil(IDCommandControlPointOpcode.startPriming.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1284), IDCommandControlPointOpcode.stopPriming)
        XCTAssertNil(IDCommandControlPointOpcode.stopPriming.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x128b), IDCommandControlPointOpcode.setInitialResevoirFillLevel)
        XCTAssertNil(IDCommandControlPointOpcode.setInitialResevoirFillLevel.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x12b7), IDCommandControlPointOpcode.resetResevoirInsulinOperationTime)
        XCTAssertNil(IDCommandControlPointOpcode.resetResevoirInsulinOperationTime.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x12b8), IDCommandControlPointOpcode.readISFProfileTemplates)
        XCTAssertNil(IDCommandControlPointOpcode.readISFProfileTemplates.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x12d1), IDCommandControlPointOpcode.readISFProfileTemplatesResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.readISFProfileTemplates, IDCommandControlPointOpcode.readISFProfileTemplatesResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x12de), IDCommandControlPointOpcode.writeISFProfileTemplate)
        XCTAssertNil(IDCommandControlPointOpcode.writeISFProfileTemplate.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x12e2), IDCommandControlPointOpcode.writeISFProfileTemplateResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.writeISFProfileTemplate, IDCommandControlPointOpcode.writeISFProfileTemplateResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x12ed), IDCommandControlPointOpcode.readI2CHOProfileTemplates)
        XCTAssertNil(IDCommandControlPointOpcode.readI2CHOProfileTemplates.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1414), IDCommandControlPointOpcode.readI2CHOProfileTemplatesResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.readI2CHOProfileTemplates, IDCommandControlPointOpcode.readI2CHOProfileTemplatesResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x141b), IDCommandControlPointOpcode.writeI2CHOProfileTemplate)
        XCTAssertNil(IDCommandControlPointOpcode.writeI2CHOProfileTemplate.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1427), IDCommandControlPointOpcode.writeI2CHOProfileTemplateResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.writeI2CHOProfileTemplate, IDCommandControlPointOpcode.writeI2CHOProfileTemplateResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1428), IDCommandControlPointOpcode.readTargetGlucoseRangeProfileTemplates)
        XCTAssertNil(IDCommandControlPointOpcode.readTargetGlucoseRangeProfileTemplates.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1441), IDCommandControlPointOpcode.readTargetGlucoseRangeProfileTemplatesResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.readTargetGlucoseRangeProfileTemplates, IDCommandControlPointOpcode.readTargetGlucoseRangeProfileTemplatesResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x144e), IDCommandControlPointOpcode.writeTargetGlucoseRangeProfileTemplate)
        XCTAssertNil(IDCommandControlPointOpcode.writeTargetGlucoseRangeProfileTemplate.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1472), IDCommandControlPointOpcode.writeTargetGlucoseRangeProfileTemplateResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.writeTargetGlucoseRangeProfileTemplate, IDCommandControlPointOpcode.writeTargetGlucoseRangeProfileTemplateResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x147d), IDCommandControlPointOpcode.getMaxBolusAmount)
        XCTAssertNil(IDCommandControlPointOpcode.getMaxBolusAmount.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x1482), IDCommandControlPointOpcode.getMaxBolusAmountResponse)
        XCTAssertEqual(IDCommandControlPointOpcode.getMaxBolusAmount, IDCommandControlPointOpcode.getMaxBolusAmountResponse.requestOpcode)
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: 0x148d), IDCommandControlPointOpcode.setMaxBolusAmount)
        XCTAssertNil(IDCommandControlPointOpcode.setMaxBolusAmount.requestOpcode)
    }
    
    func testResponseCode() {
        XCTAssertEqual(IDCommandControlPointResponseCode(rawValue: 0x0f), IDCommandControlPointResponseCode.success)
        XCTAssertEqual(IDCommandControlPointResponseCode(rawValue: 0x70), IDCommandControlPointResponseCode.opcodeNotSupported)
        XCTAssertEqual(IDCommandControlPointResponseCode(rawValue: 0x71), IDCommandControlPointResponseCode.invalidOperand)
        XCTAssertEqual(IDCommandControlPointResponseCode(rawValue: 0x72), IDCommandControlPointResponseCode.procedureNotCompleted)
        XCTAssertEqual(IDCommandControlPointResponseCode(rawValue: 0x73), IDCommandControlPointResponseCode.parameterOutOfRange)
        XCTAssertEqual(IDCommandControlPointResponseCode(rawValue: 0x74), IDCommandControlPointResponseCode.procedureNotApplicable)
        XCTAssertEqual(IDCommandControlPointResponseCode(rawValue: 0x75), IDCommandControlPointResponseCode.plausibilityCheckFailed)
        XCTAssertEqual(IDCommandControlPointResponseCode(rawValue: 0x76), IDCommandControlPointResponseCode.maxBolusNumberReached)
    }

    func testInsulinTherapyControlState() {
        XCTAssertEqual(InsulinTherapyControlState(rawValue: 0x0f), InsulinTherapyControlState.undetermined)
        XCTAssertEqual(InsulinTherapyControlState(rawValue: 0x33), InsulinTherapyControlState.stop)
        XCTAssertEqual(InsulinTherapyControlState(rawValue: 0x3c), InsulinTherapyControlState.pause)
        XCTAssertEqual(InsulinTherapyControlState(rawValue: 0x55), InsulinTherapyControlState.run)
    }
    
    func testWriteBasalRateFlags() {
        let endTransaction: UInt8 = 0x01
        var writeBasalRateFlags = WriteBasalRateFlags(rawValue: endTransaction)
        XCTAssertTrue(writeBasalRateFlags.contains(.endTransaction))
        
        let secondTimeBlockPresent: UInt8 = 0x02
        writeBasalRateFlags = WriteBasalRateFlags(rawValue: secondTimeBlockPresent)
        XCTAssertTrue(writeBasalRateFlags.contains(.secondTimeBlockPresent))
        
        let thirdTimeBlockPresent: UInt8 = 0x04
        writeBasalRateFlags = WriteBasalRateFlags(rawValue: thirdTimeBlockPresent)
        XCTAssertTrue(writeBasalRateFlags.contains(.thirdTimeBlockPresent))
        
        let multipleFlags: UInt8 = 0x03
        writeBasalRateFlags = WriteBasalRateFlags(rawValue: multipleFlags)
        XCTAssertTrue(writeBasalRateFlags.contains(.endTransaction))
        XCTAssertTrue(writeBasalRateFlags.contains(.secondTimeBlockPresent))
    }
    
    func testHandleGeneralResponse() {
        let requestOpcode = IDCommandControlPointOpcode.setInitialResevoirFillLevel
        let responseCode = IDCommandControlPointResponseCode.success
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()
        
        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGeneralResponseOpcodeNotSupported() {
        let requestOpcode = IDCommandControlPointOpcode.setInitialResevoirFillLevel
        let responseCode = IDCommandControlPointResponseCode.opcodeNotSupported
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .opcodeNotSupported)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGeneralResponseInvalidOperand() {
        let requestOpcode = IDCommandControlPointOpcode.setInitialResevoirFillLevel
        let responseCode = IDCommandControlPointResponseCode.invalidOperand
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidOperand)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGeneralResponseProcedureNotCompleted() {
        let requestOpcode = IDCommandControlPointOpcode.setInitialResevoirFillLevel
        var responseCode = IDCommandControlPointResponseCode.procedureNotCompleted
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()

        var (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .procedureNotCompleted)
        default:
            XCTAssert(false)
        }

        responseCode = IDCommandControlPointResponseCode.plausibilityCheckFailed
        response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()

        (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .procedureNotCompleted)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGeneralResponseMaxBolusNumberReached() {
        let requestOpcode = IDCommandControlPointOpcode.setInitialResevoirFillLevel
        let responseCode = IDCommandControlPointResponseCode.maxBolusNumberReached
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .maxBolusNumberReached)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGeneralResponseParameterOutOfRange() {
        let requestOpcode = IDCommandControlPointOpcode.setInitialResevoirFillLevel
        let responseCode = IDCommandControlPointResponseCode.parameterOutOfRange
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .parameterOutOfRange)
        default:
            XCTAssert(false)
        }
    }

    func testHandleGeneralResponseProcedureNotApplicable() {
        let requestOpcode = IDCommandControlPointOpcode.setInitialResevoirFillLevel
        let responseCode = IDCommandControlPointResponseCode.procedureNotApplicable
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .procedureNotApplicable)
        default:
            XCTAssert(false)
        }
    }

    func testResponseOpcode() {
        let expectedResponseOpcode: IDCommandControlPointOpcode = .cancelBolusResponse
        let response = Data(expectedResponseOpcode.rawValue)
        let responseOpcode: IDCommandControlPointOpcode? = insulinDeliveryControlPoint.responseOpcode(response)
        XCTAssertEqual(responseOpcode, expectedResponseOpcode)
    }

    func testCreateSetInitialReservoirFillLevelRequest() {
        let fillLevel = 200
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createSetInitialReservoirFillLevelRequest(fillLevel))
        
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.setInitialResevoirFillLevel.rawValue)
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), fillLevel.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    
    func testCreateResetReservoirInuslinOperationTimeRequest() {
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createResetReservoirInsulinOperationTimeRequest())
        
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.resetResevoirInsulinOperationTime.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testCreateStartPrimingRequest() {
        let primingAmount = 1.0
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createStartPrimingRequest(primingAmount))

        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.startPriming.rawValue)
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), primingAmount.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testCreateStopPrimingRequest() {
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createStopPrimingRequest())
        
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.stopPriming.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testCreateStartInsulinTherapyRequest() {
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createStartInsulinTherapyRequest())
        
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.setTherapyControlState.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), InsulinTherapyControlState.run.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testCreateStopInsulinTherapyRequest() {
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createStopInsulinTherapyRequest())
        
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.setTherapyControlState.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), InsulinTherapyControlState.stop.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testCreateActivateProfileTemplatesRequest() {
        let numOfProfileTemplates: UInt8 = 1
        let profileTemplateNumber: UInt8 = 1
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createActivateProfileTemplatesRequest())
        
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.activateProfileTemplates.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), numOfProfileTemplates)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), profileTemplateNumber)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testHandleActivateProfileTemplatesResponse() {
        let numberOfProfiles: UInt8 = 1
        let profileTemplateNumber: UInt8 = 1
        var response = Data(IDCommandControlPointOpcode.activateProfileTemplatesResponse.rawValue)
        response.append(numberOfProfiles)
        response.append(profileTemplateNumber)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()
        
        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }
    
    func testCreateWriteBasalRateProfileRequest1Segment() {
        let basalTemplateNumber: TemplateNumber = 1
        let basalSegment = BasalSegment(index: 1,
                                        rate: 0.1,
                                        duration: TimeInterval.days(1).minutes)
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createWriteBasalRateSegmentsRequest(for: [basalSegment], templateNumber: basalTemplateNumber, isLast: true))
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.writeBasalRateTemplate.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), WriteBasalRateFlags.endTransaction.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalTemplateNumber)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalSegment.index)
        index += 1
        XCTAssertEqual(TimeInterval(minutes: Int(request[request.startIndex.advanced(by: index)...].to(UInt16.self))), basalSegment.duration)
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), basalSegment.rate.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testCreateWriteBasalRateProfileRequest2Segments() {
        let basalTemplateNumber: TemplateNumber = 1
        let basalSegment1 = BasalSegment(index: 1,
                                        rate: 0.1,
                                        duration: TimeInterval.hours(10).minutes)
        let basalSegment2 = BasalSegment(index: 2,
                                         rate: 0.2,
                                         duration: TimeInterval.hours(14).minutes)
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createWriteBasalRateSegmentsRequest(for: [basalSegment1, basalSegment2], templateNumber: basalTemplateNumber, isLast: true))
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.writeBasalRateTemplate.rawValue)
        index += 2
        
        let expectedFlags: WriteBasalRateFlags = [.endTransaction, .secondTimeBlockPresent]
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), expectedFlags.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalTemplateNumber)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalSegment1.index)
        index += 1
        XCTAssertEqual(TimeInterval(minutes: Int(request[request.startIndex.advanced(by: index)...].to(UInt16.self))), basalSegment1.duration)
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), basalSegment1.rate.sfloat)
        index += 2
        XCTAssertEqual(TimeInterval(minutes: Int(request[request.startIndex.advanced(by: index)...].to(UInt16.self))), basalSegment2.duration)
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), basalSegment2.rate.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testCreateWriteBasalRateProfileRequest3Segments() {
        let basalTemplateNumber: TemplateNumber = 1
        // 3 basal segments
        let basalSegment1 = BasalSegment(index: 1,
                                        rate: 0.1,
                                        duration: TimeInterval.hours(6).minutes)
        let basalSegment2 = BasalSegment(index: 2,
                                         rate: 0.2,
                                         duration: TimeInterval.hours(8).minutes)
        let basalSegment3 = BasalSegment(index: 3,
                                         rate: 0.03,
                                         duration: TimeInterval.hours(10).minutes)
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createWriteBasalRateSegmentsRequest(for: [basalSegment1, basalSegment2, basalSegment3], templateNumber: basalTemplateNumber, isLast: true))
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.writeBasalRateTemplate.rawValue)
        index += 2
        
        let expectedFlags: WriteBasalRateFlags = [.endTransaction, .secondTimeBlockPresent, .thirdTimeBlockPresent]
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), expectedFlags.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalTemplateNumber)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalSegment1.index)
        index += 1
        XCTAssertEqual(TimeInterval(minutes: Int(request[request.startIndex.advanced(by: index)...].to(UInt16.self))), basalSegment1.duration)
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), basalSegment1.rate.sfloat)
        index += 2
        XCTAssertEqual(TimeInterval(minutes: Int(request[request.startIndex.advanced(by: index)...].to(UInt16.self))), basalSegment2.duration)
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), basalSegment2.rate.sfloat)
        index += 2
        XCTAssertEqual(TimeInterval(minutes: Int(request[request.startIndex.advanced(by: index)...].to(UInt16.self))), basalSegment3.duration)
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), basalSegment3.rate.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testPrepareWriteBasalRateRequests4Segments() {
        let basalTemplateNumber: TemplateNumber = 1
        var basalProfile: [BasalSegment] = []
        let timeIncrement = TimeInterval.days(1)/4
        for index in 1...4 {
            let basalSegment = BasalSegment(index: UInt8(index),
                                            rate: Double(index)/10,
                                            duration: timeIncrement)
            basalProfile.append(basalSegment)
        }
        
        insulinDeliveryControlPoint.queueWriteBasalProfileRequests(for: basalProfile)
        XCTAssertFalse(insulinDeliveryControlPoint.requestQueue.isEmpty)
        XCTAssertEqual(insulinDeliveryControlPoint.requestQueue.count, 2)
        
        // check first request
        var request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.requestQueue[0].request)
        var expectedFlags: WriteBasalRateFlags = [.secondTimeBlockPresent, .thirdTimeBlockPresent]
        var index = 0
        
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.writeBasalRateTemplate.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), expectedFlags.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalTemplateNumber)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), 1)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.1.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.2.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.3.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
        
        // check second request
        request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.requestQueue[1].request)
        expectedFlags = [.endTransaction]
        index = 0
        
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.writeBasalRateTemplate.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), expectedFlags.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalTemplateNumber)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), 4)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.4.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testPrepareWriteBasalRateRequests8Segments() {
        let basalTemplateNumber: TemplateNumber = 1
        var basalProfile: [BasalSegment] = []
        let timeIncrement = TimeInterval.days(1)/8
        for index in 1...8 {
            let basalSegment = BasalSegment(index: UInt8(index),
                                            rate: Double(index)/10,
                                            duration: timeIncrement)
            basalProfile.append(basalSegment)
        }
        
        insulinDeliveryControlPoint.queueWriteBasalProfileRequests(for: basalProfile)
        XCTAssertFalse(insulinDeliveryControlPoint.requestQueue.isEmpty)
        XCTAssertEqual(insulinDeliveryControlPoint.requestQueue.count, 3)
        
        // check first request
        var request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.requestQueue[0].request)
        var expectedFlags: WriteBasalRateFlags = [.secondTimeBlockPresent, .thirdTimeBlockPresent]
        var index = 0
        
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.writeBasalRateTemplate.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), expectedFlags.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalTemplateNumber)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), 1)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.1.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.2.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.3.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
        
        // check second request
        request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.requestQueue[1].request)
        index = 0
        
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.writeBasalRateTemplate.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), expectedFlags.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalTemplateNumber)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), 4)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.4.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.5.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.6.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
        
        // check third request
        request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.requestQueue[2].request)
        expectedFlags = [.secondTimeBlockPresent, .endTransaction]
        index = 0
        
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.writeBasalRateTemplate.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), expectedFlags.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), basalTemplateNumber)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), 7)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.7.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), UInt16(timeIncrement.minutes))
        index += 2
        XCTAssertEqual(request.subdata(in: index..<index+2), 0.8.sfloat)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testHandleWriteBasalRateProfileResponse() {
        insulinDeliveryControlPoint.appendToRequestQueue(Data(IDCommandControlPointOpcode.writeBasalRateTemplate.rawValue), completion: nil)
        insulinDeliveryControlPoint.appendToRequestQueue(Data(IDCommandControlPointOpcode.writeBasalRateTemplate.rawValue), completion: nil)
        insulinDeliveryControlPoint.procedureRunning = true

        // initial response
        var flags: WriteBasalRateFlags = .allZeros
        var basalRateProfileNumber: UInt8 = 1
        var firstTimeBlockNumberIndex: UInt8 = 1
        var e2eCounter: UInt8 = 1
        var response = Data(IDCommandControlPointOpcode.writeBasalRateTemplateResponse.rawValue)
        response.append(flags.rawValue)
        response.append(basalRateProfileNumber)
        response.append(firstTimeBlockNumberIndex)
        response.append(e2eCounter)
        response = response.appendingCRC()

        var (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .partialResponse)
            XCTAssertFalse(insulinDeliveryControlPoint.procedureRunning)
            XCTAssertEqual(insulinDeliveryControlPoint.requestQueue.count, 1)
        default:
            XCTAssert(false)
        }

        // final response
        insulinDeliveryControlPoint.procedureRunning = true

        flags = .endTransaction
        firstTimeBlockNumberIndex = 4
        e2eCounter += 1
        response = Data(IDCommandControlPointOpcode.writeBasalRateTemplateResponse.rawValue)
        response.append(flags.rawValue)
        response.append(basalRateProfileNumber)
        response.append(firstTimeBlockNumberIndex)
        response.append(e2eCounter)
        response = response.appendingCRC()

        (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
            XCTAssertFalse(insulinDeliveryControlPoint.procedureRunning)
            XCTAssertTrue(insulinDeliveryControlPoint.requestQueue.isEmpty)
        default:
            XCTAssert(false)
        }
        
        // invalid response. The basal rate profile number needs to be 1 for Solo
        flags = .endTransaction
        basalRateProfileNumber = 2
        firstTimeBlockNumberIndex = 1
        e2eCounter += 1
        response = Data(IDCommandControlPointOpcode.writeBasalRateTemplateResponse.rawValue)
        response.append(flags.rawValue)
        response.append(basalRateProfileNumber)
        response.append(firstTimeBlockNumberIndex)
        response.append(e2eCounter)
        response = response.appendingCRC()
        
        (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .parameterOutOfRange)
        default:
            XCTAssert(false)
        }
    }
    
    func testCreateSnoozeAnnunciationRequest() {
        let annunciationID: UInt16 = 10
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createSnoozeAnnunciationRequest(for: annunciationID))
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.snoozeAnnunciation.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), annunciationID)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testHandleSnoozeAnnunciationResponse() {
        let annunciationID: UInt16 = 10
        var response = Data(IDCommandControlPointOpcode.snoozeAnnunciationResponse.rawValue)
        response.append(annunciationID)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()
        
        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }

    func testHandleSnoozeAnnunciationResponseInvalidFormat() {
        let annunciationID: UInt8 = 10
        var response = Data(IDCommandControlPointOpcode.snoozeAnnunciationResponse.rawValue)
        response.append(annunciationID)
        response = response.appendingCRC()

        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidFormat)
        default:
            XCTAssert(false)
        }
    }
    
    func testCreateConfirmAnnunciationRequest() {
        let annunciationID: UInt16 = 5
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createConfirmAnnunciationRequest(for: annunciationID))
        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), IDCommandControlPointOpcode.confirmAnnunciation.rawValue)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), annunciationID)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testHandleConfirmAnnunciationResponse() {
        let annunciationID: UInt16 = 10
        var response = Data(IDCommandControlPointOpcode.confirmAnnunciationResponse.rawValue)
        response.append(annunciationID)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()
        
        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }

    func testHandleConfirmAnnunciationResponseInvalidFormat() {
        let annunciationID: UInt8 = 10
        var response = Data(IDCommandControlPointOpcode.confirmAnnunciationResponse.rawValue)
        response.append(annunciationID)
        response = response.appendingCRC()

        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidFormat)
        default:
            XCTAssert(false)
        }
    }
    
    func testCreateSetBolusRequest() {
        let bolusAmount = 1.5
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createSetBolusRequest(for: bolusAmount, activationType: .manuallyChangedRecommendedBolus))
        
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDCommandControlPointOpcode.RawValue.self)), .setBolus)
        index += 2
        XCTAssertEqual(BolusFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(BolusFlag.RawValue.self)), .activationTypePresent)
        index += 1
        XCTAssertEqual(BolusType(rawValue: request[request.startIndex.advanced(by: index)...].to(BolusType.RawValue.self)), .fast)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), bolusAmount)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 0)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), 0)
        index += 2
        XCTAssertEqual(IDBolusActivationType(rawValue: request[request.startIndex.advanced(by: index)...].to(IDBolusActivationType.RawValue.self)), .manuallyChangedRecommendedBolus)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testHandleSetBolusResponse() {
        let bolusID: BolusID = 10
        var response = Data(IDCommandControlPointOpcode.setBolusResponse.rawValue)
        response.append(bolusID)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()
        
        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }
    
    func testCreateCancelCurrentBolusRequest() {
        let bolusID: BolusID = 5
        bolusManager.activeBolusDeliveryStatus = BolusDeliveryStatus(id: bolusID, progressState: .inProgress, type: .fast, insulinProgrammed: 2, insulinDelivered: 1)
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createCancelCurrentBolusRequest()!)
        
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .cancelBolus)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(BolusID.self), bolusID)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testHandleCancelBolusResponse() {
        let bolusID: BolusID = 10
        bolusManager.activeBolusDeliveryStatus = BolusDeliveryStatus(id: bolusID, progressState: .inProgress, type: .fast, insulinProgrammed: 2, insulinDelivered: 1)
        var response = Data(IDCommandControlPointOpcode.cancelBolusResponse.rawValue)
        response.append(bolusID)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()
        
        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.progressState, .canceled)
            XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.id, 10)
        default:
            XCTAssert(false)
        }
    }
    
    func testCreateSetTempBasalRequest() {
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createSetTempBasalRequest(unitsPerHour: 1.2,
                                                                                                                               durationInMinutes: 30,
                                                                                                                               deliveryContext: .aidController,
                                                                                                                               replaceExisting: false))
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDCommandControlPointOpcode.RawValue.self)), .setTempBasalAdjustment)
        index += 2
        XCTAssertEqual(TempBasalFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(TempBasalFlag.RawValue.self)), .deliveryContextPresent)
        index += 1
        XCTAssertEqual(TempBasalType(rawValue: request[request.startIndex.advanced(by: index)...].to(TempBasalType.RawValue.self)), .absolute)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)..<index+2].sfloatToDouble(), 1.2)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt16.self), 30)
        index += 2
        XCTAssertEqual(BasalDeliveryContext(rawValue: request[request.startIndex.advanced(by: index)...].to(BasalDeliveryContext.RawValue.self)), .aidController)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testHandleSetTempBasalAdjustmentResponse() {
        let requestOpcode = IDCommandControlPointOpcode.setTempBasalAdjustment
        let responseCode = IDCommandControlPointResponseCode.success
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()
        
        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }
    
    func testCreateCancelTempBasalRequest() {
        let request = insulinDeliveryControlPoint.appendingE2EProtection(insulinDeliveryControlPoint.createCancelTempBasalRequest())
        var index = 0
        XCTAssertEqual(IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(UInt16.self)), .cancelTempBasalAdjustment)
        index += 2
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), insulinDeliveryControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
    
    func testHandleCancelTempBasalAdjustmentResponse() {
        let requestOpcode = IDCommandControlPointOpcode.cancelTempBasalAdjustment
        let responseCode = IDCommandControlPointResponseCode.success
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()
        
        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        default:
            XCTAssert(false)
        }
    }
    
    func testIsActivateBasalRateResponse() {
        var response = Data(IDCommandControlPointOpcode.activateProfileTemplatesResponse.rawValue)
        XCTAssertTrue(insulinDeliveryControlPoint.isActivateBasalRateResponse(response))
        
        response = Data(IDCommandControlPointOpcode.setTherapyControlState.rawValue)
        XCTAssertFalse(insulinDeliveryControlPoint.isSetTherapyControlStateResponse(response))
    }
    
    func testIsSetTherapyControlStateResponse() {
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(IDCommandControlPointOpcode.setTherapyControlState.rawValue)
        XCTAssertTrue(insulinDeliveryControlPoint.isSetTherapyControlStateResponse(response))
        
        response = Data(IDCommandControlPointOpcode.activateProfileTemplatesResponse.rawValue)
        XCTAssertFalse(insulinDeliveryControlPoint.isSetTherapyControlStateResponse(response))
    }
    
    func testIsSetBolusResponse() {
        var response = Data(IDCommandControlPointOpcode.setBolusResponse.rawValue)
        XCTAssertTrue(insulinDeliveryControlPoint.isSetBolusResponse(response))
        
        response = Data(IDCommandControlPointOpcode.activateProfileTemplatesResponse.rawValue)
        XCTAssertFalse(insulinDeliveryControlPoint.isSetBolusResponse(response))
    }
    
    func testIsCancelBolusResponse() {
        var response = Data(IDCommandControlPointOpcode.cancelBolusResponse.rawValue)
        XCTAssertTrue(insulinDeliveryControlPoint.isCancelBolusResponse(response))
        
        response = Data(IDCommandControlPointOpcode.activateProfileTemplatesResponse.rawValue)
        XCTAssertFalse(insulinDeliveryControlPoint.isCancelBolusResponse(response))
    }
    
    func testIsSetTempBasalResponse() {
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(IDCommandControlPointOpcode.setTempBasalAdjustment.rawValue)
        XCTAssertTrue(insulinDeliveryControlPoint.isSetTempBasalResponse(response))
        
        response = Data(IDCommandControlPointOpcode.activateProfileTemplatesResponse.rawValue)
        XCTAssertFalse(insulinDeliveryControlPoint.isSetTempBasalResponse(response))
    }
    
    func testIsCancelTempBasalResponse() {
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(IDCommandControlPointOpcode.cancelTempBasalAdjustment.rawValue)
        XCTAssertTrue(insulinDeliveryControlPoint.isCancelTempBasalResponse(response))
        
        response = Data(IDCommandControlPointOpcode.activateProfileTemplatesResponse.rawValue)
        XCTAssertFalse(insulinDeliveryControlPoint.isCancelTempBasalResponse(response))
    }

    func testHandleResponseInvalidCRC() {
        let requestOpcode = IDCommandControlPointOpcode.setInitialResevoirFillLevel
        let responseCode = IDCommandControlPointResponseCode.success
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response.append(0x0000)

        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .invalidCRC)
        default:
            XCTAssert(false)
        }
    }

    func testHandleResponseOpcodeUnknown() {
        let requestOpcode = IDCommandControlPointOpcode.setInitialResevoirFillLevel
        let responseCode = IDCommandControlPointResponseCode.success
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()

        let (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .opcodeUnknown(response.hexadecimalString))
        default:
            XCTAssert(false)
        }
    }

    func testHandleResponseActivateProfileTemplatesParameterOutOfRange() {
        var numberOfProfiles: UInt8 = 2
        let profileTemplateNumber: UInt8 = 2
        var response = Data(IDCommandControlPointOpcode.activateProfileTemplatesResponse.rawValue)
        response.append(numberOfProfiles)
        response.append(profileTemplateNumber)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()

        var (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .parameterOutOfRange)
        default:
            XCTAssert(false)
        }

        numberOfProfiles = 1
        response = Data(IDCommandControlPointOpcode.activateProfileTemplatesResponse.rawValue)
        response.append(numberOfProfiles)
        response.append(profileTemplateNumber)
        response.append(insulinDeliveryControlPoint.e2eCounter)
        response = response.appendingCRC()

        (result, _) = insulinDeliveryControlPoint.handleResponse(response)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .parameterOutOfRange)
        default:
            XCTAssert(false)
        }
    }

    func testProcedureIDForResponse() {
        for opcode in IDCommandControlPointOpcode.responseOpcodes {
            if opcode == .responseCode {
                let requestOpcode = IDCommandControlPointOpcode.setTherapyControlState
                var response = Data(opcode.rawValue)
                response.append(requestOpcode.rawValue)
                let procedureID = insulinDeliveryControlPoint.procedureIDForResponse(response)
                XCTAssertEqual(procedureID, requestOpcode.procedureID)
            } else {
                let response = Data(opcode.rawValue)
                let procedureID = insulinDeliveryControlPoint.procedureIDForResponse(response)
                switch opcode {
                case .snoozeAnnunciationResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.snoozeAnnunciation.procedureID)
                case .confirmAnnunciationResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.confirmAnnunciation.procedureID)
                case .readBasalRateTemplateResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.readBasalRateTemplate.procedureID)
                case .writeBasalRateTemplateResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.writeBasalRateTemplate.procedureID)
                case .getTempBasalTemplateResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.getTempBasalTemplate.procedureID)
                case .setTempBasalTemplateResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.setTempBasalTemplate.procedureID)
                case .setBolusResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.setBolus.procedureID)
                case .cancelBolusResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.cancelBolus.procedureID)
                case .getAvailableBolusesResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.getAvailableBoluses.procedureID)
                case .getBolusTemplateResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.getBolusTemplate.procedureID)
                case .setBolusTemplateResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.setBolusTemplate.procedureID)
                case .getTemplateStatusAndDetailsResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.getTemplateStatusAndDetails.procedureID)
                case .resetTemplateStatusResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.resetTemplateStatus.procedureID)
                case .activateProfileTemplatesResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.activateProfileTemplates.procedureID)
                case .getActivatedProfileTemplatesResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.getActivatedProfileTemplates.procedureID)
                case .readISFProfileTemplatesResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.readISFProfileTemplates.procedureID)
                case .writeISFProfileTemplateResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.writeISFProfileTemplate.procedureID)
                case .readI2CHOProfileTemplatesResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.readI2CHOProfileTemplates.procedureID)
                case .writeI2CHOProfileTemplateResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.writeI2CHOProfileTemplate.procedureID)
                case .readTargetGlucoseRangeProfileTemplatesResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.readTargetGlucoseRangeProfileTemplates.procedureID)
                case .writeTargetGlucoseRangeProfileTemplateResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.writeTargetGlucoseRangeProfileTemplate.procedureID)
                case .getMaxBolusAmountResponse: XCTAssertEqual(procedureID, IDCommandControlPointOpcode.getMaxBolusAmount.procedureID)
                default:
                    XCTAssert(false)
                }
            }
        }
    }
}
