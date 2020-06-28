 //
//  PlayerDetail.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 15/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CloudKit
import CoreData

 class PlayerDetail: NSObject, DataTableViewerDataSource {
    
    // A class to hold the details of a player which can then be reflected in a core data playerMO class
    // or in a CKRecord CloudKit class
  
    // Make sure that if you add any more properties you add them to the methods below - especially ==
    public var name = ""
    public var nameDate: Date!
    public var playerUUID = ""
    public var emailDate: Date!
    public var visibleLocally = false
    public var dateCreated: Date! = Date()
    public var localDateCreated: Date! = Date()
    public var datePlayed: Date!
    public var externalId: String!
    public var tempEmail: String!
    public var gamesPlayed: Int64 = 0
    public var gamesWon: Int64 = 0
    public var handsPlayed: Int64 = 0
    public var handsMade: Int64 = 0
    public var twosMade: Int64 = 0
    public var totalScore: Int64 = 0
    public var thumbnail: Data?
    public var thumbnailDate: Date!
    public var maxScore: Int64 = 0
    public var maxScoreDate: Date!
    public var maxMade: Int64 = 0
    public var maxMadeDate: Date!
    public var maxTwos: Int64 = 0
    public var maxTwosDate: Date!
    public var syncDate: Date!
    public var syncRecordID: String!
    public var objectID: NSManagedObjectID!
    public var syncedOk = false
    
    init(visibleLocally: Bool = false) {
        self.visibleLocally = visibleLocally
        self.localDateCreated = Date()
        self.playerUUID = Scorecard.deviceName + UUID().uuidString // TODO - remove device name
    }
    
    public var indexMO: Int? {
        get {
            return Scorecard.shared.playerList.firstIndex(where: {($0.objectID == self.objectID)})
        }
    }
    
    public var playerMO: PlayerMO! {
        get {
            // Find the player managed object relating to a player detail object
            let index = self.indexMO
            if index == nil {
                return nil
            } else {
                return Scorecard.shared.playerList[index!]
            }
        }
    }
    
    public func updateMO() {
        // Copy details to Managed Object
        let index = self.indexMO
        if index != nil {
            if !CoreData.update(updateLogic: {
                // Copy back edited data
                self.toManagedObject(playerMO: Scorecard.shared.playerList[index!])
            }) {
                // Ignore errors
            }
        }
    }
    
    public func restoreMO() {
        // Copy details back from managed object
        let index = self.indexMO
        if index != nil {
            self.fromManagedObject(playerMO: Scorecard.shared.playerList[index!])
        }
    }
    
    public func deleteMO() {
        // Delete the managed object
        let index = self.indexMO
        if index != nil {
            if !CoreData.update(updateLogic: {
                // Delete this player
                CoreData.delete(record: Scorecard.shared.playerList[index!])
            }) {
                // Ignore errors
            } else {
                // Remove the managed object
                Scorecard.shared.playerList.remove(at: index!)
                
                // Save to iCloud
                Scorecard.settings.saveToICloud()

            }
        }
    }
    
    public func createMO(noSync: Bool = true, saveToICloud: Bool = true) -> PlayerMO! {
        var playerMO: PlayerMO!
        if Scorecard.game?.isPlayingComputer ?? false {
            playerMO = CoreData.create(from: "Player") as? PlayerMO
            self.toManagedObject(playerMO: playerMO)
        } else {
            if !CoreData.update(updateLogic: {
                playerMO = CoreData.create(from: "Player") as? PlayerMO
                self.toManagedObject(playerMO: playerMO)
                // If necessary avoid syncing values back to cloud
                if noSync {
                    playerMO.syncGamesPlayed = playerMO.gamesPlayed
                    playerMO.syncGamesWon = playerMO.gamesWon
                    playerMO.syncHandsPlayed = playerMO.handsPlayed
                    playerMO.syncHandsMade = playerMO.handsMade
                    playerMO.syncTwosMade = playerMO.twosMade
                    playerMO.syncTotalScore = playerMO.totalScore
                }
            }) {
                // Ignore errors
            } else {
                let index = Scorecard.shared.playerList.firstIndex(where: {($0.name! > self.name)})
                Scorecard.shared.playerList.insert(playerMO, at: (index == nil ? Scorecard.shared.playerList.count : index!))
                self.objectID = playerMO.objectID
            }
        }
        if playerMO != nil && saveToICloud {
            // Save to iCloud
            Scorecard.settings.saveToICloud()

        }
        return playerMO
    }
    
    public func dedupName() {
        let name = self.name
        var modifier = 1
        while Scorecard.shared.isDuplicateName(self) {
            modifier += 1
            self.name = "\(name) (\(modifier))"
        }
    }
    
    public func copy() -> PlayerDetail {
        let result = PlayerDetail()
        result.name = self.name
        result.nameDate = self.nameDate
        result.playerUUID = self.playerUUID
        result.emailDate = self.emailDate
        result.visibleLocally = self.visibleLocally
        result.dateCreated = self.dateCreated
        result.localDateCreated = self.localDateCreated
        result.datePlayed = self.datePlayed
        result.externalId = self.externalId
        result.tempEmail = self.tempEmail
        result.gamesPlayed = self.gamesPlayed
        result.gamesWon = self.gamesWon
        result.handsPlayed = self.handsPlayed
        result.handsMade = self.handsMade
        result.twosMade = self.twosMade
        result.totalScore = self.totalScore
        result.maxScore = self.maxScore
        result.maxScoreDate = self.maxScoreDate
        result.maxMade = self.maxMade
        result.maxMadeDate = self.maxMadeDate
        result.maxTwos = self.maxTwos
        result.maxTwosDate = self.maxTwosDate
        result.syncDate = self.syncDate
        result.syncRecordID = self.syncRecordID
        result.thumbnail = self.thumbnail
        result.thumbnailDate = self.thumbnailDate
        
        return result
    }
    
    public func toManagedObject(playerMO: PlayerMO, updateThumbnail: Bool = true) {
        // Doesn't set thumbnail or date as they are downloaded separately and update direct
        playerMO.name = self.name
        playerMO.nameDate = self.nameDate
        playerMO.playerUUID = self.playerUUID
        playerMO.emailDate = self.emailDate
        playerMO.visibleLocally = self.visibleLocally
        playerMO.dateCreated = self.dateCreated
        playerMO.localDateCreated = self.localDateCreated
        playerMO.datePlayed = self.datePlayed
        playerMO.externalId = self.externalId
        playerMO.tempEmail = self.tempEmail
        playerMO.gamesPlayed = self.gamesPlayed
        playerMO.gamesWon = self.gamesWon
        playerMO.handsPlayed = self.handsPlayed
        playerMO.handsMade = self.handsMade
        playerMO.twosMade = self.twosMade
        playerMO.totalScore = self.totalScore
        playerMO.maxScore = self.maxScore
        playerMO.maxScoreDate = self.maxScoreDate
        playerMO.maxMade = self.maxMade
        playerMO.maxMadeDate = self.maxMadeDate
        playerMO.maxTwos = self.maxTwos
        playerMO.maxTwosDate = self.maxTwosDate
        playerMO.syncDate = self.syncDate
        playerMO.syncRecordID = self.syncRecordID
        if updateThumbnail {
            playerMO.thumbnail = self.thumbnail
            playerMO.thumbnailDate = self.thumbnailDate
        }
    }
    
    public func fromManagedObject(playerMO: PlayerMO) {
        self.name = (playerMO.name == nil ? "" : playerMO.name!)
        self.nameDate = playerMO.nameDate as Date?
        self.playerUUID = (playerMO.playerUUID == nil ? "" : playerMO.playerUUID!)
        self.emailDate = playerMO.emailDate as Date?
        self.visibleLocally = playerMO.visibleLocally
        self.dateCreated = (playerMO.dateCreated == nil ? Date() : playerMO.dateCreated! as Date)
        self.localDateCreated = (playerMO.localDateCreated == nil ? Date() : playerMO.localDateCreated! as Date)
        self.datePlayed = playerMO.datePlayed as Date?
        self.externalId = playerMO.externalId
        self.tempEmail = playerMO.tempEmail
        self.gamesPlayed = playerMO.gamesPlayed
        self.gamesWon = playerMO.gamesWon
        self.handsPlayed = playerMO.handsPlayed
        self.handsMade = playerMO.handsMade
        self.twosMade = playerMO.twosMade
        self.totalScore = playerMO.totalScore
        self.thumbnail = playerMO.thumbnail
        self.thumbnailDate = playerMO.thumbnailDate as Date?
        self.maxScore = playerMO.maxScore
        self.maxScoreDate = playerMO.maxScoreDate as Date?
        self.maxMade = playerMO.maxMade
        self.maxMadeDate = playerMO.maxMadeDate as Date?
        self.maxTwos = playerMO.maxTwos
        self.maxTwosDate = playerMO.maxTwosDate as Date?
        self.syncDate = playerMO.syncDate as Date?
        self.syncRecordID = playerMO.syncRecordID
        self.objectID = playerMO.objectID
    }
    
    public func fromCloudObject(cloudObject: CKRecord) {
        // Doesn't set thumbnail as they are downloaded separately and update direct
        self.name = Utility.objectString(cloudObject: cloudObject, forKey: "name")
        self.nameDate = Utility.objectDate(cloudObject: cloudObject, forKey: "nameDate")
        self.playerUUID = Utility.objectString(cloudObject: cloudObject, forKey: "playerUUID")
        self.emailDate = Utility.objectDate(cloudObject: cloudObject, forKey:"emailDate")
        self.dateCreated = Utility.objectDate(cloudObject: cloudObject, forKey:"dateCreated")
        self.datePlayed = Utility.objectDate(cloudObject: cloudObject, forKey:"datePlayed")
        self.gamesPlayed = Utility.objectInt(cloudObject: cloudObject, forKey:"gamesPlayed")
        self.externalId = Utility.objectString(cloudObject: cloudObject, forKey:"externalId")
        self.gamesWon = Utility.objectInt(cloudObject: cloudObject, forKey:"gamesWon")
        self.handsPlayed = Utility.objectInt(cloudObject: cloudObject, forKey:"handsPlayed")
        self.handsMade = Utility.objectInt(cloudObject: cloudObject, forKey:"handsMade")
        self.twosMade = Utility.objectInt(cloudObject: cloudObject, forKey:"twosMade")
        self.totalScore = Utility.objectInt(cloudObject: cloudObject, forKey:"totalScore")
        self.thumbnailDate = Utility.objectDate(cloudObject: cloudObject, forKey:"thumbnailDate")
        self.maxScore = Utility.objectInt(cloudObject: cloudObject, forKey:"maxScore")
        self.maxScoreDate = Utility.objectDate(cloudObject: cloudObject, forKey:"maxScoreDate")
        self.maxMade = Utility.objectInt(cloudObject: cloudObject, forKey:"maxMade")
        self.maxMadeDate = Utility.objectDate(cloudObject: cloudObject, forKey:"maxMadeDate")
        self.maxTwos = Utility.objectInt(cloudObject: cloudObject, forKey:"maxTwos")
        self.maxTwosDate = Utility.objectDate(cloudObject: cloudObject, forKey:"maxTwosDate")
        self.syncDate = Utility.objectDate(cloudObject: cloudObject, forKey: "syncDate")
        self.syncRecordID = cloudObject.recordID.recordName
    }
    
    public func toCloudObject(cloudObject: CKRecord) {
        // Doesn't set thumbnail or date as they are downloaded separately and update direct
        cloudObject.setValue(self.name, forKey: "name")
        cloudObject.setValue(self.nameDate , forKey: "nameDate")
        cloudObject.setValue(self.playerUUID , forKey: "playerUUID")
        cloudObject.setValue(self.emailDate , forKey: "emailDate")
        cloudObject.setValue(self.dateCreated , forKey: "dateCreated")
        cloudObject.setValue(self.datePlayed , forKey: "datePlayed")
        cloudObject.setValue(self.gamesPlayed , forKey: "gamesPlayed")
        cloudObject.setValue(self.externalId , forKey: "externalId")
        cloudObject.setValue(self.gamesWon , forKey: "gamesWon")
        cloudObject.setValue(self.handsPlayed , forKey: "handsPlayed")
        cloudObject.setValue(self.handsMade , forKey: "handsMade")
        cloudObject.setValue(self.twosMade , forKey: "twosMade")
        cloudObject.setValue(self.totalScore , forKey: "totalScore")
        cloudObject.setValue(self.maxScore , forKey: "maxScore")
        cloudObject.setValue(self.maxScoreDate , forKey: "maxScoreDate")
        cloudObject.setValue(self.maxMade , forKey: "maxMade")
        cloudObject.setValue(self.maxMadeDate , forKey: "maxMadeDate")
        cloudObject.setValue(self.maxTwos , forKey: "maxTwos")
        cloudObject.setValue(self.maxTwosDate , forKey: "maxTwosDate")
        cloudObject.setValue(self.syncDate, forKey: "syncDate")
    }
    
    override func value(forKey: String) -> Any? {
        var result: Any?
        let mirror = Mirror(reflecting: self)
        if let index = mirror.children.firstIndex(where: {$0.label == forKey}) {
            result = mirror.children[index].value
        }
        return result
    }
    
    internal func derivedField(field: String, record: DataTableViewerDataSource, sortValue: Bool) -> String {
        var numericResult: Double?
        var result: String
        let format = (ScorecardUI.landscapePhone() ? "%.1f" : "%.0f")
        
        let record = record as! PlayerDetail
        if record.gamesPlayed == 0 {
            numericResult = 0.0
            result = ""
        } else {
            switch field  {
            case "gamesWon%":
                numericResult = Double(record.gamesWon) / Double(record.gamesPlayed) * 100.0
                result = "\(String(format: format, numericResult!)) %"
            case "averageScore":
                numericResult = Double(record.totalScore) / Double(record.gamesPlayed)
                result = String(format: format, numericResult!)
            case "handsMade%":
                numericResult = Double(record.handsMade) / Double(record.handsPlayed) * 100.0
                result = "\(String(format: format, numericResult!)) %"
            case "twosMade%":
                numericResult = Double(record.twosMade) / Double(record.handsPlayed) * 100.0
                result = "\(String(format: format, numericResult!)) %"
            default:
                result = ""
            }
        }
        
        if numericResult != nil && sortValue {
            let valueString = String(format: "%.4f", Double(numericResult!) + 1e14)
            result = String(repeating: " ", count: 20 - valueString.count) + valueString
        }
        
        return result
    }
}
