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
import os.log

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    /// Logs the view cycles like viewDidLoad.
    static let debugInfo = OSLog(subsystem: subsystem, category: "debug")
}

class Utility {
    
    static private var _isDevelopment: Bool!
    static private var _isSimulator: Bool!
    
    // MARK: - Execute closure after delay ===================================================================== -
    
    class func mainThread(_ message: String = "Utility", suppressDebug: Bool = false, qos: DispatchQoS = .userInteractive, execute: @escaping ()->()) {
        if false && !suppressDebug {
            Utility.debugMessage(message, "About to execute closure on main thread", mainThread: false)
        }
        DispatchQueue.main.async(qos: qos, execute: execute)
        if false && !suppressDebug {
            Utility.debugMessage(message, "Main thread closure executed", mainThread: false)
        }
    }
    
    class func executeAfter(_ message: String="Utility", delay: Double, suppressDebug: Bool = false, qos: DispatchQoS = .userInteractive, completion: (()->())?) {
        if false && !suppressDebug {
            Utility.debugMessage(message, "Queing closure after \(delay)", mainThread: false)
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay, qos: qos, execute: {
            if false && !suppressDebug {
                Utility.debugMessage(message, "About to execute delayed closure", mainThread: false)
            }
            completion?()
            if false && !suppressDebug {
                    Utility.debugMessage(message, "Delayed closure executed", mainThread: false)
            }
        })
    }
    
    // MARK: - Thumbnail display routine ===================================================================== -
    
    class func setThumbnail(data: Data?, imageView: UIImageView, initials: String = "", label: UILabel! = nil, size: CGFloat = 0) {
        
        // If given data exists then put it in an image view, otherwise use label for a disk with initials in it
        if data != nil {
            if size != 0.0 {
                imageView.frame.size = CGSize(width: size, height: size)
            }
            imageView.image = UIImage(data: data!)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.alpha = 1.0
            imageView.superview!.bringSubviewToFront(imageView)
            imageView.isHidden = false
            ScorecardUI.veryRoundCorners(imageView, radius: size / 2)
            if label != nil {
                label.isHidden = true
            }
            
        } else if label != nil {
            // No image - replace with an empty disc (possibly containing initials)
            if size != 0.0 {
                label.frame.size = CGSize(width: size, height: size)
            }
            label.text = toInitials(initials)
            label.textAlignment = .center
            ScorecardUI.thumbnailDiscStyle(label)
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
    
    class func roundQuotient(_ numerator: Int64, _ denominator: Int64) -> Int64 {
        var quotient = self.quotient(CGFloat(numerator), CGFloat(denominator))
        quotient.round()
        return Int64(quotient)
    }
    
    class func roundQuotient(_ numerator: Int16, _ denominator: Int16) -> Int16 {
        var quotient = self.quotient(CGFloat(numerator), CGFloat(denominator))
        quotient.round()
        return Int16(quotient)
    }
    
    class func roundQuotient(_ numerator: Int, _ denominator: Int) -> Int {
        var quotient = self.quotient(CGFloat(numerator), CGFloat(denominator))
        quotient.round()
        return Int(quotient)
    }
    
    class func round(_ value: Double) -> Int {
        var value = value
        value.round()
        return Int(value)
    }
    
    // MARK: - Array helper functions ==================================================================== -
    
    class func sum(_ array: [Int]) -> Int {
        return array.reduce(0) {$0 + $1}
    }
    
    class func toString(_ array: [String]) -> String {
        var result = ""
        
        for (index, element) in array.enumerated() {
            
            if result == "" {
                result = element
            } else {
                if index == array.count-1 {
                    result = result + " and " + element
                } else {
                    result = result + ", " + element
                }
            }
        }
        return result
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
    
    class func objectBool(cloudObject: CKRecord, forKey: String) -> Bool {
        let bool = cloudObject.object(forKey: forKey)
        if bool == nil {
            return false
        } else {
            return bool as! Bool
        }
    }
    
    class func objectImage(cloudObject: CKRecord, forKey: String) -> NSData?{
        var result: NSData? = nil
        
        if let image = cloudObject.object(forKey: forKey) {
            let imageAsset = image as! CKAsset
            if let imageData = try? Data.init(contentsOf: imageAsset.fileURL!) {
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
            ((try? scaledImage.jpegData(compressionQuality: 0.8)?.write(to: imageFileURL)) as ()??)
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
        var value1 = 0
        var value2 = 0
        
        version1Elements = version1.components(separatedBy: ".")
        version1Elements.append("\(build1)")
        
        version2Elements = version2.components(separatedBy: ".")
        version2Elements.append("\(build2)")
        
        while true {
            
            // Set up next value in first version string
            if element < version1Elements.count {
                value1 = Int(version1Elements[element]) ?? 0
            } else {
                value1 = 0
                version1Exhausted = true
            }
            
            // Set up next value in second version string
            if element < version2Elements.count {
                value2 = Int(version2Elements[element]) ?? 0
            } else {
                value2 = 0
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
    
    // MARK: - Animate ============================================================================== -
    
    public class func animate(view: UIView? = nil, duration: TimeInterval = 0.5, curve: UIView.AnimationCurve = .linear, afterDelay: TimeInterval? = 0.0, animations: @escaping ()->()) {
        var view = view
        if view == nil {
            view = Utility.getActiveViewController()!.view!
        }
        view!.layoutIfNeeded()
        let animation = UIViewPropertyAnimator(duration: duration, curve: curve) {
            animations()
            view!.layoutIfNeeded()
        }
        animation.startAnimation(afterDelay: afterDelay ?? 0.01)
    }
    
    // MARK: - Functions to get view controllers, use main thread and wrapper system level stuff ==============
    
    public static var appDelegate: AppDelegate? {
        get {
            if let delegate = UIApplication.shared.delegate as? AppDelegate {
                return delegate
            } else {
                return nil
            }
        }
    }

    public class func getActiveViewController(fullScreenOnly: Bool = false) -> UIViewController? {
        var viewController = UIApplication.shared.keyWindow?.rootViewController
        let fullHeight = viewController?.view.frame.height
        var activeViewController = viewController
        
        // Work down through any child view controllers
        while true {
            if viewController?.children == nil || viewController?.children.count == 0 {
                break
            }
            viewController = viewController?.children[(viewController?.children.count)!-1]
            if !fullScreenOnly || viewController?.view.frame.height == fullHeight {
                activeViewController = viewController
            }
        }
        // Now work down through any presented controllers
        while true {
            if viewController?.presentedViewController == nil {
                break
            }
            viewController = viewController?.presentedViewController
            if !fullScreenOnly || viewController?.view.frame.height == fullHeight {
                activeViewController = viewController
            }
        }
        
        return activeViewController
    }
    
    class func debugMessage(_ from: String, _ message: String, showDevice: Bool = false, force: Bool = false, mainThread: Bool = true) {
        
        func closure() {
            var outputMessage: String
            let timestamp = Utility.dateString(Date(), format: "HH:mm:ss.SS", localized: false)
            outputMessage = "DEBUG(\(from)): \(timestamp)"
            if showDevice {
                #if ContractWhist
                    outputMessage = outputMessage + " - Device:\(Scorecard.deviceName)"
                #else
                    outputMessage = outputMessage + UIDevice.current.name
                #endif
            }
            outputMessage = outputMessage + " - \(message)"
            if ProcessInfo.processInfo.environment["MULTISIM"] == "TRUE" {
                // Running multiple simulators - output to system console
                os_log("%{PUBLIC}@", log:OSLog.debugInfo, type:.info, outputMessage)
            } else {
                print(outputMessage)
                fflush(stdout)
            }
            #if ContractWhist
                // Write to rabbitMQ logs
                if (Config.rabbitMQUri_DevMode != .amqpServer || Scorecard.adminMode || force) && Config.rabbitMQLogQueue != "" && Config.rabbitMQUri != "" {
                    let scorecard = Scorecard.shared
                    if scorecard.logService == nil {
                        scorecard.logService = RabbitMQClientService(purpose: .other, serviceID: Config.rabbitMQUri, deviceName: Scorecard.deviceName)
                        scorecard.logQueue = scorecard.logService.startQueue(delegate: scorecard.logService, queueUUID: Config.rabbitMQLogQueue)
                    }
                    scorecard.logQueue.sendBroadcast(data: ["0" : ["from"      : from,
                                                                   "message"   : message,
                                                                   "timestamp" : timestamp]])
                }
            
                // Write to multi-peer logs
                if Config.multiPeerLogService != "" {
                    MultipeerLogger.logger.write(timestamp: timestamp, source: from, message: message)
                }
            
            #endif
        }
        
        if Utility.isDevelopment || Scorecard.adminMode || force || (Config.multiPeerLogService != "" && MultipeerLogger.logger.connected) {
            if mainThread {
                Utility.mainThread(suppressDebug: true, execute: {
                    closure()
                })
            } else {
                closure()
            }
        }
    }
    
    public static func deviceName() -> String {
        var result = UIDevice.current.name
        if result.left(7) == "Custom-" {
            result = result.mid(8,result.length-7)
        }
        return result
    }
    
    public static func getCloudRecordCount(_ table: String, predicate: NSPredicate? = nil, cursor: CKQueryOperation.Cursor? = nil, runningTotal: Int! = nil, completion: ((Int?)->())? = nil) {
        // Fetch data from cloud
        var queryOperation: CKQueryOperation
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        var result: Int = (runningTotal == nil ? 0 : runningTotal)
        
        if let cursor = cursor {
            queryOperation = CKQueryOperation(cursor: cursor, qos: .userInteractive)
        } else {
            var predicate = predicate
            if predicate == nil {
                predicate = NSPredicate(format: "TRUEPREDICATE")
            }
            let query = CKQuery(recordType: table, predicate: predicate!)
            queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        }
        queryOperation.queuePriority = .veryHigh
        queryOperation.recordFetchedBlock = { (record) -> Void in
            result += 1
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error != nil {
                completion?(nil)
                return
            }
            
            if cursor != nil {
                // More records to come - recurse
                Utility.getCloudRecordCount(table, cursor: cursor, runningTotal: result, completion: completion)
            } else {
                completion?(result)
            }
        }
        
        // Execute the query
        publicDatabase.add(queryOperation)
    }

    // MARK: - FaceTime ======================================================================== -

    private class func faceTimeInternal(phoneNumber:String = "", video: Bool = false, checkOnly: Bool = false) -> Bool {
        var ok = false
        var prefix: String
        if video {
            prefix = "facetime"
        } else {
            prefix = "facetime-audio"
        }
        
        if let faceTimeURL:URL = URL(string: "\(prefix)://\(phoneNumber)") {
            let application:UIApplication = UIApplication.shared
            if (application.canOpenURL(faceTimeURL)) {
                ok = true
                if !checkOnly {
                    application.open(faceTimeURL)
                }
            }
        }
        return ok
    }

    public class func faceTime(phoneNumber:String, video: Bool = false) {
        if Utility.isSimulator {
            Utility.getActiveViewController()?.alertDecision(phoneNumber, title: "", okButtonText: "Call", cancelButtonText: "Cancel")
        } else if !Utility.faceTimeInternal(phoneNumber: phoneNumber, video: video) {
            Utility.getActiveViewController()?.alertMessage("FaceTime not available")
        }
    }

    public class func faceTimeAvailable(video: Bool = false) -> Bool {
        if Utility.isSimulator {
            return true
        } else {
            return Utility.faceTimeInternal(video: video, checkOnly: true)
        }
    }
}

