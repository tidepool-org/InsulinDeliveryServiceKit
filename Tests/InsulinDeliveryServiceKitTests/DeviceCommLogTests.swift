//
//  DeviceCommLogTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-19.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import CoreBluetooth
import BluetoothCommonKit
@testable import InsulinDeliveryServiceKit

class DeviceCommLogTests: XCTestCase {

    private var pump: TestInsulinDeliveryPump!
    private var isPumpConnected = true
    private var connectionEvents: [String] = []
    private var sendEvents: [String] = []
    private var receiveEvents: [String] = []
    private var errorEvents: [String] = []
    private var connectionEventException: XCTestExpectation?
    private var sendEventException: XCTestExpectation?
    private var receiveEventException: XCTestExpectation?
    private var errorEventException: XCTestExpectation?
    private let pendingCompletion: ProcedureResultCompletion = { _ in }

    override func setUpWithError() throws {
        let securityManager = SecurityManager()
        let bluetoothManager = BluetoothManager(peripheralConfiguration: .insulinDeliveryServiceConfiguration, servicesToDiscover: [InsulinDeliveryCharacteristicUUID.service.cbUUID], restoreOptions: nil)
        let acControlPoint = ACControlPoint(securityManager: securityManager, maxRequestSize: 19)
        let acData = ACData(securityManager: securityManager, maxRequestSize: 19)
        let bolusManager = BolusManager()
        let pumpHistoryEventManager = PumpHistoryEventManager()
        pump = TestInsulinDeliveryPump(bluetoothManager: bluetoothManager,
                                       bolusManager: bolusManager,
                                       basalManager: BasalManager(),
                                       pumpHistoryEventManager: pumpHistoryEventManager,
                                       securityManager: securityManager,
                                       acControlPoint: acControlPoint,
                                       acData: acData,
                                       state: IDPumpState(features: [.supportedE2EProtection], authorizationControlRequired: true),
                                       isConnectedHandler: { self.isPumpConnected })
        pump.loggingDelegate = self

        connectionEvents = []
        sendEvents = []
        receiveEvents = []
        errorEvents = []
        connectionEventException = nil
        sendEventException = nil
        receiveEventException = nil
        errorEventException = nil
    }

    func testLoggingDisconnect() {
        let messages = ["Pump disconnected", "disconnect()"]
        checkConnectionEventProcedure({ self.pump.handleCBError(CBError(.peripheralDisconnected)) }, for: messages)
    }

    func testLoggingTimeout() {
        let messages = ["Pump connection timed out", "disconnect()"]
        checkConnectionEventProcedure({ self.pump.handleCBError(CBError(.connectionTimeout)) }, for: messages)
    }

    func testLoggingConnetionFailed() {
        let messages = ["Pump disconnected", "disconnect()"]
        checkConnectionEventProcedure({ self.pump.handleCBError(CBError(.connectionFailed)) }, for: messages)
    }

    func testLoggingPumpAlreadyPaired() {
        let messages = ["Pump was already paired"]
        checkConnectionEventProcedure({ self.pump.handleCBError(CBError(.uuidNotAllowed)) }, for: messages)
    }

    func testLoggingPumpNotConnected() {
        isPumpConnected = false
        let messages = ["Pump not currently connected"]
        checkConnectionEventProcedure({ self.pump.getBatteryLevel() }, for: messages)
    }

    func testLoggingBeepRequest() {
        let messages = ["sendBeepRequest()"]
        checkSendEventProcedure({ self.pump.sendBeepRequest() }, for: messages)
    }

    func testLoggingSetTime() {
        let messages = ["Setting time of pump", "\(DTControlPointOpcode.proposeTimeUpdate.procedureID)"]
        checkSendEventProcedure({ self.pump.setTime(Date(), using: .currentFixed) { _ in } }, for: messages)
    }

    func testLoggingPrepareForInsulinDelivery() {
        let messages = ["Setting reservoirLevel", "\(IDControlPointOpcode.setInitialResevoirFillLevel.procedureID)"]
        let basalSchedule = [BasalSegment(index: 1, rate: 1, duration: .hours(24))]
        checkSendEventProcedure({ self.pump.prepareForInsulinDelivery(reservoirLevel: 200, basalSegments: basalSchedule) { _ in } }, for: messages)
    }

    func testLoggingStartPrimingReservoir() {
        let messages = ["startPrimingReservoir", "\(IDControlPointOpcode.startPriming.procedureID)"]
        checkSendEventProcedure({ self.pump.startPrimingReservoir(3) { _ in } }, for: messages)
    }

    func testLoggingPrimeCannula() {
        let messages = ["primeCannula", "\(IDControlPointOpcode.startPriming.procedureID)"]
        checkSendEventProcedure({ self.pump.primeCannula(3) { _ in } }, for: messages)
    }

    func testLoggingStopPriming() {
        let messages = ["stopPriming", "\(IDControlPointOpcode.stopPriming.procedureID)"]
        checkSendEventProcedure({ self.pump.stopPriming() { _ in } }, for: messages)
    }

    func testLoggingStartInsulinDelivery() {
        let messages = ["startInsulinDelivery", "\(IDControlPointOpcode.setTherapyControlState.procedureID)"]
        checkSendEventProcedure({ self.pump.startInsulinDelivery() { _ in } }, for: messages)
    }

    func testLoggingSuspendInsulinDelivery() {
        let messages = ["suspendInsulinDelivery", "\(IDControlPointOpcode.setTherapyControlState.procedureID)"]
        checkSendEventProcedure({ self.pump.suspendInsulinDelivery() { _ in } }, for: messages)
    }

    func testLoggingGetAnnunciationStatus() {
        let messages = ["getAnnunciationStatus"]
        checkSendEventProcedure({ self.pump.getAnnunciationStatus() { _ in } }, for: messages)
    }

    func testLoggingConfirmAnnunciation() {
        let messages = ["confirmAnnunciation", "\(IDControlPointOpcode.confirmAnnunciation.procedureID)"]
        checkSendEventProcedure({ self.pump.confirmAnnunciation(GeneralAnnunciation(type: .reservoirLow, identifier: 1234)) { _ in } }, for: messages)
    }

    func testLoggingGetInsulinDeliveryStatus() {
        let messages = ["getInsulinDeliveryStatus"]
        checkSendEventProcedure({ self.pump.getInsulinDeliveryStatus() { _ in } }, for: messages)
    }

    func testLoggingSetBasalRateSchedule() {
        let messages = ["setBasalRateSchedule", "\(IDControlPointOpcode.writeBasalRateTemplate.procedureID)"]
        let basalSchedule = [BasalSegment(index: 1, rate: 1, duration: .hours(24))]
        checkSendEventProcedure({ self.pump.setBasalRateSchedule(basalSchedule) { _ in } }, for: messages)
    }

    func testLoggingSetBolus() {
        let messages = ["setBolus", "\(IDControlPointOpcode.setBolus.procedureID)"]
        checkSendEventProcedure({ self.pump.setBolus(2.0, activationType: .recommendedBolus) { _ in } }, for: messages)
    }

    func testLoggingCancelBolus() {
        pump.setBolus(2.0, activationType: .recommendedBolus) { _ in }
        pump.respondToSetBolusWithSuccess(bolusID: 1)
        sendEvents = []
        let messages = ["cancelBolus", "\(IDControlPointOpcode.cancelBolus.procedureID)"]
        checkSendEventProcedure({ self.pump.cancelBolus() { _ in } }, for: messages)
    }

    func testLoggingCancelBolusNoActiveBolus() {
        let messages = ["Could not create cancel bolus request"]
        checkErrorEventProcedure({ self.pump.cancelBolus() { _ in } }, for: messages)
    }

    func testLoggingGetInsulinDeliveryStatusChanged() {
        let messages = ["getInsulinDeliveryStatusChanged"]
        checkSendEventProcedure({ self.pump.getInsulinDeliveryStatusChanged() { _ in } }, for: messages)
    }

    func testLoggingResetActiveBolusStatusChanged() {
        let messages = ["activeBolusStatusChanged", "\(IDStatusReaderOpcode.resetStatus.procedureID)"]
        checkSendEventProcedure({ self.pump.resetStatusChanged(.activeBolusStatusChanged) { _ in } }, for: messages)
    }

    func testLoggingResetHistoryEventRecordedStatusChanged() {
        let messages = ["historyEventRecordedChanged", "\(IDStatusReaderOpcode.resetStatus.procedureID)"]
        checkSendEventProcedure({ self.pump.resetStatusChanged(.historyEventRecordedChanged) { _ in } }, for: messages)
    }

    func testLoggingResetAnnunciationStatusChanged() {
        let messages = ["annunciationStatusChanged", "\(IDStatusReaderOpcode.resetStatus.procedureID)"]
        checkSendEventProcedure({ self.pump.resetStatusChanged(.annunciationStatusChanged) { _ in } }, for: messages)
    }

    func testLoggingGetActiveBolusIDs() {
        let messages = ["getActiveBolusIDs", "\(IDStatusReaderOpcode.getActiveBolusIDs.procedureID)"]
        checkSendEventProcedure({ self.pump.getActiveBolusIDs() { _ in } }, for: messages)
    }

    func testLoggingGetActiveBolusDeliveredDetails() {
        pump.setBolus(2.0, activationType: .recommendedBolus) { _ in }
        pump.respondToSetBolusWithSuccess(bolusID: 1)
        sendEvents = []
        let messages = ["getActiveBolusDeliveredDetails", "\(IDStatusReaderOpcode.getActiveBolusDelivery.procedureID)"]
        checkSendEventProcedure({ self.pump.getActiveBolusDeliveredDetails() { _ in } }, for: messages)
    }

    func testLoggingGetActiveBolusProgrammedDetails() {
        pump.setBolus(2.0, activationType: .recommendedBolus) { _ in }
        pump.respondToSetBolusWithSuccess(bolusID: 1)
        sendEvents = []
        let messages = ["getActiveBolusProgrammedDetails", "\(IDStatusReaderOpcode.getActiveBolusDelivery.procedureID)"]
        checkSendEventProcedure({ self.pump.getActiveBolusProgrammedDetails() { _ in } }, for: messages)
    }

    func testLoggingSetTempBasal() {
        let messages = ["getDeliveredInsulin", "\(IDStatusReaderOpcode.getDeliveredInsulin.procedureID)"]
        checkSendEventProcedure({ self.pump.setTempBasal(unitsPerHour: 2.0, durationInMinutes: 30, replaceExisting: true) { _ in } }, for: messages)
    }

    func testLoggingCancelTempBasal() {
        let messages = ["getDeliveredInsulin", "\(IDStatusReaderOpcode.getDeliveredInsulin.procedureID)"]
        checkSendEventProcedure({ self.pump.cancelTempBasal() { _ in } }, for: messages)
    }

    func testLoggingGetMostCurrentReferenceTimeHistoryEvent() {
        let messages = ["getMostCurrentReferenceTimeHistoryEvent", "\(RACPOpcode.reportStoredRecords.procedureID)"]
        checkSendEventProcedure({ self.pump.getMostCurrentReferenceTimeHistoryEvent() { _ in } }, for: messages)
    }

    func testLoggingGetOldestHistoryEvent() {
        let messages = ["getOldestHistoryEvent", "\(RACPOpcode.reportStoredRecords.procedureID)"]
        checkSendEventProcedure({ self.pump.getOldestHistoryEvent() { _ in } }, for: messages)
    }

    func testLoggingGetPumpHistoryEvents() {
        pump.reportHistoryEventTherapyControlStateChanged()
        let messages = ["getPumpHistoryEvents", "\(RACPOpcode.reportStoredRecords.procedureID)"]
        checkSendEventProcedure({ self.pump.getPumpHistoryEvents() { _ in } }, for: messages)
    }

    func testLoggingGetPumpHistoryEventsNoPriorHistory() {
        let messages = ["getPumpHistoryEvents", "getMostCurrentReferenceTimeHistoryEvent", "\(RACPOpcode.reportStoredRecords.procedureID)"]
        checkSendEventProcedure({ self.pump.getPumpHistoryEvents() { _ in } }, for: messages)
    }

    func testLoggingGetBatteryLevel() {
        let messages = ["getBatteryLevel"]
        checkSendEventProcedure({ self.pump.getBatteryLevel() }, for: messages)
    }

    func testLoggingManageACDataValueError() {
        let segmentationHeader: SegmentationHeader = SegmentationHeader(rawValue: 7)
        let messages = ["manageACDataValue", "Received secure data"]
        checkReceiveEventProcedure({ self.pump.manageACDataValue(Data(segmentationHeader.rawValue)) }, for: messages)
    }

    func testLoggingManageInsulinDeliveryControlPointResponseError() {
        let requestOpcode = IDControlPointOpcode.setBolus
        let messages = ["\(requestOpcode.procedureID) encountered error"]
        pump.idControlPoint.appendToRequestQueue(Data(requestOpcode.rawValue), completion: pendingCompletion)
        checkErrorEventProcedure({ self.pump.sendInsulinDeliveryControlPointResponseError(requestOpcode: requestOpcode) }, for: messages)
    }

    func testLoggingManageInsulinDeliveryStatusReaderResponseError() {
        let requestOpcode = IDStatusReaderOpcode.resetStatus
        let messages = ["\(requestOpcode.procedureID) encountered error"]
        pump.idStatusReader.appendToRequestQueue(Data(requestOpcode.rawValue), completion: pendingCompletion)
        checkErrorEventProcedure({ self.pump.sendInsulinDeliveryStatusReaderResponseError(requestOpcode: requestOpcode) }, for: messages)
    }

    func testLoggingManageRecordAccessControlPointResponseError() {
        let requestOpcode = RACPOpcode.reportStoredRecords
        let messages = ["\(requestOpcode.procedureID) encountered error"]
        pump.recordAccessControlPoint.appendToRequestQueue(Data(requestOpcode.rawValue), completion: pendingCompletion)
        checkErrorEventProcedure({ self.pump.sendRecordAccessControlPointResponseError(requestOpcode: requestOpcode) }, for: messages)
    }

    func testLoggingManageInsulinDeliveryHistoryDataError() {
        let messages = ["Failed to process pump history event"]
        checkErrorEventProcedure({ self.pump.reportHistoryEventError() }, for: messages)
    }

    func testLoggingManageInsulinDeliveryStatusDataError() {
        let charToRead = InsulinDeliveryCharacteristicUUID.status
        let cbUUID = charToRead.cbUUID
        let procedureID = charToRead.procedureID
        pump.appendToReadRequestQueue(cbUUID: cbUUID, procedureID: procedureID, completion: pendingCompletion)
        let messages = ["\(procedureID) encountered error"]
        checkErrorEventProcedure({ self.pump.sendInsulinDeliveryStatusDataError() }, for: messages)
    }

    func testLoggingManageInsulinDeliveryStatusChangedDataError() {
        let charToRead = InsulinDeliveryCharacteristicUUID.statusChanged
        let cbUUID = charToRead.cbUUID
        let procedureID = charToRead.procedureID
        pump.appendToReadRequestQueue(cbUUID: cbUUID, procedureID: procedureID, completion: pendingCompletion)
        let messages = ["\(procedureID) encountered error"]
        checkErrorEventProcedure({ self.pump.sendInsulinDeliveryStatusChangedDataError() }, for: messages)
    }

    func testLoggingManageInsulinDeliveryAnnunciationStatusDataError() {
        let charToRead = InsulinDeliveryCharacteristicUUID.annunciationStatus
        let cbUUID = charToRead.cbUUID
        let procedureID = charToRead.procedureID
        pump.appendToReadRequestQueue(cbUUID: cbUUID, procedureID: procedureID, completion: pendingCompletion)
        let messages = ["\(procedureID) encountered error"]
        checkErrorEventProcedure({ self.pump.sendInsulinDeliveryAnnunciationStatusDataError() }, for: messages)
    }

    func testLoggingDidEncounterE2ECounterError() {
        var messages = ["Encountered E2E counter error"]
        checkErrorEventProcedure({ self.pump.didEncounterE2ECounterError() }, for: messages)
        errorEventException = nil
        connectionEvents = []
        messages = ["Triggering reconnect to resolve counter error", "disconnect"]
        checkConnectionEventProcedure({ self.pump.didEncounterE2ECounterError() }, for: messages)
    }

    func testLoggingDidEncounterSegmentCounterError() {
        var messages = ["Encountered segment counter error"]
        checkErrorEventProcedure({ self.pump.didEncounterSegmentCounterError() }, for: messages)
        errorEventException = nil
        connectionEvents = []
        messages = ["Triggering reconnect to resolve counter error", "disconnect"]
        checkConnectionEventProcedure({ self.pump.didEncounterSegmentCounterError() }, for: messages)
    }

    func testLoggingSetTempBasalResponse() {
        let requestOpcode = IDControlPointOpcode.setTempBasalAdjustment
        let messages = ["\(requestOpcode.procedureID) was successful"]
        pump.idControlPoint.appendToRequestQueue(Data(requestOpcode.rawValue), completion: pendingCompletion)
        checkReceiveEventProcedure({ self.pump.respondToTempBasalAdjustmentWithSuccess() }, for: messages)
    }

    func testLoggingSetBolusResponse() {
        let requestOpcode = IDControlPointOpcode.setBolus
        let messages = ["\(requestOpcode.procedureID) was successful"]
        pump.idControlPoint.appendToRequestQueue(Data(requestOpcode.rawValue), completion: pendingCompletion)
        checkReceiveEventProcedure({ self.pump.respondToSetBolusWithSuccess(bolusID: 1) }, for: messages)
    }

    func testLoggingStopPrimingResponse() {
        let requestOpcode = IDControlPointOpcode.stopPriming
        let messages = ["\(requestOpcode.procedureID) was successful"]
        pump.idControlPoint.appendToRequestQueue(Data(requestOpcode.rawValue), completion: pendingCompletion)
        checkReceiveEventProcedure({ self.pump.respondToStopPriming() }, for: messages)
    }

    func testLoggingStartPrimingResponse() {
        let requestOpcode = IDControlPointOpcode.startPriming
        let messages = ["\(requestOpcode.procedureID) was successful"]
        pump.idControlPoint.appendToRequestQueue(Data(requestOpcode.rawValue), completion: pendingCompletion)
        checkReceiveEventProcedure({ self.pump.respondToStartPriming() }, for: messages)
    }

    func testLoggingPrepareForInsulinDeliveryResponse() {
        let requestOpcode = IDControlPointOpcode.activateProfileTemplates
        let messages = ["\(requestOpcode.procedureID) was successful"]
        pump.idControlPoint.appendToRequestQueue(Data(requestOpcode.rawValue), completion: pendingCompletion)
        checkReceiveEventProcedure({ self.pump.respondToActivateProfileTemplate() }, for: messages)
    }

    func testLoggingSetTherapyControlStateResponse() {
        let requestOpcode = IDControlPointOpcode.setTherapyControlState
        let messages = ["\(requestOpcode.procedureID) was successful"]
        pump.idControlPoint.appendToRequestQueue(Data(requestOpcode.rawValue), completion: pendingCompletion)
        checkReceiveEventProcedure({ self.pump.respondToSetTherapyControlState() }, for: messages)
    }

    func testLoggingManageInsulinDeliveryStatusDataResponse() {
        let charToRead = InsulinDeliveryCharacteristicUUID.status
        let cbUUID = charToRead.cbUUID
        let procedureID = charToRead.procedureID
        pump.appendToReadRequestQueue(cbUUID: cbUUID, procedureID: procedureID, completion: pendingCompletion)
        let messages = ["manageInsulinDeliveryStatusData", "\(procedureID) was successful"]
        checkReceiveEventProcedure({ self.pump.sendInsulinDeliveryStatusData() }, for: messages)
    }

    func testLoggingManageInsulinDeliveryStatusChangedDataResponse() {
        let charToRead = InsulinDeliveryCharacteristicUUID.statusChanged
        let cbUUID = charToRead.cbUUID
        let procedureID = charToRead.procedureID
        pump.appendToReadRequestQueue(cbUUID: cbUUID, procedureID: procedureID, completion: pendingCompletion)
        let messages = ["manageInsulinDeliveryStatusChangedData", "Received insulin delivery status changed", "\(procedureID) was successful"]
        checkReceiveEventProcedure({ self.pump.sendInsulinDeliveryStatusChangedData() }, for: messages)
    }

    func testLoggingmanageInsulinDeliveryAnnunciationStatusDataResponseNoAnnunciations() {
        let charToRead = InsulinDeliveryCharacteristicUUID.annunciationStatus
        let cbUUID = charToRead.cbUUID
        let procedureID = charToRead.procedureID
        pump.appendToReadRequestQueue(cbUUID: cbUUID, procedureID: procedureID, completion: pendingCompletion)
        let messages = ["manageInsulinDeliveryAnnunciationStatusData", "No current annunciation", "\(procedureID) was successful"]
        checkReceiveEventProcedure({ self.pump.sendInsulinDeliveryAnnunciationStatusDataNoAnnunciations() }, for: messages)
    }

    func testLoggingmanageInsulinDeliveryAnnunciationStatusDataResponse() {
        let charToRead = InsulinDeliveryCharacteristicUUID.annunciationStatus
        let cbUUID = charToRead.cbUUID
        let procedureID = charToRead.procedureID
        pump.appendToReadRequestQueue(cbUUID: cbUUID, procedureID: procedureID, completion: pendingCompletion)
        let messages = ["manageInsulinDeliveryAnnunciationStatusData", "Annunciation of type", "\(procedureID) was successful"]
        checkReceiveEventProcedure({ self.pump.sendInsulinDeliveryAnnunciationStatusData() }, for: messages)
    }
}

extension DeviceCommLogTests {
    func checkConnectionEventProcedure(_ procedure: (() -> Void)? = nil, for messages: [String]) {
        connectionEventException = expectation(description: #function)
        connectionEventException?.expectedFulfillmentCount = messages.count
        connectionEventException?.assertForOverFulfill = false
        procedure?()
        wait(for: [connectionEventException!], timeout: 1)
        for message in messages {
            XCTAssertTrue(connectionEvents.contains(where: { $0.contains(message) }))
        }
    }

    func checkSendEventProcedure(_ procedure: (() -> Void)? = nil, for messages: [String]) {
        sendEventException = expectation(description: #function)
        sendEventException?.expectedFulfillmentCount = messages.count
        sendEventException?.assertForOverFulfill = false
        procedure?()
        wait(for: [sendEventException!], timeout: 1)
        for message in messages {
            XCTAssertTrue(sendEvents.contains(where: { $0.contains(message) }))
        }
    }

    func checkErrorEventProcedure(_ procedure: (() -> Void)? = nil, for messages: [String]) {
        errorEventException = expectation(description: #function)
        errorEventException?.expectedFulfillmentCount = messages.count
        errorEventException?.assertForOverFulfill = false
        procedure?()
        wait(for: [errorEventException!], timeout: 1)
        for message in messages {
            XCTAssertTrue(errorEvents.contains(where: { $0.contains(message) }))
        }
    }

    func checkReceiveEventProcedure(_ procedure: (() -> Void)? = nil, for messages: [String]) {
        receiveEventException = expectation(description: #function)
        receiveEventException?.expectedFulfillmentCount = messages.count
        receiveEventException?.assertForOverFulfill = false
        procedure?()
        wait(for: [receiveEventException!], timeout: 1)
        for message in messages {
            XCTAssertTrue(receiveEvents.contains(where: { $0.contains(message) }))
        }
    }
}

extension DeviceCommLogTests: DeviceCommLoggingDelegate {
    func logConnectionEvent(function: StaticString, _ message: String) {
        connectionEvents.append("\(function) \(message)")
        connectionEventException?.fulfill()
    }

    func logSendEvent(function: StaticString, _ message: String) {
        sendEvents.append("\(function) \(message)")
        sendEventException?.fulfill()
    }

    func logReceiveEvent(function: StaticString, _ message: String) {
        receiveEvents.append("\(function) \(message)")
        receiveEventException?.fulfill()
    }

    func logErrorEvent(function: StaticString, _ message: String) {
        errorEvents.append("\(function) \(message)")
        errorEventException?.fulfill()
    }
}
