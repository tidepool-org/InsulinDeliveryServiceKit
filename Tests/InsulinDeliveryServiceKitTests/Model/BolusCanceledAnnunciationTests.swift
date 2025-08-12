//
//  BolusCanceledAnnunciationTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-19.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

class BolusCanceledAnnunciationTests: XCTestCase {

    func testInitialization() {
        let type: AnnunciationType = .bolusCanceled
        let identifier: AnnunciationIdentifier = 456

        let bolusID: BolusID = 123
        let bolusType: BolusType = .fast
        let padding: UInt8 = 0x00
        let insulinProgrammed = 2.5
        let insulinDelivered = 1.7
        var auxiliaryData = Data(bolusID)
        auxiliaryData.append(bolusType.rawValue)
        auxiliaryData.append(padding)
        auxiliaryData.append(insulinProgrammed.sfloat)
        auxiliaryData.append(insulinDelivered.sfloat)
    
        let bolusCanceledAnnunciation = BolusCanceledAnnunciation(identifier: identifier,
                                                                  auxiliaryData: auxiliaryData)
        
        XCTAssertEqual(bolusCanceledAnnunciation.type, type)
        XCTAssertEqual(bolusCanceledAnnunciation.identifier, identifier)
        XCTAssertEqual(bolusCanceledAnnunciation.bolusDeliveryStatus.id, bolusID)
        XCTAssertEqual(bolusCanceledAnnunciation.bolusDeliveryStatus.type, bolusType)
        XCTAssertEqual(bolusCanceledAnnunciation.bolusDeliveryStatus.insulinProgrammed, insulinProgrammed)
        XCTAssertEqual(bolusCanceledAnnunciation.bolusDeliveryStatus.insulinDelivered, insulinDelivered)
    }
}
