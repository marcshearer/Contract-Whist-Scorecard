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
    public var email = ""
    public var emailDate: Date!
    public var visibleLocally = false
    public var dateCreated: Date! = Date()
    public var localDateCreated: Date! = Date()
    public var datePlayed: Date!
    public var externalId: String!
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
    private var scorecard: Scorecard
    
    init(_ scorecard: Scorecard, visibleLocally: Bool = false) {
        self.scorecard = scorecard
        self.visibleLocally = visibleLocally
        self.localDateCreated = Date()
    }
    
    public var indexMO: Int? {
        get {
            return self.scorecard.playerList.firstIndex(where: {($0.objectID == self.objectID)})
        }
    }
    
    public var playerMO: PlayerMO! {
        get {
            // Find the player managed object relating to a player detail object
            let index = self.indexMO
            if index == nil {
                return nil
            } else {
                return self.scorecard.playerList[index!]
            }
        }
    }
    
    public func updateMO() {
        // Copy details to Managed Object
        let index = self.indexMO
        if index != nil {
            if !CoreData.update(updateLogic: {
                // Copy back edited data
                self.toManagedObject(playerMO: self.scorecard.playerList[index!])
            }) {
                // Ignore errors
            }
        }
    }
    
    public func restoreMO() {
        // Copy details back from managed object
        let index = self.indexMO
        if index != nil {
            self.fromManagedObject(playerMO: self.scorecard.playerList[index!])
        }
    }
    
    public func deleteMO() {
        // Delete the managed object
        let index = self.indexMO
        if index != nil {
            if !CoreData.update(updateLogic: {
                // Delete this player
                CoreData.delete(record: self.scorecard.playerList[index!])
            }) {
                // Ignore errors
            } else {
                // Remove the managed object
                self.scorecard.playerList.remove(at: index!)
            }
        }
    }
    
    public func createMO(noSync: Bool = true) -> PlayerMO! {
        var playerMO: PlayerMO!
        if self.scorecard.isPlayingComputer {
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
                let index = self.scorecard.playerList.firstIndex(where: {($0.name! > self.name)})
                self.scorecard.playerList.insert(playerMO, at: (index == nil ? self.scorecard.playerList.count : index!))
                self.objectID = playerMO.objectID
            }
        }
        return playerMO
    }
    
    public func dedupName(_ scorecard: Scorecard) {
        let name = self.name
        var modifier = 1
        while scorecard.isDuplicateName(self) {
            modifier += 1
            self.name = "\(name) (\(modifier))"
        }
    }
    
    
    public func toManagedObject(playerMO: PlayerMO) {
        // Doesn't set thumbnail or date as they are downloaded separately and update direct
        playerMO.name = self.name
        playerMO.nameDate = self.nameDate
        playerMO.email = self.email
        playerMO.emailDate = self.emailDate
        playerMO.visibleLocally = self.visibleLocally
        playerMO.dateCreated = self.dateCreated
        playerMO.localDateCreated = self.localDateCreated
        playerMO.datePlayed = self.datePlayed
        playerMO.externalId = self.externalId
        playerMO.gamesPlayed = self.gamesPlayed
        playerMO.gamesWon = self.gamesWon
        playerMO.handsPlayed = self.handsPlayed
        playerMO.handsMade = self.handsMade
        playerMO.twosMade = self.twosMade
        playerMO.totalScore = self.totalScore
        playerMO.thumbnail = self.thumbnail
        playerMO.maxScore = self.maxScore
        playerMO.maxScoreDate = self.maxScoreDate
        playerMO.maxMade = self.maxMade
        playerMO.maxMadeDate = self.maxMadeDate
        playerMO.maxTwos = self.maxTwos
        playerMO.maxTwosDate = self.maxTwosDate
        playerMO.syncDate = self.syncDate
        playerMO.syncRecordID = self.syncRecordID
    }
    
    public func fromManagedObject(playerMO: PlayerMO) {
        self.name = (playerMO.name == nil ? "" : playerMO.name!)
        self.nameDate = playerMO.nameDate as Date?
        self.email = (playerMO.email == nil ? "" : playerMO.email!)
        self.emailDate = playerMO.emailDate as Date?
        self.visibleLocally = playerMO.visibleLocally
        self.dateCreated = (playerMO.dateCreated == nil ? Date() : playerMO.dateCreated! as Date)
        self.localDateCreated = (playerMO.localDateCreated == nil ? Date() : playerMO.localDateCreated! as Date)
        self.datePlayed = playerMO.datePlayed as Date?
        self.externalId = playerMO.externalId
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
        self.name = Utility.objectString(cloudObject: cloudObject, forKey: "name")
        self.nameDate = Utility.objectDate(cloudObject: cloudObject, forKey: "nameDate")
        self.email = Utility.objectString(cloudObject: cloudObject, forKey: "email")
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
        cloudObject.setValue(self.name, forKey: "name")
        cloudObject.setValue(self.nameDate , forKey: "nameDate")
        cloudObject.setValue(self.email , forKey: "email")
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
    
}
