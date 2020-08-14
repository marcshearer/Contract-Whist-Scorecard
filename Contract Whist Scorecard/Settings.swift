//
//  Settings.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 04/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation
import CloudKit

enum SettingState: Int {
    case notAvailable = 0
    case availableNotify = 1
    case available = 2
}

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
    public var rawColorTheme = ThemeName.standard.rawValue
    public var colorTheme: ThemeName {
        get { ThemeName(rawValue: self.rawColorTheme)! }
        set { self.rawColorTheme = newValue.rawValue }
    }
    private var rawAppearance = ThemeAppearance.device.rawValue
    public var appearance: ThemeAppearance {
        get { ThemeAppearance(rawValue: self.rawAppearance)! }
        set { self.rawAppearance = newValue.rawValue }
    }
    public var termsDate: Date!
    public var termsUser = ""
    public var termsDevice = ""
    public var confettiWin = false

    // Settings states
    public var rawOnlineGamesEnabledSettingState = SettingState.availableNotify.rawValue
    public var onlineGamesEnabledSettingState: SettingState {
        get { SettingState(rawValue: self.rawOnlineGamesEnabledSettingState)!}
        set { self.rawOnlineGamesEnabledSettingState = newValue.rawValue}
    }
    public var rawConfettiWinSettingState = SettingState.notAvailable.rawValue
    public var confettiWinSettingState: SettingState {
        get { SettingState(rawValue: self.rawConfettiWinSettingState)!}
        set { self.rawConfettiWinSettingState = newValue.rawValue}
    }

    public var saveStats: Bool = true           // Only used in a game (not saved) - initially set to same as saveHistory but can be overridden
    
    private func saved(_ label: String) -> Bool {
        switch label {
        case "saveStats":
            return false
        default:
            return true
        }
    }
    
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
        case "rawColorTheme":
            self.rawColorTheme = value as! String
        case "rawAppearance":
            self.rawAppearance = value as! Int
        case "thisPlayerUUID":
            self.thisPlayerUUID = value as! String
        case "termsDate":
            self.termsDate = value as! Date?
        case "termsDevice":
            self.termsDevice = value as! String
        case "termsUser":
            self.termsUser = value as! String
        case "saveStats":
            self.saveStats = value as! Bool
        case "confettiWin":
            self.confettiWin = value as! Bool
        case "rawOnlineGamesEnabledSettingState":
            if self.onlineGamesEnabled {
                self.onlineGamesEnabledSettingState = .available
            } else {
                self.rawOnlineGamesEnabledSettingState = value as! Int
            }
        case "rawConfettiWinSettingState":
            if self.confettiWin {
                self.confettiWinSettingState = .available
            } else {
                self.rawConfettiWinSettingState = value as! Int
            }
        case "colorTheme", "appearance":
            // Old values no longer used
            break
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
    
    /// Return number of state settings set to 'notify'
    /// - Returns: Number of state settings set to 'notify'
    public func notifyCount() -> Int {
        var count = 0
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let label = child.label {
                if label.left(3) == "raw" && label.right(12) == "SettingState" {
                    if let value = child.value as? Int {
                        if value == SettingState.availableNotify.rawValue {
                            count += 1
                        }
                    }
                }
            }
        }
        return count
    }
    
    public func load() {
        
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let label = child.label {
                if self.saved(label) {
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
                if self.saved(label) {
                    UserDefaults.standard.set(value, forKey: label)
                }
            } else {
                fatalError("Error saving settings locally")
            }
        }
    }
        
    public func saveToICloud() {
        var downloadList: [(label: String, deviceName: String, type: String, value: String, record: CKRecord)] = []
        
        let cloudContainer = CKContainer.init(identifier: Config.iCloudIdentifier)
        let database = cloudContainer.privateCloudDatabase
        
        let predicate = NSPredicate(format: "deviceName IN %@", argumentArray: [["", Scorecard.deviceName]])

        Sync.read(recordType: "Settings", predicate: predicate, database: database, downloadAction: { (record) in
                if let label = record.value(forKey: "name") as? String,
                   let deviceName = record.value(forKey: "deviceName") as? String,
                   let type = record.value(forKey: "type") as? String,
                    let value = record.value(forKey: "value") as? String {
                    downloadList.append((label,deviceName,type,value,record))
                }
            },
            completeAction: { (error) in
                self.saveToICloudUpdate(downloadList: downloadList, database: database)
            })
    }
    
    public func saveToICloudUpdate(downloadList: [(label: String, deviceName: String, type: String, value: String, record: CKRecord)], database: CKDatabase) {
        var updateList: [(label: String, deviceName: String, record: CKRecord)] = []
        var unchangedList: [(label: String, deviceName: String)] = []
        var recordIDsToDelete: [CKRecord.ID] = []
        var playersChanged = false
        
        func saveRecord(label: String, type: String, value: NSObject?) -> Bool {
            var changed = false
            for pass in 1...2 {
                let deviceName = (pass == 1 ? Scorecard.deviceName : "")
                let existing = downloadList.first(where: {$0.label == label && $0.deviceName == deviceName})
                let value = self.saveToICloudValue(type: type, value: value)
                if existing != nil && type == existing!.type && value == existing!.value {
                    unchangedList.append((label,deviceName))
                } else {
                    let cloudObject = self.saveToICloudRecord(existing: existing?.record, label: label, type: type, value: value, deviceName: deviceName)
                    updateList.append((label, deviceName, cloudObject))
                    changed = true
                }
            }
            return changed
        }
        
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let label = child.label {
                if self.saved(label) {
                    let value = child.value as? NSObject
                    let type = saveToICloudType(value: value)
                    _ = saveRecord(label: label, type: type, value: value)
                }
            } else {
                fatalError("Error saving settings to cloud")
            }
        }
        // Save dummy entry for current players
        playersChanged = saveRecord(label: "[players]", type: "[String]", value: Scorecard.shared.playerUUIDList().sorted() as NSObject)
        
        for entry in downloadList {
            if !updateList.contains(where: {$0.label == entry.label && $0.deviceName == entry.deviceName}) &&
                !unchangedList.contains(where: {$0.label == entry.label && $0.deviceName == entry.deviceName}) {
                // This isn't in the update list or the unchanged list - need to delete it
                recordIDsToDelete.append(entry.record.recordID)
            }
        }
        
        let records = updateList.map{$0.record}
        Sync.update(records: records, recordIDsToDelete: recordIDsToDelete, database: database) { (error) in
            Utility.debugMessage("Settings","Settings to iCloud complete (\(error?.localizedDescription ?? "Success"))")
            if playersChanged {
                Notifications.updateHighScoreSubscriptions()
            }
        }
    }
    
    private func saveToICloudRecord(existing: CKRecord?, label: String, type: String, value: String, deviceName: String?) -> CKRecord {
        var cloudObject: CKRecord
        
        if let existing = existing {
            cloudObject = existing
        } else {
            var idString: String
            if deviceName == nil {
                idString = label
            } else {
                idString = "\(deviceName!)+\(label)"
            }
            let recordID = CKRecord.ID(recordName: "Settings-\(idString)")
            
            cloudObject = CKRecord(recordType: "Settings", recordID: recordID)
            cloudObject.setValue(label, forKey: "name")
            cloudObject.setValue(deviceName ?? "", forKey: "deviceName")
        }
        
        cloudObject.setValue(type, forKey: "type")
        cloudObject.setValue(value, forKey: "value")
       
        return cloudObject
    }
    
    private func saveToICloudValue(type: String, value: NSObject?) -> String {
        var data: String
        switch type {
        case "[String]":
            data = (value as! [String]).joined(separator: ";")
        case "[Int]":
            data = (value as! [Int]).map{"\($0)"}.joined(separator: ";")
        case "Date":
            data = Utility.dateString(value as! Date, format: "yyyy-MM-dd HH:mm:ss Z", localized: false)
        default:
            data = (value == nil ? "" : "\(value!)")
        }
        return data
    }
    
    private func saveToICloudType(value: NSObject?) -> String {
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
        return type
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
