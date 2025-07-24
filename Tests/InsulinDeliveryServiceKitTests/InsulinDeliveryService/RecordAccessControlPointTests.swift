//
//  RecordAccessControlPointTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-07-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import BluetoothCommonKit
@testable import InsulinDeliveryServiceKit

class RecordAccessControlPointTests: XCTestCase, E2EProtectionDelegate {
    var isE2EProtectionSupported: Bool = true

    private let recordAccessControlPoint = IDRecordAccessControlPointDataHandler()

    override func setUp() {
        recordAccessControlPoint.e2eDelegate = self
    }
    
    func testIDRACPOpcode() {
        XCTAssertEqual(IDRACPOpcode(rawValue: 0x0f), .responseCode)
        XCTAssertEqual(IDRACPOpcode(rawValue: 0x33), .reportStoredRecords)
        XCTAssertEqual(IDRACPOpcode(rawValue: 0x3c), .deleteStoredRecords)
        XCTAssertEqual(IDRACPOpcode(rawValue: 0x55), .abortOperation)
        XCTAssertEqual(IDRACPOpcode(rawValue: 0x5a), .reportNumberOfStoredRecords)
        XCTAssertEqual(IDRACPOpcode(rawValue: 0x66), .numberOfStoredRecordsResponse)
    }

    func testIDRACPOperator() {
        XCTAssertEqual(IDRACPOperator(rawValue: 0x0f), .nullOperator)
        XCTAssertEqual(IDRACPOperator(rawValue: 0x33), .allRecords)
        XCTAssertEqual(IDRACPOperator(rawValue: 0x3c), .lessThanOrEqualTo)
        XCTAssertEqual(IDRACPOperator(rawValue: 0x55), .greaterThanOrEqualTo)
        XCTAssertEqual(IDRACPOperator(rawValue: 0x5a), .inclusiveRange)
        XCTAssertEqual(IDRACPOperator(rawValue: 0x66), .firstRecord)
        XCTAssertEqual(IDRACPOperator(rawValue: 0x69), .lastRecord)
    }

    func testIDRACPResponseCode() {
        XCTAssertEqual(IDRACPResponseCode(rawValue: 0xf0), .success)
        XCTAssertEqual(IDRACPResponseCode(rawValue: 0x02), .opcodeNotSupported)
        XCTAssertEqual(IDRACPResponseCode(rawValue: 0x03), .invalidOperator)
        XCTAssertEqual(IDRACPResponseCode(rawValue: 0x04), .operatorNotSupported)
        XCTAssertEqual(IDRACPResponseCode(rawValue: 0x05), .invalidOperand)
        XCTAssertEqual(IDRACPResponseCode(rawValue: 0x06), .noRecordsFound)
        XCTAssertEqual(IDRACPResponseCode(rawValue: 0x07), .abortUnsuccessful)
        XCTAssertEqual(IDRACPResponseCode(rawValue: 0x08), .procedureNotCompleted)
        XCTAssertEqual(IDRACPResponseCode(rawValue: 0x09), .operandNotSupported)
        XCTAssertEqual(IDRACPResponseCode(rawValue: 0x0A), .procedureNotApplicable)
    }

    func testIDRACPFilterType() {
        XCTAssertEqual(IDRACPFilterType(rawValue: 0x0f), .recordNumber)
        XCTAssertEqual(IDRACPFilterType(rawValue: 0x33), .recordNumberByReferenceTimeEvent)
        XCTAssertEqual(IDRACPFilterType(rawValue: 0x3c), .recordNumberByNonReferenceTimeEvent)
    }

    func testBolusDeliveredFlag() {
        var flags = BolusDeliveredFlag(rawValue: 0)
        XCTAssertEqual(flags, BolusDeliveredFlag.allZeros)

        flags = BolusDeliveredFlag(rawValue: 7)
        XCTAssertTrue(flags.contains(.activationTypePresent))
        XCTAssertTrue(flags.contains(.endReasonPresent))
        XCTAssertTrue(flags.contains(.annunciationIDPresent))
    }

    func testBolusEndReason() {
        XCTAssertEqual(BolusEndReason(rawValue: 0x0f), .undetermined)
        XCTAssertEqual(BolusEndReason(rawValue: 0x33), .programmedAmountDelivered)
        XCTAssertEqual(BolusEndReason(rawValue: 0x3c), .canceled)
        XCTAssertEqual(BolusEndReason(rawValue: 0x55), .errorAbort)
    }

    func testCreateRequestGetAllStoredRecordsStartingAt() {
        let startAtrecordNumber: RecordNumber = 100
        var request = recordAccessControlPoint.createGetAllStoredRecordsRequest(afterIncludingRecordNumber: startAtrecordNumber)
        request = recordAccessControlPoint.appendingE2EProtection(request)

        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOpcode.reportStoredRecords.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOperator.greaterThanOrEqualTo.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPFilterType.recordNumber.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self), startAtrecordNumber)
        index += 4
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), recordAccessControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }

    func testCreateRequestGetNextBlockOfStoredRecordsStartingAt() {
        let startAtrecordNumber: RecordNumber = 100
        let endAtrecordNumber: RecordNumber = 125
        var request = recordAccessControlPoint.createGetNextBlockOfStoredRecordsRequest(startingAtRecordNumber: startAtrecordNumber)
        request = recordAccessControlPoint.appendingE2EProtection(request)

        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOpcode.reportStoredRecords.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOperator.inclusiveRange.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPFilterType.recordNumber.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self), startAtrecordNumber)
        index += 4
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self), endAtrecordNumber)
        index += 4
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), recordAccessControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }

    func testCreateRequestGetMostCurrentStoredRecords() {
        var request = recordAccessControlPoint.createGetMostCurrentStoredRecordRequest()
        request = recordAccessControlPoint.appendingE2EProtection(request)

        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOpcode.reportStoredRecords.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOperator.lastRecord.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPFilterType.recordNumber.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), recordAccessControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }

    func testCreateRequestReportNumberOfStoredRecordsStartingAt() {
        let startAtRecordNumber: RecordNumber = 100
        var request = recordAccessControlPoint.createReportNumberOfStoredRecordsRequest(afterIncludingRecordNumber: startAtRecordNumber)
        request = recordAccessControlPoint.appendingE2EProtection(request)

        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOpcode.reportNumberOfStoredRecords.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOperator.greaterThanOrEqualTo.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPFilterType.recordNumber.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self), startAtRecordNumber)
        index += 4
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), recordAccessControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }

    func testCreateRequestAbortProcedure() {
        var request = recordAccessControlPoint.createAbortProcedureRequest()
        request = recordAccessControlPoint.appendingE2EProtection(request)

        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOpcode.abortOperation.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOperator.nullOperator.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), recordAccessControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }

    func testProcedureIDForRequest() {
        var request = recordAccessControlPoint.createGetAllStoredRecordsRequest(afterIncludingRecordNumber: 100)
        XCTAssertEqual(recordAccessControlPoint.procedureIDForRequest(request), IDRACPOpcode.reportStoredRecords.procedureID)

        request = recordAccessControlPoint.createReportNumberOfStoredRecordsRequest(afterIncludingRecordNumber: 100)
        XCTAssertEqual(recordAccessControlPoint.procedureIDForRequest(request), IDRACPOpcode.reportNumberOfStoredRecords.procedureID)

        request = recordAccessControlPoint.createAbortProcedureRequest()
        XCTAssertEqual(recordAccessControlPoint.procedureIDForRequest(request), IDRACPOpcode.abortOperation.procedureID)
    }

    func testHandleResponseResponseCodeSuccess() {
        let response = createResponseCode(forRequestOpcode: .reportStoredRecords, withResponseCode: .success)
        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        case .failure(_):
            XCTAssert(false)
        }
    }

    func testHandleResponseResponseCodeOpodeNotSupported() {
        let response = createResponseCode(forRequestOpcode: .reportStoredRecords, withResponseCode: .opcodeNotSupported)
        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .opcodeNotSupported)
        }
    }

    func testHandleResponseResponseCodeInvalidOperator() {
        let response = createResponseCode(forRequestOpcode: .reportStoredRecords, withResponseCode: .invalidOperator)
        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .commandFailed(String(describing: IDRACPResponseCode.invalidOperator)))
        }
    }

    func testHandleResponseResponseCodeOperatorNotSupported() {
        let response = createResponseCode(forRequestOpcode: .reportStoredRecords, withResponseCode: .operatorNotSupported)
        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .commandFailed(String(describing: IDRACPResponseCode.operatorNotSupported)))
        }
    }

    func testHandleResponseResponseCodeInvalidOperand() {
        let response = createResponseCode(forRequestOpcode: .reportStoredRecords, withResponseCode: .invalidOperand)
        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .invalidOperand)
        }
    }

    func testHandleResponseResponseCodeNoRecordsFound() {
        let response = createResponseCode(forRequestOpcode: .reportStoredRecords, withResponseCode: .noRecordsFound)
        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .noRecordsFound)
        }
    }

    func testHandleResponseResponseCodeAbortUnsuccessful() {
        let response = createResponseCode(forRequestOpcode: .reportStoredRecords, withResponseCode: .abortUnsuccessful)
        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .commandFailed(String(describing: IDRACPResponseCode.abortUnsuccessful)))
        }
    }

    func testHandleResponseResponseCodeProcedureNotCompleted() {
        let response = createResponseCode(forRequestOpcode: .reportStoredRecords, withResponseCode: .procedureNotCompleted)
        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .procedureNotCompleted)
        }
    }

    func testHandleResponseResponseCodeOperandNotSupported() {
        let response = createResponseCode(forRequestOpcode: .reportStoredRecords, withResponseCode: .operandNotSupported)
        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .commandFailed(String(describing: IDRACPResponseCode.operandNotSupported)))
        }
    }

    func testHandleResponseResponseCodeProcedureNotApplicable() {
        let response = createResponseCode(forRequestOpcode: .reportStoredRecords, withResponseCode: .procedureNotApplicable)
        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(false)
        case .failure(let error):
            XCTAssertEqual(error, .procedureNotApplicable)
        }
    }

    func testHandleResponseNumberOfStoredRecords() {
        // reportNumberOfStoredRecords
        var response = Data(IDRACPOpcode.numberOfStoredRecordsResponse.rawValue)
        response.append(IDRACPOperator.nullOperator.rawValue)
        response.append(UInt32(100))
        response = recordAccessControlPoint.appendingE2EProtection(response)

        let (result, _) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success(_):
            XCTAssert(true)
        case .failure(_):
            XCTAssert(false)
        }
    }

    func testProcedureIDForResponse() {
        // report stored records
        var response = Data(IDRACPOpcode.responseCode.rawValue)
        response.append(IDRACPOperator.nullOperator.rawValue)
        response.append(IDRACPOpcode.reportStoredRecords.rawValue)
        response.append(IDRACPResponseCode.success.rawValue)
        XCTAssertEqual(recordAccessControlPoint.procedureIDForResponse(response), IDRACPOpcode.reportStoredRecords.procedureID)

        // abort procedure
        response = Data(IDRACPOpcode.responseCode.rawValue)
        response.append(IDRACPOperator.nullOperator.rawValue)
        response.append(IDRACPOpcode.abortOperation.rawValue)
        response.append(IDRACPResponseCode.success.rawValue)
        XCTAssertEqual(recordAccessControlPoint.procedureIDForResponse(response), IDRACPOpcode.abortOperation.procedureID)

        // reportNumberOfStoredRecords
        response = Data(IDRACPOpcode.numberOfStoredRecordsResponse.rawValue)
        response.append(IDRACPOperator.nullOperator.rawValue)
        response.append(UInt32(100))
        XCTAssertEqual(recordAccessControlPoint.procedureIDForResponse(response), IDRACPOpcode.reportNumberOfStoredRecords.procedureID)
    }

    func testCreateGetMostCurrentStoredReferenceTimeRecordRequest() {
        var request = recordAccessControlPoint.createGetMostCurrentStoredReferenceTimeRecordRequest()
        request = recordAccessControlPoint.appendingE2EProtection(request)

        var index = 0
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOpcode.reportStoredRecords.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPOperator.lastRecord.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), IDRACPFilterType.recordNumberByReferenceTimeEvent.rawValue)
        index += 1
        XCTAssertEqual(request[request.startIndex.advanced(by: index)...].to(UInt8.self), recordAccessControlPoint.e2eCounter)
        XCTAssertTrue(request.isCRCValid)
    }
}

extension RecordAccessControlPointTests {
    func createResponseCode(forRequestOpcode requestOpcode: IDRACPOpcode, withResponseCode responseCode: IDRACPResponseCode) -> Data {
        var response = Data(IDRACPOpcode.responseCode.rawValue)
        response.append(IDRACPOperator.nullOperator.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        response = recordAccessControlPoint.appendingE2EProtection(response)

        return response
    }
}
