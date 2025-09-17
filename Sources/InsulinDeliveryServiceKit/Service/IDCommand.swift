//
//  IDCommand.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//
//  This is based on version 1.0 of the Insulin Delivery Service: https://www.bluetooth.com/specifications/specs/insulin-delivery-service-1-0-2/
//

import CoreBluetooth
import BluetoothCommonKit
import os.log

// MARK: - Support Server Implementation
public protocol IDCommandControlPointCharacteristicDelegate: AnyObject {
    var isPumpBehaviourEnabled: Bool { get }
    var basalProfileTemplateNumber: TemplateNumber { get }
    var basalProfile: [BasalSegment] { get }
    var basalProfileConfigured: Bool { get }
    var basalProfileComplete: Bool { get }
    var basalRateProfileActivated: Bool { get }
    var maxBolusAmount: Double { get }
    var isBolusActive: Bool { get }
    var therapyState: InsulinTherapyControlState { get }
    func setTherapyControlState(_ state: InsulinTherapyControlState) -> Bool
    func changeAnnunciationStatus(_ annunciationStatus: AnnunciationStatus, for identifier: AnnunciationIdentifier) -> Bool
    func updateBasalProfile(basalSegment: BasalSegment)
    func resetBasalProfile()
    func setTempBasal(rate: Double, duration: TimeInterval, deliveryContext: BasalDeliveryContext, now: Date, changeTempBasal: Bool) -> Bool
    func cancelTempBasal() -> Bool
    func setBolus(_ amount: Double, activationType: IDBolusActivationType) -> BolusID
    func cancelBolus(for bolusID: BolusID) -> Bool
    func activateBasalRateProfile()
    func startPriming(_ amount: Double) -> Bool
    func stopPriming() -> Bool
    func setMaxBolusAmount(_ amount: Double)
    func updateInitialReservoirFillLevel(_ fillLevel: Double)
}

open class IDCommandControlPointCharacteristic: WritableCharacteristic, E2EProtection {
    public var e2eCounter: UInt8 = 0
    
    public weak var e2eDelegate: E2EProtectionDelegate?
    public weak var delegate: IDCommandControlPointCharacteristicDelegate?
    
    var messageQueue: MessagingQueue
    
    var idCommandDataCharacteristic: IDCommandDataCharacteristic
    
    var basalRateProfileConfigured: Bool {
        !(delegate?.basalProfile ?? []).isEmpty
    }
    
    public required init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
        self.idCommandDataCharacteristic = IDCommandDataCharacteristic(messageQueue: messageQueue)
        self.idCommandDataCharacteristic.e2eDelegate = self
    }

    open func onWrite(_ request: Data?) -> CBATTError.Code {
        ConsoleOut.shared.logMessage(message: "\(#function) ID Command Control Point request \(String(describing: request?.hexadecimalString))")
        guard let request = request else {
            return CBATTError.Code.invalidPdu
        }
        
        guard let response = responseForRequest(request) else {
            return CBATTError.Code.commandNotSupported
        }
        
        sendResponse(response)
        return CBATTError.Code.success
    }

    func responseForRequest(_ request: Data) -> Data? {
        var index = 0
        let requestOpcode = IDCommandControlPointOpcode(rawValue: request[request.startIndex.advanced(by: index)...].to(IDCommandControlPointOpcode.RawValue.self))
        index += 2
        
        switch requestOpcode {
        case .setTherapyControlState:
            let therapyControlState = InsulinTherapyControlState(rawValue: request[request.startIndex.advanced(by: index)...].to(InsulinTherapyControlState.RawValue.self)) ?? .undetermined
            ConsoleOut.shared.logMessage(message: "Received setTherapyControlState with therapyControlState: \(therapyControlState)")
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || delegate?.setTherapyControlState(therapyControlState) ?? false else {
                return createResponse(to: .setTherapyControlState, with: .procedureNotApplicable)
            }
            return createResponseWithSuccess(to: .setTherapyControlState)
        case .setFlightMode:
            ConsoleOut.shared.logMessage(message: "Received setFlightMode")
            return createResponseWithSuccess(to: .setFlightMode)
        case .snoozeAnnunciation:
            let annunciationID = request[request.startIndex.advanced(by: index)...].to(AnnunciationIdentifier.self)
            ConsoleOut.shared.logMessage(message: "Received snoozeAnnunciation with annunciationID: \(annunciationID)")
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || delegate?.changeAnnunciationStatus(.snoozed, for: annunciationID) ?? false else {
                return createResponse(to: .snoozeAnnunciation, with: .procedureNotApplicable)
            }
            return createRespondToSnoozeAnnunciation(annunciationID)
        case .confirmAnnunciation:
            let annunciationID = request[request.startIndex.advanced(by: index)...].to(AnnunciationIdentifier.self)
            ConsoleOut.shared.logMessage(message: "Received confirmAnnunciation with annunciationID: \(annunciationID)")
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || delegate?.changeAnnunciationStatus(.confirmed, for: annunciationID) ?? false else {
                return createResponse(to: .confirmAnnunciation, with: .procedureNotApplicable)
            }
            return createRespondToConfirmAnnunciation(annunciationID)
        case .readBasalRateTemplate:
            let templateNumber = request[request.startIndex.advanced(by: index)...].to(TemplateNumber.self)
            ConsoleOut.shared.logMessage(message: "Received readBasalRateTemplate with templateNumber: \(templateNumber)")
            guard let basalProfileTemplateNumber = delegate?.basalProfileTemplateNumber,
                  templateNumber == basalProfileTemplateNumber,
                  let basalProfile = delegate?.basalProfile
            else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    return createResponse(to: .readBasalRateTemplate, with: .procedureNotApplicable)
                }
                let basalProfile: [BasalSegment] = [BasalSegment(index: 1, rate: 1, duration: 780), BasalSegment(index: 2, rate: 2, duration: 780)]
                idCommandDataCharacteristic.sendReadBasalRateProfileResponse(basalProfile: basalProfile, templateNumber: 1)
                return createResponseWithSuccess(to: .readBasalRateTemplate)
            }
            idCommandDataCharacteristic.sendReadBasalRateProfileResponse(basalProfile: basalProfile, templateNumber: templateNumber)
            return createResponseWithSuccess(to: .readBasalRateTemplate)
        case .writeBasalRateTemplate:
            guard request.count >= 9 else {
                return createResponse(to: .writeBasalRateTemplate, with: .invalidOperand)
            }
            let flags = WriteBasalRateFlags(rawValue: request[request.startIndex.advanced(by: index)...].to(WriteBasalRateFlags.RawValue.self))
            index += 1
            
            let templateNumber = request[request.startIndex.advanced(by: index)...].to(TemplateNumber.self)
            index += 1
            
            guard let basalProfileTemplateNumber = delegate?.basalProfileTemplateNumber,
                  templateNumber == basalProfileTemplateNumber
            else {
                return createResponse(to: .writeBasalRateTemplate, with: .parameterOutOfRange)
            }
            
            let firstTimeBlockNumber = request[request.startIndex.advanced(by: index)...].to(UInt8.self)
            index += 1
            var currentTimeBlockNumber = firstTimeBlockNumber
            
            let requestCount = e2eDelegate?.isE2EProtectionSupported ?? false ? request.count - 3 : request.count
            while index < requestCount {
                let duration = TimeInterval(minutes: Int(request[request.startIndex.advanced(by: index)...].to(UInt16.self)))
                index += 2
                let rate = Data(request[request.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
                index += 2
                let basalSegment = BasalSegment(index: currentTimeBlockNumber, rate: rate, duration: duration)
                delegate?.updateBasalProfile(basalSegment: basalSegment)
                currentTimeBlockNumber += 1
            }
                
            guard flags.contains(.endTransaction),
                  !(delegate?.basalProfileComplete ?? false)
            else {
                return createRespondToWriteBasalRate(transactionCompleted: flags.contains(.endTransaction), firstTimeBlockNumber: firstTimeBlockNumber)
            }
            
            return createResponse(to: .writeBasalRateTemplate, with: .plausibilityCheckFailed)
        case .setTempBasalAdjustment:
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || delegate?.therapyState == .run else {
                return createResponse(to: .setTempBasalAdjustment, with: .procedureNotApplicable)
            }
            
            let flags = TempBasalFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(TempBasalFlag.RawValue.self))
            index += 1
            let type = TempBasalType(rawValue: request[request.startIndex.advanced(by: index)...].to(TempBasalType.RawValue.self)) ?? .undetermined
            index += 1
            
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || type == .absolute else {
                return createResponse(to: .setTempBasalAdjustment, with: .procedureNotApplicable)
            }
            
            let rate = Data(request[request.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
            index += 2
            let duration = TimeInterval(minutes: Int(request[request.startIndex.advanced(by: index)...].to(UInt16.self)))
            index += 2
            
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || !flags.contains(.templateNumberPresent) else {
                return createResponse(to: .setTempBasalAdjustment, with: .procedureNotApplicable)
            }
            
            var deliveryContext: BasalDeliveryContext = .undetermined
            if flags.contains(.deliveryContextPresent) {
                deliveryContext = BasalDeliveryContext(rawValue: request[request.startIndex.advanced(by: index)...].to(BasalDeliveryContext.RawValue.self)) ?? .undetermined
            }
            
            ConsoleOut.shared.logMessage(message: "Received setTempBasalAdjustment with flags: \(flags), type: \(type), rate: \(rate), duration: \(duration), deliveryContext: \(deliveryContext)")
            
            guard delegate?.setTempBasal(rate: rate, duration: duration, deliveryContext: deliveryContext, now: Date(), changeTempBasal: flags.contains(.changeTempBasal)) ?? false else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    return createResponse(to: .setTempBasalAdjustment, with: .procedureNotApplicable)
                }
                return createResponseWithSuccess(to: .setTempBasalAdjustment)
            }
            
            return createResponseWithSuccess(to: .setTempBasalAdjustment)
        case .cancelTempBasalAdjustment:
            ConsoleOut.shared.logMessage(message: "Received cancelTempBasalAdjustmen")
            guard delegate?.cancelTempBasal() ?? false else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    return createResponse(to: .cancelTempBasalAdjustment, with: .procedureNotApplicable)
                }
                return createResponseWithSuccess(to: .cancelTempBasalAdjustment)
            }
            return createResponseWithSuccess(to: .cancelTempBasalAdjustment)
        case .getAvailableBoluses:
            return createResponseToGetAvailableBoluses()
        case .setBolus:
            guard !(delegate?.isPumpBehaviourEnabled ?? false) ||  delegate?.therapyState == .run,
                  !(delegate?.isPumpBehaviourEnabled ?? false) || !(delegate?.isBolusActive ?? true)
            else {
                return createResponse(to: .setBolus, with: .procedureNotApplicable)
            }
            
            let flags = BolusFlag(rawValue: request[request.startIndex.advanced(by: index)...].to(BolusFlag.RawValue.self))
            index += 1
            let type = BolusType(rawValue: request[request.startIndex.advanced(by: index)...].to(BolusType.RawValue.self)) ?? .undetermined
            index += 1
            guard type != .undetermined else {
                return createResponse(to: .setBolus, with: .invalidOperand)
            }
            let fastAmount = Data(request[request.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
            index += 2
            let extendedAmount = Data(request[request.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
            index += 2
            
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || extendedAmount == 0 else {
                return createResponse(to: .setBolus, with: .procedureNotApplicable)
            }
            
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || fastAmount <= delegate?.maxBolusAmount ?? 0 else {
                return createResponse(to: .setBolus, with: .procedureNotApplicable)
            }
            let duration = TimeInterval(minutes: Int(request[request.startIndex.advanced(by: index)...].to(UInt16.self)))
            index += 2
            guard duration == 0 else {
                return createResponse(to: .setBolus, with: .procedureNotApplicable)
            }

            guard !(delegate?.isPumpBehaviourEnabled ?? false) || !flags.contains(.delayTimePresent),
                  !(delegate?.isPumpBehaviourEnabled ?? false) || !flags.contains(.templateNumberPresent)
            else {
                return createResponse(to: .setBolus, with: .procedureNotApplicable)
            }

            var activationType: IDBolusActivationType? = nil
            if flags.contains(.activationTypePresent) {
                activationType = IDBolusActivationType(rawValue: request[request.startIndex.advanced(by: index)...].to(IDBolusActivationType.RawValue.self))
            }
            
            ConsoleOut.shared.logMessage(message: "Received setBolus with flags: \(flags), fastAmount: \(fastAmount), extendedAmount: \(extendedAmount), duration: \(duration), activationType: \(String(describing: activationType))")
            
            guard let bolusID = delegate?.setBolus(fastAmount, activationType: activationType ?? .undetermined) else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    return createResponse(to: .setBolus, with: .procedureNotCompleted)
                }
                return createRespondToSetBolus(1)
            }
            return createRespondToSetBolus(bolusID)
        case .cancelBolus:
            let bolusID = request[request.startIndex.advanced(by: index)...].to(BolusID.self)
            ConsoleOut.shared.logMessage(message: "Received cancelBolus with bolusID: \(bolusID)")
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || delegate?.cancelBolus(for: bolusID) ?? false else {
                return createResponse(to: .cancelBolus, with: .procedureNotApplicable)
            }
            return createRespondToCancelBolus(bolusID)
        case .getTemplateStatusAndDetails:
            ConsoleOut.shared.logMessage(message: "Received getTemplateStatusAndDetails")
            idCommandDataCharacteristic.sendGetTemplateStatusAndDetailsResponse(basalRateProfileConfigured: basalRateProfileConfigured)
            return createResponseWithSuccess(to: .getTemplateStatusAndDetails)
        case .resetTemplateStatus:
            let numberOfProfilesToReset = request[request.startIndex.advanced(by: index)...].to(UInt8.self)
            index += 1
            guard numberOfProfilesToReset <= 1 else {
                return createResponse(to: .resetTemplateStatus, with: .invalidOperand)
            }
            
            guard numberOfProfilesToReset == 1 else {
                return createResponseWithSuccess(to: .resetTemplateStatus)
            }
            
            let templateNumber = request[request.startIndex.advanced(by: index)...].to(TemplateNumber.self)
            guard let basalProfileTemplateNumber = delegate?.basalProfileTemplateNumber,
                  !(delegate?.isPumpBehaviourEnabled ?? false) || templateNumber == basalProfileTemplateNumber
            else {
                return createResponse(to: .resetTemplateStatus, with: .invalidOperand)
            }
            
            ConsoleOut.shared.logMessage(message: "Received resetTemplateStatus with numberOfProfilesToReset: \(numberOfProfilesToReset), templateNumber: \(templateNumber)")
            
            delegate?.resetBasalProfile()
            return createRespondToResetTemplateStatus()
        case .activateProfileTemplates:
            let numberOfProfilesToActivate = request[request.startIndex.advanced(by: index)...].to(UInt8.self)
            index += 1
            guard numberOfProfilesToActivate == 1 else {
                return createResponse(to: .activateProfileTemplates, with: .invalidOperand)
            }
            
            let templateNumber = request[request.startIndex.advanced(by: index)...].to(TemplateNumber.self)
            guard let basalProfileTemplateNumber = delegate?.basalProfileTemplateNumber,
                  !(delegate?.isPumpBehaviourEnabled ?? false) || templateNumber == basalProfileTemplateNumber
            else {
                return createResponse(to: .activateProfileTemplates, with: .invalidOperand)
            }
            
            ConsoleOut.shared.logMessage(message: "Received activateProfileTemplates with numberOfProfilesToActivate: \(numberOfProfilesToActivate), templateNumber: \(templateNumber)")
            
            guard basalRateProfileConfigured else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    return createResponse(to: .activateProfileTemplates, with: .procedureNotApplicable)
                }
                return createRespondToActivateProfileTemplate()
            }
            delegate?.activateBasalRateProfile()
            return createRespondToActivateProfileTemplate()
        case .getActivatedProfileTemplates:
            return createRespondToGetActivatedProfileTemplates()
        case .startPriming:
            let amount = Data(request[request.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
            ConsoleOut.shared.logMessage(message: "Received startPriming with amount: \(amount)")
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || delegate?.startPriming(amount) ?? false else {
                return createResponse(to: .startPriming, with: .procedureNotApplicable)
            }
            return createResponseWithSuccess(to: .startPriming)
        case .stopPriming:
            ConsoleOut.shared.logMessage(message: "Received stopPriming")
            guard !(delegate?.isPumpBehaviourEnabled ?? false) || delegate?.stopPriming() ?? false else {
                return createResponse(to: .stopPriming, with: .procedureNotApplicable)
            }
            return createResponseWithSuccess(to: .stopPriming)
        case .setInitialResevoirFillLevel:
            let fillLevel = Data(request[request.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
            ConsoleOut.shared.logMessage(message: "Received setInitialResevoirFillLevel with fillLevel: \(fillLevel)")
            delegate?.updateInitialReservoirFillLevel(fillLevel)
            return createResponseWithSuccess(to: .setInitialResevoirFillLevel)
        case .resetResevoirInsulinOperationTime:
            ConsoleOut.shared.logMessage(message: "Received resetResevoirInsulinOperationTime")
            return createResponseWithSuccess(to: .resetResevoirInsulinOperationTime)
        case .getMaxBolusAmount:
            ConsoleOut.shared.logMessage(message: "Received getMaxBolusAmount")
            guard let maxBolusAmount = delegate?.maxBolusAmount else {
                guard !(delegate?.isPumpBehaviourEnabled ?? false) else {
                    return createResponse(to: .getMaxBolusAmount, with: .procedureNotApplicable)
                }
                return createRespondToGetMaxBolus(25)
            }
            return createRespondToGetMaxBolus(maxBolusAmount)
        case .setMaxBolusAmount:
            let maxBolusAmount = Data(request[request.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
            ConsoleOut.shared.logMessage(message: "Received setMaxBolusAmount with maxBolusAmount: \(maxBolusAmount)")
            delegate?.setMaxBolusAmount(maxBolusAmount)
            return createResponseWithSuccess(to: .setMaxBolusAmount)
        default:
            ConsoleOut.shared.logMessage(message: "Command not supported")
            return nil
        }
    }

    public func createRespondToSnoozeAnnunciation(_ annunicationID: AnnunciationIdentifier) -> Data {
        var response = Data(IDCommandControlPointOpcode.snoozeAnnunciationResponse.rawValue)
        response.append(annunicationID)
        return addE2EProtection(response: response)
    }
    
    public func createRespondToConfirmAnnunciation(_ annunicationID: AnnunciationIdentifier) -> Data {
        var response = Data(IDCommandControlPointOpcode.confirmAnnunciationResponse.rawValue)
        response.append(annunicationID)
        return addE2EProtection(response: response)
    }
    
    public func createRespondToWriteBasalRate(transactionCompleted: Bool, firstTimeBlockNumber: UInt8) -> Data {
        let flag: WriteBasalRateFlags = transactionCompleted ? .endTransaction : .allZeros
        var response = Data(IDCommandControlPointOpcode.writeBasalRateTemplateResponse.rawValue)
        response.append(flag.rawValue)
        response.append(delegate?.basalProfileTemplateNumber ?? 0)
        response.append(firstTimeBlockNumber)
        return addE2EProtection(response: response)
    }
    
    public func createResponseToGetAvailableBoluses(_ flags: AvailableBolusesFlag = .availableFast) -> Data {
        var response = Data(IDCommandControlPointOpcode.getAvailableBolusesResponse.rawValue)
        response.append(flags.rawValue)
        return addE2EProtection(response: response)
    }
    
    public func createRespondToSetBolus(_ bolusID: BolusID) -> Data {
        var response = Data(IDCommandControlPointOpcode.setBolusResponse.rawValue)
        response.append(bolusID)
        return addE2EProtection(response: response)
    }
    
    public func createRespondToCancelBolus(_ bolusID: BolusID) -> Data {
        var response = Data(IDCommandControlPointOpcode.cancelBolusResponse.rawValue)
        response.append(bolusID)
        return addE2EProtection(response: response)
    }
    
    public func createRespondToResetTemplateStatus() -> Data {
        createProfileResponse(for: .resetTemplateStatusResponse)
    }
    
    public func createRespondToActivateProfileTemplate() -> Data {
        createProfileResponse(for: .activateProfileTemplatesResponse)
    }
    
    public func createRespondToGetActivatedProfileTemplates() -> Data {
        let opcode = IDCommandControlPointOpcode.getActivatedProfileTemplatesResponse
        guard delegate?.basalRateProfileActivated ?? false else {
            var response = Data(opcode.rawValue)
            response.append(UInt8(0)) // no profiles activated
            return addE2EProtection(response: response)
        }
        
        return createProfileResponse(for: opcode)
    }
    
    private func createProfileResponse(for opcode: IDCommandControlPointOpcode) -> Data {
        var response = Data(opcode.rawValue)
        response.append(UInt8(1)) // only 1 profile activated
        response.append(delegate?.basalProfileTemplateNumber ?? 0)
        return addE2EProtection(response: response)
    }
    
    public func createRespondToGetMaxBolus(_ maxAmount: Double = 30) -> Data {
        var response = Data(IDCommandControlPointOpcode.getMaxBolusAmountResponse.rawValue)
        response.append(maxAmount.sfloat)
        return addE2EProtection(response: response)
    }
    
    public func createResponseWithSuccess(to requestOpcode: IDCommandControlPointOpcode) -> Data {
        createResponse(to: requestOpcode, with: .success)
    }

    public func createResponse(to requestOpcode: IDCommandControlPointOpcode, with responseCode: IDCommandControlPointResponseCode) -> Data {
        ConsoleOut.shared.logMessage(message: "\(#function) requestOpcode: \(requestOpcode) responseCode: \(responseCode)")
        var response = Data(IDCommandControlPointOpcode.responseCode.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        return addE2EProtection(response: response)
    }
        
    public func respondWithSuccess(to requestOpcode: IDCommandControlPointOpcode) {
        response(to: requestOpcode, with: .success)
    }
    
    public func response(to requestOpcode: IDCommandControlPointOpcode, with responseCode: IDCommandControlPointResponseCode) {
        sendResponse(createResponse(to: requestOpcode, with: responseCode))
    }
    
    public func addE2EProtection(response: Data) -> Data {
        var response = response
        if e2eDelegate?.isE2EProtectionSupported ?? false {
            incrementE2ECounter()
            response = appendingE2EProtection(response)
        }
        return response
    }
    
    public func sendResponse(_ response: Data) {
        messageQueue.addQueueItem(
            UUIDValuePair(
                uuid: InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID,
                value: response
            )
        )
    }
}

extension IDCommandControlPointCharacteristic: E2EProtectionDelegate {
    public var isE2EProtectionSupported: Bool {
        e2eDelegate?.isE2EProtectionSupported ?? false
    }
}

// MARK: - Support Client Implementation
open class IDCommandControlPointDataHandler: ControlPoint, E2EProtection {
    
    private let log = OSLog(category: "InsulinDeliveryControlPoint")
    
    public var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> = Locked([])
    
    private var lockedE2ECounter: Locked<UInt8>
    
    public weak var e2eDelegate: E2EProtectionDelegate?

    private let bolusManager: BolusManager
    
    private let basalManager: BasalManager
    
    private let idCommandData: IDCommandDataHandler
    
    private let basalProfileNumber: TemplateNumber
    
    public var procedureRunning: Bool = false
    
    private var lastSentMaxBolus: UInt16?
    
    private var lastSentMaxBasal: UInt16?

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
    
    public init(bolusManager: BolusManager,
                basalManager: BasalManager,
                basalProfileNumber: TemplateNumber = 1,
                e2eCounter: UInt8 = IDCommandControlPointDataHandler.e2eCounterInitalValue)
    {
        self.bolusManager = bolusManager
        self.basalManager = basalManager
        self.basalProfileNumber = basalProfileNumber
        self.lockedE2ECounter = Locked(e2eCounter)
        self.idCommandData =    IDCommandDataHandler(basalRateProfileTemplateNumber: basalManager.basalRateProfileTemplateNumber)
        self.idCommandData.e2eDelegate = self
    }
    
    private func checkBasalRateTemplate() -> DeviceCommResult<Any?> {
        guard idCommandData.writeBasalProfile == idCommandData.readBasalProfile else {
            log.error("Written basal rate profile does not match read basal rate profile opcode not known. written: %{public}@ read:  %{public}@", String(describing: idCommandData.writeBasalProfile), String(describing: idCommandData.readBasalProfile))
            return .failure(.procedureNotCompleted)
        }
        return .success(idCommandData.readBasalProfile)
    }
    
    //MARK: - Response Handling
    public func handleCommandDataResponse(_ response: Data) -> DeviceCommResult<Any?> {
        idCommandData.handleResponse(response)
    }
    
    open func handleResponse(_ response: Data) -> (result: DeviceCommResult<Any?>, completion: Any?) {
        guard e2eDelegate?.isE2EProtectionSupported == false || (e2eDelegate?.isE2EProtectionSupported == true && response.isCRCValid) else {
            return (.failure(.invalidCRC), nil)
        }
        
        guard let opcode: IDCommandControlPointOpcode = responseOpcode(response),
              IDCommandControlPointOpcode.responseOpcodes.contains(opcode)
        else {
            log.error("Response opcode not known. Complete response: %{public}@", response.hexadecimalString)
            return (.failure(.opcodeUnknown(response.hexadecimalString)), nil)
        }
        
        log.debug("idcp response opcode: %{public}@", opcode.procedureID)
        switch opcode {
        case .responseCode:
            guard response.count >= 5 else { return (.failure(.invalidFormat), nil) }
            let requestOpcode = IDCommandControlPointOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDCommandControlPointOpcode.RawValue.self))
            
            guard let responseCode = IDCommandControlPointResponseCode(rawValue: response[response.startIndex.advanced(by: 4)...].to(IDCommandControlPointResponseCode.RawValue.self)) else {
                return (.failure(.parameterOutOfRange), nil)
            }
            log.debug("request opcode  %{public}@, response code %{public}@", requestOpcode.procedureID, String(reflecting: responseCode))

            let completion = completeProcedure(requestOpcode)
            
            switch responseCode {
            case .success:
                if requestOpcode == .readBasalRateTemplate {
                    return (checkBasalRateTemplate(), completion)
                }
                return (.success(nil), completion)
            case .opcodeNotSupported:
                return (.failure(.opcodeNotSupported), completion)
            case .invalidOperand:
                return (.failure(.invalidOperand), completion)
            case .procedureNotCompleted:
                return (.failure(.procedureNotCompleted), completion)
            case .parameterOutOfRange:
                return (.failure(.parameterOutOfRange), completion)
            case .procedureNotApplicable:
                return (.failure(.procedureNotApplicable), completion)
            case .plausibilityCheckFailed:
                // write basal schedule plausibility check failed. Treat as procedure not completed
                return (.failure(.procedureNotCompleted), completion)
            case .maxBolusNumberReached:
                return (.failure(.maxBolusNumberReached), completion)
            }
        case .activateProfileTemplatesResponse:
            let completion = completeProcedure(IDCommandControlPointOpcode.activateProfileTemplates)
            let numberOfProfileTemplatesActivated = response[response.startIndex.advanced(by: 2)...].to(UInt8.self)
            guard numberOfProfileTemplatesActivated == basalManager.numberOfBasalRateProfiles else {
                return (.failure(.parameterOutOfRange), completion)
            }
            
            let profileTemplateActivated = response[response.startIndex.advanced(by: 3)...].to(TemplateNumber.self)
            guard profileTemplateActivated == basalManager.basalRateProfileTemplateNumber else {
                return (.failure(.parameterOutOfRange), completion)
            }
            
            return (.success(nil), completion)
        case .getActivatedProfileTemplatesResponse:
            let completion = completeProcedure(IDCommandControlPointOpcode.getActivatedProfileTemplates)
            let numberOfProfileTemplatesActivated = response[response.startIndex.advanced(by: 2)...].to(UInt8.self)
            guard numberOfProfileTemplatesActivated == basalManager.numberOfBasalRateProfiles else {
                return (.failure(.procedureNotApplicable), completion)
            }
            
            let profileTemplateActivated = response[response.startIndex.advanced(by: 3)...].to(TemplateNumber.self)
            guard profileTemplateActivated == basalManager.basalRateProfileTemplateNumber else {
                return (.failure(.procedureNotApplicable), completion)
            }
            
            return (.success(profileTemplateActivated), completion)
        case .resetTemplateStatusResponse:
            let completion = completeProcedure(IDCommandControlPointOpcode.resetTemplateStatus)
            let numberOfProfileTemplatesActivated = response[response.startIndex.advanced(by: 2)...].to(UInt8.self)
            guard numberOfProfileTemplatesActivated == basalManager.numberOfBasalRateProfiles else {
                return (.failure(.procedureNotApplicable), completion)
            }
            
            let profileTemplateActivated = response[response.startIndex.advanced(by: 3)...].to(TemplateNumber.self)
            guard profileTemplateActivated == basalManager.basalRateProfileTemplateNumber else {
                return (.failure(.procedureNotApplicable), completion)
            }
            
            return (.success(nil), completion)
        case .writeBasalRateTemplateResponse:
            let completion = completeProcedure(IDCommandControlPointOpcode.writeBasalRateTemplate)

            let basalRateProfileNumber = response[response.startIndex.advanced(by: 3)...].to(UInt8.self)
            guard basalRateProfileNumber == basalManager.basalRateProfileTemplateNumber else {
                return (.failure(.parameterOutOfRange), completion)
            }
            
            let flags = WriteBasalRateFlags(rawValue: response[response.startIndex.advanced(by: 2)...].to(WriteBasalRateFlags.RawValue.self))

            guard flags.contains(.endTransaction) else {
                log.debug("basal rate has not been completely written.")
                return (.failure(.partialResponse), completion)
            }

            log.debug("completed writing basal rate profile")
            return (.success(flags), completion)
        case .snoozeAnnunciationResponse:
            let completion = completeProcedure(IDCommandControlPointOpcode.snoozeAnnunciation)
            guard e2eDelegate?.isE2EProtectionSupported == true ? response.count == 7 : response.count == 4 else {
                return (.failure(.invalidFormat), completion)
            }
            let annunciationID = response[response.startIndex.advanced(by: 2)...].to(AnnunciationIdentifier.self)
            log.debug("Snoozed annunciation with ID %{public}@", String(reflecting: annunciationID))
            return (.success(annunciationID), completion)
        case .confirmAnnunciationResponse:
            let completion = completeProcedure(IDCommandControlPointOpcode.confirmAnnunciation)
            guard e2eDelegate?.isE2EProtectionSupported == true ? response.count == 7 : response.count == 4 else {
                return (.failure(.invalidFormat), completion)
            }
            let annunciationID = response[response.startIndex.advanced(by: 2)...].to(AnnunciationIdentifier.self)
            log.debug("Confirmed annunciation with ID %{public}@", String(reflecting: annunciationID))
            return (.success(annunciationID), completion)
        case .setBolusResponse:
            let completion = completeProcedure(IDCommandControlPointOpcode.setBolus)
            let result = bolusManager.handleResponse(response, with: opcode)
            return (result, completion)
        case .cancelBolusResponse:
            let completion = completeProcedure(IDCommandControlPointOpcode.cancelBolus)
            let result = bolusManager.handleResponse(response, with: opcode)
            return (result, completion)
        case .getAvailableBolusesResponse:
            let completion = completeProcedure(IDCommandControlPointOpcode.getAvailableBoluses)
            let flags = AvailableBolusesFlag(rawValue: response[response.startIndex.advanced(by: 2)...].to(AvailableBolusesFlag.RawValue.self))
            return (.success(flags), completion)
        case .getMaxBolusAmountResponse:
            let completion = completeProcedure(IDCommandControlPointOpcode.getMaxBolusAmount)
            let maxBolusAmount = Data(response[response.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
            return (.success(maxBolusAmount), completion)
        default:
            log.error("handler not implemented yet")
            return (.failure(.opcodeNotImplemented), nil)
        }
    }

    public func procedureIDForResponse(_ response: Data) -> ProcedureID? {
        for opcode in IDCommandControlPointOpcode.responseOpcodes {
            if isSpecificResponse(expectedOpcode: opcode, response: response) {
                switch opcode {
                case .responseCode:
                    let requestOpcode = IDCommandControlPointOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDCommandControlPointOpcode.RawValue.self))
                    return requestOpcode.procedureID
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
        log.error("Insulin Delivery Control Point response does not have a procedure ID (raw response: %{public}@)", response.toHexString())
        return nil
    }

    public func procedureIDForRequest(_ request: Data) -> ProcedureID {
        IDCommandControlPointOpcode(rawValue: request[request.startIndex...].to(IDCommandControlPointOpcode.RawValue.self)).procedureID
    }

    func isSpecificResponse(expectedOpcode: IDCommandControlPointOpcode, response: Data) -> Bool {
        let opcode = IDCommandControlPointOpcode(rawValue: response[response.startIndex...].to(IDCommandControlPointOpcode.RawValue.self))
        guard opcode == expectedOpcode else {
            return false
        }
        return true
    }
    
    func isGeneralResponseToSpecificRequest(expectedRequestOpcode: IDCommandControlPointOpcode, response: Data) -> Bool {
        let isGeneralResponse = isSpecificResponse(expectedOpcode: IDCommandControlPointOpcode.responseCode, response: response)
        let requestOpcode = IDCommandControlPointOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDCommandControlPointOpcode.RawValue.self))
        guard isGeneralResponse,
              requestOpcode == expectedRequestOpcode else
        {
            return false
        }
        
        return true
    }
    
    func isActivateBasalRateResponse(_ response: Data) -> Bool {
        return isSpecificResponse(expectedOpcode: .activateProfileTemplatesResponse, response: response)
    }

    func isSetTherapyControlStateResponse(_ response: Data) -> Bool {
        return isGeneralResponseToSpecificRequest(expectedRequestOpcode: .setTherapyControlState, response: response)
    }

    func isFinishedWritingBasalRateSchedule(_ response: Data) -> Bool {
        guard isSpecificResponse(expectedOpcode: .writeBasalRateTemplateResponse, response: response) else {
            return false
        }

        let flags = WriteBasalRateFlags(rawValue: response[response.startIndex.advanced(by: 2)...].to(WriteBasalRateFlags.RawValue.self))
        return flags.contains(.endTransaction)
    }

    func isSetBolusResponse(_ response: Data) -> Bool {
        return isSpecificResponse(expectedOpcode: .setBolusResponse, response: response)
    }

    func isStartPrimingResponse(_ response: Data) -> Bool {
        return isGeneralResponseToSpecificRequest(expectedRequestOpcode: .startPriming, response: response)
    }

    func isCancelBolusResponse(_ response: Data) -> Bool {
        return isSpecificResponse(expectedOpcode: .cancelBolusResponse, response: response)
    }

    func isSetTempBasalResponse(_ response: Data) -> Bool {
        return isGeneralResponseToSpecificRequest(expectedRequestOpcode: .setTempBasalAdjustment, response: response)
    }

    func isCancelTempBasalResponse(_ response: Data) -> Bool {
        return isGeneralResponseToSpecificRequest(expectedRequestOpcode: .cancelTempBasalAdjustment, response: response)
    }
    
    //MARK: - Create Requests
    public func buildRequest(_ opcode: IDCommandControlPointOpcode, operand: Data? = nil) -> Data {
        IDCommandControlPointDataHandler.buildControlPointRequest(opcode: opcode, operand: operand)
    }
    
    public func createSetInitialReservoirFillLevelRequest(_ fillLevel: Int) -> Data {
        buildRequest(.setInitialResevoirFillLevel, operand: fillLevel.sfloat)
    }
    
    public func createResetReservoirInsulinOperationTimeRequest() -> Data {
        buildRequest(.resetResevoirInsulinOperationTime)
    }
    
    public func createStartPrimingRequest(_ amount: Double) -> Data {
        buildRequest(.startPriming, operand: amount.sfloat)
    }

    public func createStopPrimingRequest() -> Data {
        buildRequest(.stopPriming)
    }

    public func createStartInsulinTherapyRequest() -> Data {
        createSetTherapyControlStateRequest(.run)
    }
    
    public func createStopInsulinTherapyRequest() -> Data {
        createSetTherapyControlStateRequest(.stop)
    }
    
    public func createSetTherapyControlStateRequest(_ state: InsulinTherapyControlState) -> Data {
        let operand = Data(state.rawValue)
        return buildRequest(IDCommandControlPointOpcode.setTherapyControlState, operand: operand)
    }
        
    public func createActivateProfileTemplatesRequest(for templateNumbers: [UInt8] = [1]) -> Data {
        var operand = Data(UInt8(templateNumbers.count))
        for templateNumber in templateNumbers {
            operand.append(templateNumber)
        }
        return buildRequest(.activateProfileTemplates, operand: operand)
    }
    
    public func createGetActivatedProfileTemplates() -> Data {
        buildRequest(.getActivatedProfileTemplates)
    }
    
    public func createDeactivateProfileTemplatesRequest(for templateNumbers: [UInt8] = [1]) -> Data {
        var operand = Data(UInt8(templateNumbers.count))
        for templateNumber in templateNumbers {
            operand.append(templateNumber)
        }
        return buildRequest(.resetTemplateStatus, operand: operand)
    }
    
    public func createReadBasalRateProfileRequest(for templateNumber: TemplateNumber) -> Data {
        idCommandData.readBasalProfile = []
        return  buildRequest(.readBasalRateTemplate, operand: Data(templateNumber))
    }
    
    public func createWriteBasalRateSegmentsRequest(for basalSegments: [BasalSegment], templateNumber: TemplateNumber, isLast last: Bool) -> Data {
        guard basalSegments.count <= 3,
              let firstSegment = basalSegments.first else
        {
            fatalError("A write basal rate profile request must have at least 1 segment and can only write up to 3 segments at once")
        }
        
        var requestFlags: WriteBasalRateFlags = last ? .endTransaction : .allZeros
        var operand = Data(templateNumber)
        operand.append(firstSegment.index)
        operand.append(UInt16(firstSegment.duration.minutes))
        operand.append(firstSegment.rate.sfloat)
        
        if let secondSegment = basalSegments[safe: 1] {
            requestFlags.update(with: .secondTimeBlockPresent)
            operand.append(UInt16(secondSegment.duration.minutes))
            operand.append(secondSegment.rate.sfloat)
        }
        
        if let thirdSegment = basalSegments[safe: 2] {
            requestFlags.update(with: .thirdTimeBlockPresent)
            operand.append(UInt16(thirdSegment.duration.minutes))
            operand.append(thirdSegment.rate.sfloat)
        }
        
        // add the flags once all the segments are accounted for
        operand.insert(requestFlags.rawValue, at: 0)
        
        return buildRequest(IDCommandControlPointOpcode.writeBasalRateTemplate, operand: operand)
    }

    public func createSnoozeAnnunciationRequest(for annunciationID: AnnunciationIdentifier) -> Data {
        // the annunciation will be snoozed for 5 mins (300 seconds)
        let operand = Data(annunciationID)
        return buildRequest(.snoozeAnnunciation, operand: operand)
    }
    
    public func createConfirmAnnunciationRequest(for annunciationID: UInt16) -> Data {
        let operand = Data(annunciationID)
        return buildRequest(.confirmAnnunciation, operand: operand)
    }
    
    public func createSetBolusRequest(for amount: Double, activationType: IDBolusActivationType) -> Data {
        bolusManager.createFastBolusRequest(for: amount, activationType: activationType)
    }
    
    func createCancelCurrentBolusRequest() -> Data? {
        bolusManager.createCancelCurrentBolusRequest()
    }
    
    public func createSetTempBasalRequest(unitsPerHour: Double,
                                          durationInMinutes: UInt16,
                                          deliveryContext: BasalDeliveryContext,
                                          replaceExisting: Bool = false) -> Data
    {
        basalManager.createSetTempBasalAdjustmentRequest(unitsPerHour: unitsPerHour,
                                                         durationInMinutes: durationInMinutes,
                                                         deliveryContext: deliveryContext,
                                                         replaceExisting: replaceExisting)
    }
    
    public func createCancelTempBasalRequest() -> Data {
        BasalManager.createCancelTempBasalAdjustmentRequest()
    }
    
    public func createGetMaxBolusAmountRequest() -> Data {
        buildRequest(.getMaxBolusAmount)
    }
    
    public func createSetMaxBolusAmountRequest(_ amount: Double) -> Data {
        buildRequest(.setMaxBolusAmount, operand: Data(amount.sfloat))
    }
    
    public func createGetTemplateStatusDetailsRequest() -> Data {
        buildRequest(.getTemplateStatusAndDetails)
    }
    
    public func createSetFlightModeRequest() -> Data {
        buildRequest(.setFlightMode)
    }
    
    public func createGetAvailableBolusesRequest() -> Data {
        buildRequest(.getAvailableBoluses)
    }

    //MARK: - Queue Requests
    func queueInsulinSetupRequests(fillValue: Int, basalProfile: [BasalSegment], completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createSetInitialReservoirFillLevelRequest(fillValue), completion: nil)
        appendToRequestQueue(createResetReservoirInsulinOperationTimeRequest(), completion: nil)
        queueWriteBasalProfileRequests(for: basalProfile)
        queueActivateAndConfirmProfileTemplateRequests(completion: completion)
    }
    
    public func queueActivateAndConfirmProfileTemplateRequests(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createActivateProfileTemplatesRequest(), completion: nil)
        appendToRequestQueue(createGetActivatedProfileTemplates(), completion: completion)
    }

    public func queueWriteAndConfirmBasalRateRequests(for basalProfile: [BasalSegment], completion: ProcedureResultCompletion? = nil) {
        queueWriteBasalProfileRequests(for: basalProfile)
        appendToRequestQueue(createReadBasalRateProfileRequest(for: basalProfileNumber), completion: nil)
    }

    public func queueWriteBasalProfileRequests(for basalProfile: [BasalSegment], completion: ProcedureResultCompletion? = nil) {
        idCommandData.writeBasalProfile = basalProfile

        let groupsOfBasalSegments: [[BasalSegment]] = basalProfile.chunked(into: 3)
        groupsOfBasalSegments.enumerated().forEach { (index, basalSegments) in
            let isLast = index == groupsOfBasalSegments.count-1
            appendToRequestQueue(createWriteBasalRateSegmentsRequest(for: basalSegments,
                                                                     templateNumber: basalProfileNumber,
                                                                     isLast: isLast),
                                 completion: isLast ? completion : nil)
        }
    }

    func queueStartPrimingRequest(_ primingAmount: Double, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createStartPrimingRequest(primingAmount), completion: completion)
    }

    func queueStopPrimingRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createStopPrimingRequest(), completion: completion)
    }

    func queueStartInsulinTherapyRequest(completion: PumpDeliveryStatusCompletion? = nil) {
        appendToRequestQueue(createStartInsulinTherapyRequest(), completion: completion)
    }

    func queueStopInsulinTherapyRequest(completion: PumpDeliveryStatusCompletion? = nil) {
        appendToRequestQueue(createStopInsulinTherapyRequest(), completion: completion)
    }

    func queueSnoozeAnnunciationRequest(for annunciationID: AnnunciationIdentifier, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createSnoozeAnnunciationRequest(for: annunciationID), completion: completion)
    }

    func queueConfirmAnnunciationRequest(for annunciationID: AnnunciationIdentifier, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createConfirmAnnunciationRequest(for: annunciationID), completion: completion)
    }

    func queueSetBolusRequest(for amount: Double, activationType: IDBolusActivationType, completion: BolusDeliveryStatusCompletion? = nil) {
        appendToRequestQueue(createSetBolusRequest(for: amount, activationType: activationType), completion: completion)
    }

    func didQueueCancelCurrentBolusRequest(completion: BolusDeliveryStatusCompletion? = nil) -> Bool {
        guard let request = createCancelCurrentBolusRequest() else { return false }
        appendToRequestQueue(request, completion: completion)
        return true
    }

    func queueSetTempBasalRequest(unitsPerHour: Double,
                                  durationInMinutes: UInt16,
                                  deliveryContext: BasalDeliveryContext,
                                  replaceExisting: Bool = false,
                                  completion: ProcedureResultCompletion? = nil)
    {
        appendToRequestQueue(createSetTempBasalRequest(unitsPerHour: unitsPerHour,
                                                      durationInMinutes: durationInMinutes,
                                                      deliveryContext: deliveryContext,
                                                       replaceExisting: replaceExisting), completion: completion)
    }

    func queueCancelTempBasalRequest(completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createCancelTempBasalRequest(), completion: completion)
    }
}

extension IDCommandControlPointDataHandler: E2EProtectionDelegate {
    public var isE2EProtectionSupported: Bool {
        e2eDelegate?.isE2EProtectionSupported ?? false
    }
}

//MARK: - Write Insulin Delivery Control Point Request
extension PeripheralManager {
    func writeInsulinDeliveryControlPointRequest(_ request: Data, type: CBCharacteristicWriteType = .withResponse, timeout: TimeInterval) throws {
        guard let characteristic = peripheral?.getInsulinDeliveryCharacteristicWithUUID(.commandControlPoint) else {
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
public struct IDCommandControlPointOpcode: RawRepresentable, Equatable, Sendable {
    public var rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    static public let responseCode = IDCommandControlPointOpcode(rawValue: 0x0f55)
    static public let setTherapyControlState = IDCommandControlPointOpcode(rawValue: 0x0f5a)
    static public let setFlightMode = IDCommandControlPointOpcode(rawValue: 0x0f66)
    static public let snoozeAnnunciation = IDCommandControlPointOpcode(rawValue: 0x0f69)
    static public let snoozeAnnunciationResponse = IDCommandControlPointOpcode(rawValue: 0x0f96)
    static public let confirmAnnunciation = IDCommandControlPointOpcode(rawValue: 0x0f99)
    static public let confirmAnnunciationResponse = IDCommandControlPointOpcode(rawValue: 0x0fa5)
    static public let readBasalRateTemplate = IDCommandControlPointOpcode(rawValue: 0x0faa)
    static public let readBasalRateTemplateResponse = IDCommandControlPointOpcode(rawValue: 0x0fc3)
    static public let writeBasalRateTemplate = IDCommandControlPointOpcode(rawValue: 0x0fcc)
    static public let writeBasalRateTemplateResponse = IDCommandControlPointOpcode(rawValue: 0x0ff0)
    static public let setTempBasalAdjustment = IDCommandControlPointOpcode(rawValue: 0x0fff)
    static public let cancelTempBasalAdjustment = IDCommandControlPointOpcode(rawValue: 0x1111)
    static public let getTempBasalTemplate = IDCommandControlPointOpcode(rawValue: 0x111e)
    static public let getTempBasalTemplateResponse = IDCommandControlPointOpcode(rawValue: 0x1122)
    static public let setTempBasalTemplate = IDCommandControlPointOpcode(rawValue: 0x112d)
    static public let setTempBasalTemplateResponse = IDCommandControlPointOpcode(rawValue: 0x1144)
    static public let setBolus = IDCommandControlPointOpcode(rawValue: 0x114b)
    static public let setBolusResponse = IDCommandControlPointOpcode(rawValue: 0x1177)
    static public let cancelBolus = IDCommandControlPointOpcode(rawValue: 0x1178)
    static public let cancelBolusResponse = IDCommandControlPointOpcode(rawValue: 0x1187)
    static public let getAvailableBoluses = IDCommandControlPointOpcode(rawValue: 0x1188)
    static public let getAvailableBolusesResponse = IDCommandControlPointOpcode(rawValue: 0x11b4)
    static public let getBolusTemplate = IDCommandControlPointOpcode(rawValue: 0x11bb)
    static public let getBolusTemplateResponse = IDCommandControlPointOpcode(rawValue: 0x11d2)
    static public let setBolusTemplate = IDCommandControlPointOpcode(rawValue: 0x11dd)
    static public let setBolusTemplateResponse = IDCommandControlPointOpcode(rawValue: 0x11e1)
    static public let getTemplateStatusAndDetails = IDCommandControlPointOpcode(rawValue: 0x11ee)
    static public let getTemplateStatusAndDetailsResponse = IDCommandControlPointOpcode(rawValue: 0x1212)
    static public let resetTemplateStatus = IDCommandControlPointOpcode(rawValue: 0x121d)
    static public let resetTemplateStatusResponse = IDCommandControlPointOpcode(rawValue: 0x1221)
    static public let activateProfileTemplates = IDCommandControlPointOpcode(rawValue: 0x122e)
    static public let activateProfileTemplatesResponse = IDCommandControlPointOpcode(rawValue: 0x1247)
    static public let getActivatedProfileTemplates = IDCommandControlPointOpcode(rawValue: 0x1248)
    static public let getActivatedProfileTemplatesResponse = IDCommandControlPointOpcode(rawValue: 0x1274)
    static public let startPriming = IDCommandControlPointOpcode(rawValue: 0x127b)
    static public let stopPriming = IDCommandControlPointOpcode(rawValue: 0x1284)
    static public let setInitialResevoirFillLevel = IDCommandControlPointOpcode(rawValue: 0x128b)
    static public let resetResevoirInsulinOperationTime = IDCommandControlPointOpcode(rawValue: 0x12b7)
    static public let readISFProfileTemplates = IDCommandControlPointOpcode(rawValue: 0x12b8)
    static public let readISFProfileTemplatesResponse = IDCommandControlPointOpcode(rawValue: 0x12d1)
    static public let writeISFProfileTemplate = IDCommandControlPointOpcode(rawValue: 0x12de)
    static public let writeISFProfileTemplateResponse = IDCommandControlPointOpcode(rawValue: 0x12e2)
    static public let readI2CHOProfileTemplates = IDCommandControlPointOpcode(rawValue: 0x12ed)
    static public let readI2CHOProfileTemplatesResponse = IDCommandControlPointOpcode(rawValue: 0x1414)
    static public let writeI2CHOProfileTemplate = IDCommandControlPointOpcode(rawValue: 0x141b)
    static public let writeI2CHOProfileTemplateResponse = IDCommandControlPointOpcode(rawValue: 0x1427)
    static public let readTargetGlucoseRangeProfileTemplates = IDCommandControlPointOpcode(rawValue: 0x1428)
    static public let readTargetGlucoseRangeProfileTemplatesResponse = IDCommandControlPointOpcode(rawValue: 0x1441)
    static public let writeTargetGlucoseRangeProfileTemplate = IDCommandControlPointOpcode(rawValue: 0x144e)
    static public let writeTargetGlucoseRangeProfileTemplateResponse = IDCommandControlPointOpcode(rawValue: 0x1472)
    static public let getMaxBolusAmount = IDCommandControlPointOpcode(rawValue: 0x147d)
    static public let getMaxBolusAmountResponse = IDCommandControlPointOpcode(rawValue: 0x1482)
    static public let setMaxBolusAmount = IDCommandControlPointOpcode(rawValue: 0x148d)
    
    public var procedureID: ProcedureID {
        String("InsulinDeliveryControlPoint.\(self.debugDescription)")
    }

    public var requestOpcode: IDCommandControlPointOpcode? {
        switch self {
        case .snoozeAnnunciationResponse: return .snoozeAnnunciation
        case .confirmAnnunciationResponse: return .confirmAnnunciation
        case .readBasalRateTemplateResponse: return .readBasalRateTemplate
        case .writeBasalRateTemplateResponse: return .writeBasalRateTemplate
        case .getTempBasalTemplateResponse: return .getTempBasalTemplate
        case .setTempBasalTemplateResponse: return .setTempBasalTemplate
        case .setBolusResponse: return .setBolus
        case .cancelBolusResponse: return .cancelBolus
        case .getAvailableBolusesResponse: return .getAvailableBoluses
        case .getBolusTemplateResponse: return .getBolusTemplate
        case .setBolusTemplateResponse: return .setBolusTemplate
        case .getTemplateStatusAndDetailsResponse: return .getTemplateStatusAndDetails
        case .resetTemplateStatusResponse: return .resetTemplateStatus
        case .activateProfileTemplatesResponse: return .activateProfileTemplates
        case .getActivatedProfileTemplatesResponse: return .getActivatedProfileTemplates
        case .readISFProfileTemplatesResponse: return .readISFProfileTemplates
        case .writeISFProfileTemplateResponse: return .writeISFProfileTemplate
        case .readI2CHOProfileTemplatesResponse: return .readI2CHOProfileTemplates
        case .writeI2CHOProfileTemplateResponse: return .writeI2CHOProfileTemplate
        case .readTargetGlucoseRangeProfileTemplatesResponse: return .readTargetGlucoseRangeProfileTemplates
        case .writeTargetGlucoseRangeProfileTemplateResponse: return .writeTargetGlucoseRangeProfileTemplate
        case .getMaxBolusAmountResponse: return .getMaxBolusAmount
        default:
            return nil
        }
    }

    static var responseOpcodes: [IDCommandControlPointOpcode] {
        return [
            .responseCode,
            .snoozeAnnunciationResponse,
            .confirmAnnunciationResponse,
            .readBasalRateTemplateResponse,
            .writeBasalRateTemplateResponse,
            .getTempBasalTemplateResponse,
            .setTempBasalTemplateResponse,
            .setBolusResponse,
            .cancelBolusResponse,
            .getAvailableBolusesResponse,
            .getBolusTemplateResponse,
            .setBolusTemplateResponse,
            .getTemplateStatusAndDetailsResponse,
            .resetTemplateStatusResponse,
            .activateProfileTemplatesResponse,
            .getActivatedProfileTemplatesResponse,
            .readISFProfileTemplatesResponse,
            .writeISFProfileTemplateResponse,
            .readI2CHOProfileTemplatesResponse,
            .writeI2CHOProfileTemplateResponse,
            .readTargetGlucoseRangeProfileTemplatesResponse,
            .writeTargetGlucoseRangeProfileTemplateResponse,
            .getMaxBolusAmountResponse,
        ]
    }
    
    private var debugDescription: String {
        switch self {
        case .responseCode: return "responseCode"
        case .setTherapyControlState: return "setTherapyControlState"
        case .setFlightMode: return "setFlightMode"
        case .snoozeAnnunciation: return "snoozeAnnunciation"
        case .snoozeAnnunciationResponse: return "snoozeAnnunciationResponse"
        case .confirmAnnunciation: return "confirmAnnunciation"
        case .confirmAnnunciationResponse: return "confirmAnnunciationResponse"
        case .readBasalRateTemplate: return "readBasalRateTemplate"
        case .readBasalRateTemplateResponse: return "readBasalRateTemplateResponse"
        case .writeBasalRateTemplate: return "writeBasalRateTemplate"
        case .writeBasalRateTemplateResponse: return "writeBasalRateTemplateResponse"
        case .setTempBasalAdjustment: return "setTempBasalAdjustment"
        case .cancelTempBasalAdjustment: return "cancelTempBasalAdjustment"
        case .getTempBasalTemplate: return "getTempBasalTemplate"
        case .getTempBasalTemplateResponse: return "getTempBasalTemplateResponse"
        case .setTempBasalTemplate: return "setTempBasalTemplate"
        case .setTempBasalTemplateResponse: return "setTempBasalTemplateResponse"
        case .setBolus: return "setBolus"
        case .setBolusResponse: return "setBolusResponse"
        case .cancelBolus: return "cancelBolus"
        case .cancelBolusResponse: return "cancelBolusResponse"
        case .getAvailableBoluses: return "getAvailableBoluses"
        case .getAvailableBolusesResponse: return "getAvailableBolusesResponse"
        case .getBolusTemplate: return "getBolusTemplate"
        case .getBolusTemplateResponse: return "getBolusTemplateResponse"
        case .setBolusTemplate: return "setBolusTemplate"
        case .setBolusTemplateResponse: return "setBolusTemplateResponse"
        case .getTemplateStatusAndDetails: return "getTemplateStatusAndDetails"
        case .getTemplateStatusAndDetailsResponse: return "getTemplateStatusAndDetailsResponse"
        case .resetTemplateStatus: return "resetTemplateStatus"
        case .resetTemplateStatusResponse: return "resetTemplateStatusResponse"
        case .activateProfileTemplates: return "activateProfileTemplates"
        case .activateProfileTemplatesResponse: return "activateProfileTemplatesResponse"
        case .getActivatedProfileTemplates: return "getActivatedProfileTemplates"
        case .getActivatedProfileTemplatesResponse: return "getActivatedProfileTemplatesResponse"
        case .startPriming: return "startPriming"
        case .stopPriming: return "stopPriming"
        case .setInitialResevoirFillLevel: return "setInitialResevoirFillLevel"
        case .resetResevoirInsulinOperationTime: return "resetResevoirInsulinOperationTime"
        case .readISFProfileTemplates: return "readISFProfileTemplates"
        case .readISFProfileTemplatesResponse: return "readISFProfileTemplatesResponse"
        case .writeISFProfileTemplate: return "writeISFProfileTemplate"
        case .writeISFProfileTemplateResponse: return "writeISFProfileTemplateResponse"
        case .readI2CHOProfileTemplates: return "readI2CHOProfileTemplates"
        case .readI2CHOProfileTemplatesResponse: return "readI2CHOProfileTemplatesResponse"
        case .writeI2CHOProfileTemplate: return "writeI2CHOProfileTemplate"
        case .writeI2CHOProfileTemplateResponse: return "writeI2CHOProfileTemplateResponse"
        case .readTargetGlucoseRangeProfileTemplates: return "readTargetGlucoseRangeProfileTemplates"
        case .readTargetGlucoseRangeProfileTemplatesResponse: return "readTargetGlucoseRangeProfileTemplatesResponse"
        case .writeTargetGlucoseRangeProfileTemplate: return "writeTargetGlucoseRangeProfileTemplate"
        case .writeTargetGlucoseRangeProfileTemplateResponse: return "writeTargetGlucoseRangeProfileTemplateResponse"
        case .getMaxBolusAmount: return "getMaxBolusAmount"
        case .getMaxBolusAmountResponse: return "getMaxBolusAmountResponse"
        case .setMaxBolusAmount: return "setMaxBolusAmount"
        default: return "unknown opcode \(self.rawValue)"
        }
    }
}

public enum IDCommandControlPointResponseCode: UInt8 {
    case success = 0x0f
    case opcodeNotSupported = 0x70
    case invalidOperand = 0x71
    case procedureNotCompleted = 0x72
    case parameterOutOfRange = 0x73
    case procedureNotApplicable = 0x74
    case plausibilityCheckFailed = 0x75
    case maxBolusNumberReached = 0x76
    
    public var description: String {
        switch self {
        case .success: return "success"
        case .opcodeNotSupported: return "opcodeNotSupported"
        case .invalidOperand: return "invalidOperand"
        case .procedureNotCompleted: return "procedureNotCompleted"
        case .parameterOutOfRange: return "parameterOutOfRange"
        case .procedureNotApplicable: return "procedureNotApplicable"
        case .plausibilityCheckFailed: return "plausibilityCheckFailed"
        case .maxBolusNumberReached: return "maxBolusNumberReached"
        }
    }
}

public enum IDTemplateType: UInt8 {
    case undetermined = 0x0f
    case profileBasalRate = 0x33
    case tempBasal = 0x3c
    case bolus = 0x55
    case profileISF = 0x5a
    case profileI2CHO = 0x66
    case profileTargetGlucoseRange = 0x96
    
    public var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .profileBasalRate: return "profileBasalRate"
        case .tempBasal: return "tempBasal"
        case .bolus: return "bolus"
        case .profileISF: return "profileISF"
        case .profileI2CHO: return "profileI2CHO"
        case .profileTargetGlucoseRange: return "profileTargetGlucoseRange"
        }
    }
}

//MARK: - Option sets
struct WriteBasalRateFlags: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8
    
    static let endTransaction  = WriteBasalRateFlags(rawValue: 1 << 0)
    static let secondTimeBlockPresent = WriteBasalRateFlags(rawValue: 1 << 1)
    static let thirdTimeBlockPresent = WriteBasalRateFlags(rawValue: 1 << 2)
    static let allZeros = WriteBasalRateFlags([])
    
    static let debugDescriptions: [WriteBasalRateFlags:String] = {
        var descriptions = [WriteBasalRateFlags:String]()
        descriptions[.endTransaction] = "endTransaction"
        descriptions[.secondTimeBlockPresent] = "secondTimeBlockPresent"
        descriptions[.thirdTimeBlockPresent] = "thirdTimeBlockPresent"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in WriteBasalRateFlags.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "WriteBasalRateFlags(rawValue: \(rawValue)) \(result)"
    }
}

public struct AvailableBolusesFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let availableFast  = AvailableBolusesFlag(rawValue: 1 << 0)
    public static let availableExtended = AvailableBolusesFlag(rawValue: 1 << 1)
    public static let availableMultiwave = AvailableBolusesFlag(rawValue: 1 << 2)
    public static let allZeros = AvailableBolusesFlag([])
    
    public static let debugDescriptions: [AvailableBolusesFlag:String] = {
        var descriptions = [AvailableBolusesFlag:String]()
        descriptions[.availableFast] = "availableFast"
        descriptions[.availableExtended] = "availableExtended"
        descriptions[.availableMultiwave] = "availableMultiwave"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in AvailableBolusesFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "AvailableBolusesFlag(rawValue: \(rawValue)) \(result)"
    }
}
