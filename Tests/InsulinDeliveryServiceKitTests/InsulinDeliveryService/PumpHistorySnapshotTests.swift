//
//  PumpHistorySnapshotTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2026-11-03.
//  Copyright © 2026 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

/// The persisted form of the pump history survives JSON and rebuilds the typed event.
class PumpHistorySnapshotTests: XCTestCase {
    func testSnapshotRoundTripsThroughJSONAndTheFactory() throws {
        let eventData = BolusProgrammedHistoryEvent.createEventDataPart1(id: 1, type: .fast, fastAmount: 3.3, extendedAmount: 0, duration: 0)
        let event = try XCTUnwrap(PumpHistoryEventFactory.createPumpHistoryEvent(type: .bolusProgrammedPart1, recordNumber: 7, relativeOffet: 42, eventData: eventData))
        let storable = try XCTUnwrap(StorablePumpHistoryEvent(pumpHistoryEvent: event))
        let snapshot = PumpHistorySnapshot(events: [storable], nextRecordNumber: 8)

        let decoded = try JSONDecoder().decode(PumpHistorySnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.events[0].type, .bolusProgrammedPart1)
        XCTAssertEqual(decoded.events[0].data, event.data)

        let rebuilt = try XCTUnwrap(PumpHistoryEventFactory.createPumpHistoryEvent(type: decoded.events[0].type, recordNumber: decoded.events[0].recordNumber, relativeOffet: decoded.events[0].relativeOffset, eventData: decoded.events[0].eventData))
        XCTAssertEqual(rebuilt.data, event.data)
        XCTAssertEqual(rebuilt.recordNumber, 7)
    }
}
