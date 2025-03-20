//
//  PumpExpiresSoonAnnunciation.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-18.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public struct PumpExpiresSoonAnnunciation: Annunciation {
    nonisolated(unsafe) public static let type: AnnunciationType = .endOfLifetime
    public let type: AnnunciationType = type

    public let identifier: UInt16

    public let timeRemaining: TimeInterval?
    
    public var annunciationMessageCauseArgs: [CVarArg] {
        let defaultString = NSLocalizedString("soon", comment: "Fallback string for Pump Expiration date annunciation")
        // NOTE: This used to use RelativeDateTimeFormatter but it would give different calculated results than
        // DateComponentsFormatter, which is used here and in other places for consistency.
        let defaultFormat = NSLocalizedString("in %@", comment: "Default format for relative time when we have a time.")
        
        if let timeRemaining = timeRemaining,
           let expirationTimeString = DateComponentsFormatter.expirationTimeFormatter.string(from: timeRemaining) {
            return [String(format: defaultFormat, expirationTimeString)]
        } else {
            return [defaultString]
        }
    }
}
