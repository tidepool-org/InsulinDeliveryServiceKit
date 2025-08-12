//
//  IDAnnunciationStatusTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-07-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

class IDAnnunciationStatusTests: XCTestCase {

    private var testE2EProtection = TestE2EProtection()

    func testAnnunciationType() {
        XCTAssertEqual(AnnunciationType(rawValue: 0x000f), AnnunciationType.systemIssue)
        XCTAssertEqual(AnnunciationType(rawValue: 0x0033), AnnunciationType.mechanicalIssue)
        XCTAssertEqual(AnnunciationType(rawValue: 0x003c), AnnunciationType.occlusionDetected)
        XCTAssertEqual(AnnunciationType(rawValue: 0x0055), AnnunciationType.reservoirIssue)
        XCTAssertEqual(AnnunciationType(rawValue: 0x005a), AnnunciationType.reservoirEmpty)
        XCTAssertEqual(AnnunciationType(rawValue: 0x0066), AnnunciationType.reservoirLow)
        XCTAssertEqual(AnnunciationType(rawValue: 0x0069), AnnunciationType.primingIssue)
        XCTAssertEqual(AnnunciationType(rawValue: 0x0096), AnnunciationType.infusionSetIncomplete)
        XCTAssertEqual(AnnunciationType(rawValue: 0x0099), AnnunciationType.infusionSetDetached)
        XCTAssertEqual(AnnunciationType(rawValue: 0x00a5), AnnunciationType.powerSourceInsufficient)
        XCTAssertEqual(AnnunciationType(rawValue: 0x00aa), AnnunciationType.batteryEmpty)
        XCTAssertEqual(AnnunciationType(rawValue: 0x00c3), AnnunciationType.batteryLow)
        XCTAssertEqual(AnnunciationType(rawValue: 0x00cc), AnnunciationType.batteryMedium)
        XCTAssertEqual(AnnunciationType(rawValue: 0x00f0), AnnunciationType.batteryFull)
        XCTAssertEqual(AnnunciationType(rawValue: 0x00ff), AnnunciationType.temperatureOutOfRange)
        XCTAssertEqual(AnnunciationType(rawValue: 0x0303), AnnunciationType.airPressureOutOfRange)
        XCTAssertEqual(AnnunciationType(rawValue: 0x030c), AnnunciationType.bolusCanceled)
        XCTAssertEqual(AnnunciationType(rawValue: 0x0330), AnnunciationType.tempBasalOver)
        XCTAssertEqual(AnnunciationType(rawValue: 0x033f), AnnunciationType.tempBasalCanceled)
        XCTAssertEqual(AnnunciationType(rawValue: 0x0356), AnnunciationType.maxDelivery)
        XCTAssertEqual(AnnunciationType(rawValue: 0x0359), AnnunciationType.dateTimeIssue)
    }
    
    func testAnnunciationStatus() {
        XCTAssertEqual(AnnunciationStatus(rawValue: 0x0f), AnnunciationStatus.undetermined)
        XCTAssertEqual(AnnunciationStatus(rawValue: 0x33), AnnunciationStatus.pending)
        XCTAssertEqual(AnnunciationStatus(rawValue: 0x3c), AnnunciationStatus.snoozed)
        XCTAssertEqual(AnnunciationStatus(rawValue: 0x55), AnnunciationStatus.confirmed)
    }
    
    func testAnnunciationStatusFlag() {
        let presentAnnunciation: UInt8 = 0x01
        var annunciationStatus = AnnunciationStatusFlag(rawValue: presentAnnunciation)
        XCTAssertTrue(annunciationStatus.contains(.presentAnnunciation))
        
        let presentAuxInfo1: UInt8 = 0x02
        annunciationStatus = AnnunciationStatusFlag(rawValue: presentAuxInfo1)
        XCTAssertTrue(annunciationStatus.contains(.presentAuxInfo1))
        
        let presentAuxInfo2: UInt8 = 0x04
        annunciationStatus = AnnunciationStatusFlag(rawValue: presentAuxInfo2)
        XCTAssertTrue(annunciationStatus.contains(.presentAuxInfo2))
        
        let presentAuxInfo3: UInt8 = 0x08
        annunciationStatus = AnnunciationStatusFlag(rawValue: presentAuxInfo3)
        XCTAssertTrue(annunciationStatus.contains(.presentAuxInfo3))
        
        let presentAuxInfo4: UInt8 = 0x10
        annunciationStatus = AnnunciationStatusFlag(rawValue: presentAuxInfo4)
        XCTAssertTrue(annunciationStatus.contains(.presentAuxInfo4))
        
        let presentAuxInfo5: UInt8 = 0x20
        annunciationStatus = AnnunciationStatusFlag(rawValue: presentAuxInfo5)
        XCTAssertTrue(annunciationStatus.contains(.presentAuxInfo5))
        
        let multipleFlags: UInt8 = 0x0f
        annunciationStatus = AnnunciationStatusFlag(rawValue: multipleFlags)
        XCTAssertTrue(annunciationStatus.contains(.presentAnnunciation))
        XCTAssertTrue(annunciationStatus.contains(.presentAuxInfo1))
        XCTAssertTrue(annunciationStatus.contains(.presentAuxInfo2))
        XCTAssertTrue(annunciationStatus.contains(.presentAuxInfo3))
    }
    
    func testHandleAnnunciationStatusDataWithNoAux() {
        let flags = AnnunciationStatusFlag.init(arrayLiteral: [.presentAnnunciation])
        let expectedAnnunciationID: UInt16 = 4
        let expectedAnnunciationType = AnnunciationType.batteryLow
        let expectedAnnunciationStatus = AnnunciationStatus.pending
        
        var data = Data(flags.rawValue)
        data.append(expectedAnnunciationID)
        data.append(expectedAnnunciationType.rawValue)
        data.append(expectedAnnunciationStatus.rawValue)
        
        let results = IDAnnunciationStatusDataHandler.handleData(testE2EProtection.appendingE2EProtection(data), e2eProtectionSupported: false)
        switch results {
        case .success(let annunciation):
            guard let annunciation = annunciation else {
                XCTAssert(false)
                return
            }

            XCTAssertEqual(annunciation.identifier, expectedAnnunciationID)
            XCTAssertEqual(annunciation.type, expectedAnnunciationType)
            XCTAssertEqual(annunciation.status, expectedAnnunciationStatus)
        case .failure(_):
            XCTAssert(false)
        }
    }
}
