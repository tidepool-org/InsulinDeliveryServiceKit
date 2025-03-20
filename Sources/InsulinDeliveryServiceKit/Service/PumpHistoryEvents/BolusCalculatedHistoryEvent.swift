//
//  BolusCalculatedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

struct BolusCalculatedHistoryEvent {
    let part1: BolusCalculatedPart1HistoryEvent

    let part2: BolusCalculatedPart2HistoryEvent

    var sequenceNumbers: [HistoryEventSequenceNumber] {
        [part1.sequenceNumber, part2.sequenceNumber]
    }

    var relativeOffset: TimeInterval {
        // the relative offset is the same for part 1 and part 2
        part1.relativeOffset
    }

    var recommendedFastAmountMeal: Double { part1.recommendedFastAmountMeal }

    var recommendedFastAmountCorrection: Double { part1.recommendedFastAmountCorrection }

    var recommendedExtendedAmountMeal: Double { part1.recommendedExtendedAmountMeal }

    var recommendedExtendedAmountCorrection: Double { part1.recommendedExtendedAmountCorrection }

    var confirmedFastAmountMeal: Double { part2.confirmedFastAmountMeal }

    var confirmedFastAmountCorrection: Double { part2.confirmedFastAmountCorrection }

    var confirmedExtendedAmountMeal: Double { part2.confirmedExtendedAmountMeal }

    var confirmedExtendedAmountCorrection: Double { part2.confirmedExtendedAmountCorrection }

    init?(part1: BolusCalculatedPart1HistoryEvent, part2: BolusCalculatedPart2HistoryEvent) {
        guard part1.relativeOffset == part2.relativeOffset else { return nil }
        self.part1 = part1
        self.part2 = part2
    }
}

struct BolusCalculatedPart1HistoryEvent: PumpHistoryEvent {

    let type: IDHistoryEventType = .bolusCalculatedPart1

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var recommendedFastAmountMeal: Double {
        Data(auxData[auxData.startIndex...].to(SFLOAT.self)).sfloatToDouble()
    }

    var recommendedFastAmountCorrection: Double {
        Data(auxData[auxData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var recommendedExtendedAmountMeal: Double {
        Data(auxData[auxData.startIndex.advanced(by: 4)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var recommendedExtendedAmountCorrection: Double {
        Data(auxData[auxData.startIndex.advanced(by: 6)...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension BolusCalculatedPart1HistoryEvent {
    var description: String {
        "BolusDeliveredPart1HistoryEvent recommendedFastAmountMeal: \(recommendedFastAmountMeal), recommendedFastAmountCorrection: \(recommendedFastAmountCorrection), recommendedExtendedAmountMeal: \(recommendedExtendedAmountMeal), recommendedExtendedAmountCorrection: \(recommendedExtendedAmountCorrection), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

struct BolusCalculatedPart2HistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .bolusCalculatedPart2

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var confirmedFastAmountMeal: Double {
        Data(auxData[auxData.startIndex...].to(SFLOAT.self)).sfloatToDouble()
    }

    var confirmedFastAmountCorrection: Double {
        Data(auxData[auxData.startIndex.advanced(by: 2)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var confirmedExtendedAmountMeal: Double {
        Data(auxData[auxData.startIndex.advanced(by: 4)...].to(SFLOAT.self)).sfloatToDouble()
    }

    var confirmedExtendedAmountCorrection: Double {
        Data(auxData[auxData.startIndex.advanced(by: 6)...].to(SFLOAT.self)).sfloatToDouble()
    }
}

extension BolusCalculatedPart2HistoryEvent {
    var description: String {
        "BolusCalculatedPart2HistoryEvent confirmedFastAmountMeal: \(confirmedFastAmountMeal), confirmedFastAmountCorrection: \(confirmedFastAmountCorrection), confirmedExtendedAmountMeal: \(confirmedExtendedAmountMeal), confirmedExtendedAmountCorrection: \(confirmedExtendedAmountCorrection), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}
