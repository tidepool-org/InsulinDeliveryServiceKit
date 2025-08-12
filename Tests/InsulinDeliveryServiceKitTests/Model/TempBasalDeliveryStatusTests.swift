//
//  TempBasalDeliveryStatusTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-19.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

final class TempBasalDeliveryStatusTests: XCTestCase {
    
    func testInitialization() {
        let progressState = TempBasalProgressState.inProgress
        let duration: TimeInterval = . minutes(30)
        let rate = 2.4
        let insulinDelivered = 1.1
        let startTime = Date()
        let tempBasalDeliveryStatus = TempBasalDeliveryStatus(progressState: progressState,
                                                              duration: duration,
                                                              rate: rate,
                                                              startTime: startTime,
                                                              insulinDelivered: insulinDelivered)
        
        XCTAssertEqual(tempBasalDeliveryStatus.progressState, progressState)
        XCTAssertEqual(tempBasalDeliveryStatus.duration, duration)
        XCTAssertEqual(tempBasalDeliveryStatus.rate, rate)
        XCTAssertEqual(tempBasalDeliveryStatus.insulinDelivered, insulinDelivered)
        XCTAssertEqual(tempBasalDeliveryStatus.startTime, startTime)
    }
    
    func testIsTempBasalActive() {
        var tempBasalDeliveryStatus: TempBasalDeliveryStatus = .noActiveTempBasal
        XCTAssertFalse(tempBasalDeliveryStatus.isTempBasalActive)
        
        tempBasalDeliveryStatus = TempBasalDeliveryStatus(progressState: .inProgress, duration: .minutes(30), rate: 2.4, startTime: Date(), insulinDelivered: 0)
        XCTAssertTrue(tempBasalDeliveryStatus.isTempBasalActive)
        
        tempBasalDeliveryStatus.progressState = .completed
        XCTAssertTrue(tempBasalDeliveryStatus.isTempBasalActive)
        
        tempBasalDeliveryStatus.progressState = .noActiveTempBasal
        XCTAssertFalse(tempBasalDeliveryStatus.isTempBasalActive)
    }
    
    func testRawValue() {
        let progressState = TempBasalProgressState.inProgress
        let duration: TimeInterval = . minutes(30)
        let rate = 2.4
        let insulinDelivered = 1.1
        let startTime = Date()
        let tempBasalDeliveryStatus = TempBasalDeliveryStatus(progressState: progressState,
                                                              duration: duration,
                                                              rate: rate,
                                                              startTime: startTime,
                                                              insulinDelivered: insulinDelivered)
        
        let rawValue = tempBasalDeliveryStatus.rawValue
        XCTAssertEqual(rawValue["progressState"] as? TempBasalProgressState.RawValue, progressState.rawValue)
        XCTAssertEqual(rawValue["duration"] as? TimeInterval, duration)
        XCTAssertEqual(rawValue["rate"] as? Double, rate)
        XCTAssertEqual(rawValue["insulinDelivered"] as? Double, insulinDelivered)
        XCTAssertEqual(rawValue["startTime"] as? Date, startTime)
    }
    
    func testInitializeFromRawValue() {
        let progressState = TempBasalProgressState.inProgress
        let duration: TimeInterval = . minutes(30)
        let rate = 2.4
        let insulinDelivered = 1.1
        let startTime = Date()
        
        let rawValue: [String: Any] = [
            "progressState": progressState.rawValue,
            "duration": duration,
            "rate": rate,
            "insulinDelivered": insulinDelivered,
            "startTime": startTime,
        ]
        
        let tempBasalProgressState = TempBasalDeliveryStatus(rawValue: rawValue)
        XCTAssertEqual(tempBasalProgressState?.progressState, progressState)
        XCTAssertEqual(tempBasalProgressState?.duration, duration)
        XCTAssertEqual(tempBasalProgressState?.rate, rate)
        XCTAssertEqual(tempBasalProgressState?.insulinDelivered, insulinDelivered)
        XCTAssertEqual(tempBasalProgressState?.startTime, startTime)
    }
}
