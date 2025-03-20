//
//  IDStatusReader.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//
//
//  This is based on version 1.0 of the Insulin Delivery Service: https://www.bluetooth.com/specifications/specs/insulin-delivery-service-1-0/

import CoreBluetooth
import BluetoothCommonKit
import os.log

public class IDStatusReader: ControlPoint, E2EProtection {
    
    private let log = OSLog(category: "IDSStatusReader")

    public var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> = Locked([])

    private var lockedE2ECounter: Locked<UInt8>

    private let bolusManager: BolusManager
    
    private let basalManager: BasalManager

    public var procedureRunning: Bool = false {
        didSet {
            guard procedureRunning else { return }
            informBolusManagerIfNeeded()
        }
    }

    public var e2eCounter: UInt8 {
        get {
            lockedE2ECounter.value
        }
        set {
            lockedE2ECounter.mutate { e2eCounter in
                e2eCounter = newValue
            }
        }
    }

    let lifetimeCounterType: CounterType = .lifetime
    var lifetimeRemainingHandler: ((TimeInterval) -> Void)?
    
    var totalInsulinDeliveredHandler: ((_ totalBolusDelivered: Double, _ totalBasalDelivered: Double) -> Void)?
    
    init(bolusManager: BolusManager,
         basalManager: BasalManager,
         e2eCounter: UInt8 = IDStatusReader.e2eCounterInitalValue)
    {
        self.bolusManager = bolusManager
        self.basalManager = basalManager
        self.lockedE2ECounter = Locked(e2eCounter)
    }
    
    //MARK: - Response Handling
    func handleResponse(_ response: Data) -> (result: DeviceCommResult<Void>, completion: Any?) {
        guard response.isCRCValid else {
            return (.failure(.invalidCRC), nil)
        }
        
        guard let opcode: IDStatusReaderOpcode = responseOpcode(response) else {
            log.error("Response opcode not known. Complete response: %{public}@", response.hexadecimalString)
            return (.failure(.opcodeUnknown(response.hexadecimalString)), nil)
        }
        
        log.debug("idsr response opcode: %{public}@", opcode.procedureID)
        
        switch opcode {
        case .responseCode:
            guard response.count == 8 else { return (.failure(.invalidFormat), nil) }

            guard let requestOpcode = IDStatusReaderOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDStatusReaderOpcode.RawValue.self)),
                  let responseCode = IDStatusReaderResponseCode(rawValue: response[response.startIndex.advanced(by: 4)...].to(IDStatusReaderResponseCode.RawValue.self))
            else {
                return (.failure(.parameterOutOfRange), nil)
            }
            log.debug("request opcode %{public}@, response code %{public}@", requestOpcode.procedureID, String(reflecting: responseCode))
            let completion = completeProcedure(requestOpcode)

            switch responseCode {
            case .success:
                return (.success, completion)
            case .invalidOperand:
                return (.failure(.invalidOperand), completion)
            case .opcodeNotSupported:
                return (.failure(.opcodeNotSupported), completion)
            case .parameterOutOfRange:
                return (.failure(.parameterOutOfRange), completion)
            case .procedureNotApplicable:
                if requestOpcode == .getActiveBolusDelivery {
                    return (bolusManager.handleGetActiveBolusDeliveryNotApplicable(), completion)
                }
                return (.failure(.procedureNotApplicable), completion)
            case .procedureNotCompleted:
                return (.failure(.procedureNotCompleted), completion)
            }
        case .getActiveBolusDeliveryResponse:
            let completion = completeProcedure(IDStatusReaderOpcode.getActiveBolusDelivery)
            return (bolusManager.handleResponse(response, with: opcode), completion)
        case .getActiveBolusIDsResponse:
            let completion = completeProcedure(IDStatusReaderOpcode.getActiveBolusIDs)
            return (bolusManager.handleResponse(response, with: opcode), completion)
        case .getCounterResponse:
            let completion = completeProcedure(IDStatusReaderOpcode.getCounter)
            guard response.count == 11 else { return (.failure(.invalidFormat), completion) }

            guard let counterType = CounterType(rawValue: response[response.startIndex.advanced(by: 2)...].to(CounterType.RawValue.self)),
                  let counterValueSelection = CounterValueSelection(rawValue: response[response.startIndex.advanced(by: 3)...].to(CounterValueSelection.RawValue.self))
            else {
                return (.failure(.parameterOutOfRange), completion)
            }

            if counterType == .lifetime,
               counterValueSelection == .remaining
            {
                let remainingLifetime = TimeInterval.minutes(Int(response[response.startIndex.advanced(by: 4)...].to(Int32.self)))
                lifetimeRemainingHandler?(remainingLifetime)
            }
            return (.success, completion)
        case .getDeliveredInsulinResponse:
            let completion = completeProcedure(IDStatusReaderOpcode.getDeliveredInsulin)
            return (basalManager.handleResponse(response, with: opcode), completion)
        case .getActiveBasalRateDeliveryResponse:
            let completion = completeProcedure(IDStatusReaderOpcode.getActiveBasalRateDelivery)
            return (basalManager.handleResponse(response, with: opcode), completion)
        default:
            log.error("handler not implemented yet")
            return (.failure(.opcodeNotImplemented), nil)
        }
    }

    public func procedureIDForRequest(_ request: Data) -> ProcedureID {
        guard let procedureID = IDStatusReaderOpcode(rawValue: request[request.startIndex...].to(IDStatusReaderOpcode.RawValue.self))?.procedureID else {
            fatalError("Opcode does not have a procedure ID \(request.toHexString())")
        }
        return procedureID
    }

    public func procedureIDForResponse(_ response: Data) -> ProcedureID? {
        for opcode in IDStatusReaderOpcode.responseOpcodes {
            if isSpecificResponse(expectedOpcode: opcode, response: response) {
                switch opcode {
                case .responseCode:
                    if let requestOpcode = IDStatusReaderOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDStatusReaderOpcode.RawValue.self)) {
                        return  requestOpcode.procedureID
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
        log.error("Insulin Delivery Status Reader response does not have a procedure ID (raw response: %{public}@)", response.toHexString())
        return nil
    }

    func isSpecificResponse(expectedOpcode: IDStatusReaderOpcode, response: Data) -> Bool {
        guard let opcode = IDStatusReaderOpcode(rawValue: response[response.startIndex...].to(IDStatusReaderOpcode.RawValue.self)),
              opcode == expectedOpcode else
        {
            return false
        }
        return true
    }

    //MARK: - Create Request
    private func informBolusManagerIfNeeded() {
        guard IDStatusReaderOpcode.getActiveBolusDelivery == currentProcedureOpcode(),
              let (request, _) = nextRequestToSend(),
              request.count >= 5,
              let bolusValueSelection = BolusValueSelection(rawValue: request[request.startIndex.advanced(by: 4)...].to(BolusValueSelection.RawValue.self))
        else { return }
        
        bolusManager.sendingActiveBolusRequest(bolusValueSelection)
    }
    
    func buildRequest(_ opcode: IDStatusReaderOpcode, operand: Data? = nil) -> Data {
        IDStatusReader.buildControlPointRequest(opcode: opcode, operand: operand)
    }
    
    func createGetActiveBolusDeliveredDetailsRequest() -> Data? {
        bolusManager.createGetActiveBolusDeliveryRequest(bolusValueSelection: .delivered)
    }

    func createGetActiveBolusProgrammedDetailsRequest() -> Data? {
        bolusManager.createGetActiveBolusDeliveryRequest(bolusValueSelection: .programmed)
    }

    func createGetRemainingLifetimeRequest() -> Data {
        var operand = Data(CounterType.lifetime.rawValue)
        operand.append(CounterValueSelection.remaining.rawValue)
        return buildRequest(IDStatusReaderOpcode.getCounter, operand: operand)
    }
    
    func createGetDeliveredInsulinRequest() -> Data {
        buildRequest(.getDeliveredInsulin)
    }
    
    func createGetActiveBasalRateDeliveryRequest() -> Data {
        buildRequest(.getActiveBasalRateDelivery)
    }

    func createResetStatusChangedRequestFor(_ statusToReset: IDStatusChangedFlag) -> Data {
        let operand = Data(statusToReset.rawValue)
        return buildRequest(.resetStatus, operand:operand)
    }

    func createGetActiveBolusIDs() -> Data {
        buildRequest(.getActiveBolusIDs)
    }

    //MARK: - Queue Request
    func didQueueGetActiveBolusDeliveredDetailsRequest(completion: ProcedureResultCompletion? = nil) -> Bool {
        guard let request = createGetActiveBolusDeliveredDetailsRequest() else { return false }
        appendToRequestQueue(request, completion: completion)
        return true
    }

    func didQueueGetActiveBolusProgrammedDetailsRequest(completion: ProcedureResultCompletion? = nil) -> Bool {
        guard let request = createGetActiveBolusProgrammedDetailsRequest() else { return false }
        appendToRequestQueue(request, completion: completion)
        return true
    }

    func queueGetRemainingLifetimeRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetRemainingLifetimeRequest(), completion: completion)
    }

    func queueGetDeliveredInsulinRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetDeliveredInsulinRequest(), completion: completion)
    }
    
    func queueGetActiveBasalRateDelivery(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetActiveBasalRateDeliveryRequest(), completion: completion)
    }

    func queueResetStatusChangedRequest(_ statusToReset: IDStatusChangedFlag, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createResetStatusChangedRequestFor(statusToReset), completion: completion)
    }

    func queueGetActiveBolusIDs(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetActiveBolusIDs(), completion: completion)
    }
}

//MARK: - Write Insulin Delivery Status Reader Request
extension PeripheralManager {
    func writeInsulinDeliveryStatusReaderRequest(_ request: Data, type: CBCharacteristicWriteType = .withResponse, timeout: TimeInterval) throws {
        guard let characteristic = peripheral?.getInsulinDeliveryCharacteristicWithUUID(.statusReaderControlPoint) else {
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
enum IDStatusReaderOpcode: UInt16, CaseIterable {
    case responseCode = 0x0303
    case resetStatus = 0x030c
    case getActiveBolusIDs = 0x330
    case getActiveBolusIDsResponse = 0x033f
    case getActiveBolusDelivery = 0x0356
    case getActiveBolusDeliveryResponse = 0x0359
    case getActiveBasalRateDelivery = 0x0365
    case getActiveBasalRateDeliveryResponse = 0x036a
    case getTotalDailyInsulinStatus = 0x0395
    case getTotalDailyInsulinStatusResponse = 0x039a
    case getCounter = 0x03a6
    case getCounterResponse = 0x03a9
    case getDeliveredInsulin = 0x3c0
    case getDeliveredInsulinResponse = 0x03cf
    case getInsulinOnBoard = 0x03f3
    case getInsulinOnBoardResponse = 0x03fc
    
    var procedureID: ProcedureID {
        String("InsulinDeliveryStatusReader.\(self.debugDescription)")
    }

    var requestOpcode: IDStatusReaderOpcode? {
        switch self {
        case .getActiveBolusIDsResponse: return .getActiveBolusIDs
        case .getActiveBolusDeliveryResponse: return .getActiveBolusDelivery
        case .getActiveBasalRateDeliveryResponse: return .getActiveBasalRateDelivery
        case .getTotalDailyInsulinStatusResponse: return .getTotalDailyInsulinStatus
        case .getCounterResponse: return .getCounter
        case .getDeliveredInsulinResponse: return .getDeliveredInsulin
        case .getInsulinOnBoardResponse: return .getInsulinOnBoard
        default:
            return nil
        }
    }

    static var responseOpcodes: [IDStatusReaderOpcode] {
        return [
            .responseCode,
            .getActiveBolusIDsResponse,
            .getActiveBolusDeliveryResponse,
            .getActiveBasalRateDeliveryResponse,
            .getTotalDailyInsulinStatusResponse,
            .getCounterResponse,
            .getDeliveredInsulinResponse,
            .getInsulinOnBoardResponse
        ]
    }
    
    private var debugDescription: String {
        switch self {
        case .responseCode: return "responseCode"
        case .resetStatus: return "resetStatus"
        case .getActiveBolusIDs: return "getActiveBolusIDs"
        case .getActiveBolusIDsResponse: return "getActiveBolusIDsResponse"
        case .getActiveBolusDelivery: return "getActiveBolusDelivery"
        case .getActiveBolusDeliveryResponse: return "getActiveBolusDeliveryResponse"
        case .getActiveBasalRateDelivery: return "getActiveBasalRateDelivery"
        case .getActiveBasalRateDeliveryResponse: return "getActiveBasalRateDeliveryResponse"
        case .getTotalDailyInsulinStatus: return "getTotalDailyInsulinStatus"
        case .getTotalDailyInsulinStatusResponse: return "getTotalDailyInsulinStatusResponse"
        case .getCounter: return "getCounter"
        case .getCounterResponse: return "getCounterResponse"
        case .getDeliveredInsulin: return "getDeliveredInsulin"
        case .getDeliveredInsulinResponse: return "getDeliveredInsulinResponse"
        case .getInsulinOnBoard: return "getInsulinOnBoard"
        case .getInsulinOnBoardResponse: return "getInsulinOnBoardResponse"
        }
    }
}

enum IDStatusReaderResponseCode: UInt8 {
    case success = 0x0f
    case opcodeNotSupported = 0x70
    case invalidOperand = 0x71
    case procedureNotCompleted = 0x72
    case parameterOutOfRange = 0x73
    case procedureNotApplicable = 0x74
}

enum BolusValueSelection: UInt8 {
    case programmed = 0x0f
    case remaining = 0x33
    case delivered = 0x3c
}

enum CounterType: UInt8 {
    case lifetime = 0x0f
    case warrantyTime = 0x33
    case loanerTime = 0x3c
    case reservoirInsulinOperationTime = 0x55
}

enum CounterValueSelection: UInt8 {
    case remaining = 0x0f
    case elasped = 0x33
}
