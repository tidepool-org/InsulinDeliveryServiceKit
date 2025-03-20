//
//  RecordAccessControlPoint.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import BluetoothCommonKit
import os.log

public typealias HistoryEventSequenceNumber = UInt32

class RecordAccessControlPoint: ControlPoint, E2EProtection {

    private let log = OSLog(category: "RecordAccessControlPoint")

    var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> = Locked([])

    private var lockedE2ECounter: Locked<UInt8>

    var procedureRunning: Bool = false
    
    var isReceivingHistoryEvents: Bool {
        guard procedureRunning,
              let request = lockedRequestQueue.value.first?.request,
              procedureIDForRequest(request) == RACPOpcode.reportStoredRecords.procedureID
        else { return false }
        
        return true
    }

    var e2eCounter: UInt8 {
        get {
            lockedE2ECounter.value
        }
        set {
            lockedE2ECounter.mutate { e2eCounter in
                e2eCounter = newValue
            }
        }
    }

    init(e2eCounter: UInt8 = RecordAccessControlPoint.e2eCounterInitalValue) {
        self.lockedE2ECounter = Locked(e2eCounter)
    }

    //MARK: - Response Handling
    func handleResponse(_ response: Data) -> (result: DeviceCommResult<Void>, completion: Any?) {
        guard response.isCRCValid else {
            return (.failure(.invalidCRC), nil)
        }

        guard let opcode: RACPOpcode = responseOpcode(response) else {
            log.error("Response opcode not known. Complete response: %{public}@", response.hexadecimalString)
            return (.failure(.opcodeUnknown(response.hexadecimalString)), nil)
        }

        log.debug("racp response opcode: %{public}@", opcode.procedureID)
        switch opcode {
        case .responseCode:
            guard response.count == 7,
                  RACPOperator(rawValue: response[response.startIndex.advanced(by: 1)...].to(RACPOperator.RawValue.self)) == .nullOperator
            else { return (.failure(.invalidFormat), nil) }

            guard let requestOpcode = RACPOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(RACPOpcode.RawValue.self)),
                  let responseCode = RACPResponseCode(rawValue: response[response.startIndex.advanced(by: 3)...].to(RACPResponseCode.RawValue.self))
            else { return (.failure(.parameterOutOfRange), nil) }

            log.debug("request opcode  %{public}@, response code %{public}@", requestOpcode.procedureID, String(reflecting: responseCode))

            let completion = completeProcedure(requestOpcode)

            switch responseCode {
            case .success:
                return (.success, completion)
            case .opcodeNotSupported:
                return (.failure(.opcodeNotSupported), completion)
            case .invalidOperator:
                return (.failure(.commandFailed(String(describing: responseCode))), completion)
            case .operatorNotSupported:
                return (.failure(.commandFailed(String(describing: responseCode))), completion)
            case .invalidOperand:
                return (.failure(.invalidOperand), completion)
            case .noRecordsFound:
                return (.failure(.noRecordsFound), completion)
            case .abortUnsuccessful:
                return (.failure(.commandFailed(String(describing: responseCode))), completion)
            case .procedureNotCompleted:
                return (.failure(.procedureNotCompleted), completion)
            case .operandNotSupported:
                return (.failure(.commandFailed(String(describing: responseCode))), completion)
            case .procedureNotApplicable:
                return (.failure(.procedureNotApplicable), completion)
            }
        case .numberOfStoredRecordsResponse:
            let completion = completeProcedure(RACPOpcode.reportNumberOfStoredRecords)
            let numberOfStoredRecords = Int(response[response.startIndex.advanced(by: 2)...].to(UInt32.self))
            log.debug("there are %{public}d stored records based on the request", numberOfStoredRecords)
            return (.success, completion)
        default:
            log.error("handler not implemented yet")
            return (.failure(.opcodeNotImplemented), nil)
        }
    }

    func procedureIDForResponse(_ response: Data) -> ProcedureID? {
        for opcode in RACPOpcode.responseOpcodes {
            if isSpecificResponse(expectedOpcode: opcode, response: response) {
                switch opcode {
                case .responseCode:
                    if let requestOpcode = RACPOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(RACPOpcode.RawValue.self)) {
                        return requestOpcode.procedureID
                    }
                default:
                    if let requestOpcode = opcode.requestOpcode {
                        return requestOpcode.procedureID
                    } else {
                        log.error("Opcode does not have a procedure ID")
                        break
                    }
                }
            }
        }
        log.error("Record Access Control Point response does not have a procedure ID (raw response: %{public}@)", response.toHexString())
        return nil
    }

    func procedureIDForRequest(_ request: Data) -> ProcedureID {
        guard let procedureID = RACPOpcode(rawValue: request[request.startIndex...].to(RACPOpcode.RawValue.self))?.procedureID else {
            fatalError("Opcode does not have a procedure ID \(request.toHexString())")
        }
        return procedureID
    }

    func isSpecificResponse(expectedOpcode: RACPOpcode, response: Data) -> Bool {
        guard let opcode = RACPOpcode(rawValue: response[response.startIndex...].to(RACPOpcode.RawValue.self)),
              opcode == expectedOpcode else
        {
            return false
        }
        return true
    }

    //MARK: - Create Request
    func buildRequest(_ opcode: RACPOpcode, racpOperator: RACPOperator = .nullOperator, operand: Data? = nil) -> Data {
        var operatorAndOperand = Data(racpOperator.rawValue)
        if let operand = operand {
            operatorAndOperand.append(operand)
        }
        return RecordAccessControlPoint.buildControlPointRequest(opcode: opcode, operand: operatorAndOperand)
    }

    func createGetAllStoredRecordsRequest(startingAtSequenceNumber sequenceNumber: HistoryEventSequenceNumber) -> Data {
        var operand = Data(RACPFilterType.sequenceNumber.rawValue)
        operand.append(sequenceNumber)
        return buildRequest(.reportStoredRecords, racpOperator: .greaterThanOrEqualTo, operand: operand)
    }

    func createGetNextBlockOfStoredRecordsRequest(startingAtSequenceNumber sequenceNumber: HistoryEventSequenceNumber) -> Data {
        let numberOfRecordsInBlock: UInt32 = 25
        var operand = Data(RACPFilterType.sequenceNumber.rawValue)
        operand.append(sequenceNumber)
        operand.append(sequenceNumber+numberOfRecordsInBlock)
        return buildRequest(.reportStoredRecords, racpOperator: .inclusiveRange, operand: operand)
    }

    func createGetMostCurrentStoredRecordRequest() -> Data {
        let operand = Data(RACPFilterType.sequenceNumber.rawValue)
        return buildRequest(.reportStoredRecords, racpOperator: .lastRecord, operand: operand)
    }

    func createGetMostCurrentStoredReferenceTimeRecordRequest() -> Data {
        let operand = Data(RACPFilterType.sequenceNumberByReferenceTimeEvent.rawValue)
        return buildRequest(.reportStoredRecords, racpOperator: .lastRecord, operand: operand)
    }

    func createOldestStoredRecordRequest() -> Data {
        let operand = Data(RACPFilterType.sequenceNumber.rawValue)
        return buildRequest(.reportStoredRecords, racpOperator: .firstRecord, operand: operand)
    }

    func createReportNumberOfStoredRecordsRequest() -> Data {
        let operand = Data(RACPFilterType.sequenceNumber.rawValue)
        return buildRequest(.reportNumberOfStoredRecords, racpOperator: .allRecords, operand: operand)
    }

    func createReportNumberOfStoredRecordsRequest(startingAtSequenceNumber sequenceNumber: HistoryEventSequenceNumber) -> Data {
        var operand = Data(RACPFilterType.sequenceNumber.rawValue)
        operand.append(sequenceNumber)
        return buildRequest(.reportNumberOfStoredRecords, racpOperator: .greaterThanOrEqualTo, operand: operand)
    }

    func createAbortProcedureRequest() -> Data {
        return buildRequest(.abortOperation)
    }

    //MARK: - Queue Request
    func queueGetAllStoredRecordsRequest(startingAtSequenceNumber sequenceNumber: HistoryEventSequenceNumber, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetAllStoredRecordsRequest(startingAtSequenceNumber: sequenceNumber), completion: completion)
    }

    func queueGetMostCurrentStoredReferenceTimeRecordRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetMostCurrentStoredReferenceTimeRecordRequest(), completion: completion)
    }

    func queueOldestStoredRecordRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createOldestStoredRecordRequest(), completion: completion)
    }

}

//MARK: - Write Record Access Control Point Request
extension PeripheralManager {
    func writeRecordAccessControlPointRequest(_ request: Data, type: CBCharacteristicWriteType = .withResponse, timeout: TimeInterval) throws {
        guard let characteristic = peripheral?.getInsulinDeliveryCharacteristicWithUUID(.recordAccessControlPoint) else {
            throw PeripheralManagerError.unknownCharacteristic
        }

        do {
            try writeValue(request, for: characteristic, type: type, timeout: timeout)
        } catch let error as PeripheralManagerError {
            throw error
        }
    }
}

//MARK: - Enumerations
enum RACPOpcode: UInt8, CaseIterable {
    case responseCode = 0x0f
    case reportStoredRecords = 0x33
    case deleteStoredRecords = 0x3c
    case abortOperation = 0x55
    case reportNumberOfStoredRecords = 0x5a
    case numberOfStoredRecordsResponse = 0x66

    var procedureID: ProcedureID {
        String("RecordAccessControlPoint.\(self.debugDescription)")
    }

    var requestOpcode: RACPOpcode? {
        switch self {
        case .numberOfStoredRecordsResponse: return .reportNumberOfStoredRecords
        default:
            return nil
        }
    }

    static var responseOpcodes: [RACPOpcode] {
        return [
            .responseCode,
            .numberOfStoredRecordsResponse,
        ]
    }

    private var debugDescription: String {
        switch self {
        case .responseCode: return "responseCode"
        case .reportStoredRecords: return "reportStoredRecords"
        case .deleteStoredRecords: return "deleteStoredRecords"
        case .abortOperation: return "abortOperation"
        case .reportNumberOfStoredRecords: return "reportNumberOfStoredRecords"
        case .numberOfStoredRecordsResponse: return "numberOfStoredRecordsResponse"
        }
    }
}

enum RACPOperator: UInt8 {
    case nullOperator = 0x0f
    case allRecords = 0x33
    case lessThanOrEqualTo = 0x3c
    case greaterThanOrEqualTo = 0x55
    case inclusiveRange = 0x5a
    case firstRecord = 0x66
    case lastRecord = 0x69
}

enum RACPResponseCode: UInt8, CustomStringConvertible {
    case success = 0xf0
    case opcodeNotSupported = 0x02
    case invalidOperator = 0x03
    case operatorNotSupported = 0x04
    case invalidOperand = 0x05
    case noRecordsFound = 0x06
    case abortUnsuccessful = 0x07
    case procedureNotCompleted = 0x08
    case operandNotSupported = 0x09
    case procedureNotApplicable = 0x0A

    var description: String {
        self.debugDescription
    }

    private var debugDescription: String {
        switch self {
        case .success: return "success"
        case .opcodeNotSupported: return "opcodeNotSupported"
        case .invalidOperator: return "invalidOperator"
        case .operatorNotSupported: return "operatorNotSupported"
        case .invalidOperand: return "invalidOperand"
        case .noRecordsFound: return "noRecordsFound"
        case .abortUnsuccessful: return "abortUnsuccessful"
        case .procedureNotCompleted: return "procedureNotCompleted"
        case .operandNotSupported: return "operandNotSupported"
        case .procedureNotApplicable: return "procedureNotApplicable"
        }
    }
}

enum RACPFilterType: UInt8 {
    case sequenceNumber = 0x0f
    case sequenceNumberByReferenceTimeEvent = 0x33 // filters by sequence number if the event type is a reference time or reference time base offset
    case sequenceNumberByNonReferenceTimeEvent = 0x3c // filters by sequence number if the event type is a not a reference time nor a reference time base offset
}
