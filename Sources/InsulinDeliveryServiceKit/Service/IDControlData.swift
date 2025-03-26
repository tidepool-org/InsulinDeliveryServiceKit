//
//  IDControlData.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit
import os.log

fileprivate let log = OSLog(category: "InsulinDeliveryControlData")

class IDControlData {
    
    private let expectedMinResponseLength = 9
    
    let basalRateProfileTemplateNumber: UInt8
    
    var readBasalSegments: [BasalSegment]?
    
    var writeBasalSegments: [BasalSegment]?
    
    init(basalRateProfileTemplateNumber: UInt8 = 1) {
        self.basalRateProfileTemplateNumber = basalRateProfileTemplateNumber
    }
    
    //MARK: - Response Handling
    func handleResponse(_ response: Data) -> DeviceCommResult<Void> {
        guard response.count >= expectedMinResponseLength else {
            return .failure(.invalidFormat)
        }
        
        var index = 0
        guard let opcode = IDControlPointOpcode(rawValue: response[response.startIndex.advanced(by: index)...].to(IDControlPointOpcode.RawValue.self)),
              opcode == .readBasalRateTemplateResponse
        else {
            log.error("Response opcode not known. Complete response: %{public}@", response.hexadecimalString)
            return .failure(.opcodeUnknown(response.hexadecimalString))
        }
        index += 2

        let flags = ReadBasalRateFlags(rawValue: response[response.startIndex.advanced(by: index)...].to(ReadBasalRateFlags.RawValue.self))
        index += 1
        
        let basalRateProfileNumber = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
        guard basalRateProfileNumber == basalRateProfileTemplateNumber else {
            return .failure(.procedureNotApplicable)
        }
        index += 1
                
        var timeblockIndex = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
        index += 1
        
        var duration = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
        index += 2
        
        var rate = Data(response[response.startIndex.advanced(by: index)...].to(SFLOAT.self)).floatToDouble()
        index += 2
        
        readBasalSegments?.append(BasalSegment(index: timeblockIndex, rate: rate, duration: TimeInterval(minutes: Int(duration))))
        
        guard flags.contains(.secondTimeBlockPresent) else {
            log.info("read basal segments %{public}@", String(describing: readBasalSegments))
            return .success
        }
        
        timeblockIndex += 1
        
        duration = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
        index += 2
        
        rate = Data(response[response.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
        index += 2
        
        readBasalSegments?.append(BasalSegment(index: timeblockIndex, rate: rate, duration: TimeInterval(minutes: Int(duration))))
        
        guard flags.contains(.thirdTimeBlockPresent) else {
            log.info("read basal segments %{public}@", String(describing: readBasalSegments))
            return .success
        }
        
        timeblockIndex += 1
        
        duration = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
        index += 2
        
        rate = Data(response[response.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
        index += 2
        
        readBasalSegments?.append(BasalSegment(index: timeblockIndex, rate: rate, duration: TimeInterval(minutes: Int(duration))))
        
        log.info("read basal segments %{public}@", String(describing: readBasalSegments))
        return .success
    }
}


//MARK: - Option sets
struct ReadBasalRateFlags: OptionSet, Hashable, CustomStringConvertible, Sendable{
    let rawValue: UInt8
    
    static let secondTimeBlockPresent = ReadBasalRateFlags(rawValue: 1 << 0)
    static let thirdTimeBlockPresent = ReadBasalRateFlags(rawValue: 1 << 1)
    static let allZeros = ReadBasalRateFlags([])
    
    static let debugDescriptions: [ReadBasalRateFlags:String] = {
        var descriptions = [ReadBasalRateFlags:String]()
        descriptions[.secondTimeBlockPresent] = "secondTimeBlockPresent"
        descriptions[.thirdTimeBlockPresent] = "thirdTimeBlockPresent"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in ReadBasalRateFlags.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "ReadBasalRateFlags(rawValue: \(rawValue)) \(result)"
    }
}
