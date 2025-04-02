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

//TODO update tests to include server and client implementation

//MARK: - Support Server Implementation
open class IDStatusReaderControlPoint: E2EProtection {
    public var e2eCounter: UInt8 = 1
    
    var messageQueue: MessagingQueue

    public init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }

    open func onWrite(_ request: Data?) -> CBATTError.Code {
        ConsoleOut.shared.logMessage(message: "\(#function) ID Status Reader Control Point request \(String(describing: request?.hexadecimalString))")
        guard let request = request else {
            return CBATTError.Code.invalidPdu
        }

        var index = 0
        let requestOpcode = IDStatusReaderOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusReaderOpcode.RawValue.self))
        index += 2
        
        switch requestOpcode {
        case .resetStatus:
            ConsoleOut.shared.logMessage(message: "Opcode resetStatus (opcode: \(String(describing: requestOpcode)))")
            let flags = IDStatusChangedFlag(rawValue: request[request.startIndex...].to(IDStatusChangedFlag.RawValue.self))
            respondWithSuccess(to: .resetStatus)
        case .getActiveBolusIDs:
            ConsoleOut.shared.logMessage(message: "Opcode getActiveBolusIDs (opcode: \(String(describing: requestOpcode)))")
            responseToGetActiveBolusIDs()
        case .getActiveBolusDelivery:
            ConsoleOut.shared.logMessage(message: "Opcode getActiveBolusDelivery (opcode: \(String(describing: requestOpcode)))")
            let bolusID: BolusID = request[request.startIndex.advanced(by: index)...].to(BolusID.self)
            index += 2
            let selectionType = BolusValueSelection(rawValue: request[request.startIndex.advanced(by: index)...].to(BolusValueSelection.RawValue.self))
            responseToGetActiveBolus(selectionType!, bolusID: bolusID)
        case .getActiveBasalRateDelivery:
            ConsoleOut.shared.logMessage(message: "Opcode getActiveBasalRateDelivery (opcode: \(String(describing: requestOpcode)))")
            responseToGetActiveBasalRateDelivery()
        case .getTotalDailyInsulinStatus:
            ConsoleOut.shared.logMessage(message: "Opcode getTotalDailyInsulinStatus (opcode: \(String(describing: requestOpcode)))")
            responseToGetTotalDailyInsulin()
        case .getCounter:
            ConsoleOut.shared.logMessage(message: "Opcode getCounter (opcode: \(String(describing: requestOpcode)))")
            guard let counterType = CounterType(rawValue: request[request.startIndex...].to(CounterType.RawValue.self)),
                  let valueSelection = CounterValueSelection(rawValue: request[request.startIndex.advanced(by: 1)...].to(CounterValueSelection.RawValue.self))
            else {
                responseWithResponseCode(.invalidOperand, to: .getCounter)
                break
            }
            
            respondToGetCounter(type: counterType, valueSection: valueSelection)
        case .getDeliveredInsulin:
            ConsoleOut.shared.logMessage(message: "Opcode getDeliveredInsulin (opcode: \(String(describing: requestOpcode)))")
            responseToGetDeliveredInsulin()
        case .getInsulinOnBoard:
            ConsoleOut.shared.logMessage(message: "Opcode getDeliveredInsulin (opcode: \(String(describing: requestOpcode)))")
            responseToGetInsulinOnBoard()
        default:
            ConsoleOut.shared.logMessage(message: "Command not supported")
            return CBATTError.Code.commandNotSupported
        }
        return CBATTError.Code.success
    }
    
    open func responseToGetActiveBasalRateDelivery() {
        let opcode = IDStatusReaderOpcode.getActiveBasalRateDeliveryResponse
        let flag: ActiveBasalRateFlag = [.deliveryContextPresent]
        let activeBasalTemplate: UInt8 = 1
        let activeBasalRate: Double = 2.0
        let deliveryContext: BasalDeliveryContext = .aidController
        let amountDelivered: Double = 1.0
        
        
        var response = Data(opcode.rawValue)
        response.append(flag.rawValue)
        response.append(activeBasalTemplate)
        response.append(activeBasalRate.sfloat)
        response.append(deliveryContext.rawValue)
        response.append(amountDelivered.sfloat)
        sendResponse(response)
    }
    
    public func responseToGetActiveBolusIDs() {
        let opcode = IDStatusReaderOpcode.getActiveBolusIDsResponse
        let numberOfActiveBoluses: UInt8 = 1
        let bolusID: BolusID = 42
        
        var response = Data(opcode.rawValue)
        response.append(numberOfActiveBoluses)
        response.append(bolusID)
        sendResponse(response)
    }
    
    public func responseToGetActiveBolus(_ selectionType: BolusValueSelection, bolusID: BolusID = 42) {
        let opcode = IDStatusReaderOpcode.getActiveBolusDeliveryResponse
        let flag: BolusFlag = [.activationTypePresent]
        let bolusType: BolusType = .fast
        let bolusAmountFast: Double = selectionType == .programmed ? 2.0 : selectionType == .delivered ? 1.5 : 0.5
        let bolusAmountExtended: Double = 0.0
        let bolusDuration: UInt16 = 0
        let bolusActivationType: IDBolusActivationType = .aidController
        
        var response = Data(opcode.rawValue)
        response.append(flag.rawValue)
        response.append(bolusID)
        response.append(bolusType.rawValue)
        response.append(bolusAmountFast.sfloat)
        response.append(bolusAmountExtended.sfloat)
        response.append(bolusDuration)
        response.append(bolusActivationType.rawValue)
        sendResponse(response)
    }
    
    public func responseToGetTotalDailyInsulin() {
        let opcode = IDStatusReaderOpcode.getTotalDailyInsulinStatusResponse
        let bolusDelivered = 7.0
        let basalDelivered = 5.0
        
        var response = Data(opcode.rawValue)
        response.append(bolusDelivered.sfloat)
        response.append(basalDelivered.sfloat)
        response.append((bolusDelivered + basalDelivered).sfloat)
        sendResponse(response)
    }
    
    public func respondToGetCounter(type: CounterType, valueSection: CounterValueSelection) {
        let remainingTime: TimeInterval
        let elapsedTime: TimeInterval
        switch type {
        case .lifetime:
            remainingTime = .days(4)
            elapsedTime = .days(6)
        case .loanerTime:
            remainingTime = .days(20)
            elapsedTime = .days(10)
        case .reservoirInsulinOperationTime:
            remainingTime = .days(3)
            elapsedTime = .days(1)
        case .warrantyTime:
            remainingTime = .days(350)
            elapsedTime = .days(15)
        }
        
        let opcode = IDStatusReaderOpcode.getCounterResponse
        
        var response = Data(opcode.rawValue)
        response.append(type.rawValue)
        response.append(valueSection.rawValue)
        response.append(UInt32(valueSection == .elasped ? elapsedTime.minutes : remainingTime.minutes))
        sendResponse(response)
    }
    
    public func responseToGetDeliveredInsulin() {
        let opcode = IDStatusReaderOpcode.getDeliveredInsulinResponse
        let bolusDelivered = 15.0
        let basalDelivered = 35.0
        
        var response = Data(opcode.rawValue)
        response.append(bolusDelivered.sfloat)
        response.append(basalDelivered.sfloat)
        sendResponse(response)
    }
    
    public func responseToGetInsulinOnBoard(_ insulinOnBoard: Double = 3.4, remainingDuration: TimeInterval = .minutes(60)) {
        let opcode = IDStatusReaderOpcode.getInsulinOnBoardResponse
        
        var response = Data(opcode.rawValue)
        response.append(insulinOnBoard.sfloat)
        response.append(UInt16(remainingDuration.minutes))
        sendResponse(response)
    }

    public func respondWithSuccess(to requestOpcode: IDStatusReaderOpcode) {
        responseWithResponseCode(.success, to: requestOpcode)
    }
    
    public func responseWithResponseCode(_ responseCode: IDStatusReaderResponseCode, to requestOpcode: IDStatusReaderOpcode) {
        ConsoleOut.shared.logMessage(message: "\(#function) requestOpcode: \(requestOpcode) responseCode: \(responseCode)")
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        sendResponse(response)
    }
    
    public func sendResponse(_ response: Data) {
        let protectedResponse = appendingE2EProtection(response)
        messageQueue.addQueueItem(
            UUIDValuePair(
                uuid: InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID,
                value: protectedResponse
            )
        )
    }
}

//MARK: - Support Client Implementation
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

    public let lifetimeCounterType: CounterType = .lifetime
    public var lifetimeRemainingHandler: ((TimeInterval) -> Void)?
    
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
            let requestOpcode = IDStatusReaderOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDStatusReaderOpcode.RawValue.self))
            guard let responseCode = IDStatusReaderResponseCode(rawValue: response[response.startIndex.advanced(by: 4)...].to(IDStatusReaderResponseCode.RawValue.self))
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
        case .getActiveBolusIDsResponse:
            let completion = completeProcedure(IDStatusReaderOpcode.getActiveBolusIDs)
            return (bolusManager.handleResponse(response, with: opcode), completion)
        case .getActiveBolusDeliveryResponse:
            let completion = completeProcedure(IDStatusReaderOpcode.getActiveBolusDelivery)
            return (bolusManager.handleResponse(response, with: opcode), completion)
        case .getActiveBasalRateDeliveryResponse:
            let completion = completeProcedure(IDStatusReaderOpcode.getActiveBasalRateDelivery)
            return (basalManager.handleResponse(response, with: opcode), completion)
        case .getTotalDailyInsulinStatusResponse:
            // For AID implementations, this is currently unused
            let completion = completeProcedure(IDStatusReaderOpcode.getTotalDailyInsulinStatus)
            let totalDailyBolusDelivered = Data(response[response.startIndex...].to(SFLOAT.self)).sfloatToDouble()
            let totalDailyBasalDelivered = Data(response[response.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
            let totalDailyInsulinDelivered = Data(response[response.startIndex.advanced(by: 4)...].to(SFLOAT.self)).sfloatToDouble()
            return (.success, completion)
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
        case .getInsulinOnBoardResponse:
            // For AID implementations, this is currently unused
            let completion = completeProcedure(IDStatusReaderOpcode.getInsulinOnBoard)
            let flags = InsulinOnBoardFlag(rawValue: response[response.startIndex...].to(InsulinOnBoardFlag.RawValue.self))
            let insulinOnBoard = Data(response[response.startIndex.advanced(by: 1)...].to(SFLOAT.self)).sfloatToDouble()
            if flags.contains(.presentRemainingDuration) {
                let remainingDuration = TimeInterval.minutes(Int(response[response.startIndex.advanced(by: 3)...].to(UInt16.self)))
            }
            return (.success, completion)
        default:
            log.error("handler not implemented yet")
            return (.failure(.opcodeNotImplemented), nil)
        }
    }

    public func procedureIDForRequest(_ request: Data) -> ProcedureID {
        IDStatusReaderOpcode(rawValue: request[request.startIndex...].to(IDStatusReaderOpcode.RawValue.self)).procedureID
    }

    public func procedureIDForResponse(_ response: Data) -> ProcedureID? {
        for opcode in IDStatusReaderOpcode.responseOpcodes {
            if isSpecificResponse(expectedOpcode: opcode, response: response) {
                switch opcode {
                case .responseCode:
                    return  IDStatusReaderOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDStatusReaderOpcode.RawValue.self)).procedureID
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
        let opcode = IDStatusReaderOpcode(rawValue: response[response.startIndex...].to(IDStatusReaderOpcode.RawValue.self))
        guard opcode == expectedOpcode else {
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
public struct IDStatusReaderOpcode: RawRepresentable, Equatable, Sendable {
    public var rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    static public let responseCode = IDStatusReaderOpcode(rawValue: 0x0303)
    static public let resetStatus = IDStatusReaderOpcode(rawValue: 0x030c)
    static public let getActiveBolusIDs = IDStatusReaderOpcode(rawValue: 0x330)
    static public let getActiveBolusIDsResponse = IDStatusReaderOpcode(rawValue: 0x033f)
    static public let getActiveBolusDelivery = IDStatusReaderOpcode(rawValue: 0x0356)
    static public let getActiveBolusDeliveryResponse = IDStatusReaderOpcode(rawValue: 0x0359)
    static public let getActiveBasalRateDelivery = IDStatusReaderOpcode(rawValue: 0x0365)
    static public let getActiveBasalRateDeliveryResponse = IDStatusReaderOpcode(rawValue: 0x036a)
    static public let getTotalDailyInsulinStatus = IDStatusReaderOpcode(rawValue: 0x0395)
    static public let getTotalDailyInsulinStatusResponse = IDStatusReaderOpcode(rawValue: 0x039a)
    static public let getCounter = IDStatusReaderOpcode(rawValue: 0x03a6)
    static public let getCounterResponse = IDStatusReaderOpcode(rawValue: 0x03a9)
    static public let getDeliveredInsulin = IDStatusReaderOpcode(rawValue: 0x3c0)
    static public let getDeliveredInsulinResponse = IDStatusReaderOpcode(rawValue: 0x03cf)
    static public let getInsulinOnBoard = IDStatusReaderOpcode(rawValue: 0x03f3)
    static public let getInsulinOnBoardResponse = IDStatusReaderOpcode(rawValue: 0x03fc)
    
    public var procedureID: ProcedureID {
        String("InsulinDeliveryStatusReader.\(self.debugDescription)")
    }

    public var requestOpcode: IDStatusReaderOpcode? {
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

    static public var responseOpcodes: [IDStatusReaderOpcode] {
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
    
    public var debugDescription: String {
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
        default: return "unknown opcode \(self)"
        }
    }
}

public enum IDStatusReaderResponseCode: UInt8 {
    case success = 0x0f
    case opcodeNotSupported = 0x70
    case invalidOperand = 0x71
    case procedureNotCompleted = 0x72
    case parameterOutOfRange = 0x73
    case procedureNotApplicable = 0x74
    
    public var description: String {
        switch self {
        case .success: return "success"
        case .opcodeNotSupported: return "opcodeNotSupported"
        case .invalidOperand: return "invalidOperand"
        case .procedureNotCompleted: return "procedureNotCompleted"
        case .parameterOutOfRange: return "parameterOutOfRange"
        case .procedureNotApplicable: return "procedureNotApplicable"
        }
    }
}

public enum BolusValueSelection: UInt8 {
    case programmed = 0x0f
    case remaining = 0x33
    case delivered = 0x3c
    
    public var description: String {
        switch self {
        case .programmed: return "programmed"
        case .remaining: return "remaining"
        case .delivered: return "delivered"
        }
    }
}

public enum CounterType: UInt8 {
    case lifetime = 0x0f
    case warrantyTime = 0x33
    case loanerTime = 0x3c
    case reservoirInsulinOperationTime = 0x55
    
    public var description: String {
        switch self {
        case .lifetime: return "lifetime"
        case .warrantyTime: return "warrantyTime"
        case .loanerTime: return "loanerTime"
        case .reservoirInsulinOperationTime: return "reservoirInsulinOperationTime"
        }
    }
}

public enum CounterValueSelection: UInt8 {
    case remaining = 0x0f
    case elasped = 0x33
    
    public var description: String {
        switch self {
        case .remaining: return "remaining"
        case .elasped: return "elasped"
        }
    }
}

public struct InsulinOnBoardFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    static public let presentRemainingDuration = InsulinOnBoardFlag(rawValue: 1 << 0)
    static public let allZeros = InsulinOnBoardFlag([])
    
    static let debugDescriptions: [InsulinOnBoardFlag: String] = {
        var descriptions = [InsulinOnBoardFlag: String]()
        descriptions[.presentRemainingDuration] = "presentRemainingDuration"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in InsulinOnBoardFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "InsulinOnBoardFlag(rawValue: \(rawValue)) \(result)"
    }
}
