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
    // Default: no args
    public var annunciationMessageCauseArgs: [CVarArg] { [] }
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
        case .mechanicalIssue:
            return .error
        case .reservoirIssue, .reservoirEmpty, .batteryEmpty, .occlusionDetected, .primingIssue:
            return .maintenance
        case .reservoirLow, .batteryLow, .tempBasalCanceled, .bolusCanceled:
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
}

public enum AnnunciationError: Error {
    case invalidAlertIdentifier
}
