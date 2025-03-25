//
//  Annunciation.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public typealias AnnunciationIdentifier = UInt16

public protocol Annunciation {
    var type: AnnunciationType { get }
    
    var identifier: AnnunciationIdentifier { get }
    
    var annunciationMessageCauseArgs: [CVarArg] { get }
}

extension Annunciation {
    var annunciationClassificationTitle: String {
        return type.classification?.title ?? "Unknown"
    }
    
    var annunciationTitle: String {
        switch self.type {
        case .mechanicalIssue:
            return LocalizedString("Mechanical Error", comment: "Title of the mechanical issue annunciation")
        case .batteryError:
            return LocalizedString("Battery Error", comment: "Title of the battery error annunciation")
        case .endOfPumpLifetime:
            return LocalizedString("Pump Expired", comment: "Title of the end of pump lifetime annunciation")
        case .reservoirIssue:
            return LocalizedString("Deviation in Reservoir Amount", comment: "Title of the reservoir issue annunciation")
        case .reservoirEmpty:
            return LocalizedString("Reservoir Empty", comment: "Title of the reservoir empty annunciation")
        case .batteryEmpty:
            return LocalizedString("Battery Empty", comment: "Title of the battery empty annunciation")
        case .automaticOff:
            return LocalizedString("Automatic off", comment: "Title of the automatic off annunciation")
        case .occlusionDetected:
            return LocalizedString("Occlusion Detected", comment: "Title of the occlusion detected annunciation")
        case .primingIssue:
            return LocalizedString("Reservoir Needle Not Filled", comment: "Title of the priming issue annunciation")
        case .pumpNotConfigured:
            return LocalizedString("Replace the Reservoir Now", comment: "Title of the data communication failed annunciation")
        case .endOfLifetime:
            return LocalizedString("Pump Expires Soon", comment: "Title of the end of lifetime annunciation")
        case .reservoirLow:
            return LocalizedString("Low Reservoir", comment: "Title of the reservoir low annunciation")
        case .batteryLow:
            return LocalizedString("Battery Almost Empty", comment: "Title of the battery low annunciation")
        case .batteryAttention:
            return LocalizedString("Limited Battery Power", comment: "Title of the battery attention annunciation")
        case .tempBasalCanceled:
            return LocalizedString("Temporary basal canceled", comment: "Title of the temp basal canceled annunciation")
        case .lowDeliveryRate:
            return LocalizedString("Low Amount of Insulin Delivered", comment: "Title of the low delivery rate annunciation")
        case .bolusCanceled:
            return LocalizedString("Bolus Delivery Interrupted", comment: "Title of the bolus canceled annunciation")
        case .endOfReservoirTime:
            return LocalizedString("Reservoir Expired", comment: "Title of the reservoir expired annunciation")
        case .stopWarning:
            return LocalizedString("Insulin Delivery Suspended", comment: "Title of the insulin delivery suspended annunciation")
        default:
            return LocalizedString("Unknown annunciation", comment: "Title of an unknown annunciation")
        }
    }
    
    var annunciationMessageCauseFormat: String? {
        switch self.type {
        case .mechanicalIssue:
            return LocalizedString("Insulin delivery stopped.", comment: "Mechanical issue possible cause message.")
        case .batteryError:
            return LocalizedString("Insulin delivery stopped.", comment: "Battery error possible cause message.")
        case .endOfPumpLifetime:
            return LocalizedString("Insulin delivery stopped.", comment: "End of pump lifetime possible cause message.")
        case .reservoirIssue:
            return LocalizedString("Programmed insulin amount differs from detected insulin amount.", comment: "Reservoir issue possible cause message.")
        case .reservoirEmpty:
            return LocalizedString("Insulin delivery stopped.", comment: "Reservoir empty possible cause message.")
        case .batteryEmpty:
            return LocalizedString("Insulin delivery stopped.", comment: "Battery empty possible cause message.")
        case .automaticOff:
            return LocalizedString("The automatic off feature has stopped insulin delivery. The pump is in STOP mode.", comment: "Automatic off possible cause message.")
        case .occlusionDetected:
            return LocalizedString("Insulin delivery stopped.", comment: "Occlusion detected possible cause message.")
        case .primingIssue:
            return LocalizedString("Insulin delivery stopped.", comment: "Priming issue possible cause message.")
        case .pumpNotConfigured:
            return LocalizedString("The pump system is no longer working.", comment: "Data communication failed possible cause message.")
        case .endOfLifetime:
            return LocalizedString("Your pump expires %1$@.", comment: "Format string for end of lifetime possible cause message. (1: localized string for time left, in days)")
        case .reservoirLow:
            return LocalizedString("%1$@ insulin or less remaining in reservoir.", comment: "Format string for alert content body for reservoir low cause message. (1: current reservoir level value).")
        case .batteryAttention:
            return LocalizedString("Energy supply to the battery is restricted.", comment: "End of lifetime possible cause message.")
        case .tempBasalCanceled:
            return LocalizedString("An active temporary basal rate was canceled.", comment: "Temporary basal rate canceled possible cause message.")
        case .lowDeliveryRate:
            return LocalizedString("The pump could not deliver the insulin amount that is programmed for the basal rate or bolus, however the pump will attempt to recover the missed insulin.", comment: "Low delivery rate possible cause message.")
        case .bolusCanceled:
            return LocalizedString("Approximately %1$@ of %2$@ of insulin were delivered of a programmed bolus.", comment: "Bolus canceled possible cause message. (1: partial bolus amount delivered, 2: programmed total amount)")
        case .stopWarning:
            return LocalizedString("The insulin suspension period has ended.", comment: "Stop warning possible cause message.")
        default:
            return nil
        }
    }
    
    var annunciationMessageCause: String? {
        annunciationMessageCauseFormat.map { String(format: $0, arguments: annunciationMessageCauseArgs) }
    }
    
    // Default: no args
    public var annunciationMessageCauseArgs: [CVarArg] { [] }
    
    var annunciationMessageSolution: String? {
        switch self.type {
        case .mechanicalIssue:
            return LocalizedString("Replace the reservoir now. If the error is still not resolved, replace the pump base.", comment: "Mechanical issue possible solution message.")
        case .batteryError:
            return LocalizedString("Battery connection lost. Replace the reservoir now.", comment: "Battery error possible solution message.")
        case .endOfPumpLifetime:
            return LocalizedString("Replace the reservoir and pump base now.", comment: "End of pump lifetime possible solution message.")
        case .reservoirIssue:
            return LocalizedString("Replace the reservoir now.", comment: "Reservoir issue possible solution message.")
        case .reservoirEmpty:
            return LocalizedString("Replace the reservoir now.", comment: "Reservoir empty possible solution message.")
        case .batteryEmpty:
            return LocalizedString("Replace the reservoir now.", comment: "Battery empty possible solution message.")
        case .automaticOff:
            return LocalizedString("Start the pump to resume insulin delivery.", comment: "Automatic off possible solution message.")
        case .occlusionDetected:
            return LocalizedString("Replace infusion assembly and reservoir now. Then check your blood glucose.", comment: "Occlusion detected possible solution message.")
        case .primingIssue:
            return LocalizedString("Replace the reservoir now.", comment: "Priming issue possible solution message.")
        case .pumpNotConfigured:
            return LocalizedString("Replace the reservoir to restart insulin delivery.", comment: "Data communication failed possible solution message.")
        case .endOfLifetime:
            return LocalizedString("Be prepared to replace it soon. Continue to view the status of your pump.", comment: "End of lifetime possible solution message.")
        case .reservoirLow:
            return LocalizedString("Replace the reservoir soon.", comment: "Reservoir low possible solution message.")
        case .batteryLow:
            return LocalizedString("The pump battery is almost empty.", comment: "Battery low possible solution message.")
        case .batteryAttention:
            return LocalizedString("Check to make sure there is unrestricted air supply to the opening for ventilation on the pump.", comment: "End of lifetime possible solution message.")
        case .tempBasalCanceled:
            return LocalizedString("Make sure that the cancellation was intentional. Program a new temporary basal rate if required.", comment: "Temporary basal rate canceled possible solution message.")
        case .lowDeliveryRate:
            return LocalizedString("Make sure the delivered amounts are sufficient for your insulin needs and stay near your device until this warning disappears.", comment: "Low delivery rate possible solution message.")
        case .bolusCanceled:
            return LocalizedString("Note the insulin amount already delivered and schedule a new bolus if necessary.", comment: "Bolus canceled possible solution message.")
        case .endOfReservoirTime:
            return LocalizedString("Replace the reservoir as soon as possible.", comment: "End of reservoir time possible solution message.")
        case .stopWarning:
            return LocalizedString("Return to App and resume.", comment: "Stop warning possible solution message.")
        default:
            return nil
        }
    }
    
    public var hasInApp: Bool {
        return true
    }
    
    public var hasUserNotification: Bool {
        return true
    }
    
    public var localizedTitle: String {
        return annunciationTitle
    }
    
    public var localizedMessage: String {
        return [annunciationMessageCause, annunciationMessageSolution]
            .compactMap { $0 }
            .joined(separator: " ")
    }
    
    public var localizedDismissActionLabel: String {
        return LocalizedString("OK", comment: "Alert acknowledgment OK button")
    }
    
    // Prioritization of this EMWR message.  Higher rank wins.
    public var rank: Int {
        return type.rank
    }
}

extension AnnunciationType {
    public var rank: Int {
        // E > M > W > R
        switch classification {
        case .error:
            return 100
        case .maintenance:
            switch self {
            case .occlusionDetected:
                return 90
            default:
                return 80
            }
        case .warning:
            return 40
        case .reminder:
            return 10
        default:
            return 0
        }
    }
}

extension AnnunciationType {
    public enum Classification {
        /// Annunciations with Error (E) importance
        case error
        /// Annunciations with Maintenance (M) importance
        case maintenance
        /// Annunciations with Warning (W) importance
        case warning
        /// Annunciations with Reminder (R) importance
        case reminder
    }

    public var classification: Classification? {
        switch self {
        case .mechanicalIssue, .batteryError:
            return .error
        case .endOfPumpLifetime, .reservoirIssue, .reservoirEmpty, .batteryEmpty, .automaticOff, .occlusionDetected, .primingIssue, .pumpNotConfigured:
            return .maintenance
        case .endOfLifetime, .reservoirLow, .batteryLow, .batteryAttention, .tempBasalCanceled, .lowDeliveryRate, .bolusCanceled, .endOfReservoirTime, .stopWarning:
            return .warning
        default:
            return nil
        }
    }
}

extension AnnunciationType.Classification {
    public var title: String {
        switch self {
        case .error:
            return LocalizedString("Error", comment: "Title of an error annunciation level")
        case .maintenance:
            return LocalizedString("Maintenance", comment: "Title of a maintenance annunciation level")
        case .warning:
            return LocalizedString("Warning", comment: "Title of a warning annunciation level")
        case .reminder:
            return LocalizedString("Reminder", comment: "Title of an error annunciation level")
        }
    }
    
    public var repeatFrequency: TimeInterval? {
        switch self {
        case .error, .maintenance:
            return nil
        case .warning:
            return nil
        case .reminder:
            return nil
        }
    }
    public var isRepeating: Bool {
        return repeatFrequency != nil
    }
}

extension AnnunciationType {
    public var isInsulinDeliveryStopped: Bool {
        return classification == .error || classification == .maintenance
    }
    
    public var insulinStatusHighlightLocalizedString: String? {
        switch classification {
        case .error, .maintenance:
            // Only EMs merit a status highlight
            switch self {
            case .occlusionDetected:
                return NSLocalizedString("Occlusion", comment: "Status highlight text for occlusion")
            default:
                return NSLocalizedString("No Insulin", comment: "Status highlight text for EMs other than occlusion")
            }
        case .warning, .reminder:
            return nil
        case .none:
            return nil
        }
    }
    
    func insulinDeliveryStatusProblemHintLocalizedString(automaticDosingEnabled: Bool) -> String? {
        switch self {
        case .automaticOff:
            // Not supported.
            return nil
        case .batteryAttention:
            return NSLocalizedString("Energy supply to the battery is restricted.", comment: "Battery attention problem descriptive hint text")
        case .batteryEmpty:
            return NSLocalizedString("Battery empty.", comment: "Battery empty problem descriptive hint text")
        case .batteryError:
            return NSLocalizedString("Battery error.", comment: "Battery error problem descriptive hint text")
        case .batteryLow:
            return NSLocalizedString("The pump battery is almost empty.", comment: "Battery low problem descriptive hint text")
        case .endOfReservoirTime:
            return NSLocalizedString("Reservoir expired.", comment: "End of reservoir time problem descriptive hint text")
        case .lowDeliveryRate:
            guard !automaticDosingEnabled else {
                return NSLocalizedString("Insulin is being delivered more slowly than expected. Tidepool Loop will continue to make adjustments to your insulin delivery to meet your needs. Stay near your device until this warning disappears.", comment: "Low delivery rate problem descriptive hint text when automatic dosing is enabled")
            }
            return NSLocalizedString("The pump could not temporarily deliver the insulin amount that is programmed for the basal rate or bolus, however the pump will attempt to recover the missed insulin. Make sure the delivered amounts are sufficient for your insulin needs and stay near your device until this warning disappears.", comment: "Low delivery rate problem descriptive hint text when automatic dosing is disabled")
        case .mechanicalIssue:
            return NSLocalizedString("Insulin delivery stopped.", comment: "Mechanical issue problem descriptive hint text")
        case .occlusionDetected:
            return NSLocalizedString("Insulin delivery stopped.", comment: "Occlusion detected problem descriptive hint text")
        case .primingIssue:
            return NSLocalizedString("Reservoir needle not filled.", comment: "Priming issue problem descriptive hint text")
        case .pumpNotConfigured:
            return NSLocalizedString("The pump system is no longer working.", comment: "Pump not configured problem descriptive hint text")
        case .reservoirEmpty:
            return NSLocalizedString("Reservoir empty.", comment: "Reservoir empty problem descriptive hint text")
        case .reservoirIssue:
            return NSLocalizedString("Programmed insulin amount differs from detected insulin amount.", comment: "Reservoir issue problem descriptive hint text")
        default:
            return isInsulinDeliveryStopped ? NSLocalizedString("Insulin delivery stopped.", comment: "Descriptive hint problem text when insulin delivery is stopped") : nil
        }
    }
    
    var insulinDeliveryStatusSolutionHintLocalizedString: String? {
        switch self {
        case .batteryAttention:
            return LocalizedString("Make sure there is unrestricted air supply to the opening of the pump.", comment: "Battery attention solution descriptive hint text")
        case .batteryLow:
            return LocalizedString("Replace the reservoir soon.", comment: "Battery low solution descriptive hint text")
        case .lowDeliveryRate:
            return nil
        case .mechanicalIssue:
            return LocalizedString("Replace the reservoir now. If the error is still not resolved, replace the pump base.", comment: "Mechanical issue solution descriptive hint text")
        case .pumpNotConfigured:
            return LocalizedString("Replace the reservoir to restart insulin delivery.", comment: "Pump not configured solution descriptive hint text")
        default:
            return nil
        }
    }

    public func insulinDeliveryStatusLocalizedString(automaticDosingEnabled: Bool = true) -> String? {
        return insulinDeliveryStatusProblemHintLocalizedString(automaticDosingEnabled: automaticDosingEnabled).map { $0 + (insulinDeliveryStatusSolutionHintLocalizedString.map { " " + $0 } ?? "") }
    }

    public static var temporaryAnnunciationTypes: [AnnunciationType] {
        [.batteryAttention, .lowDeliveryRate]
    }

    public var timeoutInterval: TimeInterval? {
        switch self {
        case .batteryAttention: return .minutes(15)
        case .lowDeliveryRate: return .minutes(60)
        default: return nil
        }
    }
}

public enum AnnunciationError: Error {
    case invalidAlertIdentifier
}
