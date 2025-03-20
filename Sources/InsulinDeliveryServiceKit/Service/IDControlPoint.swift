//
//  IDControlPoint.swift
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

public class IDControlPoint: ControlPoint, E2EProtection {
    
    private let log = OSLog(category: "InsulinDeliveryControlPoint")
    
    public var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> = Locked([])
    
    private var lockedE2ECounter: Locked<UInt8>

    private let bolusManager: BolusManager
    
    private let basalManager: BasalManager
    
    private let idControlData: IDControlData
    
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
    
    init(bolusManager: BolusManager,
         basalManager: BasalManager,
         e2eCounter: UInt8 = IDControlPoint.e2eCounterInitalValue)
    {
        self.bolusManager = bolusManager
        self.basalManager = basalManager
        self.lockedE2ECounter = Locked(e2eCounter)
        self.idControlData = IDControlData(basalRateProfileTemplateNumber: basalManager.basalRateProfileTemplateNumber)
    }
    
    private func checkBasalRateTemplate() -> DeviceCommResult<Void> {
        guard idControlData.writeBasalSegments == idControlData.readBasalSegments else {
            log.error("Written basal rate profile does not match read basal rate profile opcode not known. written: %{public}@ read:  %{public}@", String(describing: idControlData.writeBasalSegments), String(describing: idControlData.readBasalSegments))
            return .failure(.procedureNotCompleted)
        }
        return .success
    }
    
    //MARK: - Response Handling
    func handleControlDataResponse(_ response: Data) -> DeviceCommResult<Void> {
        idControlData.handleResponse(response)
    }
    
    func handleResponse(_ response: Data) -> (result: DeviceCommResult<Void>, completion: Any?) {
        guard response.isCRCValid else {
            return (.failure(.invalidCRC), nil)
        }

        guard let opcode: IDControlPointOpcode = responseOpcode(response) else {
            log.error("Response opcode not known. Complete response: %{public}@", response.hexadecimalString)
            return (.failure(.opcodeUnknown(response.hexadecimalString)), nil)
        }
        
        log.debug("idcp response opcode: %{public}@", opcode.procedureID)
        switch opcode {
        case .responseCode:
            guard response.count == 8 else { return (.failure(.invalidFormat), nil) }
            
            guard let requestOpcode = IDControlPointOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDControlPointOpcode.RawValue.self)),
                  let responseCode = IDControlPointResponseCode(rawValue: response[response.startIndex.advanced(by: 4)...].to(IDControlPointResponseCode.RawValue.self)) else
            {
                return (.failure(.parameterOutOfRange), nil)
            }
            log.debug("request opcode  %{public}@, response code %{public}@", requestOpcode.procedureID, String(reflecting: responseCode))

            let completion = completeProcedure(requestOpcode)
            
            switch responseCode {
            case .success:
                if requestOpcode == .readBasalRateTemplate {
                    return (checkBasalRateTemplate(), completion)
                }
                return (.success, completion)
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
            let completion = completeProcedure(IDControlPointOpcode.activateProfileTemplates)
            let numberOfProfileTemplatesActivated = response[response.startIndex.advanced(by: 2)...].to(UInt8.self)
            guard numberOfProfileTemplatesActivated == basalManager.numberOfBasalRateProfiles else {
                return (.failure(.parameterOutOfRange), completion)
            }
            
            let profileTemplateActivated = response[response.startIndex.advanced(by: 3)...].to(UInt8.self)
            guard profileTemplateActivated == basalManager.basalRateProfileTemplateNumber else {
                return (.failure(.parameterOutOfRange), completion)
            }
            
            return (.success, completion)
        case .getActivatedProfileTemplatesResponse:
            let completion = completeProcedure(IDControlPointOpcode.getActivatedProfileTemplates)
            let numberOfProfileTemplatesActivated = response[response.startIndex.advanced(by: 2)...].to(UInt8.self)
            guard numberOfProfileTemplatesActivated == basalManager.numberOfBasalRateProfiles else {
                return (.failure(.procedureNotApplicable), completion)
            }
            
            let profileTemplateActivated = response[response.startIndex.advanced(by: 3)...].to(UInt8.self)
            guard profileTemplateActivated == basalManager.basalRateProfileTemplateNumber else {
                return (.failure(.procedureNotApplicable), completion)
            }
            
            return (.success, completion)
        case .resetTemplateStatusResponse:
            let completion = completeProcedure(IDControlPointOpcode.resetTemplateStatus)
            let numberOfProfileTemplatesActivated = response[response.startIndex.advanced(by: 2)...].to(UInt8.self)
            guard numberOfProfileTemplatesActivated == basalManager.numberOfBasalRateProfiles else {
                return (.failure(.procedureNotApplicable), completion)
            }
            
            let profileTemplateActivated = response[response.startIndex.advanced(by: 3)...].to(UInt8.self)
            guard profileTemplateActivated == basalManager.basalRateProfileTemplateNumber else {
                return (.failure(.procedureNotApplicable), completion)
            }
            
            return (.success, completion)
        case .writeBasalRateTemplateResponse:
            let completion = completeProcedure(IDControlPointOpcode.writeBasalRateTemplate)

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
            return (.success, completion)
        case .snoozeAnnunciationResponse:
            let completion = completeProcedure(IDControlPointOpcode.snoozeAnnunciation)
            guard response.count == 7 else {
                return (.failure(.invalidFormat), completion)
            }
            let annunciationID = response[response.startIndex.advanced(by: 2)...].to(AnnunciationIdentifier.self)
            log.debug("Snoozed annunciation with ID %{public}@", String(reflecting: annunciationID))
            return (.success, completion)
        case .confirmAnnunciationResponse:
            let completion = completeProcedure(IDControlPointOpcode.confirmAnnunciation)
            guard response.count == 7 else {
                return (.failure(.invalidFormat), completion)
            }
            let annunciationID = response[response.startIndex.advanced(by: 2)...].to(AnnunciationIdentifier.self)
            log.debug("Confirmed annunciation with ID %{public}@", String(reflecting: annunciationID))
            return (.success, completion)
        case .setBolusResponse:
            let completion = completeProcedure(IDControlPointOpcode.setBolus)
            let result = bolusManager.handleResponse(response, with: opcode)
            return (result, completion)
        case .cancelBolusResponse:
            let completion = completeProcedure(IDControlPointOpcode.cancelBolus)
            let result = bolusManager.handleResponse(response, with: opcode)
            return (result, completion)
        default:
            log.error("handler not implemented yet")
            return (.failure(.opcodeNotImplemented), nil)
        }
    }

    public func procedureIDForResponse(_ response: Data) -> ProcedureID? {
        for opcode in IDControlPointOpcode.responseOpcodes {
            if isSpecificResponse(expectedOpcode: opcode, response: response) {
                switch opcode {
                case .responseCode:
                    if let requestOpcode = IDControlPointOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDControlPointOpcode.RawValue.self)) {
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
        log.error("Insulin Delivery Control Point response does not have a procedure ID (raw response: %{public}@)", response.toHexString())
        return nil
    }

    public func procedureIDForRequest(_ request: Data) -> ProcedureID {
        guard let procedureID = IDControlPointOpcode(rawValue: request[request.startIndex...].to(IDControlPointOpcode.RawValue.self))?.procedureID else {
            fatalError("Opcode does not have a procedure ID \(request.toHexString())")
        }
        return procedureID
    }

    func isSpecificResponse(expectedOpcode: IDControlPointOpcode, response: Data) -> Bool {
        guard let opcode = IDControlPointOpcode(rawValue: response[response.startIndex...].to(IDControlPointOpcode.RawValue.self)),
              opcode == expectedOpcode else
        {
            return false
        }
        return true
    }
    
    func isGeneralResponseToSpecificRequest(expectedRequestOpcode: IDControlPointOpcode, response: Data) -> Bool {
        let isGeneralResponse = isSpecificResponse(expectedOpcode: IDControlPointOpcode.responseCode, response: response)
        guard isGeneralResponse,
              let requestOpcode = IDControlPointOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDControlPointOpcode.RawValue.self)),
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
    func buildRequest(_ opcode: IDControlPointOpcode, operand: Data? = nil) -> Data {
        IDControlPoint.buildControlPointRequest(opcode: opcode, operand: operand)
    }
    
    func createSetInitialReservoirFillLevelRequest(_ fillLevel: Int) -> Data {
        buildRequest(.setInitialResevoirFillLevel, operand: fillLevel.sfloat)
    }
    
    func createResetReservoirInsulinOperationTimeRequest() -> Data {
        buildRequest(.resetResevoirInsulinOperationTime)
    }
    
    func createStartPrimingRequest(_ primingAmount: Double) -> Data {
        buildRequest(.startPriming, operand: primingAmount.sfloat)
    }
    
    func createPrimeCannulaRequest(_ primingAmount: Double) -> Data {
        buildRequest(.startPriming, operand: primingAmount.sfloat)
    }
    
    func createStopPrimingRequest() -> Data {
        buildRequest(.stopPriming)
    }
    
    func createStartInsulinTherapyRequest() -> Data {
        let operand = Data(InsulinTherapyControlState.run.rawValue)
        return buildRequest(IDControlPointOpcode.setTherapyControlState, operand: operand)
    }
    
    func createStopInsulinTherapyRequest() -> Data {
        let operand = Data(InsulinTherapyControlState.stop.rawValue)
        return buildRequest(IDControlPointOpcode.setTherapyControlState, operand: operand)
    }
        
    func createActivateProfileTemplatesRequest(for templateNumbers: [UInt8] = [1]) -> Data {
        var operand = Data(templateNumbers.count)
        for templateNumber in templateNumbers {
            operand.append(templateNumber)
        }
        return buildRequest(.activateProfileTemplates, operand: operand)
    }
    
    func createGetActivatedProfileTemplates() -> Data {
        buildRequest(.getActivatedProfileTemplates)
    }
    
    func createDeactivateProfileTemplatesRequest(for templateNumbers: [UInt8] = [1]) -> Data {
        var operand = Data(templateNumbers.count)
        for templateNumber in templateNumbers {
            operand.append(templateNumber)
        }
        return buildRequest(.resetTemplateStatus, operand: operand)
    }
    
    func createReadBasalRateProfileRequest(for templateNumber: UInt8 = 1) -> Data {
        buildRequest(.readBasalRateTemplate, operand: Data(templateNumber))
    }
    
    func createWriteBasalRateProfileRequest(for basalSegments: [BasalSegment], templateNumber: UInt8 = 1, isLast last: Bool) -> Data {
        guard basalSegments.count <= 3,
              let firstSegment = basalSegments.first else
        {
            //TODO handle this better with other error
            fatalError("A write basal rate profile request must have at least 1 segment and can only write up to 3 segments at once")
        }
        
        var requestFlags: WriteBasalRateFlags = last ? .endTransaction : .allZeros
        var operand = Data(templateNumber)
        operand.append(firstSegment.index)
        operand.append(firstSegment.durationInMinutes)
        operand.append(firstSegment.rate.sfloat)
        
        if let secondSegment = basalSegments[safe: 1] {
            requestFlags.update(with: .secondTimeBlockPresent)
            operand.append(secondSegment.durationInMinutes)
            operand.append(secondSegment.rate.sfloat)
        }
        
        if let thirdSegment = basalSegments[safe: 2] {
            requestFlags.update(with: .thirdTimeBlockPresent)
            operand.append(thirdSegment.durationInMinutes)
            operand.append(thirdSegment.rate.sfloat)
        }
        
        // add the flags once all the segments are accounted for
        operand.insert(requestFlags.rawValue, at: 0)
        
        return buildRequest(IDControlPointOpcode.writeBasalRateTemplate, operand: operand)
    }

    func createSnoozeAnnunciationRequest(for annunciationID: UInt16) -> Data {
        // the annunciation will be snoozed for 5 mins (300 seconds)
        let operand = Data(annunciationID)
        return buildRequest(.snoozeAnnunciation, operand: operand)
    }
    
    func createConfirmAnnunciationRequest(for annunciationID: UInt16) -> Data {
        let operand = Data(annunciationID)
        return buildRequest(.confirmAnnunciation, operand: operand)
    }
    
    func createSetBolusRequest(for amount: Double, activationType: IDBolusActivationType) -> Data {
        bolusManager.createFastBolusRequest(for: amount, activationType: activationType)
    }
    
    func createCancelCurrentBolusRequest() -> Data? {
        bolusManager.createCancelCurrentBolusRequest()
    }
    
    func createSetTempBasalRequest(unitsPerHour: Double,
                                   durationInMinutes: UInt16,
                                   deliveryContext: TempBasalDeliveryContext,
                                   replaceExisting: Bool = false) -> Data
    {
        basalManager.createSetTempBasalAdjustmentRequest(unitsPerHour: unitsPerHour,
                                                         durationInMinutes: durationInMinutes,
                                                         deliveryContext: deliveryContext,
                                                         replaceExisting: replaceExisting)
    }
    
    func createCancelTempBasalRequest() -> Data {
        BasalManager.createCancelTempBasalAdjustmentRequest()
    }

    //MARK: - Queue Requests
    func queueInsulinSetupRequests(fillValue: Int, basalSegments: [BasalSegment], completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createSetInitialReservoirFillLevelRequest(fillValue), completion: nil)
        appendToRequestQueue(createResetReservoirInsulinOperationTimeRequest(), completion: nil)
        queueWriteBasalRateRequests(for: basalSegments)
        appendToRequestQueue(createActivateProfileTemplatesRequest(), completion: completion)
    }

    func queueWriteBasalRateRequests(for basalSegments: [BasalSegment], completion: ProcedureResultCompletion? = nil) {
        idControlData.writeBasalSegments = basalSegments

        let groupsOfBasalSegments: [[BasalSegment]] = basalSegments.chunked(into: 3)
        groupsOfBasalSegments.enumerated().forEach { (index, basalSegments) in
            let isLast = index == groupsOfBasalSegments.count-1
            appendToRequestQueue(createWriteBasalRateProfileRequest(for: basalSegments,
                                                                   isLast: isLast),
                                 completion: isLast ? completion : nil)
        }
    }

    func queueStartPrimingRequest(_ primingAmount: Double, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createStartPrimingRequest(primingAmount), completion: completion)
    }

    func queuePrimeCannulaRequest(_ primingAmount: Double, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createPrimeCannulaRequest(primingAmount), completion: completion)
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

    func queueSnoozeAnnunciationRequest(for annunciationID: UInt16, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createSnoozeAnnunciationRequest(for: annunciationID), completion: completion)
    }

    func queueConfirmAnnunciationRequest(for annunciationID: UInt16, completion: ProcedureResultCompletion? = nil) {
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
                                  deliveryContext: TempBasalDeliveryContext,
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
enum IDControlPointOpcode: UInt16, CaseIterable {
    case responseCode = 0x0f55
    case setTherapyControlState = 0x0f5a
    case setFlightMode = 0x0f66
    case snoozeAnnunciation = 0x0f69
    case snoozeAnnunciationResponse = 0x0f96
    case confirmAnnunciation = 0x0f99
    case confirmAnnunciationResponse = 0x0fa5
    case readBasalRateTemplate = 0x0faa
    case readBasalRateTemplateResponse = 0x0fc3
    case writeBasalRateTemplate = 0x0fcc
    case writeBasalRateTemplateResponse = 0x0ff0
    case setTempBasalAdjustment = 0x0fff
    case cancelTempBasalAdjustment = 0x1111
    case getTempBasalTemplate = 0x111e
    case getTempBasalTemplateResponse = 0x1122
    case setTempBasalTemplate = 0x112d
    case setTempBasalTemplateResponse = 0x1144
    case setBolus = 0x114b
    case setBolusResponse = 0x1177
    case cancelBolus = 0x1178
    case cancelBolusResponse = 0x1187
    case getAvailableBoluses = 0x1188
    case getAvailableBolusesResponse = 0x11b4
    case getBolusTemplate = 0x11bb
    case getBolusTemplateResponse = 0x11d2
    case setBolusTemplate = 0x11dd
    case setBolusTemplateResponse = 0x11e1
    case getTemplateStatusAndDetails = 0x11ee
    case getTemplateStatusAndDetailsResponse = 0x1212
    case resetTemplateStatus = 0x121d
    case resetTemplateStatusResponse = 0x1221
    case activateProfileTemplates = 0x122e
    case activateProfileTemplatesResponse = 0x1247
    case getActivatedProfileTemplates = 0x1248
    case getActivatedProfileTemplatesResponse = 0x1274
    case startPriming = 0x127b
    case stopPriming = 0x1284
    case setInitialResevoirFillLevel = 0x128b
    case resetResevoirInsulinOperationTime = 0x12b7
    case readISFProfileTemplates = 0x12b8
    case readISFProfileTemplatesResponse = 0x12d1
    case writeISFProfileTemplate = 0x12de
    case writeISFProfileTemplateResponse = 0x12e2
    case readI2CHOProfileTemplates = 0x12ed
    case readI2CHOProfileTemplatesResponse = 0x1414
    case writeI2CHOProfileTemplate = 0x141b
    case writeI2CHOProfileTemplateResponse = 0x1427
    case readTargetGlucoseRangeProfileTemplates = 0x1428
    case readTargetGlucoseRangeProfileTemplatesResponse = 0x1441
    case writeTargetGlucoseRangeProfileTemplate = 0x144e
    case writeTargetGlucoseRangeProfileTemplateResponse = 0x1472
    case getMaxBolusAmount = 0x147d
    case getMaxBolusAmountResponse = 0x1482
    case setMaxBolusAmount = 0x148d
    
    var procedureID: ProcedureID {
        String("InsulinDeliveryControlPoint.\(self.debugDescription)")
    }

    var requestOpcode: IDControlPointOpcode? {
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

    static var responseOpcodes: [IDControlPointOpcode] {
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
        }
    }
}

enum IDControlPointResponseCode: UInt8 {
    case success = 0x0f
    case opcodeNotSupported = 0x70
    case invalidOperand = 0x71
    case procedureNotCompleted = 0x72
    case parameterOutOfRange = 0x73
    case procedureNotApplicable = 0x74
    case plausibilityCheckFailed = 0x75
    case maxBolusNumberReached = 0x76
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
