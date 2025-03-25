//
//  GeneralAnnunciationTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-19.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

// TODO compare this file and see which tests need to be added at the pump manager level

class GeneralAnnunciationTests: XCTestCase {
    
    func testAnnunciationClassification() {
        XCTAssertEqual(nil, AnnunciationType.systemIssue.classification)
        XCTAssertEqual(.error, AnnunciationType.mechanicalIssue.classification)
        XCTAssertEqual(.maintenance, AnnunciationType.occlusionDetected.classification)
        XCTAssertEqual(.maintenance, AnnunciationType.reservoirIssue.classification)
        XCTAssertEqual(.maintenance, AnnunciationType.reservoirEmpty.classification)
        XCTAssertEqual(.warning, AnnunciationType.reservoirLow.classification)
        XCTAssertEqual(.maintenance, AnnunciationType.primingIssue.classification)
        XCTAssertEqual(nil, AnnunciationType.infusionSetIncomplete.classification)
        XCTAssertEqual(nil, AnnunciationType.infusionSetDetached.classification)
        XCTAssertEqual(nil, AnnunciationType.powerSourceInsufficient.classification)
        XCTAssertEqual(.maintenance, AnnunciationType.batteryEmpty.classification)
        XCTAssertEqual(.warning, AnnunciationType.batteryLow.classification)
        XCTAssertEqual(nil, AnnunciationType.batteryMedium.classification)
        XCTAssertEqual(nil, AnnunciationType.batteryFull.classification)
        XCTAssertEqual(nil, AnnunciationType.temperatureOutOfRange.classification)
        XCTAssertEqual(nil, AnnunciationType.airPressureOutOfRange.classification)
        XCTAssertEqual(.warning, AnnunciationType.bolusCanceled.classification)
        XCTAssertEqual(nil, AnnunciationType.tempBasalOver.classification)
        XCTAssertEqual(.warning, AnnunciationType.tempBasalCanceled.classification)
        XCTAssertEqual(nil, AnnunciationType.maxDelivery.classification)
        XCTAssertEqual(nil, AnnunciationType.dateTimeIssue.classification)
    }

    func testAnnunciationEMWRPriorities() {
        // Just doing a few
        XCTAssertGreaterThan(AnnunciationType.mechanicalIssue.rank, AnnunciationType.reservoirEmpty.rank)
        XCTAssertGreaterThan(AnnunciationType.reservoirEmpty.rank, AnnunciationType.batteryLow.rank)
        XCTAssertEqual(AnnunciationType.batteryLow.rank, AnnunciationType.reservoirLow.rank)
        // Occlusion is a special "M"
        XCTAssertGreaterThan(AnnunciationType.occlusionDetected.rank, AnnunciationType.reservoirEmpty.rank)
        
        AnnunciationType.allCases.forEach { left in
            AnnunciationType.allCases.forEach { right in
                switch (left.classification, right.classification) {
                case (.error, .error):
                    XCTAssertEqual(left.rank, right.rank)
                case (.error, _):
                    XCTAssertGreaterThan(left.rank, right.rank)
                case (_, .error):
                    XCTAssertLessThan(left.rank, right.rank)
                case (.maintenance, .maintenance):
                    switch (left, right) {
                    // Occlusion is a special "M"
                    case (.occlusionDetected, .occlusionDetected):
                        XCTAssertEqual(left.rank, right.rank)
                    case (.occlusionDetected, _):
                        XCTAssertGreaterThan(left.rank, right.rank)
                    case (_, .occlusionDetected):
                        XCTAssertLessThan(left.rank, right.rank)
                    default:
                        XCTAssertEqual(left.rank, right.rank)
                    }
                case (.maintenance, _):
                    XCTAssertGreaterThan(left.rank, right.rank)
                case (_, .maintenance):
                    XCTAssertLessThan(left.rank, right.rank)
                case (.warning, .warning):
                    XCTAssertEqual(left.rank, right.rank)
                case (.warning, _):
                    XCTAssertGreaterThan(left.rank, right.rank)
                case (_, .warning):
                    XCTAssertLessThan(left.rank, right.rank)
                case (.reminder, .reminder):
                    XCTAssertEqual(left.rank, right.rank)
                case (.reminder, _):
                    XCTAssertGreaterThan(left.rank, right.rank)
                case (_, .reminder):
                    XCTAssertLessThan(left.rank, right.rank)
                case (.none, .none), (.none, _), (_, .none):
                    XCTAssertEqual(left.rank, right.rank)
                }
            }
        }
    }
    
    func testStatusTextForType() {
        // See this spreadsheet for the source of truth with this:
        //https://docs.google.com/spreadsheets/d/1xi7BkJPNZj2hP5Assg3zxsGO-ldHAS_V/edit#gid=734224882
        XCTAssertEqual(nil, AnnunciationType.systemIssue.insulinStatusHighlightLocalizedString)
        XCTAssertEqual("No Insulin", AnnunciationType.mechanicalIssue.insulinStatusHighlightLocalizedString)
        XCTAssertEqual("Occlusion", AnnunciationType.occlusionDetected.insulinStatusHighlightLocalizedString)
        XCTAssertEqual("No Insulin", AnnunciationType.reservoirIssue.insulinStatusHighlightLocalizedString)
        XCTAssertEqual("No Insulin", AnnunciationType.reservoirEmpty.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.reservoirLow.insulinStatusHighlightLocalizedString)
        XCTAssertEqual("No Insulin", AnnunciationType.primingIssue.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.infusionSetIncomplete.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.infusionSetDetached.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.powerSourceInsufficient.insulinStatusHighlightLocalizedString)
        XCTAssertEqual("No Insulin", AnnunciationType.batteryEmpty.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.batteryLow.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.batteryMedium.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.batteryFull.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.temperatureOutOfRange.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.airPressureOutOfRange.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.bolusCanceled.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.tempBasalOver.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.tempBasalCanceled.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.maxDelivery.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.dateTimeIssue.insulinStatusHighlightLocalizedString)
    }
    
    let errorTypes: [AnnunciationType] = [.mechanicalIssue, .systemIssue]
    let maintenanceTypes: [AnnunciationType] = [.reservoirIssue, .reservoirEmpty, .batteryEmpty, .occlusionDetected, .primingIssue]
    let warningTypes: [AnnunciationType] = [.reservoirLow, .batteryLow, .tempBasalCanceled, .bolusCanceled]
}

extension AnnunciationType.Classification {
    var stringCode: String {
        switch self {
        case .error:
            return "E"
        case .maintenance:
            return "M"
        case .warning:
            return "W"
        case .reminder:
            return "R"
        }
    }
}

extension AnnunciationType {
    func annunciationForType(identifier: UInt16) -> Annunciation {
        switch self {
        case .reservoirLow:
            return LowReservoirAnnunciation(identifier: identifier, currentReservoirLevel: 100)
        case .bolusCanceled:
            return BolusCanceledAnnunciation(identifier: identifier, bolusDeliveryStatus: .noActiveBolus)
        default:
            return GeneralAnnunciation(type: self, identifier: identifier)
        }
    }
}
