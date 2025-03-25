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

    func testAnnunciationClassificationTitle() {
        XCTAssertEqual(GeneralAnnunciation(type: .mechanicalIssue, identifier: 1).annunciationClassificationTitle, "Error")
        XCTAssertEqual(GeneralAnnunciation(type: .airPressureOutOfRange, identifier: 1).annunciationClassificationTitle, "Unknown")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryError, identifier: 1).annunciationClassificationTitle, "Error")
        XCTAssertEqual(GeneralAnnunciation(type: .endOfPumpLifetime, identifier: 1).annunciationClassificationTitle, "Maintenance")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirIssue, identifier: 1).annunciationClassificationTitle, "Maintenance")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirEmpty, identifier: 1).annunciationClassificationTitle, "Maintenance")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryEmpty, identifier: 1).annunciationClassificationTitle, "Maintenance")
        XCTAssertEqual(GeneralAnnunciation(type: .automaticOff, identifier: 1).annunciationClassificationTitle, "Maintenance")
        XCTAssertEqual(GeneralAnnunciation(type: .occlusionDetected, identifier: 1).annunciationClassificationTitle, "Maintenance")
        XCTAssertEqual(GeneralAnnunciation(type: .primingIssue, identifier: 1).annunciationClassificationTitle, "Maintenance")
        XCTAssertEqual(GeneralAnnunciation(type: .pumpNotConfigured, identifier: 1).annunciationClassificationTitle, "Maintenance")
        XCTAssertEqual(GeneralAnnunciation(type: .endOfLifetime, identifier: 1).annunciationClassificationTitle, "Warning")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirLow, identifier: 1).annunciationClassificationTitle, "Warning")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryLow, identifier: 1).annunciationClassificationTitle, "Warning")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryAttention, identifier: 1).annunciationClassificationTitle, "Warning")
        XCTAssertEqual(GeneralAnnunciation(type: .tempBasalCanceled, identifier: 1).annunciationClassificationTitle, "Warning")
        XCTAssertEqual(GeneralAnnunciation(type: .lowDeliveryRate, identifier: 1).annunciationClassificationTitle, "Warning")
        XCTAssertEqual(GeneralAnnunciation(type: .bolusCanceled, identifier: 1).annunciationClassificationTitle, "Warning")
        XCTAssertEqual(GeneralAnnunciation(type: .endOfReservoirTime, identifier: 1).annunciationClassificationTitle, "Warning")
        XCTAssertEqual(GeneralAnnunciation(type: .stopWarning, identifier: 1).annunciationClassificationTitle, "Warning")
    }
    
    func testAnnunciationTitle() {
        XCTAssertEqual(GeneralAnnunciation(type: .mechanicalIssue, identifier: 1).annunciationTitle, "Mechanical Error")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryError, identifier: 1).annunciationTitle, "Battery Error")
        XCTAssertEqual(GeneralAnnunciation(type: .endOfPumpLifetime, identifier: 1).annunciationTitle, "Pump Expired")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirIssue, identifier: 1).annunciationTitle, "Deviation in Reservoir Amount")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirEmpty, identifier: 1).annunciationTitle, "Reservoir Empty")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryEmpty, identifier: 1).annunciationTitle, "Battery Empty")
        XCTAssertEqual(GeneralAnnunciation(type: .automaticOff, identifier: 1).annunciationTitle, "Automatic off")
        XCTAssertEqual(GeneralAnnunciation(type: .occlusionDetected, identifier: 1).annunciationTitle, "Occlusion Detected")
        XCTAssertEqual(GeneralAnnunciation(type: .primingIssue, identifier: 1).annunciationTitle, "Reservoir Needle Not Filled")
        XCTAssertEqual(GeneralAnnunciation(type: .pumpNotConfigured, identifier: 1).annunciationTitle, "Replace the Reservoir Now")
        XCTAssertEqual(GeneralAnnunciation(type: .endOfLifetime, identifier: 1).annunciationTitle, "Pump Expires Soon")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirLow, identifier: 1).annunciationTitle, "Low Reservoir")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryLow, identifier: 1).annunciationTitle, "Battery Almost Empty")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryAttention, identifier: 1).annunciationTitle, "Limited Battery Power")
        XCTAssertEqual(GeneralAnnunciation(type: .tempBasalCanceled, identifier: 1).annunciationTitle, "Temporary basal canceled")
        XCTAssertEqual(GeneralAnnunciation(type: .lowDeliveryRate, identifier: 1).annunciationTitle, "Low Amount of Insulin Delivered")
        XCTAssertEqual(GeneralAnnunciation(type: .bolusCanceled, identifier: 1).annunciationTitle, "Bolus Delivery Interrupted")
        XCTAssertEqual(GeneralAnnunciation(type: .endOfReservoirTime, identifier: 1).annunciationTitle, "Reservoir Expired")
        XCTAssertEqual(GeneralAnnunciation(type: .stopWarning, identifier: 1).annunciationTitle, "Insulin Delivery Suspended")
        XCTAssertEqual(GeneralAnnunciation(type: .airPressureOutOfRange, identifier: 1).annunciationTitle, "Unknown annunciation")
    }
    
    func testAnnunciationMessageCause() {
        XCTAssertEqual(GeneralAnnunciation(type: .mechanicalIssue, identifier: 1).annunciationMessageCause, "Insulin delivery stopped.")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryError, identifier: 1).annunciationMessageCause, "Insulin delivery stopped.")
        XCTAssertEqual(GeneralAnnunciation(type: .endOfPumpLifetime, identifier: 1).annunciationMessageCause, "Insulin delivery stopped.")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirIssue, identifier: 1).annunciationMessageCause, "Programmed insulin amount differs from detected insulin amount.")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirEmpty, identifier: 1).annunciationMessageCause, "Insulin delivery stopped.")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryEmpty, identifier: 1).annunciationMessageCause, "Insulin delivery stopped.")
        XCTAssertEqual(GeneralAnnunciation(type: .automaticOff, identifier: 1).annunciationMessageCause, "The automatic off feature has stopped insulin delivery. The pump is in STOP mode.")
        XCTAssertEqual(GeneralAnnunciation(type: .occlusionDetected, identifier: 1).annunciationMessageCause, "Insulin delivery stopped.")
        XCTAssertEqual(GeneralAnnunciation(type: .primingIssue, identifier: 1).annunciationMessageCause, "Insulin delivery stopped.")
        XCTAssertEqual(GeneralAnnunciation(type: .pumpNotConfigured, identifier: 1).annunciationMessageCause, "The pump system is no longer working.")
        XCTAssertEqual(PumpExpiresSoonAnnunciation(identifier: 1, timeRemaining: .days(2)).annunciationMessageCause, "Your pump expires in 2 days.")
        XCTAssertEqual(PumpExpiresSoonAnnunciation(identifier: 1, timeRemaining: nil).annunciationMessageCause, "Your pump expires soon.")
        XCTAssertEqual(LowReservoirAnnunciation(identifier: 1, currentReservoirLevel: 100).annunciationMessageCause, "100.0 insulin or less remaining in reservoir.")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryLow, identifier: 1).annunciationMessageCause, nil)
        XCTAssertEqual(GeneralAnnunciation(type: .batteryAttention, identifier: 1).annunciationMessageCause, "Energy supply to the battery is restricted.")
        XCTAssertEqual(GeneralAnnunciation(type: .tempBasalCanceled, identifier: 1).annunciationMessageCause, "An active temporary basal rate was canceled.")
        XCTAssertEqual(GeneralAnnunciation(type: .lowDeliveryRate, identifier: 1).annunciationMessageCause, "The pump could not deliver the insulin amount that is programmed for the basal rate or bolus, however the pump will attempt to recover the missed insulin.")
        XCTAssertEqual(BolusCanceledAnnunciation(identifier: 1, bolusDeliveryStatus: BolusDeliveryStatus(id: 1, progressState: .canceled, type: .undetermined, insulinProgrammed: 2.0, insulinDelivered: 0.5)).annunciationMessageCause, "Approximately 0.5 of 2 of insulin were delivered of a programmed bolus.")
        XCTAssertNil(GeneralAnnunciation(type: .endOfReservoirTime, identifier: 1).annunciationMessageCause)
        XCTAssertEqual(GeneralAnnunciation(type: .stopWarning, identifier: 1).annunciationMessageCause, "The insulin suspension period has ended.")
        XCTAssertNil(GeneralAnnunciation(type: .airPressureOutOfRange, identifier: 1).annunciationMessageCause)
    }
    
    func testAnnunciationMessageSolution() {
        XCTAssertEqual(GeneralAnnunciation(type: .mechanicalIssue, identifier: 1).annunciationMessageSolution, "Replace the reservoir now. If the error is still not resolved, replace the pump base.")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryError, identifier: 1).annunciationMessageSolution, "Battery connection lost. Replace the reservoir now.")
        XCTAssertEqual(GeneralAnnunciation(type: .endOfPumpLifetime, identifier: 1).annunciationMessageSolution, "Replace the reservoir and pump base now.")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirIssue, identifier: 1).annunciationMessageSolution, "Replace the reservoir now.")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirEmpty, identifier: 1).annunciationMessageSolution, "Replace the reservoir now.")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryEmpty, identifier: 1).annunciationMessageSolution, "Replace the reservoir now.")
        XCTAssertEqual(GeneralAnnunciation(type: .automaticOff, identifier: 1).annunciationMessageSolution, "Start the pump to resume insulin delivery.")
        XCTAssertEqual(GeneralAnnunciation(type: .occlusionDetected, identifier: 1).annunciationMessageSolution, "Replace infusion assembly and reservoir now. Then check your blood glucose.")
        XCTAssertEqual(GeneralAnnunciation(type: .primingIssue, identifier: 1).annunciationMessageSolution, "Replace the reservoir now.")
        XCTAssertEqual(GeneralAnnunciation(type: .pumpNotConfigured, identifier: 1).annunciationMessageSolution, "Replace the reservoir to restart insulin delivery.")
        XCTAssertEqual(GeneralAnnunciation(type: .endOfLifetime, identifier: 1).annunciationMessageSolution, "Be prepared to replace it soon. Continue to view the status of your pump.")
        XCTAssertEqual(GeneralAnnunciation(type: .reservoirLow, identifier: 1).annunciationMessageSolution, "Replace the reservoir soon.")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryLow, identifier: 1).annunciationMessageSolution, "The pump battery is almost empty.")
        XCTAssertEqual(GeneralAnnunciation(type: .batteryAttention, identifier: 1).annunciationMessageSolution, "Check to make sure there is unrestricted air supply to the opening for ventilation on the pump.")
        XCTAssertEqual(GeneralAnnunciation(type: .tempBasalCanceled, identifier: 1).annunciationMessageSolution, "Make sure that the cancellation was intentional. Program a new temporary basal rate if required.")
        XCTAssertEqual(GeneralAnnunciation(type: .lowDeliveryRate, identifier: 1).annunciationMessageSolution, "Make sure the delivered amounts are sufficient for your insulin needs and stay near your device until this warning disappears.")
        XCTAssertEqual(GeneralAnnunciation(type: .bolusCanceled, identifier: 1).annunciationMessageSolution, "Note the insulin amount already delivered and schedule a new bolus if necessary.")
        XCTAssertEqual(GeneralAnnunciation(type: .endOfReservoirTime, identifier: 1).annunciationMessageSolution, "Replace the reservoir as soon as possible.")
        XCTAssertEqual(GeneralAnnunciation(type: .stopWarning, identifier: 1).annunciationMessageSolution, "Return to App and resume.")
        XCTAssertNil(GeneralAnnunciation(type: .airPressureOutOfRange, identifier: 1).annunciationMessageSolution)
    }
    
    func testHasInApp() {
        XCTAssertTrue(GeneralAnnunciation(type: .endOfReservoirTime, identifier: 1).hasInApp)
    }
    
    func testHasUserNotification() {
        XCTAssertTrue(GeneralAnnunciation(type: .stopWarning, identifier: 1).hasUserNotification)
    }
    
    func testLocalizedTitle() {
        let annunciation = GeneralAnnunciation(type: .airPressureOutOfRange, identifier: 1)
        XCTAssertEqual(annunciation.localizedTitle, annunciation.annunciationTitle)
    }
    
    func testLocalizedMessage() {
        for type in AnnunciationType.allCases {
            let annunciation = type.annunciationForType(identifier: 1)
            // If there's a cause, make sure it's displayed
            if let cause = annunciation.annunciationMessageCause {
                XCTAssertTrue(annunciation.localizedMessage.contains(cause), "Cause missing or incorrect for \(type): \(annunciation.localizedMessage) missing \(cause)")
            }
            // If there's a solution, make sure it's displayed
            if let solution = annunciation.annunciationMessageSolution {
                XCTAssertTrue(annunciation.localizedMessage.contains(solution), "Solution missing or incorrect for \(type): \(annunciation.localizedMessage) missing \(solution)")
            }
        }
    }
    
    func testLocalizedDismissActionLabel() {
        XCTAssertEqual(GeneralAnnunciation(type: .batteryAttention, identifier: 1).localizedDismissActionLabel, "OK")
    }
    
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
        XCTAssertEqual(.error, AnnunciationType.batteryError.classification)
        XCTAssertEqual(.maintenance, AnnunciationType.automaticOff.classification)
        XCTAssertEqual(.maintenance, AnnunciationType.pumpNotConfigured.classification)
        XCTAssertEqual(.maintenance, AnnunciationType.endOfPumpLifetime.classification)
        XCTAssertEqual(.warning, AnnunciationType.lowDeliveryRate.classification)
        XCTAssertEqual(.warning, AnnunciationType.endOfReservoirTime.classification)
        XCTAssertEqual(.warning, AnnunciationType.endOfLifetime.classification)
        XCTAssertEqual(.warning, AnnunciationType.stopWarning.classification)
        XCTAssertEqual(.warning, AnnunciationType.batteryAttention.classification)
    }

    func testAnnunciationEMWRPriorities() {
        // Just doing a few
        XCTAssertGreaterThan(AnnunciationType.mechanicalIssue.rank, AnnunciationType.endOfLifetime.rank)
        XCTAssertGreaterThan(AnnunciationType.reservoirEmpty.rank, AnnunciationType.batteryAttention.rank)
        XCTAssertEqual(AnnunciationType.batteryAttention.rank, AnnunciationType.endOfReservoirTime.rank)
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
        XCTAssertEqual("No Insulin", AnnunciationType.batteryError.insulinStatusHighlightLocalizedString)
        XCTAssertEqual("No Insulin", AnnunciationType.automaticOff.insulinStatusHighlightLocalizedString)
        XCTAssertEqual("No Insulin", AnnunciationType.pumpNotConfigured.insulinStatusHighlightLocalizedString)
        XCTAssertEqual("No Insulin", AnnunciationType.endOfPumpLifetime.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.lowDeliveryRate.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.endOfReservoirTime.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.endOfLifetime.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.stopWarning.insulinStatusHighlightLocalizedString)
        XCTAssertEqual(nil, AnnunciationType.batteryAttention.insulinStatusHighlightLocalizedString)
    }

    func testTemporaryAnnunciationTypes() {
        let temporaryAnnunciationTypes = AnnunciationType.temporaryAnnunciationTypes
        XCTAssertEqual(temporaryAnnunciationTypes.count, 2)
        XCTAssertTrue(temporaryAnnunciationTypes.contains(.lowDeliveryRate))
        XCTAssertTrue(temporaryAnnunciationTypes.contains(.batteryAttention))
    }

    func testTemporaryAnnunciationTimeout() {
        XCTAssertEqual(AnnunciationType.lowDeliveryRate.timeoutInterval, .minutes(60))
        XCTAssertEqual(AnnunciationType.batteryAttention.timeoutInterval, .minutes(15))
    }
    
    let errorTypes = AnnunciationType.allCases.filter { $0.classification == .error }
    let maintenanceTypes = AnnunciationType.allCases.filter { $0.classification == .maintenance }
    let warningTypes = AnnunciationType.allCases.filter { $0.classification == .warning }
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
        case .endOfPumpLifetime:
            return PumpExpiresSoonAnnunciation(identifier: identifier, timeRemaining: .days(2))
        default:
            return GeneralAnnunciation(type: self, identifier: identifier)
        }
    }
}
