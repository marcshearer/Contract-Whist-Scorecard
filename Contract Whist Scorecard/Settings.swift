//
//  Settings.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 04/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation
import CloudKit

class Settings : Equatable {
    
    /** Note that if you add a property you also need to add it to the setValue(forKey:) method */
    
    public var bonus2 = true
    public var cards = [13, 1]
    public var bounceNumberCards: Bool = false
    public var trumpSequence = ["♣︎", "♦︎", "♥︎", "♠︎", "NT"]
    public var syncEnabled = false
    public var saveHistory = true
    public var saveLocation = false
    public var receiveNotifications = false
    public var allowBroadcast = true
    public var alertVibrate = true
    public var thisPlayerUUID = ""
    public var onlineGamesEnabled: Bool = false
    public var faceTimeAddress = ""
    public var prefersStatusBarHidden = true
    public var colorTheme = Themes.defaultName
    public var termsDate: Date!
    public var termsDevice = ""
    
    public var saveStats: Bool = true           // Only used in a game (not saved) - initially set to same as saveHistory but can be overridden
        
    public func setValue(_ value: Any?, forKey label: String) {
        switch label {
        case "bonus2":
            self.bonus2 = value as! Bool
        case "cards":
            self.cards = value as! [Int]
        case "bounceNumberCards":
            self.bounceNumberCards = value as! Bool
        case "trumpSequence":
            self.trumpSequence = value as! [String]
        case "syncEnabled":
            self.syncEnabled = value as! Bool
        case "saveHistory":
            self.saveHistory = value as! Bool
        case "saveLocation":
            self.saveLocation = value as! Bool
        case "receiveNotifications":
            self.receiveNotifications = value as! Bool
        case "alertVibrate":
            self.alertVibrate = value as! Bool
        case "allowBroadcast":
            self.allowBroadcast = value as! Bool
        case "faceTimeAddress":
            self.faceTimeAddress = value as! String
        case "onlineGamesEnabled":
            self.onlineGamesEnabled = value as! Bool
        case "prefersStatusBarHidden":
            self.prefersStatusBarHidden = value as! Bool
        case "colorTheme":
            self.colorTheme = value as! String
        case "thisPlayerUUID":
            self.thisPlayerUUID = value as! String
        case "termsDate":
            self.termsDate = value as! Date?
        case "termsDevice":
            self.termsDevice = value as! String
        case "saveStats":
            self.saveStats = value as! Bool
        default:
            fatalError("Error setting settings value")
        }
    }
    
    public func value(forKey key: String) -> Any? {
        let mirror = Mirror(reflecting: self)
        if let child = mirror.children.first(where: { $0.label == key }) {
            return child.value
        } else {
            return nil
        }
    }
    
    public func copy() -> Settings {
        let copy = Settings()
        _ = self.copy(from: self, to: copy)
        return copy
    }
        
    private func copy(from: Settings, to: Settings) -> Int {
        var copied = 0
        let toMirror = Mirror(reflecting: to)
        let fromMirror = Mirror(reflecting: from)
        for toChild in toMirror.children {
            if let fromChild = fromMirror.children.first(where: { $0.label == toChild.label }) {
                if let label = toChild.label {
                    let fromValue = fromChild.value as? NSObject
                    to.setValue(fromValue, forKey: label)
                    copied += 1
                } else {
                    fatalError("Error copying settings")
                }
            } else {
                fatalError("Error copying settings")
            }
        }
        return copied
    }
    
    public static func == (lhs: Settings, rhs: Settings) -> Bool {
        var same = true
        
        let leftMirror = Mirror(reflecting: lhs)
        let rightMirror = Mirror(reflecting: rhs)
        for leftChild in leftMirror.children {
            if let rightChild = rightMirror.children.first(where: { $0.label == leftChild.label }) {
                let leftValue = leftChild.value as? NSObject
                let rightValue = rightChild.value as? NSObject
                if leftValue != rightValue {
                    same = false
                }
            } else {
                fatalError("Invalid settings comparison")
            }
        }
        return same
    }
    
    public func load() {
        
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let label = child.label {
                if label != "saveStats" {
                    self.setValue(UserDefaults.standard.object(forKey: label), forKey: label)
                }
            } else {
                fatalError("Error saving settings locally")
            }
        }
    }
    
    public func save() {
        
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let label = child.label {
                let value = child.value as? NSObject
                if label != "saveStats" {
                    UserDefaults.standard.set(value, forKey: label)
                }
            } else {
                fatalError("Error saving settings locally")
            }
        }
    }
    
    public func saveToICloud() {
        var cloudObjectList: [CKRecord] = []
        var recordIDsToDelete: [CKRecord.ID] = []
        
        func saveRecord(label: String, type: String, value: Any?) {
            for pass in 1...2 {
                var idString: String
                if pass == 1 {
                    idString = label
                } else {
                    idString = "\(Scorecard.deviceName)+\(label)"
                }
                let recordID = CKRecord.ID(recordName: "Settings-\(idString)")
                
                var data: String
                switch type {
                case "[String]":
                    data = (value as! [String]).joined(separator: ";")
                case "[Int]":
                    data = (value as! [Int]).map{"\($0)"}.joined(separator: ";")
                case "Date":
                    data = Utility.dateString(value as! Date, format: "yyyy-MM-dd HH:mm:ss Z", localized: false)
                default:
                    data = "\(value ?? "")"
                }
                
                let cloudObject = CKRecord(recordType: "Settings", recordID: recordID)
                if pass == 1 {
                    cloudObject.setValue("", forKey: "deviceName")
                } else {
                    cloudObject.setValue(Scorecard.deviceName, forKey: "deviceName")
                }
                cloudObject.setValue(label, forKey: "name")
                cloudObject.setValue(type, forKey: "type")
                cloudObject.setValue(data, forKey: "value")
                cloudObjectList.append(cloudObject)
                recordIDsToDelete.append(recordID)
            }
        }
        
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let label = child.label {
                let value = child.value as? NSObject
                if label != "saveStats" {
                    var type: String
                    if let _ = value as? [String] {
                        type = "[String]"
                    } else if let _ = value as? [NSNumber] {
                        type = "[Int]"
                    } else {
                        if let _ = value as? Bool {
                            type = "Bool"
                        } else if let _ = value as? Int {
                            type = "Int"
                        } else if let _ = value as? Date {
                            type = "Date"
                        } else if value == nil {
                            // Only type that allows nil is date
                            type = "Date"
                        } else {
                            type = "String"
                        }
                    }
                    saveRecord(label: label, type: type, value: value)
                }
            } else {
                fatalError("Error saving settings to cloud")
            }
        }
        // Save dummy entry for current players
        saveRecord(label: "[players]", type: "[String]", value: Scorecard.shared.playerUUIDList())
        
        let cloudContainer = CKContainer.init(identifier: Config.iCloudIdentifier)
        let database = cloudContainer.privateCloudDatabase
        Sync.update(recordIDsToDelete: recordIDsToDelete, database: database) { (error) in
            Sync.update(records: cloudObjectList, database: database) { (error) in
                Utility.debugMessage("Settings","Settings to iCloud complete (\(error?.localizedDescription ?? "Success"))")
            }
        }
    }
    
    public func loadFromICloud(completion: (([String]?)->())? = nil) {
        // Note there should be 2 values for each column, the default and the device-specific
        // By sorting by device name we should get the default first and then overwrite it
        let downloaded = Settings()
        let cloudContainer = CKContainer.init(identifier: Config.iCloudIdentifier)
        let database = cloudContainer.privateCloudDatabase
        var columnsDownloaded = 0
        var players: [String] = []
        
        let predicate = NSPredicate(format: "deviceName IN %@", argumentArray: [["", Scorecard.deviceName]])
        let sortBy = [NSSortDescriptor(key: "deviceName", ascending: true)]
        
        Sync.read(recordType: "Settings", predicate: predicate, sortBy: sortBy, database: database, downloadAction: { (record) in
        
            columnsDownloaded += 1
            
            let label = record.value(forKey: "name") as! String
            let type = record.value(forKey: "type") as! String
            let value = record.value(forKey: "value") as! String
                       
            if label == "[players]" {
                players = value.split(at: ";")
            } else {
                switch type {
                case "[String]":
                    let values: [String] = value.split(at: ";")
                    downloaded.setValue(values, forKey: label)
                case "[Int]":
                    let values: [Int] = value.split(at: ";").map({Int($0) ?? 0})
                    downloaded.setValue(values, forKey: label)
                case "Bool":
                    downloaded.setValue((Int(value) ?? 0 == 0 ? false : true), forKey: label)
                case "Int":
                    downloaded.setValue(Int(value) ?? 0, forKey: label)
                case "Date":
                    downloaded.setValue(Utility.dateFromString(value, format: "yyyy-MM-dd HH:mm:ss Z", localized: false), forKey: label)
                default:
                    downloaded.setValue(value, forKey: label)
                }
            }
            
        }, completeAction: { (error) in
            if error == nil {
                if columnsDownloaded > 0 {
                    _ = self.copy(from: downloaded, to: self)
                }
                completion?(players)
            } else {
                completion?(nil)
            }
        })
    }
}
