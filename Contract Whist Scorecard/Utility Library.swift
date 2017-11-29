//
//  Utility Library.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 20/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

class Utility {
    
    static private var _isDevelopment: Bool!
    static private var _isSimulator: Bool!
    
    // MARK: - Execute closure after delay ===================================================================== -
    
    class func mainThread(execute: @escaping ()->()) {
        DispatchQueue.main.async(execute: execute)
    }
    
    class func executeAfter(delay: Double, completion: (()->())?) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when, execute: {
            completion?()
        })
    }
    
    // MARK: - Thumbnail display routine ===================================================================== -
    
    class func setThumbnail(data: Data?, imageView: UIImageView, initials: String = "", label: UILabel! = nil, size: CGFloat = 0) {
        
        // If given data exists then put it in an image view, otherwise use label for a disk with initials in it
        if data != nil {
            imageView.image = UIImage(data: data!)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.alpha = 1.0
            imageView.superview!.bringSubview(toFront: imageView)
            imageView.isHidden = false
            ScorecardUI.veryRoundCorners(imageView, radius: size / 2)
            if label != nil {
                label.isHidden = true
            }
            
        } else if label != nil {
            // No image - replace with an empty disc (possibly containing initials)
            label.text = toInitials(initials)
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 20.0)
            ScorecardUI.darkHighlightStyle(label, lightText: true)
            imageView.isHidden = true
            label.isHidden=false
            ScorecardUI.veryRoundCorners(label, radius: size / 2)
        }
    }
    
    // MARK : Random number generator =======================================================================
    
    class func random(_ maximum: Int) -> Int {
        // Return a random integer between 1 and the maximum value provided
        return Int(arc4random_uniform(UInt32(maximum))) + 1
    }
    
    // MARK: - Get dev, simulator etc ============================================================= -

    public static var isSimulator: Bool {
        get {
            if _isSimulator == nil {
                #if arch(i386) || arch(x86_64)
                    _isSimulator = true
                #else
                    _isSimulator = false
                #endif
            }
            return _isSimulator
        }
    }
        
    public static var isDevelopment: Bool {
        get {
            if _isDevelopment == nil {
                _isDevelopment = (UserDefaults.standard.string(forKey: "database") == "development")
            }
            return _isDevelopment
        }
    }
    
    // MARK: - String manipulation ============================================================================ -
    
    class func toInitials(_ input: String) -> String {
        var output = ""
        let words = input.split(at: " ").map{String($0)}
        if words.count > 0 {
            for word in 0...(words.count-1) {
                let letter = words[word].left(1).uppercased()
                if letter >= "A" && letter <= "Z" {
                    output = output + letter
                }
            }
        }
        
        return output
    }
    
    class func dateString(_ date: Date, format: String = "dd/MM/yyyy", localized: Bool = true) -> String {
        let formatter = DateFormatter()
        if localized {
            formatter.setLocalizedDateFormatFromTemplate(format)
        } else {
            formatter.dateFormat = format
        }
        return formatter.string(from: date)
    }
    
    class func dateFromString(_ dateString: String, format: String = "dd/MM/yyyy") -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.date(from: dateString)
    }
    
    // MARK: - Percentages and quotients (with rounding to integer and protection from divide by zero) =============== -
    
    class func percent(_ numerator: CGFloat, _ denominator: CGFloat) -> CGFloat {
        // Take percentage of 2 numbers - return 0 if denominator is 0
        return (denominator == 0 ? 0 : (CGFloat(numerator) / CGFloat(denominator)) * 100)
    }
    
    class func roundPercent(_ numerator: CGFloat, _ denominator: CGFloat) -> Int {
        var percent = self.percent(CGFloat(numerator), CGFloat(denominator))
        percent.round()
        return Int(percent)
    }
    
    class func percent(_ numerator: Int64, _ denominator: Int64) -> CGFloat {
        // Take percentage of 2 numbers - return 0 if denominator is 0
        return CGFloat(denominator == 0 ? 0 : (CGFloat(numerator) / CGFloat(denominator)) * 100)
    }
    
    class func roundPercent(_ numerator: Int64, _ denominator: Int64) -> Int {
        var percent = self.percent(CGFloat(numerator), CGFloat(denominator))
        percent.round()
        return Int(percent)
    }
    
    class func quotient(_ numerator: CGFloat, _ denominator: CGFloat) -> CGFloat {
        // Take quotient of 2 numbers - return 0 if denominator is 0
        return (denominator == 0 ? 0 : (CGFloat(numerator) / CGFloat(denominator)))
    }
    
    class func roundQuotient(_ numerator: CGFloat, _ denominator: CGFloat) -> Int {
        var quotient = self.percent(CGFloat(numerator), CGFloat(denominator))
        quotient.round()
        return Int(quotient)
    }
    
    class func quotient(_ numerator: Int64, _ denominator: Int64) -> CGFloat {
        // Take quotient of 2 numbers - return 0 if denominator is 0
        return CGFloat(denominator == 0 ? 0 : (CGFloat(numerator) / CGFloat(denominator)))
    }
    
    class func roundQuotient(_ numerator: Int64, _ denominator: Int64) -> Int {
        var quotient = self.quotient(CGFloat(numerator), CGFloat(denominator))
        quotient.round()
        return Int(quotient)
    }
    
    class func roundQuotient(_ numerator: Int, _ denominator: Int) -> Int {
        var quotient = self.quotient(CGFloat(numerator), CGFloat(denominator))
        quotient.round()
        return Int(quotient)
    }
    
    //MARK: Cloud functions - get field from cloud for various types =====================================
    
    class func objectString(cloudObject: CKRecord, forKey: String) -> String! {
        let string = cloudObject.object(forKey: forKey)
        if string == nil {
            return nil
        } else {
            return string as! String?
        }
    }
    
    class func objectDate(cloudObject: CKRecord, forKey: String) -> Date! {
        let date = cloudObject.object(forKey: forKey)
        if date == nil {
            return nil
        } else {
            return date as! Date?
        }
    }
    
    class func objectInt(cloudObject: CKRecord, forKey: String) -> Int64 {
        let int = cloudObject.object(forKey: forKey)
        if int == nil {
            return 0
        } else {
            return int as! Int64
        }
    }
    
    class func objectDouble(cloudObject: CKRecord, forKey: String) -> Double {
        let double = cloudObject.object(forKey: forKey)
        if double == nil {
            return 0
        } else {
            return double as! Double
        }
    }
    
    class func objectImage(cloudObject: CKRecord, forKey: String) -> NSData?{
        var result: NSData? = nil
        
        if let image = cloudObject.object(forKey: forKey) {
            let imageAsset = image as! CKAsset
            if let imageData = try? Data.init(contentsOf: imageAsset.fileURL) {
                result = imageData as NSData?
            }
        }
        return result
    }
    
    //MARK: Cloud functions - prepare image to transmit to cloud ============================================
    
    class func imageToObject(cloudObject: CKRecord, thumbnail: NSData?, name: String) {
        // Note that this will be asynchronous and hence temporary image should not be deleted until completion
        if thumbnail != nil {
            let imageData = thumbnail! as Data
            // Resize the image
            let originalImage = UIImage(data: imageData)!
            let scalingFactor = (originalImage.size.width > 1024) ? 1024 / originalImage.size.width : 1.0
            let scaledImage = UIImage(data: imageData, scale: scalingFactor)!
            // Write the image to local file for temporary use
            let imageFilePath = NSTemporaryDirectory() + name
            let imageFileURL = URL(fileURLWithPath: imageFilePath)
            try? UIImageJPEGRepresentation(scaledImage, 0.8)?.write(to: imageFileURL)
            // Create image asset for upload
            let imageAsset = CKAsset(fileURL: imageFileURL)
            cloudObject.setValue(imageAsset, forKey: "thumbnail")
        }
    }
    
    class func tidyObject(name: String) {
        // Called to remove temporary file after completion
        let imageFilePath = NSTemporaryDirectory() + name
        let imageFileURL = URL(fileURLWithPath: imageFilePath)
        try? FileManager.default.removeItem(at: imageFileURL)
    }
    
    //MARK: Compare version numbers =======================================================================
    
    public enum CompareResult {
        case lessThan
        case equal
        case greaterThan
    }
    
    class func compareVersions(version1: String, build1: Int = 0, version2: String, build2: Int = 0) -> CompareResult {
        // Compares 2 version strings (and optionally build numbers)
        var result: CompareResult = .equal
        var version1Elements: [String]
        var version2Elements: [String]
        var version1Exhausted = false
        var version2Exhausted = false
        var element = 0
        var value1 = ""
        var value2 = ""
        
        version1Elements = version1.components(separatedBy: ".")
        version1Elements.append("\(build1)")
        
        version2Elements = version2.components(separatedBy: ".")
        version2Elements.append("\(build2)")
        
        while true {
            
            // Set up next value in first version string
            if element < version1Elements.count {
                value1 = version1Elements[element]
            } else {
                value1 = "0"
                version1Exhausted = true
            }
            
            // Set up next value in second version string
            if element < version2Elements.count {
                value2 = version2Elements[element]
            } else {
                value2 = "0"
                version2Exhausted = true
            }
            
            // If all checked exit with strings equal
            if version1Exhausted && version2Exhausted {
                // All exhausted
                result = .equal
                break
            }
            
            if value1 < value2 {
                // This value less than - exit
                result = .lessThan
                break
            } else if value1 > value2 {
                // This value greater than - exit
                result = .greaterThan
                break
            }
            
            // Still all equal - try next element
            element += 1
        }
        
        return result
    }
    
    // MARK: - Functions to get view controllers, use main thread and wrapper system level stuff ==============
    
    class func getActiveViewController() -> UIViewController? {
        var activeViewController = UIApplication.shared.keyWindow?.rootViewController
        // Work down through any child view controllers
        while true {
            if activeViewController?.childViewControllers == nil || activeViewController?.childViewControllers.count == 0 {
                break
            }
            activeViewController = activeViewController?.childViewControllers[(activeViewController?.childViewControllers.count)!-1]
        }
        // Now work down through any presented controllers
        while true {
            if activeViewController?.presentedViewController == nil {
                break
            }
            activeViewController = activeViewController?.presentedViewController
        }
        
        return activeViewController
    }
    
    class func debug(_ from: String, _ message: String, showDevice: Bool = false) {
        Utility.mainThread {
            var outputMessage: String
            let timestamp = Utility.dateString(Date(), format: "hh:mm:ss.SS", localized: false)
            outputMessage = "DEBUG(\(from)): \(timestamp)"
            if showDevice {
                #if ContractWhist
                outputMessage = outputMessage + " - Device:\(Scorecard.deviceName)"
                #else
                outputMessage = outputMessage + UIDevice.current.name
                #endif
            }
            outputMessage = outputMessage + " - \(message)"
            
            print(outputMessage)
            #if ContractWhist
                if Config.rabbitMQLogQueue != "" && Config.rabbitMQUri != "" {
                    let scorecard = Scorecard.getScorecard()!
                    if scorecard.logService == nil {
                        scorecard.logService = RabbitMQService(purpose: .other, type: .queue, serviceID: Config.rabbitMQUri)
                        scorecard.logQueue = scorecard.logService.startQueue(delegate: scorecard.logService, queueUUID: Config.rabbitMQLogQueue)
                    }
                    scorecard.logQueue.sendBroadcast(data: ["message" : message,
                                                            "timestamp" : timestamp])
                }
            #endif
        }
    }
}

// MARK: - Utility Class for Field Output ==================================================== -

class Field {
    var field: String
    var title: String
    var sequence: Int
    var width: CGFloat
    var hide: Bool
    var align: NSTextAlignment
    
    init(_ field: String,_ title: String, sequence: Int = 0, width: CGFloat, hide: Bool = false, align: NSTextAlignment = .center) {
        self.field = field
        self.title = title
        self.sequence = sequence
        self.width = width
        self.hide = hide
        self.align = align
    }
}

