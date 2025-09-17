//
//  BolusDeliveryStatusTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-19.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

class BolusDeliveryStatusTests: XCTestCase {

    private var estimatedBolusDeliveryRate = 2.5 / TimeInterval.minutes(1)
    
    func testInitialization() {
        let bolusID: BolusID = 1
        let progressState = BolusProgressState.inProgress
        let type = BolusType.fast
        let insulinProgrammed = 2.0
        let inssulinDelivered = 1.1
        let startTime = Date()
        let endTime = Date()
        let bolusDeliveryStatus = BolusDeliveryStatus(id: bolusID,
                                                      progressState: progressState,
                                                      type: type,
                                                      insulinProgrammed: insulinProgrammed,
                                                      insulinDelivered: inssulinDelivered,
                                                      startTime: startTime,
                                                      endTime: endTime)

        XCTAssertEqual(bolusDeliveryStatus.id, bolusID)
        XCTAssertEqual(bolusDeliveryStatus.progressState, progressState)
        XCTAssertEqual(bolusDeliveryStatus.type, type)
        XCTAssertEqual(bolusDeliveryStatus.insulinProgrammed, insulinProgrammed)
        XCTAssertEqual(bolusDeliveryStatus.insulinDelivered, inssulinDelivered)
        XCTAssertEqual(bolusDeliveryStatus.startTime, startTime)
        XCTAssertEqual(bolusDeliveryStatus.endTime, endTime)
    }

    func testConvertionToUnfinalizedBolus() {
        let now = Date()
        var bolusDeliveryStatus = BolusDeliveryStatus(id: nil,
                                                      progressState: .noActiveBolus,
                                                      type: .undetermined,
                                                      insulinProgrammed: 0,
                                                      insulinDelivered: 0)
        XCTAssertNil(bolusDeliveryStatus.unfinalizedBolus(at: now, estimatedBolusDeliveryRate: estimatedBolusDeliveryRate))

        // 0 delivered
        bolusDeliveryStatus = BolusDeliveryStatus(id: nil,
                                                  progressState: .inProgress,
                                                  type: .fast,
                                                  insulinProgrammed: 1,
                                                  insulinDelivered: 0,
                                                  startTime: now)
        var expectedUnfinalizedBolus = UnfinalizedDose(decisionId: nil, bolusAmount: 1, startTime: now, scheduledCertainty: .certain, estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)
        var actualUnfinalizedBolus = bolusDeliveryStatus.unfinalizedBolus(at: Date(), estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)
        XCTAssertEqual(actualUnfinalizedBolus?.startTime, expectedUnfinalizedBolus.startTime)
        XCTAssertEqual(actualUnfinalizedBolus?.programmedUnits, expectedUnfinalizedBolus.programmedUnits)
        XCTAssertEqual(actualUnfinalizedBolus?.scheduledCertainty, expectedUnfinalizedBolus.scheduledCertainty)
        XCTAssertEqual(actualUnfinalizedBolus?.progress(at: now), 0)

        // estimatingProgress
        bolusDeliveryStatus = BolusDeliveryStatus(id: nil,
                                                  progressState: .estimatingProgress,
                                                  type: .fast,
                                                  insulinProgrammed: 1,
                                                  insulinDelivered: 0)
        expectedUnfinalizedBolus = UnfinalizedDose(decisionId: nil, bolusAmount: 1, startTime: now, scheduledCertainty: .uncertain, estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)
        actualUnfinalizedBolus = bolusDeliveryStatus.unfinalizedBolus(at: now, estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)
        XCTAssertEqual(actualUnfinalizedBolus?.startTime, expectedUnfinalizedBolus.startTime)
        XCTAssertEqual(actualUnfinalizedBolus?.programmedUnits, expectedUnfinalizedBolus.programmedUnits)
        XCTAssertEqual(actualUnfinalizedBolus?.scheduledCertainty, expectedUnfinalizedBolus.scheduledCertainty)
        XCTAssertEqual(actualUnfinalizedBolus?.progress(at: now), 0)

        // 50% delivered
        bolusDeliveryStatus = BolusDeliveryStatus(id: nil,
                                                  progressState: .inProgress,
                                                  type: .fast,
                                                  insulinProgrammed: 1,
                                                  insulinDelivered: 0.5)
        expectedUnfinalizedBolus = UnfinalizedDose(decisionId: nil, bolusAmount: 1, startTime: now.addingTimeInterval(-0.5/estimatedBolusDeliveryRate), scheduledCertainty: .certain, estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)
        actualUnfinalizedBolus = bolusDeliveryStatus.unfinalizedBolus(at: now, estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)
        XCTAssertEqual(actualUnfinalizedBolus?.startTime, expectedUnfinalizedBolus.startTime)
        XCTAssertEqual(actualUnfinalizedBolus?.programmedUnits, expectedUnfinalizedBolus.programmedUnits)
        XCTAssertEqual(actualUnfinalizedBolus?.scheduledCertainty, expectedUnfinalizedBolus.scheduledCertainty)

        // 100% delivered
        bolusDeliveryStatus = BolusDeliveryStatus(id: nil,
                                                  progressState: .completed,
                                                  type: .fast,
                                                  insulinProgrammed: 1,
                                                  insulinDelivered: 1)
        expectedUnfinalizedBolus = UnfinalizedDose(decisionId: nil, bolusAmount: 1, startTime: now.addingTimeInterval(-1/estimatedBolusDeliveryRate), scheduledCertainty: .certain, estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)
        expectedUnfinalizedBolus.cancel(at: now) // simulate the bolus being completed
        actualUnfinalizedBolus = bolusDeliveryStatus.unfinalizedBolus(at: now, estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)
        XCTAssertEqual(actualUnfinalizedBolus?.startTime, expectedUnfinalizedBolus.startTime)
        XCTAssertEqual(actualUnfinalizedBolus?.programmedUnits, expectedUnfinalizedBolus.programmedUnits)
        XCTAssertEqual(actualUnfinalizedBolus?.scheduledCertainty, expectedUnfinalizedBolus.scheduledCertainty)
        XCTAssertEqual(actualUnfinalizedBolus?.progress(at: now), 1)
    }

    func testRawValue() {
        let bolusID: BolusID = 2
        let progressState = BolusProgressState.canceled
        let type = BolusType.extended
        let insulinProgrammed = 2.0
        let inssulinDelivered = 0.5
        let startTime = Date()
        let endTime = Date()
        let bolusDeliveryStatus = BolusDeliveryStatus(id: bolusID,
                                                      progressState: progressState,
                                                      type: type,
                                                      insulinProgrammed: insulinProgrammed,
                                                      insulinDelivered: inssulinDelivered,
                                                      startTime: startTime,
                                                      endTime: endTime)
        let rawValue = bolusDeliveryStatus.rawValue
        XCTAssertEqual(rawValue["bolusID"] as? BolusID, bolusID)
        XCTAssertEqual(rawValue["progressState"] as? BolusProgressState.RawValue, progressState.rawValue)
        XCTAssertEqual(rawValue["type"] as? BolusType.RawValue, type.rawValue)
        XCTAssertEqual(rawValue["insulinProgrammed"] as? Double, insulinProgrammed)
        XCTAssertEqual(rawValue["insulinDelivered"] as? Double, inssulinDelivered)
        XCTAssertEqual(rawValue["startTime"] as? Date, startTime)
        XCTAssertEqual(rawValue["endTime"] as? Date, endTime)
    }

    func testInitializeFromRawValue() {
        let bolusID: BolusID? = 3
        let progressState = BolusProgressState.completed
        let type = BolusType.multiwave
        let insulinProgrammed = 2.0
        let insulinDelivered = 2.0
        let startTime = Date()
        let endTime = Date()

        let rawValue: [String: Any] = [
            "bolusID": bolusID!,
            "progressState": progressState.rawValue,
            "type": type.rawValue,
            "insulinProgrammed": insulinProgrammed,
            "insulinDelivered": insulinDelivered,
            "startTime": startTime,
            "endTime": endTime
        ]

        let bolusDeliveryStatus = BolusDeliveryStatus(rawValue: rawValue)
        XCTAssertEqual(bolusDeliveryStatus?.id, bolusID)
        XCTAssertEqual(bolusDeliveryStatus?.progressState, progressState)
        XCTAssertEqual(bolusDeliveryStatus?.type, type)
        XCTAssertEqual(bolusDeliveryStatus?.insulinProgrammed, insulinProgrammed)
        XCTAssertEqual(bolusDeliveryStatus?.insulinDelivered, insulinDelivered)
        XCTAssertEqual(bolusDeliveryStatus?.startTime, startTime)
        XCTAssertEqual(bolusDeliveryStatus?.endTime, endTime)
    }
}
