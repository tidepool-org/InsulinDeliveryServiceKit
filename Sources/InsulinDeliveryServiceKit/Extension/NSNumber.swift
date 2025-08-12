//
//  NSNumber.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public extension NumberFormatter {
    func string(from number: Double) -> String? {
        return string(from: NSNumber(value: number))
    }
}
