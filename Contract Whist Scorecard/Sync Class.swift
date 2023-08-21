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

@objc public enum SyncStage: Int, CaseIterable {
    case started = -1
    case initialise = 0
    case downloadPlayers = 1
    case downloadGames = 2
    case uploadGames = 3
    case uploadPlayers = 4
    case complete = 5
}

@objc protocol SyncDelegate: AnyObject {
    
    // A method to manage a message from the sync controller
    @objc optional func syncMessage(_ message: String)
    
    // A method to manage stage completion in all mode
    @objc optional func syncStageComplete(_ stage: SyncStage)
    
    // A method to manage an error condition
    @objc optional func syncAlert(_ message: String, completion: @escaping () -> ())
    
    // Method to be called when synchronisation is complete
    @objc optional func syncCompletionWait(_ errors: Int, completion: @escaping ()->())
    @objc optional func syncCompletion(_ errors: Int)

    // A method to be called if the sync is queued
    @objc optional func syncQueued()
    
    // A method to be called when the sync is de-queued and started
    @objc optional func syncStarted()
    
    // A method to return a player list (only used for getPlayers/getPlayerDetails mode but couldn't make it optional)
    @objc optional func syncReturnPlayers(_ playerList: [PlayerDetail]!, _ thisPlayerUUID: String?)
    
    // A debug property to identify the calling process
    @objc optional var syncDelegateDescription: String { get }
}

public enum SyncMode {
    case syncAll
    case syncBeforeGame
    case syncGetPlayers
    case syncUpdatePlayers
    case syncGetPlayerDetails
    case syncGetVersion
}

private enum SyncPhase {
    case phaseGetVersion
    case phaseGetLastSyncDate
    case phaseUpdateLastSyncDate
    case phaseSendUserTerms
    case phaseGetCurrentGameParticipants    // Records for players in current game (or just this player)
    case phaseGetExistingParticipants
    case phaseGetNewParticipants
    case phaseGetGameParticipants           // Participants for specific historic games
    case phaseUpdateParticipants
    case phaseGetGames
    case phaseUpdateGames
    case phaseSendGamesAndParticipants
    case phaseReplaceTemporaryPlayerUUIDs
    case phaseGetPlayers
    case phaseGetLinkedPlayers
    case phaseGetPlayerList
    case phaseSendPlayers
    case phaseGetAwards
    case phaseSendAwards
    case phaseRebuildWinStreaks
    case phaseGetSendImages
    case phaseStartedStageComplete
    case phaseInitialiseStageComplete
    case phaseDownloadGamesStageComplete
    case phaseUploadGamesStageComplete
    case phaseDownloadPlayersStageComplete
    case phaseUploadPlayersStageComplete
}

private enum GetParticipantMode {
    case getCurrentGame
    case getExisting
    case getNew
    case getGame
    case getSpecific
}

class Sync {
    
    // A class which synchronises the local core data representation with the cloud
    // It has no UI - it expects the calling class to
    
    // MARK: - Class Properties ======================================================================== -
    
    // Delegate for callback protocol
    public weak var delegate: SyncDelegate?
    
    // Local class variables
    private var errors = 0
    private var cloudObjectList: [CKRecord] = []
    private var syncMode = SyncMode.syncAll
    private var syncPhases: [SyncPhase]!
    private var syncPhaseCount = -1
    private var alertInProgress = false
    private var timer: Timer!
    private var timeout: Double!
    private let uuid = UUID().uuidString
    public static let cloudKitContainer = CKContainer.init(identifier: Config.iCloudIdentifier)
    
    // Variables to hold updates
    public static var syncInProgress = false
    private var observer: NSObjectProtocol?
    
    // Player sync state
    private var cloudPlayerRecordList: [PlayerDetail] = []
    private var downloadedPlayerRecordList: [PlayerDetail] = []
    private var localPlayerRecordList: [PlayerDetail] = []
    private var localPlayerMOList: [PlayerMO] = []
    private var playerImageFromCloud: [PlayerMO] = []
    private var playerImageToCloud: [PlayerMO] = []
    private var specificPlayerUUIDs: [String]!
    private var thisPlayerUUID: String!
    private var specificEmail: String!
    private var participantPlayerUUIDList: [String] = []
    private var useMainThread: Bool = true

    // Game / participant sync state
    private var nextSyncDate: Date!
    private var lastSyncDate: Date!
    private var newGameList: [GameMO]!
    private var gameUUIDList: [String]!
    
    private let recordIdDateFormat = "yyyy-MM-dd-HH-mm-ss"

    
    // MARK: - Public class methods -
    
    public func stop() {
        if syncPhases != nil {
            self.syncPhaseCount = syncPhases.count
            self.delegate = nil
        }
    }
        
    public func synchronise(syncMode: SyncMode = .syncAll, specificPlayerUUIDs: [String] = [], specificEmail: String! = nil, timeout: Double! = 30.0, waitFinish: Bool, okToSyncWithTemporaryPlayerUUIDs: Bool = false, mainThread: Bool = true) -> Bool {
        // Reset state
        errors = 0
        cloudObjectList = []
        participantPlayerUUIDList = []
        var success = false

        if !Sync.syncInProgress || waitFinish {
            self.errors = 0
            self.syncMode = syncMode
            self.specificPlayerUUIDs = specificPlayerUUIDs
            self.specificEmail = specificEmail
            self.thisPlayerUUID = nil
            self.timeout = timeout
            self.useMainThread = mainThread
            
            switch syncMode {
            case .syncGetVersion:
                syncPhases = [.phaseGetVersion]
            case .syncAll:
                syncPhases = [.phaseStartedStageComplete,
                              .phaseGetVersion,
                              .phaseGetLastSyncDate,
                              .phaseSendUserTerms,
                              .phaseInitialiseStageComplete,
                              .phaseReplaceTemporaryPlayerUUIDs,
                              .phaseGetPlayers,
                              .phaseSendPlayers,
                              .phaseGetAwards,
                              .phaseSendAwards,
                              .phaseDownloadPlayersStageComplete,
                              .phaseGetExistingParticipants, .phaseUpdateParticipants,
                              .phaseGetNewParticipants,      .phaseUpdateParticipants,
                              .phaseGetGames,                .phaseUpdateGames,
                              .phaseGetGameParticipants,     .phaseUpdateParticipants,
                              .phaseDownloadGamesStageComplete,
                              .phaseSendGamesAndParticipants,
                              .phaseUpdateLastSyncDate,
                              .phaseUploadGamesStageComplete,
                              .phaseGetSendImages,
                              .phaseRebuildWinStreaks,
                              .phaseUploadPlayersStageComplete]
            case .syncBeforeGame:
                syncPhases = [.phaseGetVersion,
                              .phaseGetLastSyncDate,
                              .phaseGetPlayers,
                              .phaseGetAwards,
                              .phaseGetCurrentGameParticipants,
                              .phaseUpdateParticipants,
                              .phaseRebuildWinStreaks]
            case .syncUpdatePlayers:
                // Synchronise players in list with cloud
                syncPhases = [.phaseGetVersion,
                              .phaseReplaceTemporaryPlayerUUIDs,
                              .phaseGetPlayers,
                              .phaseSendPlayers,
                              .phaseGetSendImages]
            case .syncGetPlayers:
                // General request to get any players linked to currently loaded players or a specific email - now using links
                syncPhases = [.phaseGetVersion,
                              .phaseReplaceTemporaryPlayerUUIDs,
                              .phaseGetLinkedPlayers,
                              .phaseGetPlayerList]
            case .syncGetPlayerDetails:
                // Download the player records for each player in the list of specific playerUUIDs
                // Note that this is only intended for players who are not already on this device
                syncPhases = [.phaseGetVersion,
                              .phaseReplaceTemporaryPlayerUUIDs,
                              .phaseGetPlayerList]
            }
            
            if !okToSyncWithTemporaryPlayerUUIDs && Sync.temporaryPlayerUUIDs && syncPhases.first(where: {$0 == .phaseReplaceTemporaryPlayerUUIDs}) != nil {
                // Only allow sync which will update temporary player UUIDs from 'safe' places
                // where we can cope with player UUIDs being changed when we have some temporary ones
                if Utility.isDevelopment {
                    fatalError("Sync will be skipped")
                }
            } else {
                self.syncPhaseCount = -1
                if Sync.syncInProgress {
                    self.syncMessage("Waiting for previous operation to finish (\(self.uuid.right(4)))")
                    self.delegate?.syncQueued?()
                    self.delegate?.syncMessage?("Queued...")
                    observer = setSyncCompletionNotification(name: .syncCompletion)
                } else {
                    Sync.syncInProgress = true
                    self.syncController()
                }
                success = true
            }
        }
        return success
    }
    
    public static var temporaryPlayerUUIDs: Bool {
        get {
            return Scorecard.shared.playerList.filter({$0.tempEmail != nil}).count > 0
        }
    }
    
    private func syncController() {
        // Each element should either return true to signify complete (and hence should continue with next phase immediately)
        // or return true and then recall the controller from a completion block
        
        self.mainThread {
            
            var nextPhase = true
            self.observer = nil
            
            while true {
                
                // Prepare for next phase
                self.syncPhaseCount += 1
            
                // Quit if errors or finished
                if self.errors != 0 || !Sync.syncInProgress || self.syncPhaseCount >= self.syncPhases.count {
                    break
                }
            
                // Don't allow any phase to take longer than timeout seconds
                if self.timeout != nil {
                    self.startTimer(self.timeout)
                }
   
                switch self.syncPhases[self.syncPhaseCount] {
                case .phaseGetVersion:
                    nextPhase = self.getCloudVersion()
                case .phaseGetLastSyncDate:
                    nextPhase = self.getLastSyncDate()
                case .phaseUpdateLastSyncDate:
                    nextPhase = self.updateLastSyncDate()
                case .phaseSendUserTerms:
                    nextPhase = self.sendUserTerms()
                case .phaseGetCurrentGameParticipants:
                    nextPhase = self.getParticipantsFromCloud(.getCurrentGame)
                case .phaseGetExistingParticipants:
                    nextPhase = self.getParticipantsFromCloud(.getExisting)
                case .phaseGetNewParticipants:
                    nextPhase = self.getParticipantsFromCloud(.getNew)
                case .phaseGetGameParticipants:
                    nextPhase = self.getParticipantsFromCloud(.getGame)
                case .phaseUpdateParticipants:
                    nextPhase = self.updateParticipantsFromCloud()
                case .phaseGetGames:
                    nextPhase = self.getGamesFromCloud()
                case .phaseUpdateGames:
                    nextPhase = self.updateGamesFromCloud()
                case .phaseSendGamesAndParticipants:
                    nextPhase = self.sendUnconfirmedGamesAndParticipants()
                case.phaseReplaceTemporaryPlayerUUIDs:
                    nextPhase = self.replaceTemporaryPlayerUUIDs()
                case .phaseGetPlayers:
                    nextPhase = self.synchronisePlayersWithCloud()
                case .phaseSendPlayers:
                    nextPhase = self.sendPlayersToCloud()
                case .phaseGetSendImages:
                    self.fetchPlayerImagesFromCloud(self.playerImageFromCloud)
                    self.sendPlayerImagesToCloud(self.playerImageToCloud)
                    nextPhase = true
                case .phaseGetLinkedPlayers:
                    nextPhase = self.getLinkedPlayers(specificEmail: self.specificEmail)
                case .phaseGetPlayerList:
                    nextPhase = self.downloadPlayersFromCloud(
                        specificEmails: (self.specificEmail == nil ? nil : [self.specificEmail]),
                        specificPlayerUUIDs: self.specificPlayerUUIDs,
                        downloadAction: self.addPlayerList,
                        completeAction: self.completeGetPlayers)
                case .phaseGetAwards:
                    nextPhase = self.downloadAwardsFromCloud(specificPlayerUUIDs: self.specificPlayerUUIDs)
                case .phaseSendAwards:
                    nextPhase = self.sendAwardsToCloud(specificPlayerUUIDs: self.specificPlayerUUIDs)
                case .phaseRebuildWinStreaks:
                    nextPhase = self.rebuildWinStreaks()
                case .phaseStartedStageComplete:
                    self.delegate?.syncStageComplete?(.started)
                case .phaseInitialiseStageComplete:
                    self.delegate?.syncStageComplete?(.initialise)
                case .phaseDownloadGamesStageComplete:
                    self.delegate?.syncStageComplete?(.downloadGames)
                case .phaseUploadGamesStageComplete:
                    self.delegate?.syncStageComplete?(.uploadGames)
                case .phaseDownloadPlayersStageComplete:
                    self.delegate?.syncStageComplete?(.downloadPlayers)
                case .phaseUploadPlayersStageComplete:
                    self.delegate?.syncStageComplete?(.uploadPlayers)
                }
                
                if !nextPhase {
                    break
                }
                
            }
            if self.errors != 0 || self.syncPhaseCount >= self.syncPhases.count {
                self.syncCompletion()
            }
        }
    }
    
    private func mainThread(qos: DispatchQoS = .userInteractive, execute: @escaping ()->()) {
        if self.useMainThread {
            Utility.mainThread(qos: qos) {
                execute()
            }
        } else {
            execute()
        }
    }
    
    // MARK: - Get current version details ============================================================= -
    
    // Note this is always called first to check for compatibility
    // Other modes are called on successful completion
    
    private func getCloudVersion() -> Bool {
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
        
        let cloudContainer = Sync.cloudKitContainer
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
                Scorecard.version.latestVersion = "0.0"
                Scorecard.version.latestBuild = 0
                self.errors += 1
                self.syncController()
                return
            }
            Scorecard.version.latestVersion = version
            Scorecard.version.latestBuild = build
            
            // Set and save rabbitMQ URI
            RabbitMQConfig.rabbitMQUri = cloudRabbitMQUri
            RabbitMQConfig.save()
            
            // Setup simulated notification rabbitMQ queue
            Utility.mainThread {
                if Config.pushNotifications_onlineQueue &&  Utility.appDelegate?.notificationSimulator == nil {
                    Utility.appDelegate?.notificationSimulator = NotificationSimulator()
                    Utility.appDelegate?.notificationSimulator.start()
                }
            }
            
            // Set messages
            Scorecard.version.blockAccess = false
            Scorecard.version.blockSync = false
            Scorecard.version.message = ""
            
            if accessBlockVersion != nil &&
                Utility.compareVersions(version1: Scorecard.version.version,
                                           version2: accessBlockVersion) != .greaterThan {
                
                Scorecard.version.blockAccess = true
                if accessBlockMessage == "" {
                    accessBlockMessage = "A new version of the Contract Whist Scorecard app is available and this version is no longer supported. Please update to the latest version via the App Store."
                }
                Scorecard.version.message = accessBlockMessage
            }
            
            if !Scorecard.version.blockAccess && Scorecard.shared.database != "" && database != Scorecard.shared.database {
                // Database (development/production) doesn't match!!
                Scorecard.version.blockSync = true
                syncBlockMessage = "You are trying to connect to the '\(database!)' database but this device has previously synced with the '\(Scorecard.shared.database)' database"
                if database == "development" {
                    // OK if copying live to development so reset it after warning
                    syncBlockMessage = syncBlockMessage + ". It has been reset"
                    Scorecard.shared.database = database
                    UserDefaults.standard.set(database, forKey: "database")
                }
                Scorecard.version.message = syncBlockMessage
            }
            
            if !Scorecard.version.blockAccess && !Scorecard.version.blockSync && syncBlockVersion != nil &&
                Utility.compareVersions(version1: Scorecard.version.version,
                                        version2: syncBlockVersion) != .greaterThan {
                
                Scorecard.version.blockSync = true
                if syncBlockMessage == "" {
                    syncBlockMessage = "A new version of the Contract Whist Scorecard app is available and you will no longer be able to sync with iCloud using this version. Please update to the latest version via the App Store."
                }
                Scorecard.version.message = syncBlockMessage
                
            }
            
            if !Scorecard.version.blockAccess && !Scorecard.version.blockSync {
                if self.syncMode == .syncGetVersion && infoMessage != nil && infoMessage != "" {
                
                    Scorecard.version.message = infoMessage
                
                } else if self.syncMode == .syncGetVersion &&
                    Utility.compareVersions(version1: Scorecard.version.version, build1: Scorecard.version.build,
                                            version2: version, build2: build) == .lessThan  {
                    
                    Scorecard.version.message = "You are currently on version \(Scorecard.version.version) (\(Scorecard.version.build)) of the Contract Whist Scorecard app. A newer version \(version) (\(build)) is available. It is highly recommended that you update to the latest version."
                }
            }
            
            // Save messages for later use if fail to access cloud
            UserDefaults.standard.set(Scorecard.version.blockAccess, forKey: "blockAccess")
            UserDefaults.standard.set(Scorecard.version.blockSync, forKey: "blockSync")
            UserDefaults.standard.set(Scorecard.version.message, forKey: "message")
            if Scorecard.shared.database == "" {
                Scorecard.shared.database = database
                UserDefaults.standard.set(database, forKey: "database")
            }
            
            // If access and sync not blocked link to sync all if necessary - otherwise complete (and display message)
            if Scorecard.version.message != "" {
                // There is a message - either advisory in get version mode or an error
                self.syncAlert(Scorecard.version.message)
            }
            self.syncController()
        }
        
        // Execute the query
        publicDatabase.add(queryOperation)
        
        return false
    }
    
    // MARK: - Functions to get and update the last successful sync date -
    
    private func getLastSyncDate() -> Bool {
        self.nextSyncDate = Date()
        self.lastSyncDate = UserDefaults.standard.object(forKey: "confirmedSyncDate") as? Date
        if self.lastSyncDate == nil {
            self.lastSyncDate = Date(timeIntervalSinceReferenceDate: 0)
        }
        // Go back one hour to avoid overlaps
        self.lastSyncDate = Date(timeInterval: -3600, since: self.lastSyncDate)
        
        return true
    }
    
    private func updateLastSyncDate() -> Bool {
        if self.errors == 0 {
            UserDefaults.standard.set(self.nextSyncDate, forKey: "confirmedSyncDate")
        }
        
        return true
    }
    
    // MARK: - Function to send terms acceptance details - ignore any failures as will send again
    
    private func sendUserTerms() -> Bool {
        var cloudObject: CKRecord?
        if Scorecard.settings.termsDate != nil {
            let predicate = NSPredicate(format: "userID = %@ and dateAccepted = %@", Scorecard.settings.termsUser, Scorecard.settings.termsDate! as NSDate)
            Sync.read(recordType: "Terms", predicate: predicate,
                downloadAction: { (record) in
                    cloudObject = record
                },
                completeAction: { (error) in
                    // Ignore errors
                    if cloudObject == nil {
                        let recordName = "Terms-\(Scorecard.settings.termsUser)+\(Utility.dateString(Scorecard.settings.termsDate, format: self.recordIdDateFormat, localized: false))"
                        cloudObject = CKRecord(recordType: "Terms", recordID: CKRecord.ID(recordName: recordName))
                        cloudObject!.setValue(Scorecard.settings.termsDate, forKey: "dateAccepted")
                        cloudObject!.setValue(Scorecard.settings.termsUser, forKey: "userId")
                        cloudObject!.setValue(Scorecard.settings.termsDevice, forKey: "deviceName")
                    }
                    Sync.update(records: [cloudObject!], completion: { (error) in
                        // Ignore errors
                        self.syncController()
                    })
                })
        }
        return false
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
        default:
            gameUUIDList = nil
        }

        return getParticipantsFromCloudQuery(getParticipantMode, gameUUIDList: gameUUIDList)
    }
    
    private func getParticipantsFromCloudQuery(_ getParticipantMode: GetParticipantMode, gameUUIDList: [String]? = nil, remainder: [String]? = nil, cursor: CKQueryOperation.Cursor! = nil) -> Bool {
        // Fetch data from cloud
        var queryOperation: CKQueryOperation
        let cloudContainer = Sync.cloudKitContainer
        let publicDatabase = cloudContainer.publicCloudDatabase
        var predicate: NSCompoundPredicate
        var predicateList: [String]
        var gameUUIDList = gameUUIDList
        var remainder = remainder
        
        if cursor == nil {
            // First time in - setup the query
            switch getParticipantMode {
            case .getExisting:
                // Get participants based on players who were on this device before the cutoff date and only look at games since the cutoff (+24 hours for safety) since previous games should already be here
                predicateList = Scorecard.shared.playerUUIDList(getPlayerMode: .getExisting, cutoffDate: self.lastSyncDate, specificPlayerUUIDs: self.specificPlayerUUIDs)
                let predicate1 = NSPredicate(format: "playerUUID IN %@", argumentArray: [predicateList])
                let predicate2 = NSPredicate(format: "syncDate >= %@", self.lastSyncDate.addingTimeInterval(-(24*60*60)) as NSDate)
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
            case .getNew:
                // Get participants based on players who are new to this device - hence look at all games
                predicateList = Scorecard.shared.playerUUIDList(getPlayerMode: .getNew, cutoffDate: self.lastSyncDate, specificPlayerUUIDs: self.specificPlayerUUIDs)
                let predicate1 = NSPredicate(format: "playerUUID IN %@", argumentArray: [predicateList])
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1])
            case .getCurrentGame:
                // Get particpants based on a list of (probably 1) playerUUID address
                predicateList = self.specificPlayerUUIDs
                let predicate1 = NSPredicate(format: "playerUUID IN %@", argumentArray: [predicateList])
                let predicate2 = NSPredicate(format: "syncDate >= %@", self.lastSyncDate.addingTimeInterval(-(24*60*60)) as NSDate)
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
            case .getSpecific:
                // Get particpants based on a list of (probably 1) playerUUID address
                predicateList = self.specificPlayerUUIDs
                let predicate1 = NSPredicate(format: "playerUUID IN %@", argumentArray: [predicateList])
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1])
            case .getGame:
                // Get participants for a list of games - Can only fetch 50 at a time
                if gameUUIDList == nil {
                    predicateList = []
                } else {
                    let split = 30
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
                if Scorecard.adminMode {
                    message = message + " " + error.debugDescription
                }
                self.syncMessage(message)
                self.errors += 1
                self.syncController()
                return
            }
            if Scorecard.adminMode {
                self.syncMessage("\(self.cloudObjectList.count) participant history records downloaded")
            }
            
            if cursor != nil {
                // More records to come - recurse
                _ = self.getParticipantsFromCloudQuery(getParticipantMode, gameUUIDList: nil, remainder: remainder, cursor: cursor)
            } else if remainder != nil {
                // More records to get - recurse
                _ = self.getParticipantsFromCloudQuery(getParticipantMode, gameUUIDList: remainder)
            } else {
                if !Scorecard.adminMode {
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
                    CoreData.update(updateLogic: {
                    
                        History.cloudParticipantToMO(cloudObject: cloudObject, participantMO: historyParticipant.participantMO)
                        updated += 1
                    
                    })
                }
            } else {
                // Not found - create it locally
                CoreData.update(updateLogic: {
                    let participantMO = CoreData.create(from: "Participant") as! ParticipantMO
                    // Copy in data values from cloud
                    History.cloudParticipantToMO(cloudObject: cloudObject, participantMO: participantMO)
                    created += 1
                    if self.participantPlayerUUIDList.first(where: {$0 == participantMO.playerUUID}) == nil {
                        self.participantPlayerUUIDList.append(participantMO.playerUUID!)
                    }
                })
            }
        }
 
        if Scorecard.adminMode {
            self.syncMessage("\(updated) participants updated - \(created) participants created locally")
        } else {
            self.syncMessage("Local participant history records updated")
        }
        
        return true
    }
        
    // MARK: - Functions to update local games history from cloud ====================================================== -
    
    private func getGamesFromCloud() -> Bool {
        self.cloudObjectList = []
        let gameUUIDList = History.getNewParticpantGames(cutoffDate: self.lastSyncDate, specificPlayerUUIDs: self.specificPlayerUUIDs)
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
        let cloudContainer = Sync.cloudKitContainer
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
                if Scorecard.adminMode {
                    message = message + " " + error.debugDescription
                }
                self.syncMessage(message)
                self.errors += 1
                self.syncController()
                return
            }
            if Scorecard.adminMode {
                self.syncMessage("\(self.cloudObjectList.count) game history records downloaded")
            }
            
            if cursor != nil {
                // More to come - recurse
                _ = self.getGamesFromCloudQuery(gameUUIDList: nil, remainder: remainder, cursor: cursor)
            } else if remainder != nil {
                // More to get - recurse
                _ = self.getGamesFromCloudQuery(gameUUIDList: remainder)
            } else {
               if !Scorecard.adminMode {
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
        
        if Scorecard.adminMode {
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
        var links: [(fromEmail: String, from: String, to: String)] = []
        
        self.cloudObjectList = []
        
        let history = History(unconfirmed: true)
        if history.games.count != 0 {
            for historyGame in history.games {
                // First check if game confirmed - i.e. we have a cloud RecordID - should all be unconfirmed
                if historyGame.gameMO.syncRecordID == nil && !historyGame.gameMO.temporary {
                    // Not confirmed yet - send it
                    let gameMO = historyGame.gameMO!
                    let recordID = CKRecord.ID(recordName: "Games-\(Utility.dateString(gameMO.datePlayed!, format: self.recordIdDateFormat, localized: false))+\(gameMO.deviceName!)+\(gameMO.gameUUID!)")
                    let cloudObject = CKRecord(recordType:"Games", recordID: recordID)
                    History.cloudGameFromMo(cloudObject: cloudObject, gameMO: gameMO, syncDate: self.nextSyncDate)
                    self.cloudObjectList.append(cloudObject)
                    gamesQueued += 1
                }
                if historyGame.participant != nil {
                    for historyParticipant in historyGame.participant {
                        if historyGame.gameMO.syncRecordID == nil {
                            // Not confirmed yet - send it
                            let participantMO = historyParticipant.participantMO!
                            let recordID = CKRecord.ID(recordName: "Participants-\(Utility.dateString(participantMO.datePlayed!, format: self.recordIdDateFormat, localized: false))+\(participantMO.playerUUID!)+\(participantMO.gameUUID!))")
                            let cloudObject = CKRecord(recordType:"Participants", recordID: recordID)
                            History.cloudParticipantFromMO(cloudObject: cloudObject, participantMO: participantMO, syncDate: self.nextSyncDate)
                            self.cloudObjectList.append(cloudObject)
                            participantsQueued += 1
                        }
                    }
                    // Add any link records (might be duplicates) to list
                    for historyParticipant in historyGame.participant {
                        for linkedParticipant in historyGame.participant {
                            let from = historyParticipant.participantMO.playerUUID!
                            let to = linkedParticipant.participantMO.playerUUID!
                            if let fromEmail = Scorecard.shared.playerEmails[from] {
                                // Note this even creates a link for each player with themselves
                                let link = (fromEmail, from, to)
                                if links.first(where: { $0 == link}) == nil {
                                    links.append(link)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Send link records
        for link in links {
            let cloudObject = CKRecord(recordType: "Links", recordID:  CKRecord.ID(recordName: "Links+\(link.fromEmail)+\(link.to)"))
            
            cloudObject.setValue(link.fromEmail, forKey: "fromEmail")
            cloudObject.setValue(link.from, forKey: "fromPlayerUUID")
            cloudObject.setValue(link.to, forKey: "toPlayerUUID")
            self.cloudObjectList.append(cloudObject)

        }
        
        if self.cloudObjectList.count != 0 {
            return self.sendUnconfirmedGamesAndParticipantsToCloud(gamesQueued: gamesQueued, participantsQueued: participantsQueued)
        } else {
            return true
        }
    }
    
    private func sendUnconfirmedGamesAndParticipantsToCloud(gamesQueued: Int, participantsQueued: Int) -> Bool {
        // Send queued games and participants to cloud
        
        Sync.update(records: self.cloudObjectList, completion: { (error: Error?) in
            if error == nil {
                OperationQueue.main.addOperation {
                    if Scorecard.adminMode {
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
    
    // MARK: - Functions to synchronise players with cloud ====================================================== -
    
    // Note that this routine updates temporary local playerUUIDs to any new central values.
    // If it finds a conflict it restarts itself to try to recover
    
    private func replaceTemporaryPlayerUUIDs() -> Bool {
        let tempEmailList = Scorecard.shared.playerList.filter({$0.tempEmail ?? "" != ""})
        if !tempEmailList.isEmpty {
            var replaceList: [(email: String, playerUUID: String)] = []
            
            // Found some players with a temporary email address - need to check playerUUID and replace if necessary
             return self.downloadPlayersFromCloud(specificEmails: tempEmailList.map{$0.tempEmail!},
                                                 desiredKeys: ["email", "playerUUID"],
                downloadAction: { (record) in
                    if let email = record.value(forKey: "email") as? String,
                       let playerUUID = record.value(forKey: "playerUUID") as? String {
                        replaceList.append((email, playerUUID))
                    }
            }, completeAction: {
                var cloudUpdateList: [CKRecord] = []
                for playerMO in tempEmailList {
                    let replace = replaceList.first(where: {$0.email == playerMO.tempEmail})
                    if replace != nil {
                        if playerMO.playerUUID == replace!.playerUUID {
                            // No action needed as central version same as local
                        } else {
                            // Have received a different player UUID for this player need to update all local data!
                            self.replaceTemporaryPlayerUUID(playerMO: playerMO, with: replace!.playerUUID)
                        }
                    } else {
                        // Can keep local player UUID but need to update cloud and check for conflicts
                        var record: CKRecord
                        (record, _) = self.createCloudPlayer(playerMO: playerMO)
                        cloudUpdateList.append(record)
                    }
                }
                if !cloudUpdateList.isEmpty {
                    Sync.update(records: cloudUpdateList, completion: { (error) in
                        repeat {
                            if error == nil {
                                // All OK
                            } else {
                                if let error = error as? CKError {
                                    if error.code == .serverRecordChanged{
                                        // Conflict with change on centre - restart the process
                                        _ = self.replaceTemporaryPlayerUUIDs()
                                        Utility.debugMessage("sync", "Restarting player UUID replacement")
                                        break
                                    }
                                }
                                self.syncMessage("Error update local players")
                                self.errors += 1
                            }
                            self.syncController()
                        } while false
                    })
                } else {
                    self.syncController()
                }
            })
        } else {
            // Just move on to next phase
            return true
        }
    }
    
    private func getLinkedPlayers(specificEmail: String?) -> Bool {
        var results: [String] = specificPlayerUUIDs
        var thisPlayerUUID: String?
        
        return downloadLinksFromCloudQuery(specificEmail: specificEmail,
                                                 downloadAction: { (record) in
                                                    if let toPlayerUUID = record.value(forKey: "toPlayerUUID") as? String,
                                                       let fromPlayerUUID = record.value(forKey: "fromPlayerUUID") as? String {
                                                        let thisPlayer = (fromPlayerUUID == toPlayerUUID)
                                                        if results.first(where: {$0 == toPlayerUUID}) == nil {
                                                            results.append(toPlayerUUID)
                                                            if thisPlayer {
                                                                thisPlayerUUID = toPlayerUUID
                                                            }
                                                        }
                                                    }
                                                 },
                                                 completeAction: {
                                                    self.specificEmail = nil
                                                    self.specificPlayerUUIDs = results
                                                    self.thisPlayerUUID = thisPlayerUUID
                                                    self.syncController()
                                                 })
        
    }
    
    private func downloadLinksFromCloudQuery(specificEmail: String?,
                                             cursor: CKQueryOperation.Cursor! = nil,
                                             downloadAction: @escaping (CKRecord) -> (),
                                             completeAction: @escaping () -> ()) -> Bool {
        
        var queryOperation: CKQueryOperation
        var predicate: NSPredicate!

        // Fetch link records from cloud
        let cloudContainer = Sync.cloudKitContainer
        let publicDatabase = cloudContainer.publicCloudDatabase
        if cursor == nil {
            // First time in - set up the query
            var playerUUIDList: [String]
            if specificEmail != nil {
                predicate = NSPredicate(format: "fromEmail = %@", specificEmail!)
            } else {
                playerUUIDList = Scorecard.shared.playerUUIDList()
                if playerUUIDList.count == 0 {
                    return true
                }
                predicate = NSPredicate(format: "fromPlayerUUID IN %@", argumentArray: [playerUUIDList])
            }
            let query = CKQuery(recordType: "Links", predicate: predicate)
            queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        } else {
            // Continue previous query
            queryOperation = CKQueryOperation(cursor: cursor, qos: .userInteractive)
        }
        queryOperation.desiredKeys = ["fromPlayerUUID", "toPlayerUUID"]
        queryOperation.queuePriority = .veryHigh
        queryOperation.recordFetchedBlock = { (record) -> Void in
            let cloudObject: CKRecord = record
            downloadAction(cloudObject)
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error != nil {
                var message = "Unable to fetch links from cloud!"
                if Scorecard.adminMode {
                    message = message + " " + error.debugDescription
                }
                self.syncMessage(message)
                self.errors += 1
                self.syncController()
                return
            }
            
            if Scorecard.adminMode {
                self.syncMessage("\(self.downloadedPlayerRecordList.count) player records downloaded")
            }
            
            if cursor != nil {
                // More to come - recurse
                _ = self.downloadLinksFromCloudQuery(specificEmail: specificEmail,
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

    private func synchronisePlayersWithCloud(specificPlayerUUIDs: [String] = []) -> Bool {
        return downloadPlayersFromCloud(specificEmails: nil,
                                        specificPlayerUUIDs: specificPlayerUUIDs,
                                        downloadAction: self.mergePlayerCloudObject,
                                        completeAction: self.completeSynchronisePlayersWithCloud)
    }
    
    
    private func downloadPlayersFromCloud(specificEmails: [String]? = nil,
                                  specificPlayerUUIDs: [String]? = nil,
                                  desiredKeys: [String]? = nil,
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
        
        return downloadPlayersFromCloudQuery(specificEmails: specificEmails,
                                             specificPlayerUUIDs: specificPlayerUUIDs,
                                             desiredKeys: desiredKeys,
                                             downloadAction: downloadAction,
                                             completeAction: completeAction)
    }
    
    private func downloadPlayersFromCloudQuery(specificEmails: [String]? = nil,
                                       specificPlayerUUIDs: [String]? = nil,
                                       desiredKeys: [String]? = nil,
                                       cursor: CKQueryOperation.Cursor! = nil,
                                       downloadAction: @escaping (CKRecord) -> (),
                                       completeAction: @escaping () -> ()) -> Bool {
        
        var queryOperation: CKQueryOperation
        var predicate: NSPredicate!
                
        // Fetch player records from cloud
        let cloudContainer = Sync.cloudKitContainer
        let publicDatabase = cloudContainer.publicCloudDatabase
        if cursor == nil {
            // First time in - set up the query
            if specificEmails != nil {
                predicate = NSPredicate(format: "email IN %@", argumentArray: [specificEmails!])
            } else {
                var playerUUIDList: [String]
                if specificPlayerUUIDs?.count ?? 0 != 0 {
                    playerUUIDList = specificPlayerUUIDs!
                } else if self.syncMode == .syncGetPlayers {
                    playerUUIDList = History.getParticipantPlayerUUIDList()
                } else {
                    playerUUIDList = Scorecard.shared.playerUUIDList()
                }
                if playerUUIDList.count == 0 {
                    return true
                }
                predicate = NSPredicate(format: "playerUUID IN %@", argumentArray: [playerUUIDList])
            }
            let query = CKQuery(recordType: "Players", predicate: predicate)
            let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
            query.sortDescriptors = [sortDescriptor]
            queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        } else {
            // Continue previous query
            queryOperation = CKQueryOperation(cursor: cursor, qos: .userInteractive)
        }
        queryOperation.desiredKeys = desiredKeys ??  ["name", "playerUUID", "dateCreated", "datePlayed", "nameDate",
                                                      "emailDate", "thumbnailDate","gamesPlayed", "gamesWon",
                                                      "totalScore", "handsPlayed", "handsMade", "winStreak", "twosMade",
                                                      "maxScore", "maxMade", "maxWinStreak", "maxTwos",
                                                      "maxScoreDate", "maxMadeDate", "maxWinStreakDate", "maxTwosDate",
                                                      "email", "visibleLocally"]
    
        queryOperation.queuePriority = .veryHigh
        queryOperation.recordFetchedBlock = { (record) -> Void in
            let cloudObject: CKRecord = record
            downloadAction(cloudObject)
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error != nil {
                var message = "Unable to fetch players from cloud!"
                if Scorecard.adminMode {
                    message = message + " " + error.debugDescription
                }
                self.syncMessage(message)
                self.errors += 1
                self.syncController()
                return
            }
            
            if Scorecard.adminMode {
                self.syncMessage("\(self.downloadedPlayerRecordList.count) player records downloaded")
            }
            
            if cursor != nil {
                // More to come - recurse
                _ = self.downloadPlayersFromCloudQuery(specificEmails: specificEmails,
                                                       specificPlayerUUIDs: specificPlayerUUIDs,
                                                       desiredKeys: desiredKeys,
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
        let cloudRecord = PlayerDetail()
        let localRecord = PlayerDetail()
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
        if let email = cloudObject.value(forKey: "email") as? String {
            Scorecard.shared.playerEmails[cloudRecord.playerUUID] = email
        }
        
        // Try to match by playerUUID address
        if let localMO = Scorecard.shared.playerList.first(where: { $0.playerUUID?.lowercased() == cloudRecord.playerUUID.lowercased() }) {
            // Merge the records
            localRecord.fromManagedObject(playerMO: localMO)
            
            localRecord.syncRecordID = cloudObject.recordID.recordName
            
            // Clear temporary email if player UUIDs are in sync
            if localRecord.playerUUID == cloudRecord.playerUUID && localRecord.tempEmail != nil {
                localRecord.tempEmail = nil
                changed = true
            }
            
            // Update thumbnail to latest version
            // Need to queue updates for later
            
            if localRecord.thumbnail == nil {
                // If no thumbnail ignore local date
                localRecord.thumbnailDate = nil
            }
            
            if (cloudRecord.thumbnailDate != nil && (localRecord.thumbnailDate == nil || localRecord.thumbnailDate < cloudRecord.thumbnailDate)) || localRecord.thumbnail == nil {
                // thumbnail updated on cloud (or not here) - queue overwrite of local copy
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
            if localRecord.maxScore < cloudRecord.maxScore || (localRecord.maxScore == cloudRecord.maxScore && localRecord.maxScoreSplit < cloudRecord.maxScoreSplit) {
                localRecord.maxScore = cloudRecord.maxScore
                localRecord.maxScoreSplit = cloudRecord.maxScoreSplit
                localRecord.maxScoreDate = cloudRecord.maxScoreDate
                changed = true
            } else if cloudRecord.maxScore < localRecord.maxScore || (cloudRecord.maxScore == localRecord.maxScore && cloudRecord.maxScoreSplit < localRecord.maxScoreSplit) {
                cloudRecord.maxScore = localRecord.maxScore
                cloudRecord.maxScoreSplit = localRecord.maxScoreSplit
                cloudRecord.maxScoreDate = localRecord.maxScoreDate
                changed = true
            }
            if localRecord.maxMade < cloudRecord.maxMade || (localRecord.maxMade == cloudRecord.maxMade && localRecord.maxMadeSplit < cloudRecord.maxMadeSplit){
                localRecord.maxMade = cloudRecord.maxMade
                localRecord.maxMadeSplit = cloudRecord.maxMadeSplit
                localRecord.maxMadeDate = cloudRecord.maxMadeDate
                changed = true
            } else if cloudRecord.maxMade < localRecord.maxMade  || (cloudRecord.maxMade == localRecord.maxMade && cloudRecord.maxMadeSplit < localRecord.maxMadeSplit){
                cloudRecord.maxMade = localRecord.maxMade
                cloudRecord.maxMadeSplit = localRecord.maxMadeSplit
                cloudRecord.maxMadeDate = localRecord.maxMadeDate
                changed = true
            }
            if localRecord.maxWinStreak < cloudRecord.maxWinStreak {
                localRecord.maxWinStreak = cloudRecord.maxWinStreak
                localRecord.maxWinStreakDate = cloudRecord.maxWinStreakDate
                changed = true
            } else if cloudRecord.maxWinStreak < localRecord.maxWinStreak {
                cloudRecord.maxWinStreak = localRecord.maxWinStreak
                cloudRecord.maxWinStreakDate = localRecord.maxWinStreakDate
                changed = true
            }
            if localRecord.maxTwos < cloudRecord.maxTwos || (localRecord.maxTwos == cloudRecord.maxTwos && localRecord.maxTwosSplit < cloudRecord.maxTwosSplit){
                localRecord.maxTwos = cloudRecord.maxTwos
                localRecord.maxTwosSplit = cloudRecord.maxTwosSplit
                localRecord.maxTwosDate = cloudRecord.maxTwosDate
                changed = true
            } else if cloudRecord.maxTwos < localRecord.maxTwos  || (cloudRecord.maxTwos == localRecord.maxTwos && cloudRecord.maxTwosSplit < localRecord.maxTwosSplit){
                cloudRecord.maxTwos = localRecord.maxTwos
                cloudRecord.maxTwosSplit = localRecord.maxTwosSplit
                cloudRecord.maxTwosDate = localRecord.maxTwosDate
                changed = true
            }
            
            // Update date created / last played / win streak
            if cloudRecord.dateCreated == nil || localRecord.dateCreated < cloudRecord.dateCreated {
                cloudRecord.dateCreated = localRecord.dateCreated
                changed = true
            } else if localRecord.dateCreated == nil || cloudRecord.dateCreated < localRecord.dateCreated {
                localRecord.dateCreated = cloudRecord.dateCreated
                changed = true
            }
            
            if cloudRecord.datePlayed == nil || (localRecord.datePlayed != nil && localRecord.datePlayed > cloudRecord.datePlayed) {
                cloudRecord.datePlayed = localRecord.datePlayed
                cloudRecord.winStreak = localRecord.winStreak
                changed = true
            } else if localRecord.datePlayed == nil || (cloudRecord.datePlayed != nil && cloudRecord.datePlayed > localRecord.datePlayed) {
                localRecord.datePlayed = cloudRecord.datePlayed
                localRecord.winStreak = cloudRecord.winStreak
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
        if !Scorecard.adminMode {
            self.syncMessage("Player records downloaded")
        }
        self.syncController()
    }

    private func addPlayerList(_ cloudObject: CKRecord) {
        let cloudRecord = PlayerDetail()
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
                // Make sure we don't have a duplicate name (if not just checking External Ids)
                playerDetail.dedupName()
            }
            self.syncReturnPlayers(self.downloadedPlayerRecordList, self.thisPlayerUUID)
        }
    }
    
    private func sendPlayersToCloud() -> Bool {
        // Add any records which are local (with playerUUID) but not in cloud
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
        if self.specificPlayerUUIDs.count != 0 {
            // Search for specific playerUUID
            for playerUUID in specificPlayerUUIDs {
                let found = Scorecard.shared.playerList.firstIndex(where: { $0.playerUUID!.lowercased() as String == playerUUID.lowercased() })
                if found != nil && playerUUID.left(7).lowercased() != "_player" {
                    self.queueMissingPlayer(playerMO: Scorecard.shared.playerList[found!])
                }
            }
        } else {
            // Try entire list
            for playerMO in Scorecard.shared.playerList {
                if playerMO.tempEmail ?? "" != "" {
                    self.queueMissingPlayer(playerMO: playerMO)
                }
            }
        }
    }
    
    private func queueMissingPlayer(playerMO: PlayerMO) {
        let matchPlayerUUID = playerMO.playerUUID
        if matchPlayerUUID != nil && matchPlayerUUID != "" {
            // Check this playerUUID isn't already in cloud list (otherwise duplicates would multiply forever)
            let found = self.downloadedPlayerRecordList.firstIndex(where: { $0.playerUUID.lowercased() as String == matchPlayerUUID!.lowercased() })
            
            if found == nil {
                if playerMO.tempEmail ?? "" == "" {
                    fatalError("Found a local player who is not on central database but we don't have a unique ID/email for them")
                }
                // Record is not in the cloud - send it
                var cloudObject: CKRecord
                var cloudRecord: PlayerDetail
                (cloudObject, cloudRecord) = createCloudPlayer(playerMO: playerMO)
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
    
    private func createCloudPlayer(playerMO: PlayerMO) -> (CKRecord, PlayerDetail) {
        let cloudObject = CKRecord(recordType:"Players", recordID: CKRecord.ID(recordName: "Players-\(playerMO.tempEmail!)"))
        let cloudRecord = PlayerDetail()
        cloudRecord.fromManagedObject(playerMO: playerMO)
        cloudRecord.syncDate = Date()
        cloudRecord.syncRecordID = nil
        cloudRecord.toCloudObject(cloudObject: cloudObject)
        cloudObject.setValue(cloudRecord.tempEmail, forKey: "email")
        return (cloudObject, cloudRecord)
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
        let cloudContainer = Sync.cloudKitContainer
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
                    let cloudPlayerUUID = savedRecord.object(forKey: "playerUUID") as! String
                    let localPlayerUUID = self.localPlayerRecordList[playerNumber-1].playerUUID
                    if localPlayerUUID == cloudPlayerUUID {
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
                        
                        // Copy to managed object
                        self.localPlayerRecordList[playerNumber-1].toManagedObject(playerMO: self.localPlayerMOList[playerNumber - 1], updateThumbnail: false)
                        
                        // Reset sync values
                        self.localPlayerMOList[playerNumber - 1].syncGamesPlayed = self.localPlayerMOList[playerNumber - 1].gamesPlayed
                        self.localPlayerMOList[playerNumber - 1].syncGamesWon = self.localPlayerMOList[playerNumber - 1].gamesWon
                        self.localPlayerMOList[playerNumber - 1].syncTotalScore = self.localPlayerMOList[playerNumber - 1].totalScore
                        self.localPlayerMOList[playerNumber - 1].syncHandsPlayed = self.localPlayerMOList[playerNumber - 1].handsPlayed
                        self.localPlayerMOList[playerNumber - 1].syncHandsMade = self.localPlayerMOList[playerNumber - 1].handsMade
                        self.localPlayerMOList[playerNumber - 1].syncTwosMade = self.localPlayerMOList[playerNumber - 1].twosMade
                        
                        // Store record ID (for new records)
                        self.localPlayerMOList[playerNumber - 1].syncRecordID = self.localPlayerRecordList[playerNumber-1].syncRecordID
                    
                        // Notify observers this player has been updated
                        Notifications.post(name: .playerDownloaded, object: self, userInfo: ["playerObjectID": self.localPlayerMOList[playerNumber - 1].objectID])
                    }
                    // Clear sync in progress flag
                    self.localPlayerMOList[playerNumber - 1].syncInProgress = false
                }
            }) {
                self.syncMessage("Error updating local player records")
                self.errors += 1
            }
            self.syncController()
            
        }
        
        // Add the operation to an operation queue to execute it
        OperationQueue().addOperation(uploadOperation)
        return false
    }
    
    private func rebuildWinStreaks() -> Bool {
        if self.participantPlayerUUIDList.count > 0 {
            let streaks = History.getWinStreaks(playerUUIDList: self.participantPlayerUUIDList, includeZeroes: true)
            CoreData.update {
                for streak in streaks {
                    if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(streak.playerUUID) {
                        playerMO.winStreak = Int64(streak.currentStreak)
                        playerMO.maxWinStreak = Int64(streak.longestStreak)
                        playerMO.maxWinStreakDate = streak.participantMO?.datePlayed
                    }
                }
            }
        }
        return true
    }
    
    public func fetchPlayerImagesFromCloud(_ playerImageFromCloud: [PlayerMO]) {
        if playerImageFromCloud.count > 0 {
            
            let cloudContainer = Sync.cloudKitContainer
            let publicDatabase = cloudContainer.publicCloudDatabase
            var imageRecordID: [CKRecord.ID] = []
            self.cloudObjectList = []
            
            for playerNumber in 1...playerImageFromCloud.count {
                imageRecordID.append(CKRecord.ID(recordName: playerImageFromCloud[playerNumber-1].syncRecordID!))
            }
            let fetchOperation = CKFetchRecordsOperation(recordIDs: imageRecordID)
            fetchOperation.desiredKeys = ["playerUUID", "thumbnail", "thumbnailDate"]
            
            fetchOperation.perRecordCompletionBlock = { (cloudObject: CKRecord?, syncRecordID: CKRecord.ID?, error: Error?) -> Void in
                if error == nil && cloudObject != nil {
                    self.cloudObjectList.append(cloudObject!)
                }
            }
            fetchOperation.fetchRecordsCompletionBlock = { (records, error) in
                
                var playerObjectId: [NSManagedObjectID] = []
                for cloudObject in self.cloudObjectList {
                    if let playerUUID = Utility.objectString(cloudObject: cloudObject, forKey: "playerUUID") {
                        if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(playerUUID){
                            if CoreData.update(updateLogic: {
                                var thumbnail: Data?
                                thumbnail = Utility.objectImage(cloudObject: cloudObject, forKey: "thumbnail") as Data?
                                playerMO.thumbnail = thumbnail
                                playerMO.thumbnailDate = Utility.objectDate(cloudObject: cloudObject, forKey: "thumbnailDate")
                            }) {
                                playerObjectId.append(playerMO.objectID)
                            }
                        }
                    }
                }
                // Send a notification to any objects that might be interested with the object ID of the playerMO object ID
                for objectId in playerObjectId {
                    Notifications.post(name: .playerImageDownloaded, object: self, userInfo: ["playerObjectID": objectId])
                }
            }
            publicDatabase.add(fetchOperation)
        }
    }
    
    private func sendPlayerImagesToCloud(_ playerImageToCloud: [PlayerMO]) {
        if playerImageToCloud.count > 0 {
            
            let cloudContainer = Sync.cloudKitContainer
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
    
    // MARK: - Functions to update Awards ============================================================== -
    
    private func downloadAwardsFromCloud(specificPlayerUUIDs: [String]?) -> Bool {
        var records: [CKRecord] = []
        var lastPlayerUUID: String?
        let awards = Awards()
        var existing: [AwardMO] = []
        
        self.cloudObjectList = []

        let specificPlayerUUIDs = specificPlayerUUIDs ?? Scorecard.shared.playerUUIDList()
        let predicate1 = NSPredicate(format: "playerUUID IN %@", argumentArray: [specificPlayerUUIDs])
        let predicate2 = NSPredicate(format: "syncDate >= %@", self.lastSyncDate.addingTimeInterval(-(24*60*60)) as NSDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2])
        
        Sync.read(recordType: "Awards", predicate: predicate, sortBy: [NSSortDescriptor(key: "playerUUID", ascending: true)],
        downloadAction: { (record) in
            records.append(record)
        },
        completeAction: { (error) in
            if error == nil && !records.isEmpty {
                for record in records {
                    // Try to find local record and update - otherwise create
                    if let playerUUID = record.value(forKey: "playerUUID") as? String,
                        let code = record.value(forKey: "code") as? String,
                        let awardLevel = record.value(forKey: "awardLevel") as? Int {
                        if playerUUID != lastPlayerUUID {
                            existing = awards.getAchieved(playerUUID: playerUUID)
                            lastPlayerUUID = playerUUID
                        }
                        var cloudMO: AwardMO
                        if let index = existing.firstIndex(where: {$0.playerUUID == playerUUID && $0.code == code && $0.awardLevel == awardLevel}) {
                            let localCount = existing[index].count
                            let localSyncCount = existing[index].syncCount
                            let localDateAwarded = existing[index].dateAwarded!
                            cloudMO = existing[index]
                            CoreData.update {
                                cloudMO.from(cloudObject: record) // Note this overwrites existing[index] too
                                if localCount == 0 {
                                    // If local count is zero this was just a default which it appears already exists - just overwrite it
                                    cloudMO.syncCount = cloudMO.count
                                } else {
                                    let difference = cloudMO.count - localSyncCount
                                    if difference != 0 || localDateAwarded > cloudMO.dateAwarded! {
                                        // Re-awarded locally - update for any cloud changes
                                        cloudMO.syncCount = cloudMO.count
                                        cloudMO.count = localCount + difference
                                        cloudMO.dateAwarded = max(cloudMO.dateAwarded!, localDateAwarded)
                                        cloudMO.syncDate = nil
                                    }
                                }
                            }
                        } else {
                            cloudMO = CoreData.create(from: "Award")
                            CoreData.update {
                                cloudMO.from(cloudObject: record)
                                cloudMO.syncCount = cloudMO.count
                            }
                        }
                    }
                }
                self.syncMessage("Local award records updated")
            }
            self.syncController()
        })
        return false
    }
    
    private func sendAwardsToCloud(specificPlayerUUIDs: [String]?) -> Bool {
        var records: [CKRecord] = []
        
        var predicate: [NSPredicate] = []
        if (specificPlayerUUIDs?.count ?? 0) > 0 {
            predicate.append(NSPredicate(format: "playerUUID IN %@", argumentArray: [specificPlayerUUIDs!]))
        }
        predicate.append(NSPredicate(format: "syncDate = null"))
        let existing = CoreData.fetch(from: "Award", filter: predicate, sort: []) as! [AwardMO]
        
        for awardMO in existing {
            let recordID = CKRecord.ID(recordName: "Awards-\(awardMO.playerUUID!)+\(awardMO.code!)+\(awardMO.awardLevel)")
            let record = CKRecord(recordType: "Awards", recordID: recordID)
            if awardMO.count == 0 {
                // Any default still around at this point is genuine - set count to 1
                CoreData.update {
                    awardMO.count = 1
                }
            }
            awardMO.to(cloudObject: record)
            record.setValue(Date(), forKey: "syncDate")
            records.append(record)
        }
        
        if !records.isEmpty {
            Sync.update(records: records, overwriteRegardless: true, recordCompletion: sendAwardToCloudRecordCompletion, completion: { (error) in
                // Ignore errors
                self.syncMessage("Award records uploaded")
                self.syncController()
            })
            return false
        } else {
            return true
        }
    }
    
    private func sendAwardToCloudRecordCompletion(record: CKRecord, error: Error?) {
        if error == nil {
            // Reset sync count
            // Note the count could go wrong if iCloud is updated successfully, but this doesn't execute
            // This is not deemed a material problem
            if let playerUUID = record.value(forKey: "playerUUID") as? String,
               let code = record.value(forKey: "code") as? String,
               let awardLevel = record.value(forKey: "awardLevel") as? Int {
                if let awardMO = Awards.get(playerUUID: playerUUID, code: code, awardLevel: awardLevel) {
                    CoreData.update {
                        awardMO.syncCount = awardMO.count
                    }
                }
            }
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -

    private func syncMessage(_ message: String) {
        Utility.debugMessage("sync", message)
        if self.delegate != nil {
            self.delegate?.syncMessage?(message)
        }
    }
    
    private func syncAlert(_ message: String) {
        self.alertInProgress = true
        self.errors = -1
        self.delegate?.syncAlert?(message) {
            self.alertInProgress = false
            self.syncCompletion()
        }
    }
    
    private func syncCompletion() {
        // If alert in progress just wait for that to complete and call this
        if !alertInProgress {
            let delegate = self.delegate
            // All done
            if Sync.syncInProgress {
                // Call the synchronous completion if it is implemented
                if delegate?.syncCompletionWait != nil {
                    delegate?.syncCompletionWait!(self.errors, completion: self.syncFinalCompletion)
                } else {
                    // Call the normal delegate completion handler if there was one
                    delegate?.syncCompletion?(self.errors)
                    self.syncFinalCompletion()
                }
            } else {
                // Do final completion anyway
                self.syncFinalCompletion()
            }
        }
    }
    
    private func syncFinalCompletion() {
        // Stop timer
        if self.timer != nil {
            self.timer.invalidate()
        }
        
        // Complete final section
        if self.errors == 0 {
            self.delegate?.syncStageComplete?(.complete)
        }
        
        // Disconnect
        Sync.syncInProgress = false
        self.delegate = nil
        
        if self.observer != nil {
            Notifications.removeObserver(self.observer)
            self.observer = nil
        }
        Notifications.post(name: .syncCompletion, object: self)
    }
    
    private func syncReturnPlayers(_ playerList: [PlayerDetail]?, _ thisPlayer: String? = nil) {
        // All done
        // Sync.syncInProgress = false
        // Call the delegate handler if there is one
        delegate?.syncReturnPlayers?(playerList, thisPlayer)
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
    
    private func setSyncCompletionNotification(name: Notification.Name) -> NSObjectProtocol? {
        // Set a notification for background completion
        self.observer = Notifications.addObserver(forName: name) { [weak self] (notification) in
            if !Sync.syncInProgress {
                Sync.syncInProgress = true
                if let observer = self?.observer {
                    Notifications.removeObserver(observer)
                }
                self?.delegate?.syncStarted?()
                self?.delegate?.syncMessage?("Started...")
                Utility.debugMessage("sync", "Starting queued task from \(self?.delegate?.syncDelegateDescription ?? "Unknown") (\(self?.uuid.right(4) ?? ""))")
                self?.syncController()
            }
        }
        return observer
    }
    
    // MARK: - Stage helper routines ================================================================ -
    
    class public func stageDescription(stage: SyncStage) -> String {
        switch stage {
        case .started:
            return "Start"
        case .initialise:
            return "Initialise"
        case .downloadGames:
            return "Download game history"
        case .uploadGames:
            return "Upload games"
        case .downloadPlayers:
            return "Download player details"
        case .uploadPlayers:
            return "Upload player details"
        case .complete:
            return "Sync complete"
        }
    }
    
    class public func stageActionDescription(stage: SyncStage) -> String {
        switch stage {
        case .started:
            return "Starting"
        case .initialise:
            return "Initialising"
        case .downloadGames:
            return "Downloading game history"
        case .uploadGames:
            return "Uploading games"
        case .downloadPlayers:
            return "Downloading player details"
        case .uploadPlayers:
            return "Uploading player details"
        case .complete:
            return "Completing"
        }
    }
    
    // MARK: - Generic read/write =================================================================== -
    
    public class func update(records: [CKRecord]? = nil, recordIDsToDelete: [CKRecord.ID]? = nil, database: CKDatabase? = nil, overwriteRegardless: Bool = false, recordsRemainder: [CKRecord]? = nil, recordIDsToDeleteRemainder: [CKRecord.ID]? = nil, recordCompletion: ((CKRecord, Error?)->())? = nil, completion: ((Error?)->())? = nil) {
        // Copes with limit being exceeed which splits the load in two and tries again
        var lastSplit = 400
        
        if (records?.count ?? 0) + (recordIDsToDelete?.count ?? 0) > lastSplit {
            // No point trying - split immediately
            lastSplit = self.updatePortion(database: database, requireLess: true, lastSplit: lastSplit, records: records, recordIDsToDelete: recordIDsToDelete, recordsRemainder: recordsRemainder, recordIDsToDeleteRemainder: recordIDsToDeleteRemainder, completion: completion)
        } else {
            // Give it a go
            let cloudContainer = Sync.cloudKitContainer
            let database = database ?? cloudContainer.publicCloudDatabase
            
            let uploadOperation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: recordIDsToDelete)
            
            uploadOperation.isAtomic = true
            uploadOperation.database = database
            if overwriteRegardless {
                uploadOperation.savePolicy = .allKeys
            }
            
            if recordCompletion != nil {
                uploadOperation.perRecordCompletionBlock = recordCompletion
            }
            
            // Assign a completion handler
            uploadOperation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecords: [CKRecord.ID]?, error: Error?) -> Void in
                if error != nil {
                    if let error = error as? CKError {
                        if error.code == .limitExceeded {
                            // Limit exceeded - start at 400 and then split in two and try again
                            lastSplit = self.updatePortion(database: database, requireLess: true, lastSplit: lastSplit, records: records, recordIDsToDelete: recordIDsToDelete, recordsRemainder: recordsRemainder, recordIDsToDeleteRemainder: recordIDsToDeleteRemainder, completion: completion)
                        } else if error.code == .partialFailure {
                            completion?(error)
                        } else {
                            completion?(error)
                        }
                    } else {
                        completion?(error)
                    }
                } else {
                    if recordsRemainder != nil || recordIDsToDeleteRemainder != nil {
                        // Now need to send next block of records
                        lastSplit = self.updatePortion(database: database, requireLess: false, lastSplit: lastSplit, records: nil, recordIDsToDelete: nil, recordsRemainder: recordsRemainder, recordIDsToDeleteRemainder: recordIDsToDeleteRemainder, completion: completion)
                        
                    } else {
                        completion?(nil)
                    }
                }
            }
            
            // Add the operation to an operation queue to execute it
            OperationQueue().addOperation(uploadOperation)
        }
    }
    
    private class func updatePortion(database: CKDatabase?, requireLess: Bool, lastSplit: Int, records: [CKRecord]?, recordIDsToDelete: [CKRecord.ID]?, recordsRemainder: [CKRecord]?, recordIDsToDeleteRemainder: [CKRecord.ID]?, completion: ((Error?)->())?) -> Int {
        
        // Limit exceeded - start at 400 and then split in two and try again

        // Join records and remainder back together again
        var allRecords = records ?? []
        if recordsRemainder != nil {
            allRecords += recordsRemainder!
        }
        var allRecordIDsToDelete = recordIDsToDelete ?? []
        if recordIDsToDeleteRemainder != nil {
            allRecordIDsToDelete += recordIDsToDeleteRemainder!
        }

        var split = lastSplit
        let firstTime = (recordsRemainder == nil && recordIDsToDeleteRemainder == nil)
        if requireLess {
            if allRecords.count != 0 {
                // Split the records
                let half = Int((records?.count ?? 0) / 2)
                split = (firstTime ? lastSplit : half)
            } else {
                // Split the record IDs to delete
                let half = Int((recordIDsToDelete?.count ?? 0) / 2)
                split = (firstTime ? lastSplit : half)
            }
        } else {
            split = lastSplit
        }
        
        // Now split at new break point
        if allRecords.count != 0 {
            split = min(split, allRecords.count)
            let firstBlock = Array(allRecords.prefix(upTo: split))
            let secondBlock = (allRecords.count <= split ? nil : Array(allRecords.suffix(from: split)))
            self.update(records: firstBlock, database: database, recordsRemainder: secondBlock, recordIDsToDeleteRemainder: allRecordIDsToDelete, completion: completion)
        } else {
            split = min(split, allRecordIDsToDelete.count)
            let firstBlock = Array(allRecordIDsToDelete.prefix(upTo: split))
            let secondBlock = (allRecordIDsToDelete.count <= split ? nil : Array(allRecordIDsToDelete.suffix(from: split)))
            self.update(recordIDsToDelete: firstBlock, database: database, recordIDsToDeleteRemainder: secondBlock, completion: completion)
        }
        
        return split
    }
    
    public class func read(recordType: CKRecord.RecordType,
                                            predicate: NSPredicate? = nil,
                                            sortBy: [NSSortDescriptor]? = nil,
                                            database: CKDatabase? = nil,
                                            desiredKeys: [String]? = nil,
                                            cursor: CKQueryOperation.Cursor! = nil,
                                            downloadAction: @escaping (CKRecord) -> (),
                                            completeAction: @escaping (Error?) -> ()) {
        
        var queryOperation: CKQueryOperation
        var recordsRead = 0
        
        // Fetch link records from cloud
        let cloudContainer = Sync.cloudKitContainer
        let database = database ?? cloudContainer.publicCloudDatabase
        if cursor == nil {
            // First time in - set up the query
            let predicate = predicate ?? NSPredicate(value: true)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            query.sortDescriptors = sortBy
            queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        } else {
            // Continue previous query
            queryOperation = CKQueryOperation(cursor: cursor, qos: .userInteractive)
        }

        queryOperation.desiredKeys = desiredKeys
        queryOperation.queuePriority = .veryHigh
        queryOperation.recordFetchedBlock = { (record) -> Void in
            let cloudObject: CKRecord = record
            recordsRead += 1
            downloadAction(cloudObject)
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error != nil {
                completeAction(error)
            } else if cursor != nil {
                // More to come - recurse
                self.read(recordType: recordType,
                              predicate: predicate,
                              database: database,
                              cursor: cursor,
                              downloadAction: downloadAction,
                              completeAction: completeAction)
            } else {
                completeAction(nil)
            }
        }
        
        // Execute the query
        database.add(queryOperation)
    }
    
    // MARK: - Replace Player UUID routines ======================================================== -
    
    private func replaceTemporaryPlayerUUID(playerMO: PlayerMO, with playerUUID: String) {
        
        // Note this is horrible since we might add other data which would also need to be replace.
        // Worse still would be if we were to do this while holding vital Player UUIDs in memory
        // However it should happen very rarely and is the price of allowing the creating
        // of new players whilst offline. Have also changed it so that you have to call sync in a
        // special way for it to happen when there are temporary emails around.
        
        // Replace in core data tables
        self.replaceTablePlayerUUID(recordType: "Participant", key: "playerUUID", from: playerMO.playerUUID!, to: playerUUID)
        self.replaceSettingsPlayerUUID(keys: ["onlinePlayerEmail"], from: playerMO.playerUUID!, to: playerUUID)
        Scorecard.settings.save()
        
        // Replace in settings
        self.replaceUserDefaultsPlayerUUID(keys: ["tempOnlinePlayerUUID", "recoveryConnectionPlayerUUID", "recoveryConnectionRemotePlayerUUID"], from: playerMO.playerUUID!, to: playerUUID)
        
        // Replace in User Defaults
        for playerNumber in 1...Scorecard.shared.maxPlayers {
            self.replaceUserDefaultsPlayerUUID(keys: ["robot\(playerNumber)PlayerUUID", "player\(playerNumber)PlayerUUID"], from: playerMO.playerUUID!, to: playerUUID)
        }
        
        // Now check if this player was already on this device - unlikely but possible
        if let existing = Scorecard.shared.findPlayerByPlayerUUID(playerUUID) {
            // Need to merge the two player records and delete new one
            CoreData.update {
                if existing.datePlayed == nil || (playerMO.datePlayed != nil && existing.datePlayed! < playerMO.datePlayed!) {
                    existing.datePlayed = playerMO.datePlayed
                    existing.winStreak = playerMO.winStreak
                }
                existing.gamesPlayed += playerMO.gamesPlayed - playerMO.syncGamesPlayed
                existing.gamesWon += playerMO.gamesWon - playerMO.syncGamesWon
                existing.totalScore += playerMO.totalScore - playerMO.syncTotalScore
                existing.handsPlayed += playerMO.handsPlayed - playerMO.syncHandsPlayed
                existing.handsMade += playerMO.handsMade - playerMO.syncHandsMade
                existing.twosMade += playerMO.twosMade - playerMO.syncTwosMade
                if playerMO.maxScore > existing.maxScore {
                    existing.maxScore = playerMO.maxScore
                    existing.maxScoreSplit = playerMO.maxScoreSplit
                    existing.maxScoreDate = playerMO.maxScoreDate
                }
                if playerMO.maxMade > existing.maxMade {
                    existing.maxMade = playerMO.maxMade
                    existing.maxMadeSplit = playerMO.maxMadeSplit
                    existing.maxMadeDate = playerMO.maxMadeDate
                }
                if playerMO.maxWinStreak > existing.maxWinStreak {
                    existing.maxWinStreak = playerMO.maxWinStreak
                    existing.maxWinStreakDate = playerMO.maxWinStreakDate
                }
                if playerMO.maxTwos > existing.maxTwos {
                    existing.maxTwos = playerMO.maxTwos
                    existing.maxTwosSplit = playerMO.maxTwosSplit
                    existing.maxTwosDate = playerMO.maxTwosDate
                }
                if playerMO.datePlayed != nil && existing.datePlayed != nil && playerMO.datePlayed! > existing.datePlayed! {
                    existing.datePlayed = playerMO.datePlayed
                }
                // Now delete the new player
                let playerDetail = PlayerDetail()
                playerDetail.fromManagedObject(playerMO: playerMO)
                playerDetail.deleteMO()
            }
        } else {
            // Replace player UUID in player itself
            CoreData.update {
                playerMO.playerUUID = playerUUID
            }
        }
    }
    
    private func replaceTablePlayerUUID(recordType: String, key: String, from: String, to: String) {
        let records = CoreData.fetch(from: recordType, filter: NSPredicate(format: "\(key) = %@", from))
        CoreData.update {
            for record in records {
                record.setValue(to, forKey: key)
            }
        }
    }
    
    private func replaceSettingsPlayerUUID(keys: [String], from: String, to: String) {
        var changed = false
        for key in keys {
            if let currentValue = Scorecard.settings.value(forKey: key) as? String {
                if currentValue == from {
                    Scorecard.settings.setValue(to, forKey: key)
                    changed = true
                }
            }
        }
        if changed {
            Scorecard.settings.save()
        }
    }
    
    private func replaceUserDefaultsPlayerUUID(keys: [String], from: String, to : String) {
        for key in keys {
            if let currentValue = UserDefaults.standard.string(forKey: key) {
                if currentValue == from {
                    UserDefaults.standard.set(to, forKey: key)
                }
            }
        }
    }
    
    public static func getUser(completion: @escaping (String?)->()) {
        let container = Sync.cloudKitContainer
        container.fetchUserRecordID() {
            (recordID, error) in
            if error != nil || recordID == nil {
                completion(nil)
            } else {
                completion(recordID?.recordName)
            }
        }
    }
    
}



// MARK: - Utility Classes ========================================================================= -

extension Notification.Name {
    static let playerDownloaded = Notification.Name("playerDownloaded")
    static let playerImageDownloaded = Notification.Name("playerImageDownloaded")
    static let syncCompletion = Notification.Name("syncCompletion")
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


