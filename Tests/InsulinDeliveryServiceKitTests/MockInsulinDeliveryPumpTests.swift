//
//  MockInsulinDeliveryPumpTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2026-11-05.
//  Copyright © 2026 Tidepool Project. All rights reserved.
//

import XCTest
import BluetoothCommonKit
@testable import InsulinDeliveryServiceKit

/// The simulated pump's delivery behaviour as a controller sees it: therapy stop, temp basal expiry and
/// reporting, basal profile writes and the reservoir estimate.
class MockInsulinDeliveryPumpTests: XCTestCase {
    private var server: MockGATTService!
    private var queue: MockMessageQueue!
    private var pump: MockInsulinDeliveryPump!

    /// A pump that is primed, running, with a complete activated profile, so commands are accepted.
    override func setUp() {
        server = MockGATTService()
        queue = MockMessageQueue(gattServer: server)
        var status = MockInsulinDeliveryPumpStatus.withBasalProfile
        status.pumpState.deviceInformation?.pumpOperationalState = .ready
        status.pumpState.deviceInformation?.therapyControlState = .run
        status.basalRateProfileActivated = true
        pump = MockInsulinDeliveryPump(gattServer: server, messageQueue: queue, status: status)
    }

    override func tearDown() {
        pump.deliveryTimer?.invalidate()
    }

    private var historyEventTypes: [IDHistoryEventType] {
        pump.recordAccessControlPoint.storedHistoryEvents.map(\.type)
    }

    // MARK: Stop and resume

    func testStopCancelsTheActiveBolusAndTempBasal() {
        let bolusID = pump.setBolus(2, activationType: .manualBolus)
        XCTAssertTrue(pump.setTempBasal(rate: 1.5, duration: .minutes(30), deliveryContext: .aidController, now: Date(), changeTempBasal: false))
        XCTAssertTrue(pump.isBolusActive)
        XCTAssertNotNil(pump.status.tempBasal)

        XCTAssertTrue(pump.setTherapyControlState(.stop))
        XCTAssertEqual(pump.therapyState, .stop)
        XCTAssertFalse(pump.isBolusActive)
        XCTAssertNil(pump.status.tempBasal)
        XCTAssertEqual(pump.status.activeBolusDeliveryStatus.progressState, .noActiveBolus)

        // The controller can reconstruct what happened from the history alone.
        let types = historyEventTypes
        XCTAssertTrue(types.contains(.bolusDeliveredPart1), "bolus \(bolusID) should have a delivered event")
        XCTAssertTrue(types.contains(.tempBasalRateAdjustmentEnded))
        XCTAssertEqual(types.last, .therapyControlStateChanged)
    }

    func testStoppedTherapyDeliversNoBasalAndResumeDoesNotChargeTheGap() {
        XCTAssertTrue(pump.setTherapyControlState(.stop))
        let now = Date()
        // Two hours stopped, with the accounting run as a Status Reader request would run it: nothing delivered.
        pump.status.updateDelivery(until: now.addingTimeInterval(.hours(2)))
        XCTAssertEqual(pump.status.basalDelivered, 0, accuracy: 0.001)   // microseconds ran before the stop

        // Resume, then an hour of delivery: one hour at the profile rate, not three.
        XCTAssertTrue(pump.setTherapyControlState(.run))
        pump.status.updateDelivery(until: Date().addingTimeInterval(.hours(1)))
        XCTAssertEqual(pump.status.basalDelivered, 1, accuracy: 0.001)
    }

    func testStopIsAcceptedWithoutAnActivatedProfileButRunIsNot() {
        pump.status.basalRateProfileActivated = false
        XCTAssertTrue(pump.setTherapyControlState(.stop))
        XCTAssertFalse(pump.setTherapyControlState(.run))
    }

    // MARK: Temp basal

    func testTempBasalRemainingDurationCountsDown() throws {
        XCTAssertTrue(pump.setTempBasal(rate: 2, duration: .minutes(30), deliveryContext: .aidController, now: Date(), changeTempBasal: false))
        let delivery = pump.getActiveBasalDelivery()
        XCTAssertEqual(delivery.tempBasalRate, 2)
        XCTAssertEqual(delivery.tempBasalDurationProgrammed, .minutes(30))
        let remaining = try XCTUnwrap(delivery.tempBasalDurationRemaining)
        XCTAssertTrue(remaining > .minutes(29) && remaining <= .minutes(30), "remaining \(remaining)")
    }

    func testExpiredTempBasalIsRecordedAndTheScheduleResumes() {
        // Start it an hour ago so the next delivery update finds it finished.
        pump.status.setTempBasal(unitsPerHour: 2, duration: .minutes(30), at: Date().addingTimeInterval(-.hours(1)))
        let eventsBefore = historyEventTypes.count

        let delivery = pump.getActiveBasalDelivery()
        XCTAssertNil(delivery.tempBasalRate)
        XCTAssertEqual(delivery.rate, 1)   // back on the profile
        XCTAssertNil(pump.status.tempBasal)
        let added = Array(historyEventTypes.dropFirst(eventsBefore))
        XCTAssertEqual(added, [.tempBasalRateAdjustmentEnded, .deliveredBasalRateChanged])

        // A second update must not record the expiry again.
        _ = pump.getActiveBasalDelivery()
        XCTAssertEqual(historyEventTypes.count, eventsBefore + 2)
    }

    // MARK: Basal profile

    /// Priming and the profile can arrive in either order; the pump is ready once it has both.
    func testPrimedPumpBecomesReadyWhenTheProfileCompletesLater() {
        let fresh = MockInsulinDeliveryPump(gattServer: server, messageQueue: queue)   // no profile, waiting
        defer { fresh.deliveryTimer?.invalidate() }
        fresh.status.reservoirPrimed(5)
        XCTAssertEqual(fresh.operationalState, .waiting)
        fresh.updateBasalProfile(basalSegment: BasalSegment(index: 1, rate: 1, duration: .hours(12)))
        XCTAssertEqual(fresh.operationalState, .waiting)   // half a day is not a profile yet
        fresh.updateBasalProfile(basalSegment: BasalSegment(index: 2, rate: 1, duration: .hours(12)))
        XCTAssertEqual(fresh.operationalState, .ready)
    }

    /// Activation is a state change the host must hear about: before, the flag sat outside the status
    /// comparison and the HUD never learned the profile had been activated.
    func testActivatingTheProfileReportsToTheDelegate() {
        final class Spy: MockInsulinDeliveryPumpDelegate {
            var activatedSeen = false
            func mockPumpDidUpdate(_ pump: MockInsulinDeliveryPump) { activatedSeen = activatedSeen || pump.basalRateProfileActivated }
        }
        pump.status.basalRateProfileActivated = false
        let spy = Spy()
        pump.delegate = spy
        pump.activateBasalRateProfile()
        XCTAssertTrue(pump.basalRateProfileActivated)
        XCTAssertTrue(spy.activatedSeen)
    }

    func testBasalProfileBlockZeroIsIgnored() {
        pump.resetBasalProfile()
        pump.updateBasalProfile(basalSegment: BasalSegment(index: 0, rate: 1, duration: .hours(24)))
        XCTAssertTrue(pump.basalProfile.isEmpty)
        pump.updateBasalProfile(basalSegment: BasalSegment(index: 1, rate: 1, duration: .hours(24)))
        XCTAssertEqual(pump.basalProfile.count, 1)
    }

    // MARK: Response override

    /// A fast bolus request as a controller sends it: opcode, flags, type, fast amount, extended amount, duration.
    private func setBolusRequest(_ amount: Double) -> Data {
        var request = Data(IDCommandControlPointOpcode.setBolus.rawValue)
        request.append(UInt8(0))
        request.append(BolusType.fast.rawValue)
        request.append(amount.sfloat)
        request.append(0.0.sfloat)
        request.append(UInt16(0))
        return request
    }

    private var queuedCommandIndications: [Data] {
        queue.items
            .filter { $0.uuid == InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID }
            .map(\.value)
    }

    /// Response codes among the queued command indications. Successful Set Bolus and Get Max Bolus answers
    /// are value responses, not response codes, so they do not appear here.
    private var queuedCommandResponseCodes: [IDCommandControlPointResponseCode] {
        queuedCommandIndications
            .filter { $0.count >= 5 && $0[$0.startIndex...].to(UInt16.self) == IDCommandControlPointOpcode.responseCode.rawValue }
            .compactMap { IDCommandControlPointResponseCode(rawValue: $0[$0.startIndex.advanced(by: 4)]) }
    }

    func testNormalOverrideLeavesTheCommandAlone() {
        XCTAssertEqual(pump.commandControlPoint.onWrite(setBolusRequest(2)), .success)
        XCTAssertTrue(pump.isBolusActive)
        XCTAssertEqual(queuedCommandIndications.count, 1)   // the Set Bolus Response with the bolus ID
        XCTAssertTrue(queuedCommandResponseCodes.isEmpty)
    }

    func testRefuseAnswersProcedureNotApplicableWithoutExecuting() {
        pump.commandResponseOverride = .refuse
        XCTAssertEqual(pump.commandControlPoint.onWrite(setBolusRequest(2)), .success)
        XCTAssertFalse(pump.isBolusActive)
        XCTAssertEqual(queuedCommandResponseCodes, [.procedureNotApplicable])
    }

    func testFailAnswersProcedureNotCompletedWithoutExecuting() {
        pump.commandResponseOverride = .fail
        XCTAssertEqual(pump.commandControlPoint.onWrite(setBolusRequest(2)), .success)
        XCTAssertFalse(pump.isBolusActive)
        XCTAssertEqual(queuedCommandResponseCodes, [.procedureNotCompleted])
    }

    func testUncertainExecutedRunsTheCommandAndWithholdsTheAnswer() {
        pump.commandResponseOverride = .uncertainExecuted
        XCTAssertEqual(pump.commandControlPoint.onWrite(setBolusRequest(2)), .success)   // the write itself is accepted
        XCTAssertTrue(pump.isBolusActive)
        XCTAssertTrue(queuedCommandResponseCodes.isEmpty)
    }

    func testUncertainNotExecutedDropsTheCommandSilently() {
        pump.commandResponseOverride = .uncertainNotExecuted
        XCTAssertEqual(pump.commandControlPoint.onWrite(setBolusRequest(2)), .success)
        XCTAssertFalse(pump.isBolusActive)
        XCTAssertTrue(queuedCommandResponseCodes.isEmpty)
    }

    /// The override is about delivery; a template query under Refuse still gets its real answer.
    func testOverrideLeavesNonDeliveryProceduresAlone() {
        pump.commandResponseOverride = .refuse
        XCTAssertEqual(pump.commandControlPoint.onWrite(Data(IDCommandControlPointOpcode.getMaxBolusAmount.rawValue)), .success)
        XCTAssertEqual(queuedCommandIndications.count, 1)   // answered with the value, not refused
        XCTAssertTrue(queuedCommandResponseCodes.isEmpty)
    }

    // MARK: Command receipt after reconnection

    private var lastRecordNumber: RecordNumber {
        pump.recordAccessControlPoint.storedHistoryEvents.last?.recordNumber ?? 0
    }

    /// The link drops and comes back: indications still queued for the old link are lost with it, and the
    /// controller subscribes again to what it needs to catch up.
    private func reconnect() {
        queue.emptyQueue()
        server.subscribed = [
            InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID,
            InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID,
            InsulinDeliveryCharacteristicUUID.historyData.cbUUID
        ]
    }

    /// Get Active Bolus IDs as a controller asks it, decoded from the indicated response.
    private func activeBolusIDsReportedByTheStatusReader() -> [BolusID] {
        XCTAssertEqual(pump.statusReaderControlPoint.onWrite(Data(IDStatusReaderOpcode.getActiveBolusIDs.rawValue)), .success)
        guard let response = queue.items.last(where: { $0.uuid == InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID })?.value,
              response.count >= 3,
              response[response.startIndex...].to(UInt16.self) == IDStatusReaderOpcode.getActiveBolusIDsResponse.rawValue
        else {
            XCTFail("no Get Active Bolus IDs response")
            return []
        }
        let count = Int(response[response.startIndex.advanced(by: 2)])
        return (0..<count).map { response[response.startIndex.advanced(by: 3 + $0 * 2)...].to(BolusID.self) }
    }

    /// Report Stored Records for everything after the last record the controller saw, as it would catch up
    /// on history once the link is back; returns the types of the events the pump indicates.
    private func historyEventTypes(after recordNumber: RecordNumber) -> [IDHistoryEventType] {
        var request = Data(IDRACPOpcode.reportStoredRecords.rawValue)
        request.append(IDRACPOperator.greaterThanOrEqualTo.rawValue)
        request.append(IDRACPFilterType.recordNumber.rawValue)
        request.append(recordNumber + 1)
        XCTAssertEqual(pump.recordAccessControlPoint.onWrite(request), .success)
        return queue.items
            .filter { $0.uuid == InsulinDeliveryCharacteristicUUID.historyData.cbUUID }
            .map { IDHistoryEventType(rawValue: $0.value[$0.value.startIndex...].to(UInt16.self)) }
    }

    /// A controller that got no answer reconnects and asks the pump what happened: the Status Reader and
    /// the history both show the bolus landed.
    func testUncertainExecutedBolusIsVisibleAfterReconnection() {
        let lastRecordSeen = lastRecordNumber
        pump.commandResponseOverride = .uncertainExecuted
        XCTAssertEqual(pump.commandControlPoint.onWrite(setBolusRequest(2)), .success)
        XCTAssertTrue(queuedCommandIndications.isEmpty)   // nothing came back before the link dropped

        reconnect()
        XCTAssertEqual(activeBolusIDsReportedByTheStatusReader().count, 1)
        XCTAssertEqual(historyEventTypes(after: lastRecordSeen), [.bolusProgrammedPart1, .bolusProgrammedPart2])
    }

    /// The same silence, but the pump never ran the command: both queries come back empty, so the controller
    /// can safely send it again.
    func testUncertainNotExecutedBolusLeavesNoTraceAfterReconnection() {
        let lastRecordSeen = lastRecordNumber
        pump.commandResponseOverride = .uncertainNotExecuted
        XCTAssertEqual(pump.commandControlPoint.onWrite(setBolusRequest(2)), .success)
        XCTAssertTrue(queuedCommandIndications.isEmpty)

        reconnect()
        XCTAssertTrue(activeBolusIDsReportedByTheStatusReader().isEmpty)
        XCTAssertTrue(historyEventTypes(after: lastRecordSeen).isEmpty)
    }

    // MARK: RACP busy rule

    private func racpRequest(_ opcode: IDRACPOpcode, operator racpOperator: IDRACPOperator) -> Data {
        var request = Data(opcode.rawValue)
        request.append(racpOperator.rawValue)
        return request
    }

    /// A Status Changed indication waiting in the queue used to make the RACP refuse every query.
    func testPendingIndicationsForOtherCharacteristicsDoNotBlockAHistoryQuery() {
        queue.emptyQueue()
        queue.addQueueItem(UUIDValuePair(uuid: InsulinDeliveryCharacteristicUUID.statusChanged.cbUUID, value: Data([0, 0])))
        XCTAssertEqual(pump.recordAccessControlPoint.onWrite(racpRequest(.reportNumberOfStoredRecords, operator: .allRecords)), .success)
    }

    func testAReportStillBeingIndicatedBlocksTheNextQueryUntilAborted() {
        queue.emptyQueue()
        server.subscribed.insert(InsulinDeliveryCharacteristicUUID.historyData.cbUUID)
        XCTAssertEqual(pump.recordAccessControlPoint.onWrite(racpRequest(.reportStoredRecords, operator: .allRecords)), .success)
        XCTAssertTrue(queue.items.contains { $0.uuid == InsulinDeliveryCharacteristicUUID.historyData.cbUUID })

        XCTAssertEqual(pump.recordAccessControlPoint.onWrite(racpRequest(.reportNumberOfStoredRecords, operator: .allRecords)), .procedureAlreadyInProgress)
        XCTAssertEqual(pump.recordAccessControlPoint.onWrite(racpRequest(.abortOperation, operator: .nullOperator)), .success)

        queue.emptyQueue()   // the indications have gone out
        XCTAssertEqual(pump.recordAccessControlPoint.onWrite(racpRequest(.reportNumberOfStoredRecords, operator: .allRecords)), .success)
    }

    // MARK: Event log

    private var storedEvents: [PumpHistoryEvent] { pump.recordAccessControlPoint.storedHistoryEvents }

    private func eventTypes(after count: Int) -> [IDHistoryEventType] {
        Array(historyEventTypes.dropFirst(count))
    }

    /// A bolus that reaches its programmed amount is recorded as delivered, with that reason, by whichever
    /// accounting pass notices; before, only a cancelled bolus ever got a Bolus Delivered event.
    func testBolusThatRunsToCompletionIsRecordedAsDelivered() throws {
        let bolus = pump.status.setBolus(1, at: Date().addingTimeInterval(-.minutes(5)))   // long done at 2.5 U/min
        let eventsBefore = storedEvents.count

        pump.runDeliveryAccounting()

        XCTAssertEqual(eventTypes(after: eventsBefore), [.bolusDeliveredPart1, .bolusDeliveredPart2])
        let part1 = try XCTUnwrap(storedEvents[eventsBefore] as? BolusDeliveredPart1HistoryEvent)
        XCTAssertEqual(part1.bolusID, bolus.id)
        XCTAssertEqual(part1.fastAmount, 1)
        let part2 = try XCTUnwrap(storedEvents[eventsBefore + 1] as? BolusDeliveredPart2HistoryEvent)
        XCTAssertEqual(part2.endReason, .programmedAmountDelivered)
        XCTAssertFalse(pump.isBolusActive)
    }

    func testPrimeThatRunsToCompletionIsRecorded() throws {
        let fresh = MockInsulinDeliveryPump(gattServer: server, messageQueue: queue)   // no profile, so it ends waiting
        defer { fresh.deliveryTimer?.invalidate() }
        fresh.status.startPriming(2, at: Date().addingTimeInterval(-.minutes(5)))
        let eventsBefore = fresh.recordAccessControlPoint.storedHistoryEvents.count

        fresh.runDeliveryAccounting()

        let added = Array(fresh.recordAccessControlPoint.storedHistoryEvents.dropFirst(eventsBefore))
        XCTAssertEqual(added.map(\.type), [.primingDone, .operationalStateChanged])
        let done = try XCTUnwrap(added.first as? PrimingDoneHistoryEvent)
        XCTAssertEqual(done.deliveredAmount, 2)
        XCTAssertEqual(done.terminationReason, .programmedAmountReached)
        let state = try XCTUnwrap(added.last as? OperationalStateChangedHistoryEvent)
        XCTAssertEqual(state.oldState, .priming)
        XCTAssertEqual(state.newState, .waiting)
    }

    func testStartingAPrimeRecordsTheOperationalStateChange() {
        XCTAssertTrue(pump.setTherapyControlState(.stop))
        let eventsBefore = storedEvents.count
        XCTAssertTrue(pump.startPriming(1))
        XCTAssertEqual(eventTypes(after: eventsBefore), [.primingStarted, .operationalStateChanged])
    }

    func testAnnunciationIsRecordedInBothParts() {
        let eventsBefore = storedEvents.count
        pump.issueGeneralAnnunciation(annunciationType: .tempBasalCanceled)
        XCTAssertEqual(eventTypes(after: eventsBefore), [.annunciationStatusChangedPart1, .annunciationStatusChangedPart2])
    }

    func testMaxBolusChangeRecordsTheOldAndNewAmounts() throws {
        let old = pump.maxBolusAmount
        pump.setMaxBolusAmount(old + 5)
        let event = try XCTUnwrap(storedEvents.last as? MaxBolusAmountChangedHistoryEvent)
        XCTAssertEqual(event.oldAmount, old)
        XCTAssertEqual(event.newAmount, old + 5)
    }

    func testReservoirEventsOnFillAndOnReachingTheWarningLevel() throws {
        pump.updateInitialReservoirFillLevel(50)
        var event = try XCTUnwrap(storedEvents.last as? ReservoirRemainingAmountChangedHistoryEvent)
        XCTAssertEqual(event.remainingAmount, 50)

        // A finished bolus takes the level below the warning threshold (25 U by default) on the next pass.
        pump.updateInitialReservoirFillLevel(27)
        _ = pump.status.setBolus(3, at: Date().addingTimeInterval(-.minutes(5)))
        let eventsBefore = storedEvents.count
        pump.runDeliveryAccounting()
        XCTAssertEqual(eventTypes(after: eventsBefore), [.bolusDeliveredPart1, .bolusDeliveredPart2, .reservoirRemainingAmountChanged])
        event = try XCTUnwrap(storedEvents.last as? ReservoirRemainingAmountChangedHistoryEvent)
        XCTAssertEqual(event.remainingAmount, 24, accuracy: 0.2)   // a sliver of basal has accrued, and SFLOAT keeps one decimal

        // Staying below it is not a change.
        pump.runDeliveryAccounting()
        XCTAssertEqual(storedEvents.count, eventsBefore + 3)
    }

    func testChangingARunningTempBasalIsRecordedAsAChange() throws {
        XCTAssertTrue(pump.setTempBasal(rate: 1.5, duration: .minutes(30), deliveryContext: .aidController, now: Date(), changeTempBasal: false))
        let eventsBefore = storedEvents.count
        XCTAssertTrue(pump.setTempBasal(rate: 2, duration: .minutes(60), deliveryContext: .aidController, now: Date(), changeTempBasal: true))
        XCTAssertEqual(eventTypes(after: eventsBefore), [.tempBasalRateAdjustmentChanged, .deliveredBasalRateChanged])
        let change = try XCTUnwrap(storedEvents[eventsBefore] as? TempBasalAdjustmentChangedHistoryEvent)
        XCTAssertEqual(change.rate, 2)
    }

    /// A controller setting the time leaves a Reference Time event with the new time, and the history is
    /// re-anchored there so later offsets count from the change.
    func testProposedTimeUpdateRecordsAReferenceTime() throws {
        let newTime = Date(timeIntervalSince1970: 1_800_000_000)   // whole seconds; the event has no fractions
        let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: -5 * 3600))
        var request = Data(DTControlPointOpcode.proposeTimeUpdate.rawValue)
        request.append(TimeUpdateFlags([.utcAligned, .epochYear2000]).rawValue)
        request.append(newTime.baseTimeInSecondsFromEpoch2000)
        request.append(timeZone.gattTimeZoneOffset(for: newTime))
        request.append(DSTOffset.standardTime.rawValue)
        request.append(BluetoothCommonKit.TimeSource.manual.rawValue)
        request.append(UInt8(255))

        XCTAssertNotNil(pump.respondToDeviceTimeControlPoint(request))

        let event = try XCTUnwrap(storedEvents.last as? ReferenceTimeHistoryEvent)
        XCTAssertEqual(event.recordingReason, .setDateTime)
        XCTAssertEqual(event.date(using: timeZone), newTime)
        XCTAssertEqual(event.timeZone?.secondsFromGMT(), -5 * 3600)
        XCTAssertEqual(pump.recordAccessControlPoint.referenceTime.timeIntervalSinceNow, 0, accuracy: 1)
    }

    func testOtherDeviceTimeRequestsRecordNothing() {
        let eventsBefore = storedEvents.count
        _ = pump.respondToDeviceTimeControlPoint(Data(DTControlPointOpcode.retrieveActiveTimeAdjustments.rawValue))
        XCTAssertEqual(storedEvents.count, eventsBefore)
    }

    /// The event used to be written without its flags byte, so a reader took the old rate for the flags.
    func testDeliveredBasalRateChangedEventRoundTrips() {
        let eventData = DeliveredBasalRateChangedHistoryEvent.createEventData(oldRate: 1, newRate: 2.5)
        let event = DeliveredBasalRateChangedHistoryEvent(recordNumber: 1, relativeOffset: 0, eventData: eventData)
        XCTAssertEqual(event.oldRate, 1)
        XCTAssertEqual(event.newRate, 2.5)
    }

    // MARK: Reservoir

    /// The reservoir level a Status payload carries: therapy state, operational state, then the SFLOAT.
    private func reservoirLevel(in status: Data) -> Double {
        Data(status[status.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }

    /// A tester can make one Status report an impossible level; the next one is honest again.
    func testReservoirLevelOverrideIsReportedOnce() {
        server.subscribed.insert(InsulinDeliveryCharacteristicUUID.status.cbUUID)
        pump.reportReservoirLevelOnce(-1)

        let indicated = queue.items.last { $0.uuid == InsulinDeliveryCharacteristicUUID.status.cbUUID }
        XCTAssertEqual(indicated.map { reservoirLevel(in: $0.value) }, -1)
        XCTAssertNil(pump.pendingReservoirLevelOverride)
        XCTAssertEqual(reservoirLevel(in: pump.statusCharacteristic.createData()), pump.reservoirRemaining, accuracy: 0.1)
    }

    func testReservoirLevelOverrideWaitsForAReadWhenNobodyIsSubscribed() {
        pump.reportReservoirLevelOnce(999)
        XCTAssertEqual(pump.pendingReservoirLevelOverride, 999)   // the indication was dropped, the value is kept
        XCTAssertEqual(reservoirLevel(in: pump.statusCharacteristic.createData()), 999)
        XCTAssertNil(pump.pendingReservoirLevelOverride)
    }

    /// The pump's own timer indicates Status whenever the reservoir moves; with nobody subscribed that must not
    /// spend the tester's value, or the controller's next read would get the real level after all.
    func testTimerDrivenStatusIndicationWithoutASubscriberLeavesTheOverrideAlone() {
        pump.pendingReservoirLevelOverride = -1
        pump.statusCharacteristic.triggerIndication()
        XCTAssertEqual(pump.pendingReservoirLevelOverride, -1)
        XCTAssertTrue(queue.items.isEmpty)
    }

    func testReservoirFillLevelKeepsItsFraction() {
        pump.updateInitialReservoirFillLevel(180.4)
        XCTAssertEqual(pump.status.initialReservoirLevel, 180.4)
        XCTAssertEqual(pump.reservoirRemaining, 180.4)
    }
}
