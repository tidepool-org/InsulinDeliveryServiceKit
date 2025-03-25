//
//  MockIDPumpStatusTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-24.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

class MockIDPumpStatusTests: XCTestCase {

    func testInitialization() {
        let mockPumpStatus = MockIDPumpStatus()
        XCTAssertEqual(mockPumpStatus.pumpState, IDPumpState())
        XCTAssertEqual(mockPumpStatus.basalDelivered, 0)
        XCTAssertEqual(mockPumpStatus.bolusDelivered, 0)
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, 0)
        XCTAssertEqual(mockPumpStatus.totalPrimingInsulin, 0)
        XCTAssertEqual(mockPumpStatus.initialReservoirLevel, 200)
        XCTAssertNil(mockPumpStatus.basalSegments)
        XCTAssertNil(mockPumpStatus.basalRateScheduleStartDate)
        XCTAssertNil(mockPumpStatus.tempBasal)
    }

    func testInitializationWithoutBasalRateSchedule() {
        let deviceInformation = DeviceInformation(identifier: UUID(),
                                                  serialNumber: "12345678",
                                                  firmwareRevision: "1.0",
                                                  hardwareRevision: "1.0",
                                                  batteryLevel: 100,
                                                  therapyControlState: .stop,
                                                  pumpOperationalState: .waiting,
                                                  reservoirLevel: 200,
                                                  reportedRemainingLifetime: .days(10))
        let pumpState = IDPumpState(deviceInformation: deviceInformation)
        let mockPumpStatus = MockIDPumpStatus.withoutBasalSchedule
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.serialNumber, pumpState.deviceInformation!.serialNumber)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.firmwareRevision, pumpState.deviceInformation!.firmwareRevision)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.hardwareRevision, pumpState.deviceInformation!.hardwareRevision)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.batteryLevel, pumpState.deviceInformation!.batteryLevel)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.therapyControlState, pumpState.deviceInformation!.therapyControlState)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.pumpOperationalState, pumpState.deviceInformation!.pumpOperationalState)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel, pumpState.deviceInformation!.reservoirLevel)
        XCTAssertEqual(mockPumpStatus.basalDelivered, 0)
        XCTAssertEqual(mockPumpStatus.bolusDelivered, 0)
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, 0)
        XCTAssertEqual(mockPumpStatus.totalPrimingInsulin, 0)
        XCTAssertEqual(mockPumpStatus.initialReservoirLevel, 200)
        XCTAssertNil(mockPumpStatus.basalSegments)
        XCTAssertNil(mockPumpStatus.basalRateScheduleStartDate)
        XCTAssertNil(mockPumpStatus.tempBasal)
    }

    func testInitializationWithBasalRateSchedule() {
        let basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)]
        let mockPumpStatus = MockIDPumpStatus.withBasalSchedule
        XCTAssertEqual(mockPumpStatus.basalDelivered, 0)
        XCTAssertEqual(mockPumpStatus.bolusDelivered, 0)
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, 0)
        XCTAssertEqual(mockPumpStatus.totalPrimingInsulin, 0)
        XCTAssertEqual(mockPumpStatus.initialReservoirLevel, 200)
        XCTAssertEqual(mockPumpStatus.basalSegments, basalSegments)
        XCTAssertNotNil(mockPumpStatus.basalRateScheduleStartDate)
        XCTAssertNil(mockPumpStatus.tempBasal)
    }

    func testDidSetInitialReservoirLevel() {
        var mockPumpStatus = MockIDPumpStatus.withoutBasalSchedule
        mockPumpStatus.basalDelivered = 15
        mockPumpStatus.bolusDelivered = 10
        mockPumpStatus.totalPrimingInsulin = 2
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, 25) // priming insulin is not considered delivered
        mockPumpStatus.initialReservoirLevel = 150
        XCTAssertEqual(Double(mockPumpStatus.initialReservoirLevel), mockPumpStatus.pumpState.deviceInformation?.reservoirLevel)
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, 0)
        XCTAssertEqual(mockPumpStatus.basalDelivered, 0)
        XCTAssertEqual(mockPumpStatus.bolusDelivered, 0)
        XCTAssertEqual(mockPumpStatus.totalPrimingInsulin, 0)
    }

    func testUpdateDeliveryBasal() {
        let basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)]
        let now = Calendar.current.startOfDay(for: Date())
        let beforeNow1Day2Hours = now.addingTimeInterval(-.hours(26))
        var mockPumpStatus = MockIDPumpStatus(pumpState: IDPumpState(deviceInformation: DeviceInformation(identifier: UUID(), serialNumber: "12345678", reportedRemainingLifetime: .days(10))),
                                              basalSegments: basalSegments,
                                              basalRateScheduleStartDate: beforeNow1Day2Hours,
                                              lastDeliveryUpdate: beforeNow1Day2Hours,
                                              initialReservoirLevel: 200)
        mockPumpStatus.updateDelivery(until: now)
        XCTAssertTrue(mockPumpStatus.basalDelivered ~= 26)
        XCTAssertTrue(mockPumpStatus.totalInsulinDelivered ~= 26)
        XCTAssertTrue(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel ~= 174)
    }

    func testUpdateDeliveryTempBasal() {
        let now = Date()
        let anHour = TimeInterval.hours(1)
        let anHourAgo = now.addingTimeInterval(-anHour)
        let halfHourAgo = now.addingTimeInterval(-anHour/2)
        let rate = 8.0
        var mockPumpStatus = MockIDPumpStatus.withoutBasalSchedule
        mockPumpStatus.setTempBasal(unitsPerHour: rate, durationInMinutes: UInt16(anHour.minutes), at: anHourAgo)

        // temp basal isn't include until delivery is completed
        mockPumpStatus.updateDelivery(until: halfHourAgo)
        XCTAssertEqual(mockPumpStatus.basalDelivered, 0)
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, 0)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel, 200)

        mockPumpStatus.updateDelivery(until: now)
        XCTAssertEqual(mockPumpStatus.basalDelivered, rate)
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, rate)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel, 200-rate)
    }

    func testUpdateDeliveryBasalAndTempBasal() {
        let basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)]
        let now = Calendar.current.startOfDay(for: Date())
        let anHour = TimeInterval.hours(1)
        let halfHour = anHour/2
        let anHourAgo = now.addingTimeInterval(-anHour)
        let aDayAnd1HourAgo = now.addingTimeInterval(-.hours(25))
        var mockPumpStatus = MockIDPumpStatus(pumpState: IDPumpState(deviceInformation: DeviceInformation(identifier: UUID(), serialNumber: "12345678", reportedRemainingLifetime: .days(10))),
                                              basalSegments: basalSegments,
                                              basalRateScheduleStartDate: aDayAnd1HourAgo,
                                              lastDeliveryUpdate: aDayAnd1HourAgo,
                                              initialReservoirLevel: 200)
        let rate = 8.0
        mockPumpStatus.setTempBasal(unitsPerHour: rate, durationInMinutes: UInt16(halfHour.minutes), at: anHourAgo)

        mockPumpStatus.updateDelivery(until: now)
        XCTAssertTrue(mockPumpStatus.basalDelivered ~= 28.5) // basal = 24.5, temp basal = 4
        XCTAssertTrue(mockPumpStatus.totalInsulinDelivered ~= 28.5)
        XCTAssertTrue(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel ~= 171.5)
    }

    func testUpdateDeliveryBolus() {
        let now = Calendar.current.startOfDay(for: Date())
        let anHour = TimeInterval.hours(1)
        let anHourAgo = now.addingTimeInterval(-anHour)
        let halfHourAgo = now.addingTimeInterval(-anHour/2)
        let amount = 2.0
        var reportedBolusDeliveryStatus: BolusDeliveryStatus?
        var mockPumpStatus = MockIDPumpStatus.withoutBasalSchedule
        mockPumpStatus.setBolus(amount, at: halfHourAgo)
        mockPumpStatus.activeBolusUpdateHandler = { reportedBolusDeliveryStatus = $0 }

        mockPumpStatus.updateDelivery(until: anHourAgo)
        XCTAssertEqual(mockPumpStatus.bolusDelivered, 0)
        XCTAssertEqual(reportedBolusDeliveryStatus?.progressState, .noActiveBolus)
        XCTAssertEqual(mockPumpStatus.activeBolusDeliveryStatus.insulinProgrammed, 2)
        XCTAssertEqual(mockPumpStatus.activeBolusDeliveryStatus.insulinDelivered, 0)
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, 0)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel, 200)

        mockPumpStatus.updateDelivery(until: now)
        XCTAssertEqual(mockPumpStatus.bolusDelivered, 2)
        XCTAssertEqual(reportedBolusDeliveryStatus?.progressState, .completed)
        XCTAssertEqual(reportedBolusDeliveryStatus?.insulinProgrammed, 2)
        XCTAssertEqual(reportedBolusDeliveryStatus?.insulinDelivered, 2)
        XCTAssertEqual(mockPumpStatus.activeBolusDeliveryStatus.progressState, .noActiveBolus)
        XCTAssertEqual(mockPumpStatus.activeBolusDeliveryStatus.insulinDelivered, 0)
        XCTAssertEqual(mockPumpStatus.activeBolusDeliveryStatus.insulinDelivered, 0)
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, 2)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel, 198)
    }

    func testUpdateDeliveryBasalAndTempBasalAndBolus() {
        let basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)]
        let now = Calendar.current.startOfDay(for: Date())
        let anHour = TimeInterval.hours(1)
        let halfHour = anHour/2
        let anHourAgo = now.addingTimeInterval(-anHour)
        let fiveMinutesAgo = now.addingTimeInterval(-.minutes(5))
        let aDayAnd1HourAgo = now.addingTimeInterval(-.hours(25))
        var mockPumpStatus = MockIDPumpStatus(pumpState: IDPumpState(deviceInformation: DeviceInformation(identifier: UUID(), serialNumber: "12345678", reportedRemainingLifetime: .days(10))),
                                              basalSegments: basalSegments,
                                              basalRateScheduleStartDate: aDayAnd1HourAgo,
                                              lastDeliveryUpdate: aDayAnd1HourAgo,
                                              initialReservoirLevel: 200)
        let rate = 8.0
        mockPumpStatus.setTempBasal(unitsPerHour: rate, durationInMinutes: UInt16(halfHour.minutes), at: anHourAgo)

        let bolusAmount = 2.0
        mockPumpStatus.setBolus(bolusAmount, at: fiveMinutesAgo)

        mockPumpStatus.updateDelivery(until: now)
        XCTAssertTrue(mockPumpStatus.basalDelivered ~= 28.5) // basal = 24.5, temp basal = 4
        XCTAssertTrue(mockPumpStatus.bolusDelivered ~= 2.0)
        XCTAssertTrue(mockPumpStatus.totalInsulinDelivered ~= 30.5)
        XCTAssertTrue(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel ~= 169.5)
    }

    func testPumpPrimed() {
        var mockPumpStatus = MockIDPumpStatus.withoutBasalSchedule
        mockPumpStatus.reservoirPrimed(0.5)
        XCTAssertTrue(mockPumpStatus.totalPrimingInsulin ~= 0.5)
        XCTAssertTrue(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel ~= 199.5)
    }

    func testCannulaPrimed() {
        var mockPumpStatus = MockIDPumpStatus.withoutBasalSchedule
        mockPumpStatus.cannulaPrimed(0.3)
        XCTAssertTrue(mockPumpStatus.totalPrimingInsulin ~= 0.3)
        XCTAssertTrue(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel ~= 199.7)
    }

    func testSetAndCancelTempBasal() {
        let now = Date()
        let anHour = TimeInterval.hours(1)
        let anHourAgo = now.addingTimeInterval(-anHour)
        let halfHourAgo = now.addingTimeInterval(-anHour/2)
        let rate = 4.0
        var mockPumpStatus = MockIDPumpStatus.withoutBasalSchedule
        mockPumpStatus.setTempBasal(unitsPerHour: rate, durationInMinutes: UInt16(anHour.minutes), at: anHourAgo)
        XCTAssertEqual(mockPumpStatus.tempBasal?.units, rate)
        XCTAssertEqual(mockPumpStatus.tempBasal?.duration, anHour)
        XCTAssertEqual(mockPumpStatus.tempBasal?.startTime, anHourAgo)

        let testExpection = expectation(description: #function)
        mockPumpStatus.cancelTempBasal(at: halfHourAgo) { _ in
            testExpection.fulfill()
        }

        wait(for: [testExpection], timeout: 30)
        XCTAssertEqual(mockPumpStatus.basalDelivered, rate/2)
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, rate/2)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel, 198)
    }

    func testSetAndCancelBolus() {
        let now = Date()
        let twoMinutesAgo = now.addingTimeInterval(-.minutes(2))
        let oneMinutesAgo = now.addingTimeInterval(-.minutes(1))
        let amount = 5.0
        var mockPumpStatus = MockIDPumpStatus.withoutBasalSchedule
        mockPumpStatus.setBolus(amount, at: twoMinutesAgo)
        XCTAssertEqual(mockPumpStatus.activeBolusDeliveryStatus.progressState, .inProgress)
        XCTAssertEqual(mockPumpStatus.activeBolusDeliveryStatus.insulinProgrammed, amount)
        XCTAssertEqual(mockPumpStatus.activeBolusDeliveryStatus.insulinDelivered, 0)

        mockPumpStatus.cancelBolus(at: oneMinutesAgo, completion: { result in
            switch result {
            case .success(let bolusDeliveryStatus):
                XCTAssertEqual(bolusDeliveryStatus.progressState, .canceled)
                XCTAssertEqual(bolusDeliveryStatus.insulinProgrammed, amount)
                XCTAssertEqual(bolusDeliveryStatus.insulinDelivered, 2.5)
            case .failure(_):
                XCTAssert(false, "Canceling bolus failed")
            }
        })
        XCTAssertEqual(mockPumpStatus.activeBolusDeliveryStatus.progressState, .noActiveBolus)
    }

    func testStartInsulinDelivery() {
        let now = Date()
        var mockPumpStatus = MockIDPumpStatus.withBasalSchedule
        mockPumpStatus.startInsulinDelivery(at: now)
        XCTAssertEqual(mockPumpStatus.basalRateScheduleStartDate, now)
    }

    func testSuspendInsulinDelivery() {
        let now = Date()
        // temp basal
        let anHour = TimeInterval.hours(1)
        let anHourAgo = now.addingTimeInterval(-anHour)
        let rate = 4.0

        // bolus
        let amount = 2.0
        var reportedBolusDeliveryStatus: BolusDeliveryStatus?

        // basal schedule
        let basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)]
        let beforeNow1Day2Hours = now.addingTimeInterval(-.hours(26))

        var mockPumpStatus = MockIDPumpStatus(pumpState: IDPumpState(deviceInformation: DeviceInformation(identifier: UUID(), serialNumber: "12345678", reportedRemainingLifetime: .days(10))),
                                              basalSegments: basalSegments,
                                              basalRateScheduleStartDate: beforeNow1Day2Hours,
                                              lastDeliveryUpdate: beforeNow1Day2Hours,
                                              initialReservoirLevel: 200)
        mockPumpStatus.setTempBasal(unitsPerHour: rate, durationInMinutes: UInt16(anHour.minutes), at: anHourAgo)
        mockPumpStatus.setBolus(amount)
        mockPumpStatus.activeBolusUpdateHandler = { reportedBolusDeliveryStatus = $0 }
        mockPumpStatus.suspendInsulinDelivery(at: now)
        XCTAssertNil(mockPumpStatus.basalRateScheduleStartDate)
        XCTAssertNil(mockPumpStatus.tempBasal)
        XCTAssertEqual(mockPumpStatus.activeBolusDeliveryStatus.progressState, .noActiveBolus)
        XCTAssertEqual(reportedBolusDeliveryStatus?.progressState, .canceled)
    }

    func testUpdateReservoirRemaining() {
        let reservoirRemaining: Double = 100
        var status = MockIDPumpStatus.withoutBasalSchedule
        status.updateReservoirRemaining(100)
        XCTAssertEqual(status.pumpState.deviceInformation?.reservoirLevel, reservoirRemaining)
    }

    func testStartEstimatingBolusProgress() {
        var status = MockIDPumpStatus.withoutBasalSchedule
        status.setBolus(2)
        XCTAssertEqual(status.activeBolusDeliveryStatus.progressState, .inProgress)
        status.startEstimatingBolusProgress()
        XCTAssertEqual(status.activeBolusDeliveryStatus.progressState, .estimatingProgress)
    }

    func testIsActiveBolusDeliveryInPogress() {
        var status = MockIDPumpStatus.withoutBasalSchedule
        XCTAssertFalse(status.isActiveBolusDeliveryInProgress())
        status.setBolus(2)
        XCTAssertTrue(status.isActiveBolusDeliveryInProgress())
        status.startEstimatingBolusProgress()
        XCTAssertTrue(status.isActiveBolusDeliveryInProgress())
        XCTAssertEqual(status.activeBolusDeliveryStatus.progressState, .inProgress)
    }

    func testRawValue() {
        let now = Date()
        var status = MockIDPumpStatus()
        status.basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)]
        status.setTempBasal(unitsPerHour: 4, durationInMinutes: 30)
        status.basalRateScheduleStartDate = now
        status.setBolus(3, at: now)
        status.pumpState.activeBolusDeliveryStatus.progressState = .estimatingProgress // storing active bolus is always estimatingProgress
        let rawValue = status.rawValue

        XCTAssertEqual(rawValue["basalDelivered"] as! Double, status.basalDelivered)
        XCTAssertEqual(rawValue["basalSegments"] as? [BasalSegment], status.basalSegments)
        XCTAssertEqual(rawValue["basalRateScheduleStartDate"] as!
            Date, status.basalRateScheduleStartDate!)
        XCTAssertEqual(rawValue["bolusDelivered"] as! Double, status.bolusDelivered)
        XCTAssertEqual(rawValue["initialReservoirLevel"] as! Int, status.initialReservoirLevel)
        XCTAssertNotNil(rawValue["lastDeliveryUpdate"] as? Date)
        XCTAssertEqual(IDPumpState(rawValue: rawValue["pumpState"] as! IDPumpState.RawValue), status.pumpState)
        let tempBasal = UnfinalizedDose(rawValue: rawValue["tempBasal"] as! UnfinalizedDose.RawValue)
        XCTAssertEqual(tempBasal?.units, status.tempBasal?.units)
        XCTAssertEqual(tempBasal?.duration, status.tempBasal?.duration)
        XCTAssertEqual(rawValue["totalPrimingInsulin"] as! Double, status.totalPrimingInsulin)
    }

    func testRestoreFromRawValueValid() {
        let now = Date()
        let basalDelivered: Double = 2.4
        let basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 700), BasalSegment(index: 2, rate: 2, durationInMinutes: 740)]
        let basalRateScheduleStartDate = now
        let bolusDelivered: Double = 12.3
        let initialReservoirLevel: Int = 150
        let isAuthenticated = true
        let lastDeliveryUpdate = now
        let estimatedBolusDeliveryRate = 0.05
        let expiryWarningDuration = TimeInterval.days(1)
        let lifespan = TimeInterval.days(10)
        let reservoirLevelWarningThresholdInUnits = 25

        let totalPrimingInsulin = 1.7
        let tempBasal = UnfinalizedDose(tempBasalRate: 4.0, startTime: now, duration: .minutes(30), scheduledCertainty: .certain)
        let activeBolusDeliveryStatus: BolusDeliveryStatus = BolusDeliveryStatus(id: 1, progressState: .estimatingProgress, type: .fast, insulinProgrammed: 2.0, insulinDelivered: 0.5)
        let pumpState = IDPumpState(activeBolusDeliveryStatus: activeBolusDeliveryStatus)
        let rawValue: [String: Any] = ["basalDelivered": basalDelivered,
                                       "basalSegments": basalSegments,
                                       "basalRateScheduleStartDate": basalRateScheduleStartDate,
                                       "bolusDelivered": bolusDelivered,
                                       "initialReservoirLevel": initialReservoirLevel,
                                       "isAuthenticated": isAuthenticated,
                                       "lastDeliveryUpdate": lastDeliveryUpdate,
                                       "pumpState": pumpState.rawValue,
                                       "tempBasal": tempBasal.rawValue,
                                       "totalPrimingInsulin": totalPrimingInsulin,
                                       "estimatedBolusDeliveryRate": estimatedBolusDeliveryRate,
                                       "expiryWarningDuration": expiryWarningDuration,
                                       "lifespan" : lifespan,
                                       "reservoirLevelWarningThresholdInUnits": reservoirLevelWarningThresholdInUnits
        ]

        let status = MockIDPumpStatus.init(rawValue: rawValue)!
        XCTAssertEqual(status.basalDelivered, basalDelivered)
        XCTAssertEqual(status.basalSegments, basalSegments)
        XCTAssertEqual(status.basalRateScheduleStartDate, basalRateScheduleStartDate)
        XCTAssertEqual(status.activeBolusDeliveryStatus, activeBolusDeliveryStatus)
        XCTAssertEqual(status.bolusDelivered, bolusDelivered)
        XCTAssertEqual(status.initialReservoirLevel, initialReservoirLevel)
        XCTAssertEqual(status.pumpState, pumpState)
        XCTAssertEqual(status.tempBasal?.units, tempBasal.units)
        XCTAssertEqual(status.tempBasal?.duration, tempBasal.duration)
        XCTAssertEqual(status.totalPrimingInsulin, totalPrimingInsulin)
        XCTAssertEqual(status.estimatedBolusDeliveryRate, estimatedBolusDeliveryRate)
        XCTAssertEqual(status.expiryWarningDuration, expiryWarningDuration)
        XCTAssertEqual(status.lifespan, lifespan)
        XCTAssertEqual(status.reservoirLevelWarningThresholdInUnits, reservoirLevelWarningThresholdInUnits)
    }

    func testRestoreFromRawValueInvalid() {
        let basalDelivered: Double = 2.4
        let basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)]
        let basalRateScheduleStartDate = Date()
        let bolusDelivered: Double = 12.3
        let rawValue: [String: Any] = ["basalDelivered": basalDelivered,
                                       "basalSegments": basalSegments,
                                       "basalRateScheduleStartDate": basalRateScheduleStartDate,
                                       "bolusDelivered": bolusDelivered]
        let status = MockIDPumpStatus.init(rawValue: rawValue)
        XCTAssertNil(status)
    }

    func testEndTempBasal() {
        let now = Date()
        let anHour = TimeInterval.hours(1)
        let anHourAgo = now.addingTimeInterval(-anHour)
        let halfHour = anHour/2
        let halfHourAgo = now.addingTimeInterval(-halfHour)
        let rate = 4.0
        var mockPumpStatus = MockIDPumpStatus.withoutBasalSchedule
        mockPumpStatus.setTempBasal(unitsPerHour: rate, durationInMinutes: UInt16(anHour.minutes), at: anHourAgo)
        XCTAssertEqual(mockPumpStatus.tempBasal?.units, rate)
        XCTAssertEqual(mockPumpStatus.tempBasal?.duration, anHour)
        XCTAssertEqual(mockPumpStatus.tempBasal?.startTime, anHourAgo)

        let testExpection = expectation(description: #function)
        var receivedDuration: TimeInterval?
        mockPumpStatus.endTempBasal(at: halfHourAgo) { duration in
            receivedDuration = duration
            testExpection.fulfill()
        }

        wait(for: [testExpection], timeout: 30)
        XCTAssertEqual(mockPumpStatus.basalDelivered, rate/2)
        XCTAssertEqual(mockPumpStatus.totalInsulinDelivered, rate/2)
        XCTAssertEqual(mockPumpStatus.pumpState.deviceInformation?.reservoirLevel, 198)
        XCTAssertEqual(receivedDuration, halfHour)
    }
}
