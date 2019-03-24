//
//  Sync Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 26/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//
// This class allows a silent sync or UI elements can be passed to it for status

import UIKit
import CoreData
import CloudKit


// If you ever decide to make some of the methods in the protocol optional just insert @objc in front of protocol and put ? after optional method calls

protocol SyncDelegate: class {
    
    // A method to manage a message from the sync controller
    func syncMessage(_ message: String)
    
    // A method to manage an error condition
    func syncAlert(_ message: String, completion: @escaping () -> ())
    
    // A method to be called when synchronisation is complete
    func syncCompletion(_ errors: Int)
    
    // A method to return a player list (only used for getPlayers mode but couldn't make it optional
    func syncReturnPlayers(_ playerList: [PlayerDetail]!)
}

public enum SyncMode {
    case syncAll
    case syncGetPlayers
    case syncGetPlayerDetails
    case syncGetVersion
    case syncGetVersionAsync
}

private enum SyncPhase {
    case phaseGetVersion
    case phaseGetVersionAsync
    case phaseGetLastSyncDate
    case phaseUpdateLastSyncDate
    case phaseGetExistingParticipants
    case phaseGetNewParticipants
    case phaseGetGameParticipants
    case phaseGetSpecificParticipants
    case phaseGetRelatedParticipants
    case phaseBuildGameList
    case phaseBuildPlayerList
    case phaseUpdateParticipants
    case phaseGetGames
    case phaseUpdateGames
    case phaseSendGamesAndParticipants
    case phaseGetPlayers
    case phaseGetPlayerList
    case phaseSendPlayers
    case phaseGetSendImages

}

private enum GetParticipantMode {
    case getExisting
    case getNew
    case getGame
    case getSpecific
    case getRelated
}

class Sync {
    
    // A class which synchronises the local core data representation with the cloud
    // It has no UI - it expects the calling class to
    
    // MARK: - Class Properties ======================================================================== -
    
    // Delegate for callback protocol
    weak public var delegate: SyncDelegate?
    
    // Main state properties
    public var scorecard: Scorecard!
    
    // Local class variables
    private var errors = 0
    private var cloudObjectList: [CKRecord] = []
    private var syncMode = SyncMode.syncAll
    private var syncPhases: [SyncPhase]!
    private var syncPhaseCount = -1
    private var timer: Timer!
    private var timeout: Double!
    private var adminMode: Bool!
    
    // Variables to hold updates
    public static var syncInProgress = false
    public static var syncBackgroundCompletionInProgress = false
    private var setSyncBackgroundCompletionInProgress = false
    private var observer: NSObjectProtocol?
    
    // Player sync state
    private var cloudPlayerRecordList: [PlayerDetail] = []
    private var downloadedPlayerRecordList: [PlayerDetail] = []
    private var localPlayerRecordList: [PlayerDetail] = []
    private var localPlayerMOList: [PlayerMO] = []
    private var playerImageFromCloud: [PlayerMO] = []
    private var playerImageToCloud: [PlayerMO] = []
    private var specificEmail: [String]!
    private var specificExternalId: String!
    
    // Game / participant sync state
    private var nextSyncDate: Date!
    private var lastSyncDate: Date!
    private var newGameList: [GameMO]!
    private var gameUUIDList: [String]!

    
    // MARK: - Public class methods -
    
    public func initialise(scorecard: Scorecard) {
        self.scorecard = scorecard
        self.adminMode = Scorecard.adminMode
    }
    
    public func connect() -> Bool {
        if Sync.syncInProgress {
            return false
        } else {
            return true
        }
    }
    
    public func synchronise(syncMode: SyncMode = .syncAll, specificEmail: [String] = [], specificExternalId: String! = nil, timeout: Double! = 30.0, waitFinish: Bool = true) {
        // Reset state
        errors = 0
        cloudObjectList = []
        
        if Sync.syncBackgroundCompletionInProgress && !waitFinish {
            self.syncCompletion()
            return
        }
        
        if !Sync.syncInProgress {
            Sync.syncInProgress = true
            self.errors = 0
            self.syncMode = syncMode
            self.specificEmail = specificEmail
            self.specificExternalId = specificExternalId
            self.timeout = timeout
            
            switch syncMode {
            case .syncGetVersion:
                syncPhases = [.phaseGetVersion]
            case .syncGetVersionAsync:
                syncPhases = [.phaseGetVersionAsync]
            case .syncAll:
                syncPhases = [.phaseGetVersion,
                              .phaseGetLastSyncDate,
                              .phaseGetExistingParticipants, .phaseUpdateParticipants,
                              .phaseGetNewParticipants,      .phaseUpdateParticipants,
                              .phaseGetGames,                .phaseUpdateGames,
                              .phaseGetGameParticipants,     .phaseUpdateParticipants,
                              .phaseSendGamesAndParticipants,
                              .phaseUpdateLastSyncDate,
                              .phaseGetPlayers, .phaseSendPlayers,
                              .phaseGetSendImages]
            case .syncGetPlayers:
                if self.specificExternalId != nil {
                    // Got a specifc External Id - load players that match - not currently used
                    syncPhases = [.phaseGetVersion,
                                  .phaseGetPlayerList]
                } else if self.specificEmail.count == 0 {
                    // General request to get any players linked to currently loaded players - partial sync to update local participants and then deduce list
                    syncPhases = [.phaseGetVersion,
                                  .phaseGetLastSyncDate,
                                  .phaseGetExistingParticipants, .phaseUpdateParticipants,
                                  .phaseGetNewParticipants,      .phaseUpdateParticipants,
                                  .phaseGetGames,                .phaseUpdateGames,
                                  .phaseGetGameParticipants,     .phaseUpdateParticipants,
                                  .phaseGetPlayerList]
                } else {
                    // Have been passed a list of (probably 1) email addresses - get a list of games that user has participated in and then get other participants
                    syncPhases = [.phaseGetVersion,
                                  .phaseGetSpecificParticipants,
                                  .phaseBuildGameList,
                                  .phaseGetRelatedParticipants,
                                  .phaseBuildPlayerList,
                                  .phaseGetPlayerList]
                }
            case .syncGetPlayerDetails:
                // Downdload the player records for each player in the list of specific emails
                syncPhases = [.phaseGetVersion,
                              .phaseGetPlayerList]
            }
            
            syncPhaseCount = -1
            self.syncController()
        }
    }
    
    private func syncController() {
        // Each element should either return true to signify complete (and hence should continue with next phase immediately)
        // or return true and then recall the controller from a completion block
        var nextPhase = true
        observer = nil
        
        if Sync.syncBackgroundCompletionInProgress {
            // Background task completing - wait for notification
            self.syncMessage("Waiting for previous operation to finish")
            observer = setSyncBackgroundCompletionNotification()
            return
        }
        
        while true {
            
            // Prepare for next phase
            syncPhaseCount += 1
        
            // Quit if errors or finished
            if errors != 0 || !Sync.syncInProgress || syncPhaseCount >= syncPhases.count {
                break
            }
            
            // Don't allow any phase to take longer than timeout seconds
            if self.timeout != nil {
                self.startTimer(self.timeout)
            }

            switch syncPhases[syncPhaseCount] {
            case .phaseGetVersion:
                nextPhase = getCloudVersion()
            case .phaseGetVersionAsync:
                nextPhase = getCloudVersion(async: true)
            case .phaseGetLastSyncDate:
                nextPhase = getLastSyncDate()
            case .phaseUpdateLastSyncDate:
                nextPhase = updateLastSyncDate()
            case .phaseGetExistingParticipants:
                nextPhase = self.getParticipantsFromCloud(.getExisting)
            case .phaseGetNewParticipants:
                nextPhase = self.getParticipantsFromCloud(.getNew)
            case .phaseGetGameParticipants:
                nextPhase = self.getParticipantsFromCloud(.getGame)
            case .phaseGetSpecificParticipants:
                nextPhase = self.getParticipantsFromCloud(.getSpecific)
            case .phaseGetRelatedParticipants:
                nextPhase = self.getParticipantsFromCloud(.getRelated)
            case .phaseUpdateParticipants:
                nextPhase = self.updateParticipantsFromCloud()
            case .phaseGetGames:
                nextPhase = self.getGamesFromCloud()
            case .phaseUpdateGames:
                nextPhase = self.updateGamesFromCloud()
            case .phaseSendGamesAndParticipants:
                nextPhase = self.sendUnconfirmedGamesAndParticipants()
            case .phaseGetPlayers:
                nextPhase = self.synchronisePlayersWithCloud()
            case .phaseSendPlayers:
                nextPhase = self.sendPlayersToCloud()
            case .phaseGetSendImages:
                self.fetchPlayerImagesFromCloud(self.playerImageFromCloud)
                self.sendPlayerImagesToCloud(self.playerImageToCloud)
                nextPhase = true
            case .phaseBuildGameList:
                nextPhase = self.buildGameListFromParticipants()
            case .phaseBuildPlayerList:
                nextPhase = self.buildPlayerListFromParticipants()
            case .phaseGetPlayerList:
                nextPhase = self.downloadPlayersFromCloud(specificExternalId: self.specificExternalId,
                                                          specificEmail: self.specificEmail,
                                                          downloadAction: self.addPlayerList,
                                                          completeAction: self.completeGetPlayers)
            }
            
            
            if !nextPhase {
                break
            }
            
        }
        if errors != 0 || syncPhaseCount >= syncPhases.count {
            self.syncCompletion()
        }
    }
    
    // MARK: - Get current version details ============================================================= -
    
    // Note this is always called first to check for compatibility
    // Other modes are called on successful completion
    
    private func getCloudVersion(async: Bool = false) -> Bool {
        // Fetch data from cloud
        var version = "0.0"
        var build: Int = 0
        var accessBlockVersion: String! = "0.0"
        var accessBlockMessage: String! = ""
        var syncBlockVersion: String! = "0.0"
        var syncBlockMessage: String! = ""
        var infoMessage: String! = ""
        var database: String! = ""
        var cloudRabbitMQUri = ""
        
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        let query = CKQuery(recordType: "Version", predicate: NSPredicate(value: true))
        let queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        queryOperation.queuePriority = .veryHigh
        queryOperation.recordFetchedBlock = { (record) -> Void in
            
            let cloudObject: CKRecord = record
            version = Utility.objectString(cloudObject: cloudObject, forKey: "version")
            build = Int(Utility.objectInt(cloudObject: cloudObject, forKey: "build"))
            accessBlockVersion = Utility.objectString(cloudObject: cloudObject, forKey: "accessVersion")
            accessBlockMessage = Utility.objectString(cloudObject: cloudObject, forKey: "accessMessage")
            syncBlockVersion = Utility.objectString(cloudObject: cloudObject, forKey: "syncVersion")
            syncBlockMessage = Utility.objectString(cloudObject: cloudObject, forKey: "syncMessage")
            infoMessage = Utility.objectString(cloudObject: cloudObject, forKey: "infoMessage")
            database = Utility.objectString(cloudObject: cloudObject, forKey: "database")
            cloudRabbitMQUri = Utility.objectString(cloudObject: cloudObject, forKey: "rabbitMQUri")
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error != nil {
                self.scorecard.latestVersion = "0.0"
                self.scorecard.latestBuild = 0
                self.errors += 1
                return
            }
            self.scorecard.latestVersion = version
            self.scorecard.latestBuild = build
            
            // Set and save rabbitMQ URI
            Scorecard.settingRabbitMQUri = cloudRabbitMQUri
            UserDefaults.standard.set(cloudRabbitMQUri, forKey: "rabbitMQUri")
            
            // Setup simulated notification rabbitMQ queue
            Utility.mainThread {
                if Config.pushNotifications_rabbitMQ &&  Utility.appDelegate?.notificationSimulator == nil {
                    Utility.appDelegate?.notificationSimulator = NotificationSimulator()
                    Utility.appDelegate?.notificationSimulator.start()
                }
            }
            
            // Set messages
            self.scorecard.settingVersionBlockAccess = false
            self.scorecard.settingVersionBlockSync = false
            self.scorecard.settingVersionMessage = ""
            
            if accessBlockVersion != nil &&
                Utility.compareVersions(version1: self.scorecard.settingVersion,
                                           version2: accessBlockVersion) != .greaterThan {
                
                self.scorecard.settingVersionBlockAccess = true
                if accessBlockMessage == "" {
                    accessBlockMessage = "A new version of the Contract Whist Scorecard app is available and this version is no longer supported. Please update to the latest version via the App Store."
                }
                self.scorecard.settingVersionMessage = accessBlockMessage
            }
            
            if !self.scorecard.settingVersionBlockAccess && self.scorecard.settingDatabase != "" && database != self.scorecard.settingDatabase {
                // Database (development/production) doesn't match!!
                self.scorecard.settingVersionBlockSync = true
                syncBlockMessage = "You are trying to connect to the '\(database!)' database but this device has previously synced with the '\(self.scorecard.settingDatabase)' database"
                if database == "development" {
                    // OK if copying live to development so reset it after warning
                    syncBlockMessage = syncBlockMessage + ". It has been reset"
                    self.scorecard.settingDatabase = database
                    UserDefaults.standard.set(database, forKey: "database")
                }
                self.scorecard.settingVersionMessage = syncBlockMessage
            }
            
            if !self.scorecard.settingVersionBlockAccess && !self.scorecard.settingVersionBlockSync && syncBlockVersion != nil &&
                Utility.compareVersions(version1: self.scorecard.settingVersion,
                                        version2: syncBlockVersion) != .greaterThan {
                
                self.scorecard.settingVersionBlockSync = true
                if syncBlockMessage == "" {
                    syncBlockMessage = "A new version of the Contract Whist Scorecard app is available and you will no longer be able to sync with iCloud using this version. Please update to the latest version via the App Store."
                }
                self.scorecard.settingVersionMessage = syncBlockMessage
                
            }
            
            if !self.scorecard.settingVersionBlockAccess && !self.scorecard.settingVersionBlockSync {
                if self.syncMode == .syncGetVersion && infoMessage != nil && infoMessage != "" {
                
                    self.scorecard.settingVersionMessage = infoMessage
                
                } else if self.syncMode == .syncGetVersion &&
                    Utility.compareVersions(version1: self.scorecard.settingVersion, build1: self.scorecard.settingBuild,
                                            version2: version, build2: build) == .lessThan  {
                    
                    self.scorecard.settingVersionMessage = "You are currently on version \(self.scorecard.settingVersion) (\(self.scorecard.settingBuild)) of the Contract Whist Scorecard app. A newer version \(version) (\(build)) is available. It is highly recommended that you update to the latest version."
                }
            }
            
            // Save messages for later use if fail to access cloud
            UserDefaults.standard.set(self.scorecard.settingVersionBlockAccess, forKey: "versionBlockAccess")
            UserDefaults.standard.set(self.scorecard.settingVersionBlockSync, forKey: "versionBlockSync")
            UserDefaults.standard.set(self.scorecard.settingVersionMessage, forKey: "versionMessage")
            if self.scorecard.settingDatabase == "" {
                self.scorecard.settingDatabase = database
                UserDefaults.standard.set(database, forKey: "database")
            }
            
            // If access and sync not blocked link to sync all if necessary - otherwise complete (and display message)
            if self.scorecard.settingVersionMessage != "" {
                // There is a message - either advisory in get version mode or an error
                self.syncAlert(self.scorecard.settingVersionMessage)
            }
            
            if async {
                self.completeInBackgroundFinish()
            } else {
                self.syncController()
            }
        }
        
        // Execute the query
        publicDatabase.add(queryOperation)
        
        if async {
            self.completeInBackgroundStart()
            return true
        }
    
        return false
    }
    
    // MARK: - Functions to get and update the last successful sync date -
    
    private func getLastSyncDate() -> Bool {
        self.nextSyncDate = Date()
        self.lastSyncDate = UserDefaults.standard.object(forKey: "confirmedSyncDate") as? Date
        if self.lastSyncDate == nil {
            self.lastSyncDate = Date(timeIntervalSinceReferenceDate: 0)
        }
        
        return true
    }
    
    private func updateLastSyncDate() -> Bool {
        if self.errors == 0 {
            UserDefaults.standard.set(self.nextSyncDate, forKey: "confirmedSyncDate")
        }
        
        return true
    }
    
    // MARK: - Functions to update local participant history from cloud ================================================ -
    
    // Note that the participant synchronise calls the game synchronise in its completion handler
    // The game synchronise in turn calls the game/participant upload in its completion handler
    // The game/participant upload in turn calls the player synchronise from its completion handler
    
    private func getParticipantsFromCloud(_ getParticipantMode: GetParticipantMode) -> Bool {
        // Note this routine returns immediately once cloud fetch is initiated
        // Sync continues from completion handler
        var gameUUIDList: [String]?
        self.cloudObjectList = []
        
        switch getParticipantMode {
        
        case .getGame:
            // Get participants for a list of all games updated since the cutoff date
            gameUUIDList = History.getNewGames(cutoffDate: lastSyncDate)
        case .getRelated:
            // Get participant for a list of games set up elsewhere (usually a list of games a particular player was involved in)
            gameUUIDList = self.gameUUIDList
        default:
            gameUUIDList = nil
        }

        return getParticipantsFromCloudQuery(getParticipantMode, gameUUIDList: gameUUIDList)
    }
    
    private func getParticipantsFromCloudQuery(_ getParticipantMode: GetParticipantMode, gameUUIDList: [String]? = nil, remainder: [String]? = nil, cursor: CKQueryOperation.Cursor! = nil) -> Bool {
        // Fetch data from cloud
        var queryOperation: CKQueryOperation
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        var predicate: NSCompoundPredicate
        var predicateList: [String]
        var gameUUIDList = gameUUIDList
        var remainder = remainder
        
        if cursor == nil {
            // First time in - setup the query
            switch getParticipantMode {
            case .getExisting:
                // Get participants based on players who were on this device before the cutoff date and only look at games since the cutoff since previous games should already be here
                predicateList = self.scorecard.playerEmailList(getPlayerMode: .getExisting, cutoffDate: self.lastSyncDate, specificEmail: self.specificEmail)
                let predicate1 = NSPredicate(format: "email IN %@", argumentArray: [predicateList])
                let predicate2 = NSPredicate(format: "syncDate >= %@", self.lastSyncDate as NSDate)
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
            case .getNew:
                // Get participants based on players who are new to this device - hence look at all games
                predicateList = self.scorecard.playerEmailList(getPlayerMode: .getNew, cutoffDate: self.lastSyncDate, specificEmail: self.specificEmail)
                let predicate1 = NSPredicate(format: "email IN %@", argumentArray: [predicateList])
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1])
            case .getSpecific:
                // Get particpants based on a list of (probably 1) email address
                predicateList = self.specificEmail
                let predicate1 = NSPredicate(format: "email IN %@", argumentArray: [predicateList])
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1])
            case .getGame, .getRelated:
                // Get participants for a list of games - Can only fetch 50 at a time
                if gameUUIDList == nil {
                    predicateList = []
                } else {
                    let split = 50
                    if gameUUIDList != nil && gameUUIDList!.count > split {
                        remainder = Array(gameUUIDList!.suffix(from: split))
                        gameUUIDList = Array(gameUUIDList!.prefix(upTo: split))
                    }
                    predicateList = gameUUIDList!
                }
                let predicate1 = NSPredicate(format: "gameUUID IN %@", argumentArray: [predicateList])
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1])
            }
            if predicateList.count == 0 {
                // Nothing in list - continue with next step
                self.syncMessage("No local participants to update")
                return true
            }
            let query = CKQuery(recordType: "Participants", predicate: predicate)
            if getParticipantMode == .getRelated {
                let sortDescriptor = NSSortDescriptor(key: "email", ascending: true)
                query.sortDescriptors = [sortDescriptor]
            }
            queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        } else {
            queryOperation = CKQueryOperation(cursor: cursor, qos: .userInteractive)
        }
        queryOperation.queuePriority = .veryHigh
        queryOperation.recordFetchedBlock = { (record) -> Void in
            let cloudObject: CKRecord = record
            self.cloudObjectList.append(cloudObject)
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error != nil {
                var message = "Unable to fetch participants from cloud!"
                if self.adminMode {
                    message = message + " " + error.debugDescription
                }
                self.syncMessage(message)
                self.errors += 1
                self.syncController()
                return
            }
            if self.adminMode {
                self.syncMessage("\(self.cloudObjectList.count) participant history records downloaded")
            }
            
            if cursor != nil {
                // More records to come - recurse
                _ = self.getParticipantsFromCloudQuery(getParticipantMode, gameUUIDList: nil, remainder: remainder, cursor: cursor)
            } else if remainder != nil {
                // More records to get - recurse
                _ = self.getParticipantsFromCloudQuery(getParticipantMode, gameUUIDList: remainder)
            } else {
                if !self.adminMode {
                    self.syncMessage("Participant history records downloaded")
                }
                
                self.syncController()
            }
        }
        
        // Execute the query
        publicDatabase.add(queryOperation)
        return false
        
    }
    
    private func updateParticipantsFromCloud() -> Bool {
        var created = 0
        var updated = 0
        
        if self.cloudObjectList.count == 0 {
            return true
        }
        
        for cloudObject in self.cloudObjectList {
            
            let gameUUID  = Utility.objectString(cloudObject: cloudObject, forKey: "gameUUID")
            let playerNumber  = Int16(Utility.objectInt(cloudObject: cloudObject, forKey: "playerNumber"))
            let historyParticipants = History.loadParticipants(gameUUID: gameUUID!,
                                                               playerNumber: Int(playerNumber))
            if historyParticipants.count > 0 {
                // Found - update it
                let historyParticipant = historyParticipants[0]
                let localRecordName = historyParticipant.participantMO.syncRecordID
                let localSyncDate = (historyParticipant.participantMO.syncDate ?? Date(timeIntervalSinceReferenceDate: -1)) as Date
                let cloudSyncDate = Utility.objectDate(cloudObject: cloudObject, forKey: "syncDate")
                if localRecordName == nil || (CKRecord.ID(recordName: localRecordName!) == cloudObject.recordID &&
                    cloudSyncDate! > localSyncDate) {
                    // Only update if never synced before or cloud newer and not a duplicate
                    _ = CoreData.update(updateLogic: {
                    
                        History.cloudParticipantToMO(cloudObject: cloudObject, participantMO: historyParticipant.participantMO)
                        updated += 1
                    
                    })
                }
            } else {
                // Not found - create it locally
                _ = CoreData.update(updateLogic: {
                    let participantMO = CoreData.create(from: "Participant") as! ParticipantMO
                    // Copy in data values from cloud
                    History.cloudParticipantToMO(cloudObject: cloudObject, participantMO: participantMO)
                    created += 1
                    
                })
            }
        }
 
        if self.adminMode {
            self.syncMessage("\(updated) participants updated - \(created) participants created locally")
        } else {
            self.syncMessage("Local participant history records updated")
        }
        
        return true
    }
    
    private func buildGameListFromParticipants() -> Bool {
        
        gameUUIDList = []
        
        if cloudObjectList.count == 0 {
            self.syncReturnPlayers(nil)
        } else {
            for cloudObject in cloudObjectList {
                let gameUUID = Utility.objectString(cloudObject: cloudObject, forKey: "gameUUID")
                if gameUUID != nil {
                    gameUUIDList.append(gameUUID!)
                }
            }
        }
        
        return true
    }
    
    private func buildPlayerListFromParticipants() -> Bool {
        var lastEmail = ""
        
        specificEmail = []
        for cloudObject in cloudObjectList {
            let email = Utility.objectString(cloudObject: cloudObject, forKey: "email")
            if email != nil && email != "" && email != lastEmail {
                specificEmail.append(email!)
                lastEmail = email!
            }
        }
        
        return true
    }
    
    // MARK: - Functions to update local games history from cloud ====================================================== -
    
    private func getGamesFromCloud() -> Bool {
        self.cloudObjectList = []
        let gameUUIDList = History.getNewParticpantGames(cutoffDate: self.lastSyncDate, specificEmail: self.specificEmail)
        if gameUUIDList.count == 0 {
            // No new games to process
            return true
        }
        return getGamesFromCloudQuery(gameUUIDList: gameUUIDList)
    }
    
    private func getGamesFromCloudQuery(gameUUIDList: [String]! = nil, remainder: [String]! = nil, cursor: CKQueryOperation.Cursor! = nil) -> Bool {
        // Fetch data from cloud
        var gameUUIDList = gameUUIDList
        var remainder = remainder
        
        var queryOperation: CKQueryOperation
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        
        if cursor == nil {
            // First time in - create the query operation - get games for any participants created locally since the last sync date
            
            // Can only fetch 50 at a time
            let split = 50
            if gameUUIDList != nil && gameUUIDList!.count > split {
                remainder = Array(gameUUIDList!.suffix(from: split))
                gameUUIDList = Array(gameUUIDList!.prefix(upTo: split))
            }
            
            let predicate = NSPredicate(format: "gameUUID IN %@", argumentArray: [gameUUIDList!])
            let query = CKQuery(recordType: "Games", predicate: predicate)
            queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
            
        } else {
            // Continuation of previous query
            queryOperation = CKQueryOperation(cursor: cursor, qos: .userInteractive)
        }
        
        queryOperation.queuePriority = .veryHigh
        queryOperation.recordFetchedBlock = { (record) -> Void in
            let cloudObject: CKRecord = record
            self.cloudObjectList.append(cloudObject)
        }

        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error != nil {
                var message = "Unable to fetch games from cloud!"
                if self.adminMode {
                    message = message + " " + error.debugDescription
                }
                self.syncMessage(message)
                self.errors += 1
                self.syncController()
                return
            }
            if self.adminMode {
                self.syncMessage("\(self.cloudObjectList.count) game history records downloaded")
            }
            
            if cursor != nil {
                // More to come - recurse
                _ = self.getGamesFromCloudQuery(gameUUIDList: nil, remainder: remainder, cursor: cursor)
            } else if remainder != nil {
                // More to get - recurse
                _ = self.getGamesFromCloudQuery(gameUUIDList: remainder)
            } else {
               if !self.adminMode {
                    self.syncMessage("Game history records downloaded")
                }
                
                self.syncController()
            }
        }
        
        // Execute the query
        publicDatabase.add(queryOperation)
        return false
        
    }
    
    private func updateGamesFromCloud() -> Bool {
        var updated = 0
        var created = 0
        
        if self.cloudObjectList.count == 0 {
            return true
        }
        
        for cloudObject in self.cloudObjectList {
            
            let gameUUID = Utility.objectString(cloudObject: cloudObject, forKey: "gameUUID")
            let history = History(gameUUID: gameUUID, getParticipants: false)
            if history.games.count != 0 {
                // Found - confirm and update it
                if !CoreData.update(updateLogic: {
                    
                    let historyGame = history.games[0]
                    let localRecordName = historyGame.gameMO.syncRecordID
                    let localSyncDate = (historyGame.gameMO.syncDate ?? Date(timeIntervalSinceReferenceDate: -1)) as Date
                    let cloudSyncDate = Utility.objectDate(cloudObject: cloudObject, forKey: "syncDate")
                    if localRecordName == nil || (CKRecord.ID(recordName: localRecordName!) == cloudObject.recordID &&
                        cloudSyncDate! > localSyncDate) {
                        // Only update if never synced before or cloud newer and not a duplicate
                        History.cloudGameToMO(cloudObject: cloudObject, gameMO: historyGame.gameMO)
                        updated += 1
                    }
                }) {
                    self.syncMessage("Error updating local game data")
                    self.errors += 1
                    return false
                }
            } else {
                // Not found - create it locally
                 if !CoreData.update(updateLogic: {
                    let gameMO = CoreData.create(from: "Game") as! GameMO
                    // Copy in data values from cloud
                    History.cloudGameToMO(cloudObject: cloudObject, gameMO: gameMO)
                    created += 1
                 }) {
                    self.syncMessage("Error creating local game data")
                    self.errors += 1
                    return false
                }
            }
        }
        
        if self.adminMode {
            self.syncMessage("\(updated) games updated - \(created) games created locally")
        } else {
            self.syncMessage("Local game history records updated")
        }
        
        return true
    }
    
    // MARK: - Functions to send any unconfirmed game/participant history to cloud ==================================== -
    
    private func sendUnconfirmedGamesAndParticipants() -> Bool {
        // Sends any unconfirmed games and participants
        var gamesQueued = 0
        var participantsQueued = 0
            self.cloudObjectList = []
        let history = History(unconfirmed: true)
        if history.games.count != 0 {
            for historyGame in history.games {
                // First check if game confirmed - i.e. we have a cloud RecordID - should all be unconfirmed
                if historyGame.gameMO.syncRecordID == nil {
                    // Not confirmed yet - send it
                    let cloudObject = CKRecord(recordType:"Games")
                    History.cloudGameFromMo(cloudObject: cloudObject, gameMO: historyGame.gameMO, syncDate: self.nextSyncDate)
                    self.cloudObjectList.append(cloudObject)
                    gamesQueued += 1
                }
                if historyGame.participant != nil {
                    for historyParticipant in historyGame.participant {
                        if historyGame.gameMO.syncRecordID == nil {
                            // Not confirmed yet - send it
                            let cloudObject = CKRecord(recordType:"Participants")
                            History.cloudParticipantFromMO(cloudObject: cloudObject, participantMO: historyParticipant.participantMO, syncDate: self.nextSyncDate)
                            self.cloudObjectList.append(cloudObject)
                            participantsQueued += 1
                        }
                    }
                }
            }
        }
        
        if self.cloudObjectList.count != 0 {
            return self.sendUnconfirmedGamesAndParticipantsToCloud(gamesQueued: gamesQueued, participantsQueued: participantsQueued)
        } else {
            return true
        }
    }
    
    private func sendUnconfirmedGamesAndParticipantsToCloud(gamesQueued: Int, participantsQueued: Int) -> Bool {
        // Send queued games and participants to cloud
        
        self.sendRecordsToCloud(records: self.cloudObjectList, completion: { (success: Bool) in
            if success {
                OperationQueue.main.addOperation {
                    if self.adminMode {
                        self.syncMessage("\(gamesQueued) games uploaded - \(participantsQueued) participants uploaded")
                    } else {
                        self.syncMessage("Games and participants uploaded")
                    }
                }
            }
            
            self.syncController()
        })
        return false
    }
    
    private func sendRecordsToCloud(records: [CKRecord], remainder: [CKRecord]? = nil, completion: ((Bool)->())? = nil) {
        // Copes with limit being exceeed which splits the load in two and tries again
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        
        let uploadOperation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        
        uploadOperation.isAtomic = true
        uploadOperation.database = publicDatabase
        
        uploadOperation.perRecordCompletionBlock = { (savedRecord: CKRecord, error: Error?) -> Void in
            // Ignore status as will just keep sending them until they come back down
            if error != nil {
            }
        }
        
        // Assign a completion handler
        uploadOperation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecords: [CKRecord.ID]?, error: Error?) -> Void in
            if error != nil {
                if let error = error as? CKError {
                    if error.code == .limitExceeded {
                        // Limit exceeded - split in two and try again
                        let split = Int(records.count / 2)
                        // Join records and remainder back together again
                        var allRecords = records
                        if remainder != nil {
                            allRecords += remainder!
                        }
                        // Now split at new break point
                        let firstBlock = Array(allRecords.prefix(upTo: split))
                        let secondBlock = Array(allRecords.suffix(from: split))
                        self.sendRecordsToCloud(records: firstBlock, remainder: secondBlock, completion: completion)
                    }
                } else {
                    if completion != nil {
                        completion!(false)
                    }
                }
            } else {
                if remainder != nil {
                    // Now need to send second block
                    self.sendRecordsToCloud(records: remainder!, completion: completion)
                } else if completion != nil {
                    completion!(true)
                }
            }
        }
        
        // Add the operation to an operation queue to execute it
        OperationQueue().addOperation(uploadOperation)
    }
    
    // MARK: - Functions to synchronise players with cloud ====================================================== -
    
    private func synchronisePlayersWithCloud(specificEmail: [String] = []) -> Bool {
        return downloadPlayersFromCloud(specificExternalId:nil,
                                        specificEmail: specificEmail,
                                        downloadAction: self.mergePlayerCloudObject,
                                        completeAction: self.completeSynchronisePlayersWithCloud)
    }
    
    private func downloadPlayersFromCloud(specificExternalId: String! = nil,
                                  specificEmail: [String],
                                  downloadAction: @escaping (CKRecord) -> (),
                                  completeAction: @escaping () -> ()) -> Bool {
        
        // Reset state
        cloudObjectList = []
        cloudPlayerRecordList = []
        downloadedPlayerRecordList = []
        localPlayerRecordList = []
        localPlayerMOList = []
        playerImageFromCloud = []
        playerImageToCloud = []
        
        return downloadPlayersFromCloudQuery(specificExternalId:specificExternalId,
                                             specificEmail: specificEmail,
                                             downloadAction: downloadAction,
                                             completeAction: completeAction)
    }
    
    private func downloadPlayersFromCloudQuery(specificExternalId: String! = nil,
                                       specificEmail: [String],
                                       cursor: CKQueryOperation.Cursor! = nil,
                                       downloadAction: @escaping (CKRecord) -> (),
                                       completeAction: @escaping () -> ()) -> Bool {
        
        var queryOperation: CKQueryOperation
        var predicate: NSPredicate!
        
        // Fetch player records from cloud
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        if cursor == nil {
            // First time in - set up the query
            if specificExternalId != nil {
                predicate = NSPredicate(format: "externalId = %@", self.specificExternalId)
            } else {
                var emailList: [String]
                if self.specificEmail.count != 0 {
                    emailList = self.specificEmail
                } else if self.syncMode == .syncGetPlayers {
                    emailList = History.getParticipantEmailList()
                } else {
                    emailList = self.scorecard.playerEmailList()
                }
                if emailList.count == 0 {
                    return true
                }
                predicate = NSPredicate(format: "email IN %@", argumentArray: [emailList])
            }
            let query = CKQuery(recordType: "Players", predicate: predicate)
            let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
            query.sortDescriptors = [sortDescriptor]
            queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        } else {
            // Continue previous query
            queryOperation = CKQueryOperation(cursor: cursor, qos: .userInteractive)
        }
        if specificExternalId != nil {
            queryOperation.desiredKeys = ["name", "email", "externalId"]
        } else {
            queryOperation.desiredKeys = ["name", "email", "dateCreated", "datePlayed", "nameDate",
                                          "emailDate", "thumbnailDate","gamesPlayed", "gamesWon",
                                          "totalScore", "handsPlayed", "handsMade", "twosMade",
                                          "maxScore", "maxMade", "maxTwos",
                                          "maxScoreDate", "maxMadeDate", "maxTwosDate",
                                          "externalId", "visibleLocally"]
        }
        queryOperation.queuePriority = .veryHigh
        queryOperation.recordFetchedBlock = { (record) -> Void in
            let cloudObject: CKRecord = record
            downloadAction(cloudObject)
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error != nil {
                var message = "Unable to fetch players from cloud!"
                if self.adminMode {
                    message = message + " " + error.debugDescription
                }
                self.syncMessage(message)
                self.errors += 1
                self.syncController()
                return
            }
            
            if self.adminMode {
                self.syncMessage("\(self.downloadedPlayerRecordList.count) player records downloaded")
            }
            
            if cursor != nil {
                // More to come - recurse
                _ = self.downloadPlayersFromCloudQuery(specificExternalId: specificExternalId,
                                                       specificEmail: specificEmail,
                                                       cursor: cursor,
                                                       downloadAction: downloadAction,
                                                       completeAction: completeAction)
            } else {
                completeAction()
            }
        }
        
        // Execute the query
        publicDatabase.add(queryOperation)
        return false
        
    }
    
    private func mergePlayerCloudObject(_ cloudObject: CKRecord) {
        // First check if this record already in list
        let cloudRecord = PlayerDetail(scorecard)
        let localRecord = PlayerDetail(scorecard)
        var changed = false
        
        func add(to: Int64, _ value: Int64) -> Int64 {
            if value != 0 {
                changed = true
            }
            return to + value
        }
        
        func set(to: Int64, _ value: Int64) -> Int64 {
            if to != value {
                changed = true
            }
            return value
        }
        
        cloudRecord.fromCloudObject(cloudObject: cloudObject)
        self.downloadedPlayerRecordList.append(cloudRecord)
        
        // Try to match by email address
        let found = scorecard.playerList.index(where: { $0.email?.lowercased() == cloudRecord.email.lowercased() })
        if found != nil {

            // Merge the records
            let localMO = scorecard.playerList[found!]
            localRecord.fromManagedObject(playerMO: localMO)
            localRecord.syncRecordID = cloudObject.recordID.recordName
            
            // Update thumbnail to latest version
            // Need to queue updates for later
            
            if localRecord.thumbnail == nil {
                // If no thumbnail ignore local date
                localRecord.thumbnailDate = nil
            }
            
            if cloudRecord.thumbnailDate != nil && (localRecord.thumbnailDate == nil || localRecord.thumbnailDate < cloudRecord.thumbnailDate) {
                // thumbnail updated on cloud - queue overwrite of local copy
                self.playerImageFromCloud.append(localMO)
            } else if localRecord.thumbnailDate != nil && (cloudRecord.thumbnailDate == nil || localRecord.thumbnailDate > cloudRecord.thumbnailDate) {
                // Local thumbnail updated - queue overwrite of cloud copy
                self.playerImageToCloud.append(localMO)
                if localMO.syncRecordID == nil {
                    // Need to sync main record to get recordID
                    changed = true
                }
            }
            
            // Update the cloud with any new scores locally
            cloudRecord.gamesPlayed = add(to: cloudRecord.gamesPlayed, localRecord.gamesPlayed - localMO.syncGamesPlayed)
            cloudRecord.gamesWon = add(to: cloudRecord.gamesWon, localRecord.gamesWon - localMO.syncGamesWon)
            cloudRecord.totalScore = add(to: cloudRecord.totalScore,localRecord.totalScore - localMO.syncTotalScore)
            cloudRecord.handsPlayed = add(to: cloudRecord.handsPlayed, localRecord.handsPlayed - localMO.syncHandsPlayed)
            cloudRecord.handsMade = add(to: cloudRecord.handsMade, localRecord.handsMade - localMO.syncHandsMade)
            cloudRecord.twosMade = add(to: cloudRecord.twosMade,localRecord.twosMade - localMO.syncTwosMade)
            
            // Copy back new totals to local
            localRecord.gamesPlayed = set(to: localRecord.gamesPlayed,cloudRecord.gamesPlayed)
            localRecord.gamesWon = set(to: localRecord.gamesWon, cloudRecord.gamesWon)
            localRecord.totalScore = set(to: localRecord.totalScore, cloudRecord.totalScore)
            localRecord.handsPlayed = set(to:localRecord.handsPlayed, cloudRecord.handsPlayed)
            localRecord.handsMade = set(to: localRecord.handsMade, cloudRecord.handsMade)
            localRecord.twosMade = set(to: localRecord.twosMade, cloudRecord.twosMade)
            
            // Update the high scores
            if localRecord.maxScore < cloudRecord.maxScore {
                localRecord.maxScore = cloudRecord.maxScore
                localRecord.maxScoreDate = cloudRecord.maxScoreDate
                changed = true
            } else if cloudRecord.maxScore < localRecord.maxScore {
                cloudRecord.maxScore = localRecord.maxScore
                cloudRecord.maxScoreDate = localRecord.maxScoreDate
                changed = true
            }
            if localRecord.maxMade < cloudRecord.maxMade {
                localRecord.maxMade = cloudRecord.maxMade
                localRecord.maxMadeDate = cloudRecord.maxMadeDate
                  changed = true
            } else if cloudRecord.maxMade < localRecord.maxMade {
                cloudRecord.maxMade = localRecord.maxMade
                cloudRecord.maxMadeDate = localRecord.maxMadeDate
                  changed = true
            }
            if localRecord.maxTwos < cloudRecord.maxTwos {
                localRecord.maxTwos = cloudRecord.maxTwos
                localRecord.maxTwosDate = cloudRecord.maxTwosDate
                  changed = true
            } else if cloudRecord.maxTwos < localRecord.maxTwos {
                cloudRecord.maxTwos = localRecord.maxTwos
                cloudRecord.maxTwosDate = localRecord.maxTwosDate
                  changed = true
            }
            
            // Update date created / last played
            if cloudRecord.dateCreated == nil || localRecord.dateCreated < cloudRecord.dateCreated {
                cloudRecord.dateCreated = localRecord.dateCreated
                changed = true
            } else if localRecord.dateCreated == nil || cloudRecord.dateCreated < localRecord.dateCreated {
                localRecord.dateCreated = cloudRecord.dateCreated
                changed = true
            }
            
            if cloudRecord.datePlayed == nil || (localRecord.datePlayed != nil && localRecord.datePlayed > cloudRecord.datePlayed) {
                cloudRecord.datePlayed = localRecord.datePlayed
                changed = true
            } else if localRecord.datePlayed == nil || (cloudRecord.datePlayed != nil && cloudRecord.datePlayed > localRecord.datePlayed) {
                localRecord.datePlayed = cloudRecord.datePlayed
                changed = true
            }
            
            // Update the local external Id - Assume cloud is master
            if localRecord.externalId != cloudRecord.externalId {
                localRecord.externalId = cloudRecord.externalId
                changed = true
            }
            
            if changed {
                // Something has changed - re-sync
            
                // Set sync dates
                cloudRecord.syncDate = Date()
                localRecord.syncDate = cloudRecord.syncDate
 
                // Update the cloud record and queue for update
                cloudRecord.toCloudObject(cloudObject: cloudObject)
                self.cloudObjectList.append(cloudObject)
                self.cloudPlayerRecordList.append(cloudRecord)
                
                // Queue the local record for update and flag it as not synced
                self.localPlayerMOList.append(localMO)
                self.localPlayerRecordList.append(localRecord)
                self.localPlayerRecordList[self.localPlayerRecordList.count - 1].syncedOk = false
                
            }
        }
    }
    
    private func completeSynchronisePlayersWithCloud() {
        if !self.adminMode {
            self.syncMessage("Player records downloaded")
        }
        self.syncController()
    }

    private func addPlayerList(_ cloudObject: CKRecord) {
        let cloudRecord = PlayerDetail(self.scorecard)
        cloudRecord.fromCloudObject(cloudObject: cloudObject)
        self.downloadedPlayerRecordList.append(cloudRecord)
    }
    
    private func completeGetPlayers() {
        if self.errors != 0 {
            // Just return empty
            self.errors = 0
            self.syncReturnPlayers(nil)
        } else {
            for playerDetail in self.downloadedPlayerRecordList {
                if self.specificExternalId == nil {
                    // Make sure we don't have a duplicate name (if not just checking External Ids)
                    playerDetail.dedupName(scorecard)
                }
            }
            self.syncReturnPlayers(self.downloadedPlayerRecordList)
        }
    }
    
    private func sendPlayersToCloud() -> Bool {
        // Add any records which are local (with email) but not in cloud
        self.queueMissingPlayers()
        
        // Upload any changed / new records to cloud
        if self.cloudObjectList.count != 0 {
            return self.updatePlayersToCloud()
        } else {
            self.syncMessage("No player records to sync")
            return true
        }
    }
    
    private func queueMissingPlayers() {
        // Now add in records that are not in cloud yet
        if self.specificEmail.count != 0 {
            // Search for specific email
            for email in specificEmail {
                let found = scorecard.playerList.index(where: { $0.email!.lowercased() as String == email.lowercased() })
                if found != nil {
                    self.queueMissingPlayer(playerMO: scorecard.playerList[found!])
                }
            }
        } else {
            // Try entire list
            for playerMO in self.scorecard.playerList {
                self.queueMissingPlayer(playerMO: playerMO)
            }
        }
    }
    
    private func queueMissingPlayer(playerMO: PlayerMO) {
        let matchEmail = playerMO.email
        if matchEmail != nil && matchEmail != "" {
            // Check this email isn't already in cloud list (otherwise duplicates would multiply forever)
            let found = self.downloadedPlayerRecordList.index(where: { $0.email.lowercased() as String == matchEmail!.lowercased() })
            
            if found == nil {
                // Record is not in the cloud - send it
                let cloudObject = CKRecord(recordType:"Players")
                let cloudRecord = PlayerDetail(scorecard)
                cloudRecord.fromManagedObject(playerMO: playerMO)
                cloudRecord.syncDate = Date()
                cloudRecord.syncRecordID = nil
                cloudRecord.toCloudObject(cloudObject: cloudObject)
                self.cloudObjectList.append(cloudObject)
                
                // Queue local copy for update
                self.localPlayerRecordList.append(cloudRecord)
                self.localPlayerRecordList[self.localPlayerRecordList.count - 1].syncedOk = false
                self.localPlayerMOList.append(playerMO)
                
                // Queue thumbnail for upload if there is one
                if playerMO.thumbnail != nil {
                    self.playerImageToCloud.append(playerMO)
                }
            }
        }
    }
    
    private func updatePlayersToCloud() -> Bool {
        // Mark all records to be updated as "Sync in progress"
        
        if !CoreData.update(updateLogic: {
            for playerNumber in 1...self.localPlayerRecordList.count {
                self.localPlayerMOList[playerNumber - 1].syncInProgress = true
            }
        }) {
            self.syncMessage("Error marking local player records dirty")
            self.errors += 1
            return true
        }
        
        // Create a CKModifyRecordsOperation operation
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        
        let uploadOperation = CKModifyRecordsOperation(recordsToSave: self.cloudObjectList, recordIDsToDelete: nil)
        
        uploadOperation.isAtomic = true
        uploadOperation.database = publicDatabase
        
        uploadOperation.perRecordCompletionBlock = { (savedRecord: CKRecord, error: Error?) -> Void in
            if error != nil {
                self.syncMessage("Error updating \(savedRecord.object(forKey: "name")!) (\(error.debugDescription))")
                self.errors += 1
                self.syncController()
            } else {
                // Mark the record as synced OK
                for playerNumber in 1...self.localPlayerRecordList.count {
                    let cloudEmail = savedRecord.object(forKey: "email") as! String
                    let localEmail = self.localPlayerRecordList[playerNumber-1].email
                    if localEmail == cloudEmail {
                        self.localPlayerRecordList[playerNumber-1].syncedOk = true
                        // Retrieve record ID
                        self.localPlayerRecordList[playerNumber-1].syncRecordID = savedRecord.recordID.recordName
                    }
                }
                self.syncMessage("\(savedRecord.object(forKey: "name")!) updated")
            }
        }
        
        // Assign a completion handler
        uploadOperation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecords: [CKRecord.ID]?, error: Error?) -> Void in
            guard error==nil else {
                self.syncMessage("Error updating records. Sync failed")
                self.errors += 1
                self.syncController()
                return
            }
            
            // Assume all saved as set atomic so can update core data locally
            if !CoreData.update(updateLogic: {

                for playerNumber in 1...self.localPlayerRecordList.count {
                    // Copy back edited data if synced OK
                    if self.localPlayerRecordList[playerNumber-1].syncedOk {
                        self.localPlayerRecordList[playerNumber-1].toManagedObject(playerMO: self.localPlayerMOList[playerNumber - 1])
                        // Reset sync values
                        self.localPlayerMOList[playerNumber - 1].syncGamesPlayed = self.localPlayerMOList[playerNumber - 1].gamesPlayed
                        self.localPlayerMOList[playerNumber - 1].syncGamesWon = self.localPlayerMOList[playerNumber - 1].gamesWon
                        self.localPlayerMOList[playerNumber - 1].syncTotalScore = self.localPlayerMOList[playerNumber - 1].totalScore
                        self.localPlayerMOList[playerNumber - 1].syncHandsPlayed = self.localPlayerMOList[playerNumber - 1].handsPlayed
                        self.localPlayerMOList[playerNumber - 1].syncHandsMade = self.localPlayerMOList[playerNumber - 1].handsMade
                        self.localPlayerMOList[playerNumber - 1].syncTwosMade = self.localPlayerMOList[playerNumber - 1].twosMade
                        // Store record ID (for new records)
                        self.localPlayerMOList[playerNumber - 1].syncRecordID = self.localPlayerRecordList[playerNumber-1].syncRecordID
                    }
                    // Clear sync in progress flag
                    self.localPlayerMOList[playerNumber - 1].syncInProgress = false
                }
            }) {
                self.syncMessage("Error updating local player records")
                self.errors += 1
            }
            
            Utility.mainThread {
                self.syncMessage("Sync complete")
            }
            
            self.syncController()
            
        }
        
        // Add the operation to an operation queue to execute it
        OperationQueue().addOperation(uploadOperation)
        return false
    }
    
    public func fetchPlayerImagesFromCloud(_ playerImageFromCloud: [PlayerMO]) {
        if playerImageFromCloud.count > 0 {
            
            let cloudContainer = CKContainer.default()
            let publicDatabase = cloudContainer.publicCloudDatabase
            var imageRecordID: [CKRecord.ID] = []
            
            for playerNumber in 1...playerImageFromCloud.count {
                imageRecordID.append(CKRecord.ID(recordName: playerImageFromCloud[playerNumber-1].syncRecordID!))
            }
            let fetchOperation = CKFetchRecordsOperation(recordIDs: imageRecordID)
            fetchOperation.desiredKeys = ["email", "thumbnail", "thumbnailDate"]
            
            fetchOperation.perRecordCompletionBlock = { (cloudObject: CKRecord?, syncRecordID: CKRecord.ID?, error: Error?) -> Void in
                if error == nil && cloudObject != nil {
                    self.cloudObjectList.append(cloudObject!)
                }
            }
            fetchOperation.fetchRecordsCompletionBlock = { (records, error) in
                var playerObjectId: [NSManagedObjectID] = []
                for cloudObject in self.cloudObjectList {
                    let playerMO = self.scorecard.findPlayerByEmail(Utility.objectString(cloudObject: cloudObject, forKey: "email"))
                    if playerMO != nil {
                        if CoreData.update(updateLogic: {
                            var thumbnail: Data?
                            thumbnail = Utility.objectImage(cloudObject: cloudObject, forKey: "thumbnail") as Data?
                            playerMO!.thumbnail = thumbnail
                            playerMO!.thumbnailDate = Utility.objectDate(cloudObject: cloudObject, forKey: "thumbnailDate")
                        }) {
                            playerObjectId.append(playerMO!.objectID)
                        }
                    }
                }
                // Send a notification to any objects that might be interested with the object ID of the playerMO object ID
                for objectId in playerObjectId {
                    NotificationCenter.default.post(name: .playerImageDownloaded, object: self, userInfo: ["playerObjectID": objectId])
                }
                self.completeInBackgroundFinish()
            }
            self.completeInBackgroundStart()
            publicDatabase.add(fetchOperation)
        }
    }
    
    private func sendPlayerImagesToCloud(_ playerImageToCloud: [PlayerMO]) {
        if playerImageToCloud.count > 0 {
            
            let cloudContainer = CKContainer.default()
            let publicDatabase = cloudContainer.publicCloudDatabase
            
            for playerNumber in 1...playerImageToCloud.count {
                // Fetch record
                let imageRecordID = CKRecord.ID(recordName: playerImageToCloud[playerNumber-1].syncRecordID!)
                let fetchOperation = CKFetchRecordsOperation(recordIDs: [imageRecordID])
                fetchOperation.desiredKeys = []
                fetchOperation.fetchRecordsCompletionBlock = { (records, error) in
                    if error != nil {
                    } else {
                        let cloudImageObject: CKRecord = records![imageRecordID]!
                        
                        // Update thumbnail and date
                        var thumbnail: NSData? = nil
                        if let image = playerImageToCloud[playerNumber-1].thumbnail {
                            thumbnail = image as NSData
                        }
                        cloudImageObject.setValue(playerImageToCloud[playerNumber-1].thumbnailDate , forKey: "thumbnailDate")
                        Utility.imageToObject(cloudObject: cloudImageObject, thumbnail: thumbnail, name: playerImageToCloud[playerNumber-1].name!)
                        
                        // Save it
                        let uploadOperation = CKModifyRecordsOperation(recordsToSave: [cloudImageObject], recordIDsToDelete: nil)
                        
                        uploadOperation.isAtomic = true
                        uploadOperation.database = publicDatabase
                        
                        uploadOperation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecords: [CKRecord.ID]?, error: Error?) -> Void in
                            
                            // Tidy up temporary files
                            Utility.tidyObject(name: playerImageToCloud[playerNumber-1].name!)
                        }
                        // Add the operation to an operation queue to execute it
                        OperationQueue().addOperation(uploadOperation)

                    }
                }
                publicDatabase.add(fetchOperation)
            }
        }
    }
    
    public func updateExternalIds(playerIdList: [String : String], completion: @escaping (Bool, String)->()) {
        // Routine to update external Ids linked to players in the cloud immediately (without waiting for sync)
        // Not currently in use - could use for skype login for example
        
        var queryOperation: CKQueryOperation
        var predicate: NSPredicate!
        var emailList: [String] = []
        var downloadList: [CKRecord] = []
        
        // Build player list
        for (player, _) in playerIdList {
            emailList.append(player)
        }
        // Fetch player records from cloud
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        predicate = NSPredicate(format: "email IN %@", argumentArray: [emailList])
        let query = CKQuery(recordType: "Players", predicate: predicate)
        queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        queryOperation.desiredKeys = ["name", "email", "externalId"]
        queryOperation.queuePriority = .veryHigh
        queryOperation.recordFetchedBlock = { (record) -> Void in
            downloadList.append(record)
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error != nil || cursor != nil {
                var message = "Unable to fetch players from cloud!"
                if self.adminMode {
                    message = message + " " + error.debugDescription
                }
                completion(false, message)
                return
            }
            
            // Update the External Ids
            for record in downloadList {
                if let playerEmail = Utility.objectString(cloudObject: record, forKey: "email") {
                    var value = playerIdList[playerEmail]
                    if value == "" {
                        value = nil
                    }
                    record.setValue(value, forKey: "externalId")
                }
            }
            
            // Now send back the records with External Id updated
            let cloudContainer = CKContainer.default()
            let publicDatabase = cloudContainer.publicCloudDatabase
            
            let uploadOperation = CKModifyRecordsOperation(recordsToSave: downloadList, recordIDsToDelete: nil)
            
            uploadOperation.isAtomic = true
            uploadOperation.database = publicDatabase
            
            // Assign a completion handler
            uploadOperation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecords: [CKRecord.ID]?, error: Error?) -> Void in
                if error != nil {
                    completion(false, "Error updating records. Sync failed")
                    return
                }
                completion(true, "Completed successfully")
            }
            
            // Add the operation to an operation queue to execute it
            OperationQueue().addOperation(uploadOperation)
        }
        
        // Execute the download query
        publicDatabase.add(queryOperation)
    }
    
    // MARK: - Utility Routines ======================================================================== -

    private func syncMessage(_ message: String) {
        Utility.debugMessage("sync", message)
        if self.delegate != nil {
            self.delegate?.syncMessage(message)
        }
    }
    
    private func syncAlert(_ message: String) {
        if self.delegate != nil {
            self.errors = -1
            self.delegate?.syncAlert(message, completion: self.syncCompletion)
        }
    }
    
    private func syncCompletion() {
        let delegate = self.delegate
        // All done
        if Sync.syncInProgress {
            // Stop timer
            if self.timer != nil {
                self.timer.invalidate()
            }
            // Disconnect
            Sync.syncInProgress = false
            self.completeInBackgroundSet()
            self.delegate = nil
            // Call the delegate completion handler if there is one
            if delegate != nil {
                delegate?.syncCompletion(self.errors)
            }
        }
    }
    
    private func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
        // All done
        Sync.syncInProgress = false
        self.completeInBackgroundSet()
        // Call the delegate handler if there is one
        delegate?.syncReturnPlayers(playerList)
        self.syncController()
    }
    
    private func startTimer(_ seconds: Double) {
        if self.timer != nil {
            self.timer.invalidate()
        }
        self.timer = Timer.scheduledTimer(timeInterval: seconds, target: self, selector: #selector(self.timerTimeout), userInfo: nil, repeats: false)
    }
    
    @objc internal func timerTimeout() {
        self.syncAlert("Sync timed out")
    }
    
    private func completeInBackgroundFinish() {
        Utility.debugMessage("Sync", "Sync in background complete")
        Sync.syncBackgroundCompletionInProgress = false
        self.setSyncBackgroundCompletionInProgress = false
        NotificationCenter.default.post(name: .syncBackgroundCompletion, object: self, userInfo: nil)
    }
    
    private func completeInBackgroundStart() {
        if !Sync.syncInProgress {
            Sync.syncBackgroundCompletionInProgress = true
        } else {
            self.setSyncBackgroundCompletionInProgress = true
        }
    }
    
    private func completeInBackgroundSet() {
        if self.setSyncBackgroundCompletionInProgress {
            Sync.syncBackgroundCompletionInProgress = true
            self.setSyncBackgroundCompletionInProgress = false
        }
    }
    
    private func setSyncBackgroundCompletionNotification() -> NSObjectProtocol? {
        // Set a notification for background completion
        let observer = NotificationCenter.default.addObserver(forName: .syncBackgroundCompletion, object: nil, queue: nil) { (notification) in
            self.syncController()
        }
        return observer
    }
}

// MARK: - Utility Classes ========================================================================= -

extension Notification.Name {
    static let playerImageDownloaded = Notification.Name("playerImageDownloaded")
    static let syncBackgroundCompletion = Notification.Name("syncBackgroundCompletion")
}

extension CKQueryOperation {
    
    convenience init(query: CKQuery, qos: QualityOfService) {
        self.init(query: query)
        self.qualityOfService = qos
    }
    
    convenience init(cursor: CKQueryOperation.Cursor, qos: QualityOfService) {
        self.init(cursor: cursor)
        self.qualityOfService = qos
    }
}


