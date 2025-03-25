//
//  MockIDPumpTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-24.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import BluetoothCommonKit
@testable import InsulinDeliveryServiceKit

class MockIDPumpTests: XCTestCase {

    private var mockPump: MockIDPump!
    private var pumpCommsExpectation: XCTestExpectation?
    private var pumpStateUpdatedExpectation: XCTestExpectation?
    private var pumpAnnunciationExpectation: XCTestExpectation?
    private var pumpHistoryExpectationInsulinSuspended: XCTestExpectation?
    private var pumpHistoryExpectationBolusProgrammed: XCTestExpectation?
    private var pumpHistoryExpectationBolusDelivered: XCTestExpectation?
    private var pumpHistoryExpectationTempBasalEnded: XCTestExpectation?

    private var updatedPumpState: IDPumpState?
    private var pumpName: String?
    private var pumpIdentifier: UUID?
    private var pumpSerialNumber: String?
    private var didCompleteAuthentication = false
    private var didCompleteConfiguration = false
    private var didCompleteTherapyUpdate = false
    private var didReceiveAnnunciation = false
    private var currentAnnunciation: Annunciation?
    private var bolusProgrammedAmount: Double?
    private var bolusDeliveredAmount: Double?
    private var tempBasalDuration: TimeInterval?
    private var suspendedAt: Date?
    internal var isInReplacementWorkflow = false
    private var pumpDidSync: Bool?
    private var pumpSyncDate: Date?
    internal var sharedKeyData: Data?
    
    override func setUp() {
        mockPump = MockIDPump(status: MockIDPumpStatus(pumpState: IDPumpState(deviceInformation: MockIDPumpStatus.deviceInformation)), schedulerDelay: 0.1)
        mockPump.delegate = self
        pumpCommsExpectation = nil
        pumpStateUpdatedExpectation = nil
        pumpAnnunciationExpectation = nil
        updatedPumpState = nil
        pumpName = nil
        pumpIdentifier = nil
        pumpSerialNumber = nil
        didCompleteAuthentication = false
        didCompleteConfiguration = false
        didCompleteTherapyUpdate = false
        didReceiveAnnunciation = false
        bolusProgrammedAmount = nil
        bolusDeliveredAmount = nil
        tempBasalDuration = nil
    }
    
    override func tearDown() {
        pumpCommsExpectation = nil
        pumpStateUpdatedExpectation = nil
        pumpAnnunciationExpectation = nil
    }

    func testInitialization() {
        let pumpStatus = MockIDPumpStatus()
        mockPump = MockIDPump(status: pumpStatus)
        XCTAssertEqual(mockPump.status, pumpStatus)
        XCTAssertEqual(mockPump.state, pumpStatus.pumpState)
        XCTAssertFalse(mockPump.isBolusActive)
        XCTAssertEqual(1.0, MockIDPump.defaultSchedulerTimeDelay)
    }

    func testDidUpdateState() {
        var updatedDeviceInformation = mockPump.deviceInformation
        updatedDeviceInformation?.updateExpirationDate(remainingLifetime: .hours(1))
        mockPump.deviceInformation = updatedDeviceInformation
        XCTAssertNotNil(updatedPumpState)
        XCTAssertEqual(updatedPumpState, mockPump.state)
    }

    func testSetOOBString() {
        let newOOBString = "1234"
        let oobData = newOOBString.data(using: .utf8)!
        mockPump.setOOBString(newOOBString)
        XCTAssertEqual(mockPump.state.securityManagerConfiguration.oobRandomNumber, oobData)
    }

    func testDeviceInformation() {
        let deviceInformation = DeviceInformation(identifier: UUID(),
                                                  serialNumber: "GW60879524",
                                                  firmwareRevision: "1.0",
                                                  hardwareRevision: "1.0",
                                                  batteryLevel: 100,
                                                  therapyControlState: .stop,
                                                  pumpOperationalState: .off,
                                                  reservoirLevel: 200,
                                                  reportedRemainingLifetime: .days(10))
        let pumpState = IDPumpState(deviceInformation: deviceInformation)

        mockPump = MockIDPump(status: MockIDPumpStatus(pumpState: pumpState))
        XCTAssertEqual(mockPump.deviceInformation, pumpState.deviceInformation)
    }

    func testPrepareForNewPump() {
        mockPump.prepareForNewPump()
        pumpCommsExpectation = expectation(description: #function)
        wait(for: [pumpCommsExpectation!], timeout: 1)

        XCTAssertNil(mockPump.deviceInformation)
        XCTAssertEqual(pumpName, "Mock Insulin Delivery Pump")
        XCTAssertEqual(pumpIdentifier, MockIDPumpStatus.identifier)
        XCTAssertEqual(pumpSerialNumber, MockIDPumpStatus.serialNumber)
    }

    func testConnectToPump() {
        mockPump.deviceInformation = nil
        mockPump.connectToPump(withIdentifier: MockIDPumpStatus.identifier, andSerialNumber: MockIDPumpStatus.serialNumber)
        pumpStateUpdatedExpectation = expectation(description: #function)
        pumpStateUpdatedExpectation?.expectedFulfillmentCount = 3
        wait(for: [pumpStateUpdatedExpectation!], timeout: 1)

        XCTAssertTrue(didCompleteAuthentication)
    }

    func testPrepareForInsulinDelivery() {
        let testExpectation = expectation(description: #function)
        let reservoirLevel: Int = 100
        let basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)]
        mockPump.prepareForInsulinDelivery(reservoirLevel: reservoirLevel, basalSegments: basalSegments) { result in
            switch result {
            case .success:
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(mockPump.state.deviceInformation?.reservoirLevel, Double(reservoirLevel))
        XCTAssertEqual(mockPump.status.initialReservoirLevel, reservoirLevel)
        XCTAssertEqual(mockPump.status.basalSegments, basalSegments)
        XCTAssertTrue(didCompleteTherapyUpdate)
    }

    func testPrimeReservoir() {
        let testExpectation = expectation(description: #function)
        var commandSuccessful = false
        mockPump.startPrimingReservoir(1) { result in
            switch result {
            case .success():
                commandSuccessful = true
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }

        wait(for: [testExpectation], timeout: 1)
        XCTAssertTrue(commandSuccessful)
        XCTAssertEqual(mockPump.deviceInformation?.pumpOperationalState, .priming)
    }

    func testPrimeCannula() {
        let testExpectation = expectation(description: #function)
        mockPump.primeCannula(0.3) { result in
            switch result {
            case .success():
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(mockPump.deviceInformation?.pumpOperationalState, .priming)

        pumpStateUpdatedExpectation = expectation(description: #function)
        pumpStateUpdatedExpectation?.expectedFulfillmentCount = 3
        wait(for: [pumpStateUpdatedExpectation!], timeout: 1)
        XCTAssertEqual(mockPump.deviceInformation?.pumpOperationalState, .ready)
    }

    func testStopPriming() {
        let testExpectation = expectation(description: #function)
        mockPump.deviceInformation?.pumpOperationalState = .priming

        mockPump.stopPriming() { result in
            switch result {
            case .success():
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(mockPump.deviceInformation?.pumpOperationalState, .ready)
    }

    func testStartInsulinDelivery() {
        let testExpectation = expectation(description: #function)
        mockPump.startInsulinDelivery() { result in
            switch result {
            case .success(_):
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(mockPump.deviceInformation?.therapyControlState, .run)
        XCTAssertNotNil(mockPump.status.basalRateScheduleStartDate)
    }

    func testSuspendInsulinDelivery() {
        mockPump.deviceInformation?.therapyControlState = .run

        let testExpectation = expectation(description: #function)
        mockPump.suspendInsulinDelivery() { result in
            switch result {
            case .success(_):
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }
        wait(for: [testExpectation], timeout: 1)

        XCTAssertEqual(mockPump.deviceInformation?.therapyControlState, .stop)
        XCTAssertNil(mockPump.status.basalRateScheduleStartDate)
    }

    func testSuspendInsulinDeliveryActiveTempBasal() {
        mockPump.deviceInformation?.therapyControlState = .run
        var testExpectation = expectation(description: #function)
        mockPump.setTempBasal(unitsPerHour: 2, durationInMinutes: 30, replaceExisting: false) { _ in
            testExpectation.fulfill()
        }
        wait(for: [testExpectation], timeout: 1)

        testExpectation = expectation(description: #function)
        var commandSuccessful = false
        mockPump.suspendInsulinDelivery() { result in
            switch result {
            case .success(_):
                commandSuccessful = true
                testExpectation.fulfill()
            case .failure(_):
                break
            }
        }
        wait(for: [testExpectation], timeout: 1)

        XCTAssertTrue(commandSuccessful)
        XCTAssertEqual(mockPump.deviceInformation?.therapyControlState, .stop)
        XCTAssertFalse(mockPump.isTempBasalActive)
    }

    func testSuspendInsulinDeliveryActiveBolus() {
        mockPump.deviceInformation?.therapyControlState = .run
        var testExpectation = expectation(description: #function)
        mockPump.setBolus(2, activationType: .recommendedBolus) { _ in
            testExpectation.fulfill()
        }
        wait(for: [testExpectation], timeout: 1)

        testExpectation = expectation(description: #function)
        var commandSuccessful = false
        mockPump.suspendInsulinDelivery() { result in
            switch result {
            case .success(_):
                commandSuccessful = true
                testExpectation.fulfill()
            case .failure(_):
                break
            }
        }
        wait(for: [testExpectation], timeout: 1)
        XCTAssertTrue(commandSuccessful)
        XCTAssertEqual(mockPump.deviceInformation?.therapyControlState, .stop)
        XCTAssertFalse(mockPump.isBolusActive)
    }

    func testResetCounters() {
        mockPump.state.idControlPointNextE2ECounter = 100
        mockPump.state.idStatusReaderNextE2ECounter = 100
        mockPump.state.recordAccessControlPointNextE2ECounter = 100
        mockPump.resetCounters()

        XCTAssertEqual(mockPump.state.idControlPointNextE2ECounter, 1)
        XCTAssertEqual(mockPump.state.idStatusReaderNextE2ECounter, 1)
        XCTAssertEqual(mockPump.state.recordAccessControlPointNextE2ECounter, 1)
    }

    func testGetBatteryLevel() {
        mockPump.getBatteryLevel()
        pumpStateUpdatedExpectation = expectation(description: #function)
        pumpStateUpdatedExpectation?.expectedFulfillmentCount = 2
        pumpStateUpdatedExpectation?.assertForOverFulfill = false
        wait(for: [pumpStateUpdatedExpectation!], timeout: 1)

        XCTAssertNotNil(updatedPumpState)
        XCTAssertEqual(updatedPumpState, mockPump.state)
    }

    func testGetBatteryLevelLow() {
        XCTAssertNotNil(mockPump.deviceInformation)
        mockPump.deviceInformation?.batteryLevel = 19
        mockPump.getBatteryLevel()
        pumpStateUpdatedExpectation = expectation(description: "state." + #function)
        pumpStateUpdatedExpectation?.expectedFulfillmentCount = 3
        pumpStateUpdatedExpectation?.assertForOverFulfill = false
        pumpAnnunciationExpectation = expectation(description: "annunciation." + #function)
        pumpAnnunciationExpectation?.assertForOverFulfill = false
        wait(for: [pumpStateUpdatedExpectation!, pumpAnnunciationExpectation!], timeout: 1)

        XCTAssertNotNil(updatedPumpState)
        XCTAssertEqual(updatedPumpState, mockPump.state)
        XCTAssertTrue(didReceiveAnnunciation)
        XCTAssertEqual(currentAnnunciation?.type, AnnunciationType.batteryLow)
    }

    func testGetBatteryLevelEmpty() {
        XCTAssertNotNil(mockPump.deviceInformation)
        mockPump.deviceInformation?.batteryLevel = 0
        mockPump.getBatteryLevel()
        pumpStateUpdatedExpectation = expectation(description: "state." + #function)
        pumpStateUpdatedExpectation?.expectedFulfillmentCount = 3
        pumpStateUpdatedExpectation?.assertForOverFulfill = false
        pumpAnnunciationExpectation = expectation(description: "annunciation." + #function)
        pumpAnnunciationExpectation?.assertForOverFulfill = false
        wait(for: [pumpStateUpdatedExpectation!, pumpAnnunciationExpectation!], timeout: 1)

        XCTAssertNotNil(updatedPumpState)
        XCTAssertEqual(updatedPumpState, mockPump.state)
        XCTAssertTrue(didReceiveAnnunciation)
        XCTAssertEqual(currentAnnunciation?.type, AnnunciationType.batteryEmpty)
    }

    func testSetBasalRateSchedule() {
        let testExpectation = expectation(description: #function)
        let basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)]
        mockPump.setBasalRateSchedule(basalSegments) { result in
            switch result {
            case .success():
                testExpectation.fulfill()
            case .failure(_):
                break
            }
        }

        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(mockPump.status.basalSegments, basalSegments)
    }

    func testUpdateStatus() {
        XCTAssertNil(pumpSyncDate)
        mockPump.updateStatus { result in
            switch result {
            case .success(let pumpStatus):
                XCTAssertEqual(pumpStatus?.pumpOperationalState, self.mockPump.deviceInformation?.pumpOperationalState)
                XCTAssertEqual(pumpStatus?.therapyControlState, self.mockPump.deviceInformation?.therapyControlState)
                XCTAssertEqual(pumpStatus?.reservoirLevel, self.mockPump.deviceInformation?.reservoirLevel)
                XCTAssertEqual(pumpStatus?.reservoirLevel, self.mockPump.deviceInformation?.reservoirLevel)
                XCTAssertNotNil(self.pumpSyncDate)
            default:
                XCTAssert(false, "update status failed")
            }
        }
    }

    func testSetTempBasal() {
        let unitsPerHour = 2.0
        let durationInMins: UInt16 = 30
        let duration: TimeInterval = .minutes(30)
        let startTime = Date().addingTimeInterval(-duration)
        let expectedTempBasal = UnfinalizedDose(tempBasalRate: unitsPerHour,
                                                startTime: startTime,
                                                duration: duration,
                                                scheduledCertainty: .certain)
        mockPump.setTempBasal(unitsPerHour: unitsPerHour, durationInMinutes: durationInMins, replaceExisting: true) { result in
            switch result {
            case .success():
                XCTAssertEqual(self.mockPump.status.tempBasal?.duration, expectedTempBasal.duration)
                XCTAssertEqual(self.mockPump.status.tempBasal?.units, expectedTempBasal.units)
            case .failure(_):
                XCTAssert(false, "setting temp basal failed")
            }
        }
    }

    func testCancelTempBasal() {
        let unitsPerHour = 2.0
        let duration: UInt16 = 30
        let testExpectation = expectation(description: #function)
        mockPump.setTempBasal(unitsPerHour: unitsPerHour, durationInMinutes: duration, replaceExisting: true) { result in
            switch result {
            case .success():
                self.mockPump.cancelTempBasal() { result in
                    switch result {
                    case .success():
                        testExpectation.fulfill()
                    case .failure(_):
                        XCTAssert(false, "cancelling temp basal failed")
                    }
                }
            case .failure(_):
                XCTAssert(false, "setting temp basal failed")
            }
        }

        wait(for: [testExpectation], timeout: 1)
        XCTAssertNil(self.mockPump.status.tempBasal)

        pumpAnnunciationExpectation = expectation(description: #function)
        wait(for: [pumpAnnunciationExpectation!], timeout: 1)
        XCTAssertTrue(didReceiveAnnunciation)
        XCTAssertEqual(currentAnnunciation?.type, AnnunciationType.tempBasalCanceled)
    }

    func testSetBolus() {
        XCTAssertEqual(mockPump.status.activeBolusDeliveryStatus.progressState, .noActiveBolus)
        XCTAssertNil(mockPump.status.activeBolusDeliveryStatus.id)
        let amount = 2.0
        mockPump.setBolus(amount, activationType: .recommendedBolus) { result in
            switch result {
            case .success(let bolusDeliveryStatus):
                XCTAssertNotNil(bolusDeliveryStatus.id)
                XCTAssertEqual(bolusDeliveryStatus.progressState, .inProgress)
                XCTAssertEqual(bolusDeliveryStatus.insulinProgrammed, amount)
                XCTAssertEqual(bolusDeliveryStatus.insulinDelivered, 0)
                XCTAssertNotNil(self.mockPump.status.activeBolusDeliveryStatus.id)
                XCTAssertEqual(self.mockPump.status.activeBolusDeliveryStatus.progressState, .inProgress)
                XCTAssertEqual(self.mockPump.status.activeBolusDeliveryStatus.insulinProgrammed, amount)
                XCTAssertEqual(self.mockPump.status.activeBolusDeliveryStatus.insulinDelivered, 0)
            case .failure(_):
                XCTAssert(false, "setting bolus failed")
            }
        }
    }

    func testCancelBolus() {
        let amount = 2.0
        let testExpectation = expectation(description: #function)
        var receivedBolusID: BolusID?
        var receivedBolusDeliveryStatus: BolusDeliveryStatus?
        mockPump.setBolus(amount, activationType: .recommendedBolus, completion: { result in
            switch result {
            case .success(let bolusDeliveryStatus):
                receivedBolusID = bolusDeliveryStatus.id
                self.mockPump.cancelBolus() { result in
                    switch result {
                    case .success(let bolusDeliveryStatus):
                        receivedBolusDeliveryStatus = bolusDeliveryStatus
                        testExpectation.fulfill()
                    case .failure(_):
                        XCTAssert(false, "canceling bolus failed")
                    }
                }
            case .failure(_):
                XCTAssert(false, "setting bolus failed")
            }
        })

        wait(for: [testExpectation], timeout: 1)
        XCTAssertNotNil(receivedBolusID)
        XCTAssertNotNil(receivedBolusDeliveryStatus)
        XCTAssertEqual(receivedBolusDeliveryStatus?.id, receivedBolusID)
        XCTAssertEqual(receivedBolusDeliveryStatus?.progressState, .canceled)
        XCTAssertEqual(receivedBolusDeliveryStatus?.insulinProgrammed, amount)
        XCTAssertTrue(receivedBolusDeliveryStatus!.insulinDelivered < mockPump.delegate!.pulseSize) // impossible for this to be 0, but should be close to 0 since the delivery time is so short.

        pumpAnnunciationExpectation = expectation(description: #function)
        wait(for: [pumpAnnunciationExpectation!], timeout: 1)
        XCTAssertTrue(didReceiveAnnunciation)
        XCTAssertEqual(currentAnnunciation?.type, AnnunciationType.bolusCanceled)
    }

    func testTrackActiveBolusDelivery() {
        let testExpectation = XCTestExpectation(description: #function)
        let amount = 2.0
        mockPump.setBolus(amount, activationType: .recommendedBolus) { result in
            switch result {
            case .success(_):
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline:  .now() + 0.2) {
                    self.mockPump?.updateActiveBolusDeliveryDetails() { bolusDeliveryStatus in
                        XCTAssertEqual(bolusDeliveryStatus.progressState, .inProgress)
                        XCTAssertEqual(bolusDeliveryStatus.insulinProgrammed, amount)
                        XCTAssertNotEqual(bolusDeliveryStatus.insulinDelivered, 0)
                        testExpectation.fulfill()
                    }
                }
            case .failure(_):
                XCTAssert(false, "setting bolus failed")
            }
        }
        wait(for: [testExpectation], timeout: 3)
    }

    func testTriggerExpiryWarningAnnunciation() {
        mockPump.deviceInformation?.updateExpirationDate(remainingLifetime: .days(4))

        pumpAnnunciationExpectation = expectation(description: #function)
        mockPump.status.expiryWarningDuration = .days(5)
        
        wait(for: [pumpAnnunciationExpectation!], timeout: 1)
        XCTAssertTrue(didReceiveAnnunciation)
        XCTAssertEqual(currentAnnunciation?.type, AnnunciationType.endOfLifetime)
    }

    func testErrorOnNextCommsTimeout() {
        mockPump.errorOnNextComms = .connectionTimeout
        let testExpectation = expectation(description: #function)
        var receivedError: DeviceCommError?
        mockPump.setBolus(2.0, activationType: .recommendedBolus) { result in
            switch result {
            case .failure(let error):
                receivedError = error
                testExpectation.fulfill()
            case .success(_):
                XCTAssert(false)
            }
        }
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(receivedError, .connectionTimeout)
    }

    func testErrorOnNextCommsProcedureNotApplicable() {
        mockPump.errorOnNextComms = .procedureNotApplicable
        let testExpectation = expectation(description: #function)
        var receivedError: DeviceCommError?
        mockPump.setBolus(2.0, activationType: .recommendedBolus) { result in
            switch result {
            case .failure(let error):
                receivedError = error
                testExpectation.fulfill()
            case .success(_):
                XCTAssert(false)
            }
        }
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(receivedError, .procedureNotApplicable)
    }

    func testDisconnectComms() {
        mockPump.isConnected = false
        let testExpectation = expectation(description: #function)
        var receivedError: DeviceCommError?
        mockPump.setBolus(2.0, activationType: .recommendedBolus) { result in
            switch result {
            case .failure(let error):
                receivedError = error
                testExpectation.fulfill()
            case .success(_):
                XCTAssert(false)
            }
        }
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(receivedError, .disconnected)
    }

    func testUpdateReservoirRemaining() {
        let reservoirRemaining: Double = 10
        XCTAssertNotEqual(mockPump.deviceInformation?.reservoirLevel, reservoirRemaining)
        mockPump.updateReservoirRemaining(reservoirRemaining)
        XCTAssertEqual(mockPump.deviceInformation?.reservoirLevel, reservoirRemaining)
    }

    func testReservoirLowAnnunciation() {
        mockPump.status.reservoirLevelWarningThresholdInUnits = 20
        pumpAnnunciationExpectation = expectation(description: #function)
        mockPump.state.deviceInformation?.reservoirLevel = 10

        wait(for: [pumpAnnunciationExpectation!], timeout: 1)
        XCTAssertTrue(didReceiveAnnunciation)
        XCTAssertEqual(currentAnnunciation?.type, AnnunciationType.reservoirLow)
        XCTAssertEqual(["20.0"], currentAnnunciation?.annunciationMessageCauseArgs.map { String(format: "%@", $0)})
    }

    func testReservoirEmptyAnnunciation() {
        pumpAnnunciationExpectation = expectation(description: #function)
        mockPump.state.deviceInformation?.reservoirLevel = 0

        wait(for: [pumpAnnunciationExpectation!], timeout: 1)
        XCTAssertTrue(didReceiveAnnunciation)
        XCTAssertEqual(currentAnnunciation?.type, AnnunciationType.reservoirEmpty)
    }

    func testIsAuthenticated() {
        XCTAssertFalse(mockPump.isAuthenticated)
        mockPump.status.isAuthenticated = true
        XCTAssertTrue(mockPump.isAuthenticated)
    }

    func testReportingBolusDelivered() {
        let programmedAmount = 2.3
        mockPump.initiateBolus(programmedAmount)
        mockPump.updateActiveBolusDeliveryDetails(updateHandler: { _ in })

        var deliveredAmount: Double?
        let testExpectation = expectation(description: #function)
        mockPump.cancelBolus(completion: { result in
            switch result {
            case .success(let bolusDeliveryStatus):
                deliveredAmount = bolusDeliveryStatus.insulinDelivered
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        })
        wait(for: [testExpectation], timeout: 1)

        pumpHistoryExpectationBolusDelivered = expectation(description: #function)
        wait(for: [pumpHistoryExpectationBolusDelivered!], timeout: 1)
        XCTAssertEqual(bolusProgrammedAmount, programmedAmount)
        XCTAssertEqual(bolusDeliveredAmount, deliveredAmount)
    }

    func testIsTempBasalActive() {
        let testExpectation = expectation(description: #function)
        XCTAssertFalse(mockPump.isTempBasalActive)
        mockPump.setTempBasal(unitsPerHour: 2, durationInMinutes: 30, replaceExisting: false) { _ in
            testExpectation.fulfill()
        }

        wait(for: [testExpectation], timeout: 1)
        XCTAssertTrue(mockPump.isTempBasalActive)
    }

    func testReportTempBasalEnded() {
        let testExpectation = expectation(description: #function)
        mockPump.setTempBasal(unitsPerHour: 2, durationInMinutes: 30, replaceExisting: false) { _ in
            testExpectation.fulfill()
        }
        wait(for: [testExpectation], timeout: 1)

        mockPump.interruptTempBasal()
        pumpHistoryExpectationTempBasalEnded = expectation(description: #function)
        pumpHistoryExpectationTempBasalEnded?.expectedFulfillmentCount = 2
        wait(for: [pumpHistoryExpectationTempBasalEnded!], timeout: 1)
        XCTAssertNotNil(tempBasalDuration)
        XCTAssertNotEqual(tempBasalDuration, 0)
    }

    func testReportInsulinDeliverySuspended() {
        mockPump.interruptInsulinDelivery()
        pumpHistoryExpectationInsulinSuspended = expectation(description: #function)
        wait(for: [pumpHistoryExpectationInsulinSuspended!], timeout: 1)
        XCTAssertNotNil(suspendedAt)
    }

    func testPumpDidSync() {
        XCTAssertNil(pumpDidSync)
        mockPump.state.setupCompleted = true
        XCTAssertEqual(pumpDidSync, true)
    }
}

extension MockIDPumpTests: IDPumpCommDelegate {
    var pumpDiscoverableName: String { "MockPump" }
    
    var supportedBasalRates: [Double] { [1,2,3,4,5] }
    
    var supportedMaximumBasalRateAmount: Double { 5 }
    
    var supportedMaximumBasalSegmentCount: Int { 24 }
    
    var supportedMinimumBasalSegmentDuration: TimeInterval { .minutes(30) }
    
    var basalRateProfileTemplateNumber: UInt8 { 1 }
    
    var numberOfProfileTemplates: UInt8 { 1 }
    
    var supportedBolusVolumes: [Double] { [1,2,3,4,5] }
    
    var supportedMaximumBolusVolumes: [Double] { [5] }
    
    var estimatedBolusDeliveryRate: Double { 2.5 / 60 }
    
    var reservoirCapacity: Double { 100 }
    
    var reservoirAccuracyLimit: Double? { 50 }
    
    var reservoirFillSupportedVolumes: [Double] { [100] }
    
    var pulseSize: Double { 0.05 }
    
    var pulsesPerUnit: Double { 20 }
    
    var expectedLifespan: TimeInterval { .days(10) }
    
    var maxAllowedPumpClockDrift: TimeInterval { 0 }

    var basalSegments: [BasalSegment] { [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)] }
    
    var pumpTimeZone: TimeZone { .currentFixed }

    func pump(_ pump: IDPumpComms, didDiscoverPumpWithName peripheralName: String?, identifier: UUID, serialNumber: String?) {
        pumpName = peripheralName
        pumpIdentifier = identifier
        pumpSerialNumber = serialNumber
        pumpCommsExpectation?.fulfill()
    }

    func pump(_ pump: IDPumpComms, didReceiveAnnunciation annunciation: Annunciation) {
        didReceiveAnnunciation = true
        currentAnnunciation = annunciation
        pumpAnnunciationExpectation?.fulfill()
    }

    func pumpConnectionStatusChanged(_ pump: IDPumpComms) { }

    func pumpDidCompleteAuthentication(_ pump: IDPumpComms, error: DeviceCommError?) {
        didCompleteAuthentication = true
        pumpCommsExpectation?.fulfill()
    }

    func pumpDidCompleteConfiguration(_ pump: IDPumpComms) {
        didCompleteConfiguration = true
        pumpCommsExpectation?.fulfill()
    }

    func pumpDidCompleteTherapyUpdate(_ pump: IDPumpComms) {
        didCompleteTherapyUpdate = true
        pumpCommsExpectation?.fulfill()
    }

    func pumpDidUpdateState(_ pump: IDPumpComms) {
        updatedPumpState = pump.state
        pumpStateUpdatedExpectation?.fulfill()
    }

    func pumpDidInitiateBolus(_ pump: IDPumpComms, bolusID: BolusID, insulinProgrammed: Double, startTime: Date) {
        bolusProgrammedAmount = insulinProgrammed
        pumpHistoryExpectationBolusProgrammed?.fulfill()
    }

    func pumpDidDeliverBolus(_ pump: IDPumpComms, bolusID: BolusID, insulinProgrammed: Double, insulinDelivered: Double, startTime: Date, duration: TimeInterval) {
        bolusProgrammedAmount = insulinProgrammed
        bolusDeliveredAmount = insulinDelivered
        pumpHistoryExpectationBolusDelivered?.fulfill()
    }

    func pumpTempBasalStarted(_ pump: IDPumpComms, at startTime: Date, rate: Double, duration: TimeInterval) { }

    func pumpTempBasalEnded(_ pump: IDPumpComms, duration: TimeInterval) {
        tempBasalDuration = duration
        pumpHistoryExpectationTempBasalEnded?.fulfill()
    }

    func pumpDidSuspendInsulinDelivery(_ pump: IDPumpComms, suspendedAt: Date) {
        self.suspendedAt = suspendedAt
        pumpHistoryExpectationInsulinSuspended?.fulfill()
    }

    func pumpDidDetectHistoricalAnnunciation(_ pump: IDPumpComms, annunciation: Annunciation, at date: Date?) { }

    func pumpDidSync(_ pump: IDPumpComms, pendingCommandCheckCompleted: Bool, at date: Date = Date()) {
        pumpDidSync = true
        pumpSyncDate = date
    }
}
