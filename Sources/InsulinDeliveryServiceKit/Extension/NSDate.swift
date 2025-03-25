//
//  NSDate.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-24.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

extension Date {
    var timeIntervalFromStartOfDay: TimeInterval {
        timeIntervalSince(Calendar.current.startOfDay(for: self))
    }
}
