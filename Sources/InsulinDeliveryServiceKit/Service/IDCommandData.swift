//
//  IDCommandData.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit
import os.log

//MARK: - Support Server Implementation
class IDCommandDataCharacteristic: E2EProtection {
    public var e2eCounter: UInt8 = 0
    public weak var e2eDelegate: E2EProtectionDelegate?
    
    var messageQueue: MessagingQueue

    public init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }
    
    func sendReadBasalRateProfileResponse(basalProfile: [BasalSegment], templateNumber: UInt8 = 1) {
        let groupsOfBasalSegments: [[BasalSegment]] = basalProfile.chunked(into: 3)
        groupsOfBasalSegments.enumerated().forEach { (index, basalProfile) in
            let response = createReadBasalRateProfileResponse(for: basalProfile, templateNumber: templateNumber)
            ConsoleOut.shared.logMessage(message: "\(#function) read basal rate profile response: \(response.hexadecimalString)")
            sendResponse(response)
        }
    }
    
    func createReadBasalRateProfileResponse(for basalSegments: [BasalSegment], templateNumber: UInt8) -> Data {
        guard basalSegments.count <= 3,
              let firstSegment = basalSegments.first else
        {
            fatalError("A write basal rate profile request must have at least 1 segment and can only write up to 3 segments at once")
        }
        
        var flags: ReadBasalRateFlags = .allZeros
        var response = Data(templateNumber)
        response.append(firstSegment.index)
        response.append(UInt16(firstSegment.duration.minutes))
        response.append(firstSegment.rate.sfloat)
        
        if let secondSegment = basalSegments[safe: 1] {
            flags.update(with: .secondTimeBlockPresent)
            response.append(UInt16(secondSegment.duration.minutes))
            response.append(secondSegment.rate.sfloat)
        }
        
        if let thirdSegment = basalSegments[safe: 2] {
            flags.update(with: .thirdTimeBlockPresent)
            response.append(UInt16(thirdSegment.duration.minutes))
            response.append(thirdSegment.rate.sfloat)
        }
        
        // add the flags once all the segments are accounted for
        response.insert(flags.rawValue, at: 0)
        
        // add the opcode
        response.insert(contentsOf: Data(IDCommandControlPointOpcode.readBasalRateTemplateResponse.rawValue), at: 0)
        return response
    }
    
    func sendGetTemplateStatusAndDetailsResponse(basalRateProfileConfigured: Bool) {
        let configurableFlags = basalRateProfileConfigured ? 3 : 1 // 1 = the profile is configurable but not configured, 3 = the profile is configurable and configured
        var response = Data(IDCommandControlPointOpcode.getTemplateStatusAndDetailsResponse.rawValue)
        response.append(IDTemplateType.profileBasalRate.rawValue)
        response.append(UInt8(1)) // starting template number
        response.append(UInt8(1)) // number of templates
        response.append(UInt8(24)) // max number of time blocks
        response.append(configurableFlags)
        sendResponse(response)
    }
    
    public func sendResponse(_ response: Data) {
        if messageQueue.gattServer.isCharacteristicSubscribed(InsulinDeliveryCharacteristicUUID.commandData.cbUUID) == true {
            var response = response
            if e2eDelegate?.isE2EProtectionSupported ?? false {
                incrementE2ECounter()
                response = appendingE2EProtection(response)
            }
            messageQueue.addQueueItem(
                UUIDValuePair(
                    uuid: InsulinDeliveryCharacteristicUUID.commandData.cbUUID,
                    value: response
                )
            )
        } else {
            ConsoleOut.shared.logMessage(message: "\(#function): ID Command Data characteristic is not configured for indications")
        }
    }
}

//MARK: - Support Client Implementation
public class IDCommandDataHandler: E2EProtection {
    public var e2eCounter: UInt8 = 1
    
    public weak var e2eDelegate: E2EProtectionDelegate?
    
    fileprivate let log = OSLog(category: "InsulinDeliveryCommandData")
    
    private let expectedMinResponseLength = 6
    
    let basalRateProfileTemplateNumber: UInt8
    
    var readBasalProfile: [BasalSegment]?
    
    var writeBasalProfile: [BasalSegment]?
    
    public init(basalRateProfileTemplateNumber: UInt8 = 1) {
        self.basalRateProfileTemplateNumber = basalRateProfileTemplateNumber
    }
    
    //MARK: - Response Handling
    public func handleResponse(_ response: Data) -> DeviceCommResult<Any?> {
        guard e2eDelegate?.isE2EProtectionSupported == false || (e2eDelegate?.isE2EProtectionSupported == true && response.isCRCValid) else {
            return .failure(.invalidCRC)
        }
        
        guard response.count >= expectedMinResponseLength else {
            return .failure(.invalidFormat)
        }
        
        var index = 0
        let opcode = IDCommandControlPointOpcode(rawValue: response[response.startIndex.advanced(by: index)...].to(IDCommandControlPointOpcode.RawValue.self))
        index += 2
        
        switch opcode {
        case .readBasalRateTemplateResponse:
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
            
            var rate = Data(response[response.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
            index += 2
            
            readBasalProfile?.append(BasalSegment(index: timeblockIndex, rate: rate, duration: TimeInterval(minutes: Int(duration))))
            
            guard flags.contains(.secondTimeBlockPresent) else {
                log.info("read basal segments %{public}@", String(describing: readBasalProfile))
                return .success(nil)
            }
            
            timeblockIndex += 1
            
            duration = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
            index += 2
            
            rate = Data(response[response.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
            index += 2
            
            readBasalProfile?.append(BasalSegment(index: timeblockIndex, rate: rate, duration: TimeInterval(minutes: Int(duration))))
            
            guard flags.contains(.thirdTimeBlockPresent) else {
                log.info("read basal segments %{public}@", String(describing: readBasalProfile))
                return .success(nil)
            }
            
            timeblockIndex += 1
            
            duration = response[response.startIndex.advanced(by: index)...].to(UInt16.self)
            index += 2
            
            rate = Data(response[response.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
            index += 2
            
            readBasalProfile?.append(BasalSegment(index: timeblockIndex, rate: rate, duration: TimeInterval(minutes: Int(duration))))
            
            log.info("read basal segments %{public}@", String(describing: readBasalProfile))
            return .success(nil)
        case .getTemplateStatusAndDetailsResponse:
            // not currently used
            let templateType = IDTemplateType(rawValue: response[response.startIndex.advanced(by: index)...].to(IDTemplateType.RawValue.self))
            index += 1
            let startingTemplateNumber = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
            index += 1
            let numberOfTemplates = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
            index += 1
            let maxNumberOfTimeBlocks = response[response.startIndex.advanced(by: index)...].to(UInt8.self)
            index += 1
            var flags: [UInt8] = []
            for _ in 0..<Int((Double(numberOfTemplates)/4).rounded(.up)) {
                flags.append(response[response.startIndex.advanced(by: index)...].to(UInt8.self))
            }
            
            return .success((templateType,startingTemplateNumber,maxNumberOfTimeBlocks,flags))
        case .readISFProfileTemplatesResponse:
            // not currently used
            return .success(nil)
        case .readI2CHOProfileTemplatesResponse:
            // not currently used
            return .success(nil)
        case .readTargetGlucoseRangeProfileTemplatesResponse:
            // not currently used
            return .success(nil)
        default:
            log.error("Response opcode not known. Complete response: %{public}@", response.hexadecimalString)
            return .failure(.opcodeUnknown(response.hexadecimalString))
        }
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
