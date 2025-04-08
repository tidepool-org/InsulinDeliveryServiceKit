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
public protocol IDStatusReaderControlPointCharacteristicDelegate: AnyObject {
    var isPumpBehaviourEnabled: Bool { get }
    func getActiveBolusIDs() -> [BolusID]
    func isBolusIDActive(_ bolusID: BolusID) -> Bool
    func getActiveBolusDelivery(for bolusID: BolusID, bolusValueSelection: BolusValueSelection) -> (bolusType: BolusType, fastAmount: Double, extendedAmount: Double, duration: TimeInterval, delay: TimeInterval?, templateNumber: UInt8?, activationType: IDBolusActivationType?, isMeal: Bool, isCorrection: Bool)
    func getActiveBasalDelivery() -> (profileNumber: UInt8, rate: Double, tempBasalType: TempBasalType?, tempBasalRate: Double?, tempBasalDurationProgrammed: TimeInterval?, tempBasalDurationRemaining: TimeInterval?, tempBasalTemplateNumber: UInt8?, basalDeliveryContext: BasalDeliveryContext?)
    func getTotalDailyInsulin() -> (bolusDelivered: Double, basalDelivered: Double)
    func getCounterDuration(for counterType: CounterType, counterValueSelection: CounterValueSelection) -> TimeInterval
    func getDeliveredInsulin() -> (bolusDelivered: Double, basalDelivered: Double)
    func getInsulinOnBoard() -> (amount: Double, duration: TimeInterval?)
}

open class IDStatusReaderControlPointCharacteristic: E2EProtection {
    public var e2eCounter: UInt8 = 0

    public weak var e2eDelegate: E2EProtectionDelegate?
    
    public weak var delegate: IDStatusReaderControlPointCharacteristicDelegate?
    
    var messageQueue: MessagingQueue
    
    let statusChangedCharacteristic: IDStatusChangedCharacteristic

    public init(messageQueue: MessagingQueue,
                statusChangedCharacteristic: IDStatusChangedCharacteristic) {
        self.messageQueue = messageQueue
        self.statusChangedCharacteristic = statusChangedCharacteristic
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
            let flags = IDStatusChangedFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(IDStatusChangedFlag.RawValue.self))
            ConsoleOut.shared.logMessage(message: "Opcode resetStatus (opcode: \(String(describing: requestOpcode))), flags: \(flags)")
            statusChangedCharacteristic.resetFlags(flags)
            respondWithSuccess(to: .resetStatus)
        case .getActiveBolusIDs:
            ConsoleOut.shared.logMessage(message: "Opcode getActiveBolusIDs (opcode: \(String(describing: requestOpcode)))")
            let activeBolusIDs = delegate?.getActiveBolusIDs() ?? []
            responseToGetActiveBolusIDs(activeBolusIDs)
        case .getActiveBolusDelivery:
            let bolusID: BolusID = request[request.startIndex.advanced(by: index)...].to(BolusID.self)
            index += 2
            
            guard let selectionType = BolusValueSelection(rawValue: request[request.startIndex.advanced(by: index)...].to(BolusValueSelection.RawValue.self)) else {
                response(to: .getActiveBolusDelivery, with: .invalidOperand)
                break
            }
            
            ConsoleOut.shared.logMessage(message: "Opcode getActiveBolusDelivery (opcode: \(String(describing: requestOpcode))), bolusID: \(bolusID), selectionType: \(selectionType)")
            
            guard delegate?.isBolusIDActive(bolusID) ?? false else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    response(to: .getActiveBolusDelivery, with: .procedureNotApplicable)
                    break
                }
                responseToGetActiveBolus(bolusID: bolusID, bolusType: .fast, fastAmount: 1, extendedAmount: 2, duration: .minutes(3), delay: 4, templateNumber: 5, activationType: .manuallyChangedRecommendedBolus, isMeal: false, isCorrection: true)
                break
            }

            guard let activeBolusDelivery = delegate?.getActiveBolusDelivery(for: bolusID, bolusValueSelection: selectionType) else {
                response(to: .getActiveBolusDelivery, with: .procedureNotApplicable)
                break
            }
            responseToGetActiveBolus(bolusID: bolusID, bolusType: activeBolusDelivery.bolusType, fastAmount: activeBolusDelivery.fastAmount, extendedAmount: activeBolusDelivery.extendedAmount, duration: activeBolusDelivery.duration, delay: activeBolusDelivery.delay, templateNumber: activeBolusDelivery.templateNumber, activationType: activeBolusDelivery.activationType, isMeal: activeBolusDelivery.isMeal, isCorrection: activeBolusDelivery.isCorrection)
        case .getActiveBasalRateDelivery:
            ConsoleOut.shared.logMessage(message: "Opcode getActiveBasalRateDelivery (opcode: \(String(describing: requestOpcode)))")
            guard let activeBasalDelivery = delegate?.getActiveBasalDelivery() else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    response(to: .getActiveBasalRateDelivery, with: .procedureNotApplicable)
                    break
                }
                responseToGetActiveBasalRateDelivery(profileNumber: 1, rate: 2, tempBasalType: .absolute, tempBasalRate: 3, tempBasalDurationProgrammed: .minutes(15), tempBasalDurationRemaining: .minutes(8), tempBasalTemplateNumber: 1, basalDeliveryContext: .aidController)
                break
            }
            responseToGetActiveBasalRateDelivery(profileNumber: activeBasalDelivery.profileNumber, rate: activeBasalDelivery.rate, tempBasalType: activeBasalDelivery.tempBasalType, tempBasalRate: activeBasalDelivery.tempBasalRate, tempBasalDurationProgrammed: activeBasalDelivery.tempBasalDurationProgrammed, tempBasalDurationRemaining: activeBasalDelivery.tempBasalDurationRemaining, tempBasalTemplateNumber: activeBasalDelivery.tempBasalTemplateNumber, basalDeliveryContext: activeBasalDelivery.basalDeliveryContext)
        case .getTotalDailyInsulinStatus:
            ConsoleOut.shared.logMessage(message: "Opcode getTotalDailyInsulinStatus (opcode: \(String(describing: requestOpcode)))")
            guard let totalDailyInsulin = delegate?.getTotalDailyInsulin() else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    response(to: .getTotalDailyInsulinStatus, with: .procedureNotApplicable)
                    break
                }
                responseToGetTotalDailyInsulin(bolusDelivered: 10, basalDelivered: 5)
                break
            }
            responseToGetTotalDailyInsulin(bolusDelivered: totalDailyInsulin.bolusDelivered, basalDelivered: totalDailyInsulin.basalDelivered)
        case .getCounter:
            guard let counterType = CounterType(rawValue: request[request.startIndex.advanced(by: index)...].to(CounterType.RawValue.self)),
                  let valueSelection = CounterValueSelection(rawValue: request[request.startIndex.advanced(by: index+1)...].to(CounterValueSelection.RawValue.self))
            else {
                response(to: .getCounter, with: .invalidOperand)
                break
            }
            ConsoleOut.shared.logMessage(message: "Opcode getCounter (opcode: \(String(describing: requestOpcode))), counterType: \(counterType), valueSelection: \(valueSelection)")

            guard let duration = delegate?.getCounterDuration(for: counterType, counterValueSelection: valueSelection) else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    response(to: .getCounter, with: .procedureNotApplicable)
                    break
                }
                respondToGetCounter(type: counterType, valueSection: valueSelection, duration: .hours(10))
                break
            }
            respondToGetCounter(type: counterType, valueSection: valueSelection, duration: duration)
        case .getDeliveredInsulin:
            ConsoleOut.shared.logMessage(message: "Opcode getDeliveredInsulin (opcode: \(String(describing: requestOpcode)))")
            guard let deliveredInsulin = delegate?.getDeliveredInsulin() else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    response(to: .getDeliveredInsulin, with: .procedureNotApplicable)
                    break
                }
                responseToGetDeliveredInsulin(bolusDelivered: 20, basalDelivered: 40)
                break
            }
            responseToGetDeliveredInsulin(bolusDelivered: deliveredInsulin.bolusDelivered, basalDelivered: deliveredInsulin.basalDelivered)
        case .getInsulinOnBoard:
            ConsoleOut.shared.logMessage(message: "Opcode getDeliveredInsulin (opcode: \(String(describing: requestOpcode)))")
            guard let insulinOnBoard = delegate?.getInsulinOnBoard() else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    response(to: .getInsulinOnBoard, with: .procedureNotApplicable)
                    break
                }
                responseToGetInsulinOnBoard(4.2, remainingDuration: .minutes(60))
                break
            }
            responseToGetInsulinOnBoard(insulinOnBoard.amount, remainingDuration: insulinOnBoard.duration)
        default:
            ConsoleOut.shared.logMessage(message: "Command not supported")
            return CBATTError.Code.commandNotSupported
        }
        return CBATTError.Code.success
    }
    
    open func responseToGetActiveBasalRateDelivery(profileNumber: UInt8,
                                                   rate: Double,
                                                   tempBasalType: TempBasalType?,
                                                   tempBasalRate: Double?,
                                                   tempBasalDurationProgrammed: TimeInterval?,
                                                   tempBasalDurationRemaining: TimeInterval?,
                                                   tempBasalTemplateNumber: UInt8?,
                                                   basalDeliveryContext: BasalDeliveryContext?) {
        let opcode = IDStatusReaderOpcode.getActiveBasalRateDeliveryResponse
        var response = Data(opcode.rawValue)
        response.append(profileNumber)
        response.append(rate.sfloat)
        
        var flags: ActiveBasalRateFlag = .allZeros
        if let tempBasalType,
           let tempBasalRate,
           let tempBasalDurationProgrammed,
           let tempBasalDurationRemaining
        {
            flags.insert(.tbrPresent)
            response.append(tempBasalType.rawValue)
            response.append(tempBasalRate.sfloat)
            response.append(UInt16(tempBasalDurationProgrammed.minutes))
            response.append(UInt16(tempBasalDurationRemaining.minutes))
        }
        
        if let tempBasalTemplateNumber {
            flags.insert(.tbrTemplateNumberPresent)
            response.append(tempBasalTemplateNumber)
        }
        
        if let basalDeliveryContext {
            flags.insert(.deliveryContextPresent)
            response.append(basalDeliveryContext.rawValue)
        }
        
        response.insert(flags.rawValue, at: 2)
        sendResponse(response)
    }
    
    public func responseToGetActiveBolusIDs(_ activeBolusIDs: [BolusID]) {
        let opcode = IDStatusReaderOpcode.getActiveBolusIDsResponse
        var response = Data(opcode.rawValue)
        response.append(UInt8(activeBolusIDs.count))
        
        for activeBolusID in activeBolusIDs {
            response.append(activeBolusID)
        }

        sendResponse(response)
    }
    
    public func responseToGetActiveBolus(bolusID: BolusID,
                                         bolusType: BolusType,
                                         fastAmount: Double,
                                         extendedAmount: Double,
                                         duration: TimeInterval,
                                         delay: TimeInterval?,
                                         templateNumber: UInt8?,
                                         activationType: IDBolusActivationType?,
                                         isMeal: Bool,
                                         isCorrection: Bool)
    {
        let opcode = IDStatusReaderOpcode.getActiveBolusDeliveryResponse
        var flags: BolusFlag = .allZeros
        if isMeal {
            flags.insert(.deliveryReasonMeal)
        }
        if isCorrection {
            flags.insert(.deliveryReasonCorrection)
        }
        
        var response = Data(opcode.rawValue)
        response.append(bolusID)
        response.append(bolusType.rawValue)
        response.append(fastAmount.sfloat)
        response.append(extendedAmount.sfloat)
        response.append(UInt16(duration.minutes))
        
        if let delay {
            flags.insert(.delayTimePresent)
            response.append(UInt16(delay.minutes))
        }
        
        if let templateNumber {
            flags.insert(.templateNumberPresent)
            response.append(templateNumber)
        }
        
        if let activationType {
            flags.insert(.activationTypePresent)
            response.append(activationType.rawValue)
        }
        
        response.insert(flags.rawValue, at: 2)

        sendResponse(response)
    }
    
    public func responseToGetTotalDailyInsulin(bolusDelivered: Double, basalDelivered: Double) {
        let opcode = IDStatusReaderOpcode.getTotalDailyInsulinStatusResponse
        
        var response = Data(opcode.rawValue)
        response.append(bolusDelivered.sfloat)
        response.append(basalDelivered.sfloat)
        response.append((bolusDelivered + basalDelivered).sfloat)
        sendResponse(response)
    }
    
    public func respondToGetCounter(type: CounterType, valueSection: CounterValueSelection, duration: TimeInterval) {
        let opcode = IDStatusReaderOpcode.getCounterResponse
        
        var response = Data(opcode.rawValue)
        response.append(type.rawValue)
        response.append(valueSection.rawValue)
        response.append(UInt32(duration.minutes))
        sendResponse(response)
    }
    
    public func responseToGetDeliveredInsulin(bolusDelivered: Double, basalDelivered: Double) {
        let opcode = IDStatusReaderOpcode.getDeliveredInsulinResponse
        
        var response = Data(opcode.rawValue)
        response.append(bolusDelivered.float)
        response.append(basalDelivered.float)
        sendResponse(response)
    }
    
    public func responseToGetInsulinOnBoard(_ amount: Double, remainingDuration: TimeInterval?) {
        let opcode = IDStatusReaderOpcode.getInsulinOnBoardResponse
        var flags: InsulinOnBoardFlag = .allZeros
        var response = Data(opcode.rawValue)
        response.append(amount.sfloat)
        
        if let remainingDuration {
            flags.insert(.presentRemainingDuration)
            response.append(UInt16(remainingDuration.minutes))
        }
            
        response.insert(flags.rawValue, at: 2)
        sendResponse(response)
    }

    public func respondWithSuccess(to requestOpcode: IDStatusReaderOpcode) {
        response(to: requestOpcode, with: .success)
    }
    
    public func response(to requestOpcode: IDStatusReaderOpcode, with responseCode: IDStatusReaderResponseCode) {
        ConsoleOut.shared.logMessage(message: "\(#function) requestOpcode: \(requestOpcode) responseCode: \(responseCode)")
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        sendResponse(response)
    }
    
    public func sendResponse(_ response: Data) {
        var response = response
        if e2eDelegate?.isE2EProtectionSupported ?? false {
            incrementE2ECounter()
            response = appendingE2EProtection(response)
        }
        messageQueue.addQueueItem(
            UUIDValuePair(
                uuid: InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID,
                value: response
            )
        )
    }
}

//MARK: - Support Client Implementation
public class IDStatusReaderControlPointDataHandler: ControlPoint, E2EProtection {
    
    private let log = OSLog(category: "IDSStatusReader")

    public var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> = Locked([])

    private var lockedE2ECounter: Locked<UInt8>
    
    public weak var e2eDelegate: E2EProtectionDelegate?

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
    
    public init(bolusManager: BolusManager,
                basalManager: BasalManager,
                e2eCounter: UInt8 = IDStatusReaderControlPointDataHandler.e2eCounterInitalValue)
    {
        self.bolusManager = bolusManager
        self.basalManager = basalManager
        self.lockedE2ECounter = Locked(e2eCounter)
    }
    
    //MARK: - Response Handling
    public func handleResponse(_ response: Data) -> (result: DeviceCommResult<Any?>, completion: Any?) {
        guard e2eDelegate?.isE2EProtectionSupported == false || (e2eDelegate?.isE2EProtectionSupported == true && response.isCRCValid) else {
            return (.failure(.invalidCRC), nil)
        }
        
        guard let opcode: IDStatusReaderOpcode = responseOpcode(response) else {
            log.error("Response opcode not known. Complete response: %{public}@", response.hexadecimalString)
            return (.failure(.opcodeUnknown(response.hexadecimalString)), nil)
        }
        
        log.debug("idsr response opcode: %{public}@", opcode.procedureID)
        
        switch opcode {
        case .responseCode:
            guard response.count >= 5 else { return (.failure(.invalidFormat), nil) }
            let requestOpcode = IDStatusReaderOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDStatusReaderOpcode.RawValue.self))
            guard let responseCode = IDStatusReaderResponseCode(rawValue: response[response.startIndex.advanced(by: 4)...].to(IDStatusReaderResponseCode.RawValue.self))
            else {
                return (.failure(.parameterOutOfRange), nil)
            }
            log.debug("request opcode %{public}@, response code %{public}@", requestOpcode.procedureID, String(reflecting: responseCode))
            let completion = completeProcedure(requestOpcode)

            switch responseCode {
            case .success:
                return (.success(nil), completion)
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
            let totalDailyBolusDelivered = Data(response[response.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
            let totalDailyBasalDelivered = Data(response[response.startIndex.advanced(by: 4)...].to(SFLOAT.self)).sfloatToDouble()
            let totalDailyInsulinDelivered = Data(response[response.startIndex.advanced(by: 6)...].to(SFLOAT.self)).sfloatToDouble()
            return (.success((totalDailyBolusDelivered,totalDailyBasalDelivered,totalDailyInsulinDelivered)), completion)
        case .getCounterResponse:
            let completion = completeProcedure(IDStatusReaderOpcode.getCounter)
            guard response.count >= 8 else { return (.failure(.invalidFormat), completion) }

            guard let counterType = CounterType(rawValue: response[response.startIndex.advanced(by: 2)...].to(CounterType.RawValue.self)),
                  let counterValueSelection = CounterValueSelection(rawValue: response[response.startIndex.advanced(by: 3)...].to(CounterValueSelection.RawValue.self))
            else {
                return (.failure(.parameterOutOfRange), completion)
            }

            let value = TimeInterval.minutes(Int(response[response.startIndex.advanced(by: 4)...].to(Int32.self)))

            if counterType == .lifetime,
               counterValueSelection == .remaining
            {
                lifetimeRemainingHandler?(value)
            }
            return (.success((counterType,counterValueSelection,value)), completion)
        case .getDeliveredInsulinResponse:
            let completion = completeProcedure(IDStatusReaderOpcode.getDeliveredInsulin)
            return (basalManager.handleResponse(response, with: opcode), completion)
        case .getInsulinOnBoardResponse:
            // For AID implementations, this is currently unused
            let completion = completeProcedure(IDStatusReaderOpcode.getInsulinOnBoard)
            let flags = InsulinOnBoardFlag(rawValue: response[response.startIndex.advanced(by: 2)...].to(InsulinOnBoardFlag.RawValue.self))
            let insulinOnBoard = Data(response[response.startIndex.advanced(by: 3)...].to(SFLOAT.self)).sfloatToDouble()
            var remainingDuration: TimeInterval?
            if flags.contains(.presentRemainingDuration) {
                remainingDuration = TimeInterval.minutes(Int(response[response.startIndex.advanced(by: 5)...].to(UInt16.self)))
            }
            return (.success((insulinOnBoard, remainingDuration)), completion)
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
        IDStatusReaderControlPointDataHandler.buildControlPointRequest(opcode: opcode, operand: operand)
    }
    
    public func createGetActiveBolusDeliveredDetailsRequest() -> Data? {
        bolusManager.createGetActiveBolusDeliveryRequest(bolusValueSelection: .delivered)
    }

    public func createGetActiveBolusProgrammedDetailsRequest() -> Data? {
        bolusManager.createGetActiveBolusDeliveryRequest(bolusValueSelection: .programmed)
    }

    public func createGetRemainingLifetimeRequest() -> Data {
        createGetCounterRequest(for: .lifetime, counterValueSelection: .remaining)
    }
    
    public func createGetCounterRequest(for counterType: CounterType, counterValueSelection: CounterValueSelection) -> Data {
        var operand = Data(counterType.rawValue)
        operand.append(counterValueSelection.rawValue)
        return buildRequest(IDStatusReaderOpcode.getCounter, operand: operand)
    }
    
    public func createGetDeliveredInsulinRequest() -> Data {
        buildRequest(.getDeliveredInsulin)
    }
    
    public func createGetActiveBasalRateDeliveryRequest() -> Data {
        buildRequest(.getActiveBasalRateDelivery)
    }

    public func createResetStatusChangedRequest(for statusToReset: IDStatusChangedFlag) -> Data {
        let operand = Data(statusToReset.rawValue)
        return buildRequest(.resetStatus, operand:operand)
    }

    public func createGetActiveBolusIDsRequest() -> Data {
        buildRequest(.getActiveBolusIDs)
    }
    
    public func createGetTotalDailyInsulinStatusRequest() -> Data {
        buildRequest(.getTotalDailyInsulinStatus)
    }
    
    public func createGetInsulinOnBoardRequest() -> Data {
        buildRequest(.getInsulinOnBoard)
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
        appendToRequestQueue(createResetStatusChangedRequest(for: statusToReset), completion: completion)
    }

    func queueGetActiveBolusIDs(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetActiveBolusIDsRequest(), completion: completion)
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

public enum BolusValueSelection: UInt8, CaseIterable, CustomStringConvertible {
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

public enum CounterType: UInt8, CaseIterable, CustomStringConvertible {
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

public enum CounterValueSelection: UInt8, CaseIterable, CustomStringConvertible {
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
