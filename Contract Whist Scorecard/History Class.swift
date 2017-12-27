//
//  History Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 20/02/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation
import CloudKit

class History {
    
    // A class which is used to load the history of games and participants into an in-memory data structure
    // from the core data representation on this device
    
    var games: [HistoryGame] = []
    
    init(getParticipants: Bool = false, includeBF: Bool = false) {
        // Load all games
        self.loadGames(getParticipants: getParticipants, includeBF: includeBF)
    }
    
    init(gameUUID: String!, getParticipants: Bool = true) {
        // Load a specific game given a participant
        self.loadGames(getParticipants: getParticipants, gameUUID: gameUUID)
    }
    
    init(unconfirmed: Bool, getParticipants: Bool = true) {
        // Load unconfirmed games
        self.loadGames(getParticipants: getParticipants, unconfirmed: unconfirmed)
    }
    
    private func loadGames(getParticipants: Bool = false, unconfirmed: Bool = false, gameUUID: String! = nil, includeBF: Bool = false) {
        // Fetch list of games from data store
        var predicate: NSPredicate!
        var lastGameUUID: String!
        
        if unconfirmed {
            // Load all unconfirmed games
            predicate = NSPredicate(format: "syncRecordID = nil")
        } else if gameUUID != nil {
            // Limit to specific game - load participants
            predicate = NSPredicate(format: "gameUUID = %@", gameUUID)
        } else if !includeBF {
            // Exclude brought forward values from pre-history
            predicate = NSPredicate(format: "gameUUID <> 'B/F'")
        } else {
            // Include everything
            predicate = nil
        }
        
        let gameList: [GameMO] = CoreData.fetch(from: "Game",
                                              filter: predicate,
                                              sort: ("datePlayed", .descending))
        
        if gameList.count > 0 {
            for gameLoop in 1...gameList.count {
                self.games.append(HistoryGame(fromManagedObject: gameList[gameLoop - 1],
                                              duplicate: (lastGameUUID != nil && gameList[gameLoop - 1].gameUUID == lastGameUUID!)))
                lastGameUUID = gameList[gameLoop - 1].gameUUID
                if getParticipants {
                    self.getParticipants(index: gameLoop-1)
                }
            }
        }
    }
    
    static func getNewGames(cutoffDate: Date) -> [String] {
    // Fetch list of games which have been downloaded since the cutoff date
        var results: [String] = []
        
        let gameList: [GameMO] = CoreData.fetch(from: "Game",
                                              filter: NSPredicate(format: "syncDate >= %@", cutoffDate as NSDate),
                                              sort: ("gameUUID", .ascending))
        for gameMO in gameList {
            results.append(gameMO.gameUUID!)
        }
    
        return results
    }
    
    func getParticipants(index: Int) {
        // Fetch list of participants for a specific game in the games array from data store
        self.games[index].participant = History.loadParticipants(gameUUID: self.games[index].gameUUID)
    }
    
    func loadAllParticipants() {
        // Load all participants for all loaded history games
        for historyGame in self.games {
            if historyGame.participant == nil {
                historyGame.participant = History.loadParticipants(gameUUID: historyGame.gameUUID)
            }
        }
    }
    
    static func loadParticipants(gameUUID: String, playerNumber: Int! = nil) -> [HistoryParticipant] {
        // Fetch list of participants for a specific game (and possibly specific player) from data store
        var results: [HistoryParticipant] = []
        var predicate: NSPredicate
        
        // Set up filter predicate
        if playerNumber != nil {
            predicate = NSPredicate(format: "gameUUID = %@ and playerNumber = %i",
                                    gameUUID, playerNumber!)
        } else {
            predicate = NSPredicate(format: "gameUUID = %@",
                                    gameUUID)
        }
        
        
        // Get participant list for this game / player from core data
        let participantList: [ParticipantMO] = CoreData.fetch(from: "Participant",
                                                                filter: predicate,
                                                                sort: ("totalScore", .descending))
        // Append to results
        for participantMO in participantList {
            results.append(HistoryParticipant(fromManagedObject: participantMO))
        }
        
        return results
    }
    
    static func getHighScores(type: HighScoreType, limit: Int = 3, playerEmailList: [String]) -> [ParticipantMO] {
        // Setup query filters
        var sort: [(key: String, direction: SortDirection)]
        let predicate1 = NSPredicate(format: "gameUUID != 'B/F' AND excludeStats = false")
        let predicate2 = NSPredicate(format: "email IN %@", argumentArray: [playerEmailList])
        
        // Setup second sort
        switch type {
        case .totalScore:
            sort = [("totalScore", .descending), ("handsMade", .descending), ("datePlayed", .ascending)]
        case .handsMade:
            sort = [("handsMade", .descending), ("totalScore", .descending), ("datePlayed", .ascending)]
        case.twosMade:
            sort = [("twosMade", .descending), ("totalScore", .descending), ("datePlayed", .ascending)]
        }
        
        // Get list of participants from Core Data
        let results: [ParticipantMO] = CoreData.fetch(from: "Participant",
                                                      filter: predicate1, filter2: predicate2,
                                                      limit: limit,
                                                      sort: sort)
        
        return results
    }
    
    static func getParticipantEmailList() -> [String] {
        var results: [String] = []
        
        // Get list all participants on this device sorted by email
        let participantList: [ParticipantMO] = CoreData.fetch(from: "Participant",
                                                              filter: NSPredicate(format: "email != nil and email != ''"),
                                                              sort: ("email", .ascending))
        
        // Reduce to unique list of non-blank emails
        var lastEmail = ""
        for participantMO in participantList {
            if participantMO.email! != lastEmail {
                results.append(participantMO.email!)
                lastEmail = participantMO.email!
            }
        }
    
        return results
        
    }

    static func getParticipantRecordsForPlayer(playerEmail: String, includeBF: Bool = true) -> [ParticipantMO] {
        var predicate: NSPredicate
        // Get all participants from Core Data for player
        if includeBF {
            predicate = NSPredicate(format: "email = %@", playerEmail)
        } else {
            predicate = NSPredicate(format: "email = %@ and gameUUID <> 'B/F'", playerEmail)
        }
        
        let results: [ParticipantMO] = CoreData.fetch(from: "Participant",
                                                      filter: predicate,
                                                      sort: ("datePlayed", .ascending))
        
        return results
    }
    
    static func getNewParticpantGames(cutoffDate: Date, specificEmail: [String] = []) -> [String] {
        // Fetch list of games where a participant has been downloaded since the cutoff date
        var results: [String] = []
        var predicate1: NSPredicate
        var predicate2: NSPredicate!
        
        // Setup query filter predicate
        if specificEmail.count != 0 {
            predicate1 = NSPredicate(format: "syncDate >= %@ OR syncDate = null", cutoffDate as NSDate)
            predicate2 = NSPredicate(format: "email IN %@", argumentArray: specificEmail)
        } else {
            predicate1 = NSPredicate(format: "syncDate >= %@ OR syncDate = null", cutoffDate as NSDate)
            predicate2 = nil
        }
        
        // Get records from core data
        let participantList: [ParticipantMO] = CoreData.fetch(from: "Participant",
                                                              filter: predicate1, filter2: predicate2,
                                                              sort: ("gameUUID", .descending))
        
       
        // Reduce to a list of unique Game UUID strings
        var lastGameUUID: String! = nil
        
        for participantMO in participantList {
            if lastGameUUID != participantMO.gameUUID {
                results.append(participantMO.gameUUID!)
                lastGameUUID = participantMO.gameUUID!
            }
        }
        
        return results
    }
    
    static func getGameLocations(latitude: Double, longitude: Double, skipLocation: String = "") -> [GameLocation] {
        var gameLocations: [GameLocation] = []
        
        // Get game list from core data
        var gameList: [GameMO] = CoreData.fetch(from: "Game",
                                                filter: NSPredicate(format: "gameUUID != 'B/F' and location != nil  and location != %@ and location != '' and location != 'Online' and latitude != nil and longitude != nil", skipLocation),
                                                limit: 100,
                                                sort: ("datePlayed", .descending))
        
        
        // Get closest game locations
        if gameList.count > 0 {
            // Sort by distance from current location
            var sortTable: [(distance: Double, index: Int)] = []
            for game in 1...gameList.count {
                sortTable.append((abs(gameList[game-1].latitude - latitude) + abs(gameList[game-1].longitude - longitude), game))
            }
            sortTable.sort(by: { $0.distance < $1.distance })
            
            for sortIndex in 1...gameList.count {
                // Copy unique locations to result
                let game = sortTable[sortIndex-1].index
                if game < 2 || gameList[game-1].location != gameList[game-2].location {
                    // Check not already there - can happen if different names for same coordinates
                    let index = gameLocations.index(where: {$0.description == gameList[game-1].location!})
                    if index == nil {
                        gameLocations.append(GameLocation(
                            location: CLLocation(latitude: gameList[game-1].latitude,
                                                 longitude: gameList[game-1].longitude),
                            description: gameList[game-1].location!))
                    }
                }
                
            }
        }
        return gameLocations
    }
    
    class func deleteDetachedGames(scorecard: Scorecard) {
        // Run round all participants building up a list of games to delete
        var canDeleteGameUUID: [String] = []
        var lastGameUUID = ""
        var playersFound = true
        
        var participantList: [ParticipantMO]! = CoreData.fetch(from: "Participant", sort: ("gameUUID", .ascending))
        for participantMO in participantList {
            if participantMO.gameUUID != lastGameUUID {
                if !playersFound {
                    canDeleteGameUUID.append(lastGameUUID)
                }
                lastGameUUID = participantMO.gameUUID!
                playersFound = false
            }
            if !playersFound && participantMO.email != nil && participantMO.email! != "" && scorecard.findPlayerByEmail(participantMO.email!) != nil {
                playersFound = true
            }
        }
        if !playersFound {
            canDeleteGameUUID.append(lastGameUUID)
        }
        participantList = nil

        // Now delete games and participants
        if !CoreData.update(updateLogic: {
            for gameUUID in canDeleteGameUUID {
                let history = History(gameUUID: gameUUID, getParticipants: true)
                for historyGame in history.games {
                    CoreData.delete(record: historyGame.gameMO)
                    for historyParticipant in historyGame.participant {
                        CoreData.delete(record: historyParticipant.participantMO)
                    }
                }
            }
        }) {
            // Ignore - will get picked up next time
        }
    }
    
    func find(gameUUID: String) -> HistoryGame! {
        let found = self.games.index(where: {
            if $0.gameUUID == gameUUID {
                return true
            } else {
                return false}
            })
        if found == nil {
            return nil
        } else {
            return self.games[found!]
        }
    }
    
    static func cloudGameToMO(cloudObject: CKRecord, gameMO: GameMO) {
        gameMO.gameUUID = Utility.objectString(cloudObject: cloudObject, forKey: "gameUUID")
        gameMO.deviceUUID = Utility.objectString(cloudObject: cloudObject, forKey: "deviceUUID")
        gameMO.datePlayed = Utility.objectDate(cloudObject: cloudObject, forKey: "datePlayed")
        gameMO.deviceName = Utility.objectString(cloudObject: cloudObject, forKey: "deviceName")
        gameMO.location = Utility.objectString(cloudObject: cloudObject, forKey: "location")
        gameMO.latitude = Utility.objectDouble(cloudObject: cloudObject, forKey: "latitude")
        gameMO.longitude = Utility.objectDouble(cloudObject: cloudObject, forKey: "longitude")
        gameMO.excludeStats = Utility.objectBool(cloudObject: cloudObject, forKey: "excludeStats")
        gameMO.syncRecordID = cloudObject.recordID.recordName
        gameMO.syncDate = Utility.objectDate(cloudObject: cloudObject, forKey: "syncDate")
        if gameMO.localDateCreated == nil {
            gameMO.localDateCreated = Date()
        }
    }
    
    static func cloudGameFromMo(cloudObject: CKRecord, gameMO: GameMO, syncDate: Date) {
        cloudObject.setValue(gameMO.gameUUID, forKey: "gameUUID")
        cloudObject.setValue(gameMO.deviceUUID, forKey: "deviceUUID")
        cloudObject.setValue(gameMO.datePlayed, forKey: "datePlayed")
        cloudObject.setValue(gameMO.deviceName, forKey: "deviceName")
        cloudObject.setValue(gameMO.location, forKey: "location")
        cloudObject.setValue(gameMO.latitude, forKey: "latitude")
        cloudObject.setValue(gameMO.longitude, forKey: "longitude")
        cloudObject.setValue(gameMO.excludeStats, forKey: "excludeStats")
        cloudObject.setValue(syncDate, forKey: "syncDate")
    }
    
    static func cloudParticipantToMO(cloudObject: CKRecord, participantMO: ParticipantMO) {
        participantMO.gameUUID = Utility.objectString(cloudObject: cloudObject, forKey: "gameUUID")
        participantMO.deviceUUID = Utility.objectString(cloudObject: cloudObject, forKey: "deviceUUID")
        participantMO.datePlayed = Utility.objectDate(cloudObject: cloudObject, forKey: "datePlayed")
        participantMO.playerNumber = Int16(Utility.objectInt(cloudObject: cloudObject, forKey: "playerNumber"))
        participantMO.name = Utility.objectString(cloudObject: cloudObject, forKey: "name")
        participantMO.email = Utility.objectString(cloudObject: cloudObject, forKey: "email")
        participantMO.totalScore = Int16(Utility.objectInt(cloudObject: cloudObject, forKey: "totalScore"))
        participantMO.gamesPlayed = Int16(Utility.objectInt(cloudObject: cloudObject, forKey: "gamesPlayed"))
        participantMO.gamesWon = Int16(Utility.objectInt(cloudObject: cloudObject, forKey: "gamesWon"))
        participantMO.handsPlayed = Int16(Utility.objectInt(cloudObject: cloudObject, forKey: "handsPlayed"))
        participantMO.handsMade = Int16(Utility.objectInt(cloudObject: cloudObject, forKey: "handsMade"))
        participantMO.twosMade = Int16(Utility.objectInt(cloudObject: cloudObject, forKey: "twosMade"))
        participantMO.place = Int16(Utility.objectInt(cloudObject: cloudObject, forKey: "place"))
        participantMO.excludeStats = Utility.objectBool(cloudObject: cloudObject, forKey: "excludeStats")
        participantMO.syncRecordID = cloudObject.recordID.recordName
        participantMO.syncDate = Utility.objectDate(cloudObject: cloudObject, forKey: "syncDate")
        if participantMO.localDateCreated == nil {
            participantMO.localDateCreated = Date()
        }
    }
    
    static func cloudParticipantFromMO(cloudObject: CKRecord, participantMO: ParticipantMO, syncDate: Date) {
        cloudObject.setValue(participantMO.gameUUID, forKey: "gameUUID")
        cloudObject.setValue(participantMO.deviceUUID, forKey: "deviceUUID")
        cloudObject.setValue(participantMO.datePlayed, forKey: "datePlayed")
        cloudObject.setValue(participantMO.playerNumber, forKey: "playerNumber")
        cloudObject.setValue(participantMO.name, forKey: "name")
        cloudObject.setValue(participantMO.email, forKey: "email")
        cloudObject.setValue(participantMO.totalScore, forKey: "totalScore")
        cloudObject.setValue(participantMO.gamesPlayed, forKey: "gamesPlayed")
        cloudObject.setValue(participantMO.gamesWon, forKey: "gamesWon")
        cloudObject.setValue(participantMO.handsPlayed, forKey: "handsPlayed")
        cloudObject.setValue(participantMO.handsMade, forKey: "handsMade")
        cloudObject.setValue(participantMO.twosMade, forKey: "twosMade")
        cloudObject.setValue(participantMO.place, forKey: "place")
        cloudObject.setValue(participantMO.excludeStats, forKey: "excludeStats")
        cloudObject.setValue(syncDate, forKey: "syncDate")
    }
    
    func test() {
        
    }
}

public class HistoryGame {
    var gameUUID: String
    var datePlayed: Date
    var deviceUUID: String
    var gameLocation: GameLocation
    var deviceName: String!
    var participant: [HistoryParticipant]!
    var localDateCreated: Date
    var gameMO: GameMO!
    var duplicate: Bool!
    
    init(fromManagedObject gameMO: GameMO, duplicate: Bool! = nil) {
        self.gameUUID = gameMO.gameUUID!
        self.deviceUUID = gameMO.deviceUUID!
        self.datePlayed = gameMO.datePlayed! as Date
        self.deviceName = gameMO.deviceName
        let description = (gameMO.location == nil || gameMO.location == "" ? "Unknown" : gameMO.location!)
        self.gameLocation = GameLocation(location: CLLocation(latitude: gameMO.latitude, longitude: gameMO.longitude), description: description)
        self.localDateCreated = (gameMO.localDateCreated == nil ? Date() : gameMO.localDateCreated! as Date)
        self.gameMO = gameMO
        self.duplicate = duplicate
    }
}

public class HistoryParticipant {
    var gameUUID: String
    var datePlayed: Date
    var deviceUUID: String
    var playerNumber: Int16
    var name: String
    var totalScore: Int16
    var handsMade: Int16
    var handsPlayed: Int16
    var twosMade: Int16
    var localDateCreated: Date
    var participantMO: ParticipantMO!
    
    init(fromManagedObject participantMO: ParticipantMO) {
        self.gameUUID = participantMO.gameUUID!
        self.deviceUUID = participantMO.deviceUUID!
        self.datePlayed = participantMO.datePlayed! as Date
        self.playerNumber = participantMO.playerNumber
        self.name = participantMO.name!
        self.totalScore = participantMO.totalScore
        self.handsPlayed = participantMO.handsPlayed
        self.handsMade = participantMO.handsMade
        self.twosMade = participantMO.twosMade
        self.localDateCreated = (participantMO.localDateCreated == nil ? Date() : participantMO.localDateCreated! as Date)
        self.participantMO = participantMO
    }
}
