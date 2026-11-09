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

    // MARK: Reservoir

    func testReservoirFillLevelKeepsItsFraction() {
        pump.updateInitialReservoirFillLevel(180.4)
        XCTAssertEqual(pump.status.initialReservoirLevel, 180.4)
        XCTAssertEqual(pump.reservoirRemaining, 180.4)
    }
}
