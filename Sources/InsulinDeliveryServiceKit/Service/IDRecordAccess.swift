//
//  IDRecordAccess.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import BluetoothCommonKit
import os.log

public typealias RecordNumber = UInt32

// MARK: - Support Server Implementation
public class IDRecordAccessControlPointCharacteristic: WritableCharacteristic, E2EProtection, RequestHandler {
    public var e2eCounter: UInt8 = 0
    
    public var e2eDelegate: (any BluetoothCommonKit.E2EProtectionDelegate)?
    
    var messageQueue: MessagingQueue
    
    var historyDataCharacteristic: IDHistoryDataCharacteristic

    private var shouldAbort = false

    public var procedureRunning: Bool = false

    public var isServerBusy = false
    
    var currentRecordNumber: RecordNumber = 1
    
    var referenceTime: Date = Date()
    
    public var storedHistoryEvents: [PumpHistoryEvent] = []

    public required init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
        self.historyDataCharacteristic = IDHistoryDataCharacteristic(messageQueue: messageQueue)
        self.historyDataCharacteristic.e2eDelegate = self
        addReferenceTimeHistoryEvent()
        //TESTING
        loadHistoryEvents()
    }
    
    // FOR TESTING
    func loadHistoryEvents() {
        var eventData = BolusCalculatedHistoryEvent.createEventDataPart1(recommendedFastMeal: 1.1, recommendedFastCorrection: 1.2, recommendedExtendedMeal: 1.3, recommendedExtendedCorrection: 1.4)
        createHistoryEvent(for: .bolusCalculatedPart1, eventData: eventData)
        
        eventData = BolusCalculatedHistoryEvent.createEventDataPart2(confirmedFastMeal: 2.1, confirmedFastCorrection: 2.2, confirmedExtendedMeal: 2.3, confirmedExtendedCorrection: 2.4)
        createHistoryEvent(for: .bolusCalculatedPart2, eventData: eventData)
        
        eventData = BolusProgrammedHistoryEvent.createEventDataPart1(id: 1, type: .fast, fastAmount: 3.3, extendedAmount: 0, duration: 0)
        createHistoryEvent(for: .bolusProgrammedPart1, eventData: eventData)
        
        eventData = BolusProgrammedHistoryEvent.createEventDataPart2(activationType: .recommendedBolus)
        createHistoryEvent(for: .bolusProgrammedPart2, eventData: eventData)
        
        eventData = BolusDeliveredHistoryEvent.createEventDataPart1(id: 1, type: .fast, fastAmount: 1.2, extendedAmount: 0, duration: 0)
        createHistoryEvent(for: .bolusDeliveredPart1, eventData: eventData)
        
        eventData = BolusDeliveredHistoryEvent.createEventDataPart2(timeOffset: 60, activationType: .manualBolus, endReason: .canceled, annunciationID: 1)
        createHistoryEvent(for: .bolusDeliveredPart2, eventData: eventData)

        eventData = DeliveredBasalRateChangedHistoryEvent.createEventData(oldRate: 2.3, newRate: 3.4, deliveryContext: .aidController)
        createHistoryEvent(for: .deliveredBasalRateChanged, eventData: eventData)

        eventData = TempBasalAdjustmentStartedHistoryEvent.createEventData(type: .absolute, rate: 1.4, duration: .minutes(30), templateNumber: 1)
        createHistoryEvent(for: .tempBasalRateAdjustmentStarted, eventData: eventData)

        eventData = TempBasalAdjustmentEndedHistoryEvent.createEventData(type: .relative, effectiveDuration: .minutes(15), endReason: .canceled, templateNumber: 1, annunciationID: 2)
        createHistoryEvent(for: .tempBasalRateAdjustmentEnded, eventData: eventData)
        
        eventData = TempBasalAdjustmentChangedHistoryEvent.createEventData(type: .absolute, rate: 1.4, durationProgrammed: .minutes(30), durationElapsed: .minutes(15), templateNumber: 2)
        createHistoryEvent(for: .tempBasalRateAdjustmentChanged, eventData: eventData)
        
        eventData = ProfileTemplateActivatedHistoryEvent.createEventData(type: .basalRate, oldTemplateNumber: 1, newTemplateNumber: 2)
        createHistoryEvent(for: .profileTemplateActivated, eventData: eventData)
        
        eventData = BasalRateProfileTimeBlockChangedHistoryEvent.createEventData(templateNumber: 1, timeBlockNumber: 4, duration: .minutes(60), rate: 1.2)
        createHistoryEvent(for: .basalRateProfileTimeBlockChanged, eventData: eventData)

        eventData = TotalDailyInsulinDeliveryHistoryEvent.createEventData(bolusDelivered: 20, basalDelivered: 10, year: 2025, month: 5, day: 1, dateTimeChange: true)
        createHistoryEvent(for: .totalDailyInsulinDelivery, eventData: eventData)

        eventData = TherapyControlStateChangedHistoryEvent.createEventData(from: .stop, to: .run)
        createHistoryEvent(for: .therapyControlStateChanged, eventData: eventData)

        eventData = OperationalStateChangedHistoryEvent.createEventData(from: .priming, to: .waiting)
        createHistoryEvent(for: .operationalStateChanged, eventData: eventData)

        eventData = ReservoirRemainingAmountChangedHistoryEvent.createEventData(remainingAmount: 95)
        createHistoryEvent(for: .reservoirRemainingAmountChanged, eventData: eventData)

        eventData = AnnunciationStatusChangedHistoryEvent.createEventDataPart1(identifier: 1, type: .batteryEmpty, status: .pending, auxInfo1: Data(UInt16(0xffff)), auxInfo2: Data(UInt16(0xeeee)))
        createHistoryEvent(for: .annunciationStatusChangedPart1, eventData: eventData)
        
        eventData = AnnunciationStatusChangedHistoryEvent.createEventDataPart2(auxInfo3: Data(UInt16(0xdddd)), auxInfo4: Data(UInt16(0xcccc)), auxInfo5: Data(UInt16(0xbbbb)))
        createHistoryEvent(for: .annunciationStatusChangedPart2, eventData: eventData)

        eventData = ISFProfileTemplateTimeBlockChangedHistoryEvent.createEventData(templateNumber: 2, timeBlockNumber: 2, duration: 2, isf: 2)
        createHistoryEvent(for: .isfProfileTemplateTimeBlockChanged, eventData: eventData)

        eventData = I2CHORatioProfileTemplateTimeBlockChangedHistoryEvent.createEventData(templateNumber: 3, timeBlockNumber: 3, duration: 3, ratio: 3)
        createHistoryEvent(for: .i2choProfileTemplateTimeBlockChanged, eventData: eventData)

        eventData = TargetGlucoseRangeProfileTemplateTimeBlockChangedHistoryEvent.createEventData(templateNumber: 4, timeBlockNumber: 4, duration: 4, lowerTarget: 4, upperTarget: 5)
        createHistoryEvent(for: .targetGlucoseRangeProfileTemplateTimeBlockChanged, eventData: eventData)

        eventData = PrimingStartedHistoryEvent.createEventData(amount: 1.2)
        createHistoryEvent(for: .primingStarted, eventData: eventData)
        
        eventData = PrimingDoneHistoryEvent.createEventData(deliveredAmount: 1.2, terminationReason: .errorAbort, annunciationID: 1)
        createHistoryEvent(for: .primingDone, eventData: eventData)
        
        eventData = Data()
        createHistoryEvent(for: .dataCorruption, eventData: eventData)
        
        eventData = Data()
        createHistoryEvent(for: .pointerEvent, eventData: eventData)
        
        eventData = BolusTemplateChangedHistoryEvent.createEventDataPart1(templateNumber: 1, type: .fast, fastAmount: 2.3, extendedAmount: 0, duration: 0)
        createHistoryEvent(for: .bolusTemplateChangedPart1, eventData: eventData)
        
        eventData = BolusTemplateChangedHistoryEvent.createEventDataPart2(delayTime: 30)
        createHistoryEvent(for: .bolusTemplateChangedPart2, eventData: eventData)
        
        eventData = TempBasalTemplateChangedHistoryEvent.createEventData(templateNumber: 2, type: .extended, rate: 2.3, duration: .minutes(1))
        createHistoryEvent(for: .tempBasalRateTemplateChanged, eventData: eventData)
        
        eventData = MaxBolusAmountChangedHistoryEvent.createEventData(oldAmount: 30, newAmount: 20)
        createHistoryEvent(for: .maxBolusAmountChanged, eventData: eventData)
    }
    
    func addReferenceTimeHistoryEvent() {
        let eventData = ReferenceTimeHistoryEvent.createEventData(referenceTime, reason: .dateTimeLoss, timeZone: .utc, dstOffet: 0)
        createHistoryEvent(for: .referenceTime, eventData: eventData)
    }
    
    public func createHistoryEvent(for type: IDHistoryEventType, eventData: Data) {
        let relativeOffset = abs(referenceTime.timeIntervalSinceNow)
        guard let historyEvent = PumpHistoryEventFactory.createPumpHistoryEvent(type: type, recordNumber: currentRecordNumber, relativeOffet: relativeOffset, eventData: eventData) else {
            return
        }
        currentRecordNumber += 1
        storedHistoryEvents.append(historyEvent)
    }

    public func onWrite(_ request: Data?) -> CBATTError.Code {
        ConsoleOut.shared.logMessage(message: "ID Record Access Control Point request \(String(describing: request?.hexadecimalString))")
        guard let request = request else {
            return CBATTError.Code.invalidPdu
        }
        
        guard let opcode: IDRACPOpcode = responseOpcode(request),
              opcode == .abortOperation || !messageQueue.hasMessagesInQueue
        else {
            ConsoleOut.shared.logMessage(message: "Procedure is already in progress")
            return CBATTError.Code.procedureAlreadyInProgress
        }

        guard let response = responseForRequest(request) else {
            return CBATTError.Code.commandNotSupported
        }
        
        return indicateRACP(response: response)
    }

    func responseForRequest(_ request: Data) -> Data? {
        var index = 0
        guard let opcode: IDRACPOpcode = responseOpcode(request) else {
            let opcodeValue = request[request.startIndex...].to(IDRACPOpcode.RawValue.self)
            ConsoleOut.shared.logMessage(message: "Opcode is RFU. Complete response: \(request.hexadecimalString)")
            var response = Data(IDRACPOpcode.responseCode.rawValue)
            response.append(IDRACPOperator.nullOperator.rawValue)
            response.append(opcodeValue)
            response.append(IDRACPResponseCode.opcodeNotSupported.rawValue)
            return addE2EProtection(response: response)
        }
        index += 1

        guard let operatorValue = IDRACPOperator(rawValue: request[request.startIndex.advanced(by: index)...].to(IDRACPOperator.RawValue.self)) else {
            ConsoleOut.shared.logMessage(message: "Operator is RFU. Complete response: \(request.hexadecimalString)")
            return createResponseWith(.operatorNotSupported, requestOpcode: opcode)
        }
        index += 1

        ConsoleOut.shared.logMessage(message: "racp response opcode:\(opcode.procedureID)")
        switch opcode {
        case .reportStoredRecords:
            shouldAbort = false
            guard operatorValue != .nullOperator else {
                ConsoleOut.shared.logMessage(message: "Operator Invalid (Null not allowed): \(operatorValue)")
                return createResponseWith(.invalidOperator, requestOpcode: opcode)
            }

            guard !isServerBusy else {
                ConsoleOut.shared.logMessage(message: "Server is busy and cannot respond to RACP procedure: \(opcode)")
                return createResponseWith(.procedureNotApplicable, requestOpcode: opcode)
            }

            guard !storedHistoryEvents.isEmpty else {
                return createResponseNoRecordsFound(requestOpcode: opcode)
            }

            if operatorValue.includesFilterType {
                guard let filterType = IDRACPFilterType(rawValue: request[request.startIndex.advanced(by: index)...].to(IDRACPFilterType.RawValue.self)) else {
                    ConsoleOut.shared.logMessage(message: "Filter type RFU. Complete response: \(request.hexadecimalString)")
                    return createResponseWith(.operandNotSupported, requestOpcode: opcode)
                }
                index += 1

                if operatorValue == .lessThanOrEqualTo {
                    let historyEventsToReport: [PumpHistoryEvent]
                    switch filterType {
                    case .recordNumber:
                        let maxValue = Int(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self))
                        index += 4
                        historyEventsToReport = storedHistoryEvents.filter({ $0.recordNumber <= maxValue })
                    default:
                        // TODO support the other filter types
                        historyEventsToReport = []
                        break
                    }
                    guard !historyEventsToReport.isEmpty else {
                        return createResponseNoRecordsFound(requestOpcode: opcode)
                    }
                    for historyEvent in historyEventsToReport {
                        guard !shouldAbort else { break }
                        _ = indicateHistoryEvent(historyEvent)
                    }
                } else if operatorValue == .greaterThanOrEqualTo {
                    let historyEventsToReport: [PumpHistoryEvent]
                    switch filterType {
                    case .recordNumber:
                        let minValue = Int(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self))
                        index += 4
                        guard minValue <= storedHistoryEvents.count else {
                            return createResponseNoRecordsFound(requestOpcode: opcode)
                        }
                        historyEventsToReport = storedHistoryEvents.filter({ $0.recordNumber >= minValue })
                    default:
                        // TODO support the other filter types
                        historyEventsToReport = []
                        break
                    }
                    guard !historyEventsToReport.isEmpty else {
                        return createResponseNoRecordsFound(requestOpcode: opcode)
                    }
                    for historyEvent in historyEventsToReport {
                        guard !shouldAbort else { break }
                        _ = indicateHistoryEvent(historyEvent)
                    }
                } else {
                    // inclusive range
                    var historyEventsToReport: [PumpHistoryEvent]
                    switch filterType {
                    case .recordNumber:
                        let minValue = Int(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self))
                        index += 4
                        guard minValue <= storedHistoryEvents.count else {
                            return createResponseNoRecordsFound(requestOpcode: opcode)
                        }
                        historyEventsToReport = storedHistoryEvents.filter({ $0.recordNumber >= minValue })

                        let maxValue = Int(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self))
                        index += 4
                        historyEventsToReport = historyEventsToReport.filter({ $0.recordNumber <= maxValue })
                    default:
                        // TODO support the other filter types
                        historyEventsToReport = []
                        break
                    }
                    guard !historyEventsToReport.isEmpty else {
                        return createResponseNoRecordsFound(requestOpcode: opcode)
                    }

                    for historyEvent in historyEventsToReport {
                        guard !shouldAbort else { break }
                        _ = indicateHistoryEvent(historyEvent)
                    }
                }
            } else {
                if operatorValue == .allRecords {
                    for historyEvent in storedHistoryEvents {
                        guard !shouldAbort else { break }
                        _ = indicateHistoryEvent(historyEvent)
                    }
                } else if operatorValue == .firstRecord {
                    guard let historyEvent = storedHistoryEvents.first else {
                        return createResponseNoRecordsFound(requestOpcode: opcode)
                    }
                    _ = indicateHistoryEvent(historyEvent)
                } else {
                    guard let historyEvent = storedHistoryEvents.last else {
                        return createResponseNoRecordsFound(requestOpcode: opcode)
                    }
                    _ = indicateHistoryEvent(historyEvent)
                }
            }
            return createResponseWith(.success, requestOpcode: .reportStoredRecords)
        case .reportNumberOfStoredRecords:
            guard operatorValue != .nullOperator else {
                ConsoleOut.shared.logMessage(message: "Operator Invalid (Null not allowed): \(operatorValue)")
                return createResponseWith(.invalidOperator, requestOpcode: opcode)
            }

            guard !storedHistoryEvents.isEmpty else {
                return createReportNumberOfRecords(0)
            }

            if operatorValue.includesFilterType {
                guard let filterType = IDRACPFilterType(rawValue: request[request.startIndex.advanced(by: index)...].to(IDRACPFilterType.RawValue.self)) else {
                    ConsoleOut.shared.logMessage(message: "Filter type if RFU. Complete response: \(request.hexadecimalString)")
                    return createResponseWith(.operandNotSupported, requestOpcode: opcode)
                }
                index += 1

                if operatorValue == .lessThanOrEqualTo {
                    let historyEventsToReport: [PumpHistoryEvent]
                    switch filterType {
                    case .recordNumber:
                        let maxValue = Int(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self))
                        index += 4
                        historyEventsToReport = storedHistoryEvents.filter({ $0.recordNumber <= maxValue })
                    default:
                        // TODO support the other filter types
                        historyEventsToReport = []
                        break
                    }
                    guard !historyEventsToReport.isEmpty else {
                        return createReportNumberOfRecords(0)
                    }
                    return createReportNumberOfRecords(UInt32(historyEventsToReport.count))
                } else if operatorValue == .greaterThanOrEqualTo {
                    let historyEventsToReport: [PumpHistoryEvent]
                    switch filterType {
                    case .recordNumber:
                        let minValue = Int(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self))
                        index += 4
                        guard minValue <= storedHistoryEvents.count else {
                            return createReportNumberOfRecords(0)
                        }
                        historyEventsToReport = storedHistoryEvents.filter({ $0.recordNumber >= minValue })
                    default:
                        // TODO support the other filter types
                        historyEventsToReport = []
                        break
                    }
                    guard !historyEventsToReport.isEmpty else {
                        return createReportNumberOfRecords(0)
                    }
                    return createReportNumberOfRecords(UInt32(historyEventsToReport.count))
                } else {
                    // inclusive range
                    var historyEventsToReport: [PumpHistoryEvent]
                    switch filterType {
                    case .recordNumber:
                        let minValue = Int(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self))
                        index += 4
                        guard minValue <= storedHistoryEvents.count else {
                            return createReportNumberOfRecords(0)
                        }
                        historyEventsToReport = storedHistoryEvents.filter({ $0.recordNumber >= minValue })

                        let maxValue = Int(request[request.startIndex.advanced(by: index)...].to(RecordNumber.self))
                        index += 4
                        historyEventsToReport = historyEventsToReport.filter({ $0.recordNumber <= maxValue })
                    default:
                        // TODO support the other filter types
                        historyEventsToReport = []
                        break
                    }
                    guard !historyEventsToReport.isEmpty else {
                        return createReportNumberOfRecords(0)
                    }
                    return createReportNumberOfRecords(UInt32(historyEventsToReport.count))
                }
            } else {
                if operatorValue == .allRecords {
                    return createReportNumberOfRecords(UInt32(storedHistoryEvents.count))
                } else if operatorValue == .firstRecord {
                    return createReportNumberOfRecords(1)
                } else {
                    return createReportNumberOfRecords(1)
                }
            }
        case .abortOperation:
            guard operatorValue == .nullOperator else {
                ConsoleOut.shared.logMessage(message: "Operator invalid (expecting Null): \(operatorValue)")
                return createResponseWith(.invalidOperator, requestOpcode: opcode)
            }
            shouldAbort = true
            messageQueue.emptyQueue()
            return createResponseWith(.success, requestOpcode: opcode)
        default:
            ConsoleOut.shared.logMessage(message: "handler not implemented yet")
            return createResponseWith(.opcodeNotSupported, requestOpcode: opcode)
        }
    }
    
    func createReportNumberOfRecords(_ numberOfRecords: UInt32) -> Data {
        ConsoleOut.shared.logMessage(message: "\(#function) numberOfRecords: \(numberOfRecords)")
        var response = Data(IDRACPOpcode.numberOfStoredRecordsResponse.rawValue)
        response.append(IDRACPOperator.nullOperator.rawValue)
        response.append(numberOfRecords)
        return addE2EProtection(response: response)
    }

    func createResponseNoRecordsFound(requestOpcode: IDRACPOpcode) -> Data {
        ConsoleOut.shared.logMessage(message: "\(#function)")
        return createResponseWith(.noRecordsFound, requestOpcode: requestOpcode)
    }

    func createResponseWith(_ responseCode: IDRACPResponseCode, requestOpcode: IDRACPOpcode) -> Data {
        var response = Data(IDRACPOpcode.responseCode.rawValue)
        response.append(IDRACPOperator.nullOperator.rawValue)
        response.append(requestOpcode.rawValue)
        response.append(responseCode.rawValue)
        return addE2EProtection(response: response)
    }
    
    func respondWith(_ responseCode: IDRACPResponseCode, requestOpcode: IDRACPOpcode) -> CBATTError.Code {
        indicateRACP(response: createResponseWith(responseCode, requestOpcode: requestOpcode))
    }
    
    public func addE2EProtection(response: Data) -> Data {
        var response = response
        if e2eDelegate?.isE2EProtectionSupported ?? false {
            incrementE2ECounter()
            response = appendingE2EProtection(response)
        }
        return response
    }

    func indicateRACP(response: Data) -> CBATTError.Code {
        ConsoleOut.shared.logMessage(message: "\(#function) response: \(response.hexadecimalString)")
        messageQueue.addQueueItem(
            UUIDValuePair(
                uuid: InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID,
                value: response
            )
        )
        return CBATTError.Code.success
    }
    
    func indicateHistoryEvent(_ historyEvent: PumpHistoryEvent) -> CBATTError.Code {
        if shouldAbort {
            shouldAbort = false
        } else {
            historyDataCharacteristic.sendHistoryEvent(historyEvent)
        }
        return CBATTError.Code.success
    }
}

extension IDRecordAccessControlPointCharacteristic: E2EProtectionDelegate {
    public var isE2EProtectionSupported: Bool {
        e2eDelegate?.isE2EProtectionSupported ?? false
    }
}

// MARK: - Support Client Implementation
public class IDRecordAccessControlPointDataHandler: ControlPoint, E2EProtection {

    private let log = OSLog(category: "RecordAccessControlPoint")
    
    public weak var delegate: E2EProtectionDelegate?

    public var lockedRequestQueue: Locked<[(request: Data, completion: Any?)]> = Locked([])

    private var lockedE2ECounter: Locked<UInt8>
    
    public weak var e2eDelegate: E2EProtectionDelegate?

    public var procedureRunning: Bool = false
    
    var isReceivingHistoryEvents: Bool {
        guard procedureRunning,
              let request = lockedRequestQueue.value.first?.request,
              procedureIDForRequest(request) == IDRACPOpcode.reportStoredRecords.procedureID
        else { return false }
        
        return true
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

    public init(e2eCounter: UInt8 = IDRecordAccessControlPointDataHandler.e2eCounterInitalValue) {
        self.lockedE2ECounter = Locked(e2eCounter)
    }

    //MARK: - Response Handling
    public func handleResponse(_ response: Data) -> (result: DeviceCommResult<Any?>, completion: Any?) {
        guard e2eDelegate?.isE2EProtectionSupported == false || (e2eDelegate?.isE2EProtectionSupported == true && response.isCRCValid) else {
            return (.failure(.invalidCRC), nil)
        }

        guard let opcode: IDRACPOpcode = responseOpcode(response) else {
            log.error("Response opcode not known. Complete response: %{public}@", response.hexadecimalString)
            return (.failure(.opcodeUnknown(response.hexadecimalString)), nil)
        }

        log.debug("racp response opcode: %{public}@", opcode.procedureID)
        switch opcode {
        case .responseCode:
            guard response.count >= 4,
                  IDRACPOperator(rawValue: response[response.startIndex.advanced(by: 1)...].to(IDRACPOperator.RawValue.self)) == .nullOperator
            else { return (.failure(.invalidFormat), nil) }

            guard let requestOpcode = IDRACPOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDRACPOpcode.RawValue.self)),
                  let responseCode = IDRACPResponseCode(rawValue: response[response.startIndex.advanced(by: 3)...].to(IDRACPResponseCode.RawValue.self))
            else { return (.failure(.parameterOutOfRange), nil) }

            log.debug("request opcode  %{public}@, response code %{public}@", requestOpcode.procedureID, String(reflecting: responseCode))

            let completion = completeProcedure(requestOpcode)

            switch responseCode {
            case .success:
                return (.success(nil), completion)
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
            let completion = completeProcedure(IDRACPOpcode.reportNumberOfStoredRecords)
            let numberOfStoredRecords = Int(response[response.startIndex.advanced(by: 2)...].to(UInt32.self))
            log.debug("there are %{public}d stored records based on the request", numberOfStoredRecords)
            return (.success(numberOfStoredRecords), completion)
        default:
            log.error("handler not implemented yet")
            return (.failure(.opcodeNotImplemented), nil)
        }
    }

    public func procedureIDForResponse(_ response: Data) -> ProcedureID? {
        for opcode in IDRACPOpcode.responseOpcodes {
            if isSpecificResponse(expectedOpcode: opcode, response: response) {
                switch opcode {
                case .responseCode:
                    if let requestOpcode = IDRACPOpcode(rawValue: response[response.startIndex.advanced(by: 2)...].to(IDRACPOpcode.RawValue.self)) {
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

    public func procedureIDForRequest(_ request: Data) -> ProcedureID {
        guard let procedureID = IDRACPOpcode(rawValue: request[request.startIndex...].to(IDRACPOpcode.RawValue.self))?.procedureID else {
            fatalError("Opcode does not have a procedure ID \(request.toHexString())")
        }
        return procedureID
    }

    func isSpecificResponse(expectedOpcode: IDRACPOpcode, response: Data) -> Bool {
        guard let opcode = IDRACPOpcode(rawValue: response[response.startIndex...].to(IDRACPOpcode.RawValue.self)),
              opcode == expectedOpcode else
        {
            return false
        }
        return true
    }

    //MARK: - Create Request
    public func buildRequest(_ opcode: IDRACPOpcode, racpOperator: IDRACPOperator = .nullOperator, operand: Data? = nil) -> Data {
        var operatorAndOperand = Data(racpOperator.rawValue)
        if let operand = operand {
            operatorAndOperand.append(operand)
        }
        return IDRecordAccessControlPointDataHandler.buildControlPointRequest(opcode: opcode, operand: operatorAndOperand)
    }
    
    public func createGetAllStoredRecordsRequest() -> Data {
        createReportStoredRecordsRequest(racpOperator: .allRecords)
    }

    public func createGetAllStoredRecordsRequest(afterIncludingRecordNumber recordNumber: RecordNumber) -> Data {
        createReportStoredRecordsRequest(racpOperator: .greaterThanOrEqualTo, minRecordNumber: recordNumber)
    }
    
    public func createGetAllStoredRecordsRequest(beforeIncludingRecordNumber recordNumber: RecordNumber) -> Data {
        createReportStoredRecordsRequest(racpOperator: .lessThanOrEqualTo, maxRecordNumber: recordNumber)
    }
    
    public func createGetAllStoredRecordsInclusiveRangeRequest(minRecordNumber: RecordNumber, maxRecordNumber: RecordNumber) -> Data {
        createReportStoredRecordsRequest(racpOperator: .inclusiveRange, minRecordNumber: minRecordNumber, maxRecordNumber: maxRecordNumber)
    }

    // TODO test these update with coastal pump
    public func createGetNextBlockOfStoredRecordsRequest(startingAtRecordNumber recordNumber: RecordNumber) -> Data {
        let numberOfRecordsInBlock: UInt32 = 25
        return createGetAllStoredRecordsInclusiveRangeRequest(minRecordNumber: recordNumber, maxRecordNumber: recordNumber+numberOfRecordsInBlock)
    }

    public func createGetMostCurrentStoredRecordRequest() -> Data {
        createReportStoredRecordsRequest(racpOperator: .lastRecord)
    }

    public func createGetMostCurrentStoredReferenceTimeRecordRequest() -> Data {
        let operand = Data(IDRACPFilterType.recordNumberByReferenceTimeEvent.rawValue)
        return buildRequest(.reportStoredRecords, racpOperator: .lastRecord, operand: operand)
    }

    public func createOldestStoredRecordRequest() -> Data {
        createReportStoredRecordsRequest(racpOperator: .firstRecord)
    }
    
    public func createReportStoredRecordsRequest(racpOperator: IDRACPOperator, minRecordNumber: RecordNumber? = nil, maxRecordNumber: RecordNumber? = nil) -> Data {
        let min: UInt? = minRecordNumber == nil ? nil : UInt(minRecordNumber!)
        let max: UInt? = maxRecordNumber == nil ? nil : UInt(maxRecordNumber!)
        let operand = operandFor(racpOperator: racpOperator, min: min, max: max, filterType: .recordNumber)
        return buildRequest(.reportStoredRecords, racpOperator: racpOperator, operand: operand)
    }

    public func createReportNumberOfStoredRecordsRequest() -> Data {
        createReportNumberOfStoredRecordsRequest(racpOperator: .allRecords)
    }

    public func createReportNumberOfStoredRecordsRequest(afterIncludingRecordNumber recordNumber: RecordNumber) -> Data {
        createReportNumberOfStoredRecordsRequest(racpOperator: .greaterThanOrEqualTo, minRecordNumber: recordNumber)
    }
    
    public func createReportNumberOfStoredRecordsRequest(racpOperator: IDRACPOperator, minRecordNumber: RecordNumber? = nil, maxRecordNumber: RecordNumber? = nil) -> Data {
        let min: UInt? = minRecordNumber == nil ? nil : UInt(minRecordNumber!)
        let max: UInt? = maxRecordNumber == nil ? nil : UInt(maxRecordNumber!)
        let operand = operandFor(racpOperator: racpOperator, min: min, max: max, filterType: .recordNumber)
        return buildRequest(.reportNumberOfStoredRecords, racpOperator: racpOperator, operand: operand)
    }

    public func createAbortProcedureRequest() -> Data {
        return buildRequest(.abortOperation)
    }
    
    public func createDeleteStoredRecordsRequest(racpOperator: IDRACPOperator, minRecordNumber: RecordNumber?, maxRecordNumber: RecordNumber?) -> Data {
        let min: UInt? = minRecordNumber == nil ? nil : UInt(minRecordNumber!)
        let max: UInt? = maxRecordNumber == nil ? nil : UInt(maxRecordNumber!)
        let operand = operandFor(racpOperator: racpOperator, min: min, max: max, filterType: .recordNumber)
        return buildRequest(.deleteStoredRecords, racpOperator: racpOperator, operand: operand)
    }
    
    func operandFor(racpOperator: IDRACPOperator, min: UInt?, max: UInt?, filterType: IDRACPFilterType) -> Data? {
        var operand = Data(filterType.rawValue)
        switch racpOperator {
        case .nullOperator:
            fatalError("\(#function) Cannot use NULL operator")
        case .lessThanOrEqualTo:
            guard let max = max else {
                fatalError("\(#function) Need a max operator")
            }
            
            switch filterType {
            case .recordNumber:
                let maxRecordNumber = RecordNumber(max)
                operand.append(maxRecordNumber)
            default:
                // TODO support the other filter types
                break
            }
        case .greaterThanOrEqualTo:
            guard let min = min else {
                fatalError("\(#function) Need a min operator")
            }
            switch filterType {
            case .recordNumber:
                let minRecordNumber = RecordNumber(min)
                operand.append(minRecordNumber)
            default:
                // TODO support the other filter types
                break
            }
        case .inclusiveRange:
            guard let min = min,
                  let max = max
            else {
                fatalError("\(#function) Need a min and max operator")
            }
            
            switch filterType {
            case .recordNumber:
                let minRecordNumber = RecordNumber(min)
                let maxRecordNumber = RecordNumber(max)
                operand.append(minRecordNumber)
                operand.append(maxRecordNumber)
            default:
                // TODO support the other filter types
                break
            }
        default:
            break
        }
        return operand
    }

    //MARK: - Queue Request
    func queueGetAllStoredRecordsRequest(afterIncludingRecordNumber recordNumber: RecordNumber, completion: ProcedureResultCompletion? = nil) {
        appendToRequestQueue(createGetAllStoredRecordsRequest(afterIncludingRecordNumber: recordNumber), completion: completion)
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
public enum IDRACPOpcode: UInt8, CaseIterable, CustomStringConvertible {
    case responseCode = 0x0f
    case reportStoredRecords = 0x33
    case deleteStoredRecords = 0x3c
    case abortOperation = 0x55
    case reportNumberOfStoredRecords = 0x5a
    case numberOfStoredRecordsResponse = 0x66

    var procedureID: ProcedureID {
        String("RecordAccessControlPoint.\(self.debugDescription)")
    }

    var requestOpcode: IDRACPOpcode? {
        switch self {
        case .numberOfStoredRecordsResponse: return .reportNumberOfStoredRecords
        default:
            return nil
        }
    }

    static var responseOpcodes: [IDRACPOpcode] {
        return [
            .responseCode,
            .numberOfStoredRecordsResponse,
        ]
    }
    
    public var description: String {
        self.debugDescription
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

public enum IDRACPOperator: UInt8, CaseIterable, CustomStringConvertible {
    case nullOperator = 0x0f
    case allRecords = 0x33
    case lessThanOrEqualTo = 0x3c
    case greaterThanOrEqualTo = 0x55
    case inclusiveRange = 0x5a
    case firstRecord = 0x66
    case lastRecord = 0x69
    
    var includesFilterType: Bool {
        switch self {
        case .nullOperator, .allRecords, .firstRecord, .lastRecord: return false
        default: return true
        }
    }
    
    public var description: String {
        self.debugDescription
    }
    
    private var debugDescription: String {
        switch self {
        case .nullOperator: return "nullOperator"
        case .allRecords: return "allRecords"
        case .lessThanOrEqualTo: return "lessThanOrEqualTo"
        case .greaterThanOrEqualTo: return "greaterThanOrEqualTo"
        case .inclusiveRange: return "inclusiveRange"
        case .firstRecord: return "firstRecord"
        case .lastRecord: return "lastRecord"
        }
    }
}

enum IDRACPResponseCode: UInt8, CaseIterable, CustomStringConvertible {
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

enum IDRACPFilterType: UInt8, CaseIterable, CustomStringConvertible {
    case recordNumber = 0x0f
    case recordNumberByReferenceTimeEvent = 0x33 // filters by record number if the event type is a reference time or reference time base offset
    case recordNumberByNonReferenceTimeEvent = 0x3c // filters by record number if the event type is a not a reference time nor a reference time base offset
    
    var description: String {
        switch self {
        case .recordNumber: return "recordNumber"
        case .recordNumberByReferenceTimeEvent: return "recordNumberByReferenceTimeEvent"
        case .recordNumberByNonReferenceTimeEvent: return "recordNumberByNonReferenceTimeEvent"
        }
    }
}
