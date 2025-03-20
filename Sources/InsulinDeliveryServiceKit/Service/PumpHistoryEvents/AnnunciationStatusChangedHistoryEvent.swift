//
//  AnnunciationStatusChangedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

struct AnnunciationStatusChangedHistoryEvent {
    let part1: AnnunciationStatusChangedPart1HistoryEvent

    let part2: AnnunciationStatusChangedPart2HistoryEvent

    var sequenceNumbers: [HistoryEventSequenceNumber] {
        [part1.sequenceNumber, part2.sequenceNumber]
    }

    var relativeOffset: TimeInterval {
        // the relative offset is the same for part 1 and part 2
        part1.relativeOffset
    }

    init?(part1: AnnunciationStatusChangedPart1HistoryEvent, part2: AnnunciationStatusChangedPart2HistoryEvent) {
        guard part1.relativeOffset == part2.relativeOffset else { return nil }
        self.part1 = part1
        self.part2 = part2
    }

    var flag: AnnunciationStatusFlag {
        var flag: AnnunciationStatusFlag = .presentAnnunciation
        if part1.flag.contains(.auxInfo1Present) { flag.insert(.presentAuxInfo1) }
        if part1.flag.contains(.auxInfo2Present) { flag.insert(.presentAuxInfo2) }
        if part2.flag.contains(.auxInfo3Present) { flag.insert(.presentAuxInfo3) }
        if part2.flag.contains(.auxInfo4Present) { flag.insert(.presentAuxInfo4) }
        if part2.flag.contains(.auxInfo5Present) { flag.insert(.presentAuxInfo5) }
        return flag
    }

    var annunciationIdentifier: AnnunciationIdentifier {
        part1.annunciationIdentifier
    }

    var annunciationType: AnnunciationType {
        part1.annunciationType
    }

    var annunciationStatus: AnnunciationStatus {
        part1.annunciationStatus
    }

    var auxInfo1: Data {
        part1.auxInfo1
    }

    var auxInfo2: Data {
        part1.auxInfo2
    }

    var auxInfo3: Data {
        part2.auxInfo3
    }

    var auxInfo4: Data {
        part2.auxInfo4
    }

    var auxInfo5: Data {
        part2.auxInfo5
    }

    var annunciation: Annunciation {
        GeneralAnnunciation(type: annunciationType, identifier: annunciationIdentifier)
    }
}

public struct AnnunciationStatusChangedPart1HistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .annunciationStatusChangedPart1

    public let sequenceNumber: HistoryEventSequenceNumber

    public let relativeOffset: TimeInterval

    public let auxData: Data
    
    public init(sequenceNumber: HistoryEventSequenceNumber, relativeOffset: TimeInterval, auxData: Data) {
        self.sequenceNumber = sequenceNumber
        self.relativeOffset = relativeOffset
        self.auxData = auxData
    }

    var flag: AnnunciationStatusChangedPart1Flag {
        AnnunciationStatusChangedPart1Flag(rawValue: auxData[auxData.startIndex...].to(AnnunciationStatusChangedPart1Flag.RawValue.self))
    }

    var annunciationIdentifier: AnnunciationIdentifier {
        auxData[auxData.startIndex.advanced(by: 1)...].to(AnnunciationIdentifier.self)
    }

    var annunciationType: AnnunciationType {
        AnnunciationType(rawValue: auxData[auxData.startIndex.advanced(by: 3)...].to(AnnunciationType.RawValue.self)) ?? .undetermined
    }

    var annunciationStatus: AnnunciationStatus {
        AnnunciationStatus(rawValue: auxData[auxData.startIndex.advanced(by: 5)...].to(AnnunciationStatus.RawValue.self)) ?? .undetermined
    }

    var auxInfo1: Data {
        guard flag.contains(.auxInfo1Present) else { return Data() }
        return Data(auxData[auxData.startIndex.advanced(by: 6)...].to(UInt16.self))
    }

    var auxInfo2: Data {
        guard flag.contains(.auxInfo2Present) else { return Data() }
        return Data(auxData[auxData.startIndex.advanced(by: 8)...].to(UInt16.self))
    }
}

extension AnnunciationStatusChangedPart1HistoryEvent {
    public var description: String {
        "AnnunciationStatusChangedPart1HistoryEvent annunciationType: \(annunciationType), status: \(annunciationStatus), flags: \(flag), auxInfo1: \(auxInfo1.hexadecimalString), auxInfo2: \(auxInfo2.hexadecimalString), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

struct AnnunciationStatusChangedPart2HistoryEvent: PumpHistoryEvent {
    let type: IDHistoryEventType = .annunciationStatusChangedPart2

    let sequenceNumber: HistoryEventSequenceNumber

    let relativeOffset: TimeInterval

    let auxData: Data

    var flag: AnnunciationStatusChangedPart2Flag {
        AnnunciationStatusChangedPart2Flag(rawValue: auxData[auxData.startIndex...].to(AnnunciationStatusChangedPart2Flag.RawValue.self))
    }

    var auxInfo3: Data {
        guard flag.contains(.auxInfo3Present) else { return Data() }
        return Data(auxData[auxData.startIndex.advanced(by: 1)...].to(UInt16.self))
    }

    var auxInfo4: Data {
        guard flag.contains(.auxInfo4Present) else { return Data() }
        return Data(auxData[auxData.startIndex.advanced(by: 3)...].to(UInt16.self))
    }

    var auxInfo5: Data {
        guard flag.contains(.auxInfo5Present) else { return Data() }
        return Data(auxData[auxData.startIndex.advanced(by: 5)...].to(UInt16.self))
    }
}

extension AnnunciationStatusChangedPart2HistoryEvent {
    var description: String {
        "AnnunciationStatusChangedPart2HistoryEvent flags: \(flag), auxInfo3: \(auxInfo3.hexadecimalString), auxInfo4: \(auxInfo4.hexadecimalString), auxInfo5: \(auxInfo5.hexadecimalString), sequenceNumber: \(sequenceNumber), relativeOffset: \(relativeOffset), auxData: \(auxData.hexadecimalString)"
    }
}

//MARK: - Enumerations

struct AnnunciationStatusChangedPart1Flag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8

    static let auxInfo1Present = AnnunciationStatusChangedPart1Flag(rawValue: 1 << 0)
    static let auxInfo2Present = AnnunciationStatusChangedPart1Flag(rawValue: 1 << 1)
    static let allZeros = AnnunciationStatusChangedPart1Flag([])

    static let debugDescriptions: [AnnunciationStatusChangedPart1Flag:String] = {
        var descriptions = [AnnunciationStatusChangedPart1Flag:String]()
        descriptions[.auxInfo1Present] = "auxInfo1Present"
        descriptions[.auxInfo2Present] = "auxInfo2Present"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in AnnunciationStatusChangedPart1Flag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "\(result)"
    }
}

struct AnnunciationStatusChangedPart2Flag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8

    static let auxInfo3Present = AnnunciationStatusChangedPart2Flag(rawValue: 1 << 0)
    static let auxInfo4Present = AnnunciationStatusChangedPart2Flag(rawValue: 1 << 1)
    static let auxInfo5Present = AnnunciationStatusChangedPart2Flag(rawValue: 1 << 2)
    static let allZeros = AnnunciationStatusChangedPart2Flag([])

    static let debugDescriptions: [AnnunciationStatusChangedPart2Flag:String] = {
        var descriptions = [AnnunciationStatusChangedPart2Flag:String]()
        descriptions[.auxInfo3Present] = "auxInfo3Present"
        descriptions[.auxInfo4Present] = "auxInfo4Present"
        descriptions[.auxInfo5Present] = "auxInfo5Present"
        return descriptions
    }()

    public var description: String {
        var result = [String]()
        for (key, value) in AnnunciationStatusChangedPart2Flag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "\(result)"
    }
}
