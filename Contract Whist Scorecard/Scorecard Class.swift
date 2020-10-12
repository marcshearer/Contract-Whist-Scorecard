//
//  Scorecard Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 02/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import CloudKit
import Combine

// MARK: - Enumerations ============================================================== -

public enum CommsPurpose: String {
    case playing = "playing"
    case sharing = "sharing"
    case other = "other"
}

public enum GetPlayerMode {
    case getExisting
    case getNew
    case getAll
    case getSyncInProgress
}

protocol ShakeDelegate : class {
    func shakeGestureHandler() -> Bool
}

class Scorecard {
    
    // MARK: - Properties ============================================================== -
    
    /** Singleton scorecard */
    public static let shared = Scorecard()
    
    /** Game state for any game in progress */
    public static var game: Game!
    
    /** Recovery class */
    public static var recovery = Recovery()
    
    /** Version information */
    public static var version = Version()
    
    /** Settings */
    public static var settings = Settings()
    
    /** Network reachability checker*/
    public static let reachability = Reachability()
    
    /** Sync Class */
    private let sync = Sync()
    
    /** Maximum number of players currently supported - currently 4
     - Note try to use this variable throughout since only real limitation should be UI
    */
    public let maxPlayers = 4
    
    /** Number of suits
     - Unlikely to change from 4!
    */
    public let numberSuits = 4

    /** Game banners
     - Use game banner color for banners
    */
    public var useGameColor = false
    public var trueUseGameColor = false
    
    // Variables for online games
    public var viewPresenting = ScorecardView.none
    public var notificationSimulator: NotificationSimulator!
    public var alertDelegate: ScorecardAlertDelegate?
    internal var reminderTimer: Timer?
    internal var bidSubscription = PassthroughSubject<(Int, Int, Int), Never>()

    // Remote logging
    public var logService: CommsClientServiceDelegate!
    
    // Variables for test extensions
    public var autoPlayGames: Int = 0
    public var autoPlayHands: Int = 0
    
    // Class to pass state to watch
    public var watchManager: WatchManager!
    
    // Database - production / development
    public var database = ""
        
    // Core data variables
    public var playerList:[PlayerMO] = []
    
    public var playerEmails: [String:String] = [:]  // Downloaded on player sync, but not guaranteed to be in place
                                                    // These should NEVER be saved on local disk, just used to
                                                    // avoid duplicates
    
    // Network state
    public var isLoggedIn = false
    public var isNetworkAvailable = false
    public var iCloudUserIsMe = false
    
    // Comms services
    public var sharingService: CommsHostServiceDelegate?
    internal weak var _commsDelegate: CommsServiceDelegate?
    internal var _commsPurpose: CommsPurpose?
    internal var _commsPlayerDelegate: ScorecardAppPlayerDelegate?
    internal var commsScoresSubscription: AnyCancellable?
    public weak var commsDelegate: CommsServiceDelegate? { get { return _commsDelegate } }
    public var commsPurpose: CommsPurpose? { get { return _commsPurpose } }
    public var commsPlayerDelegate: ScorecardAppPlayerDelegate? { get { return _commsPlayerDelegate }}
    internal var appController: ScorecardAppController?
    internal var lastRefresh: Date?
    internal var lastPeerRefresh: [String : Date] = [:]
    public weak var shakeDelegate: ShakeDelegate?

    // Admin mode
    static var adminMode = false
    
    // MARK: - Calculated properties ========================================================= -
    
    /**
     Calculated current active settings
     - If a game is set up this will be the game settings
     - Otherwise it will be the device settings
     */
    public static var activeSettings: Settings {
        get {
            return Scorecard.game?.settings ?? Scorecard.settings
        }
    }
        
    // MARK: - Initialisation ================================================================ -

    init() {
        
        // Get last database used
        self.database = UserDefaults.standard.string(forKey: "database")!
        
        // Load settings & version etc
        Scorecard.settings.load()
        Scorecard.version.load()
        RabbitMQConfig.load()
        
        // Reset settings in test mode (unless requested not to)
        TestMode.resetSettings()
        
        // Load defaults
        self.updatePrefersStatusBarHidden()
        
        self.getPlayerList()
                
        // Set icloud user flag
        self.setICloudUserIsMe()
        
        // Set up Watch Manager
        self.watchManager = WatchManager()
        
   }
    
    // MARK: - Methods ================================================================ -

    public func getPlayerList() {
        // Fetch list of potential players from data store
        self.playerList = CoreData.fetch(from: "Player", sort: ("name", .ascending))
    }

    public func playerDetailList() -> [PlayerDetail] {
        // Return a list of player detail records corresponding to player MO list
        var playerDetailList: [PlayerDetail] = []
        for playerMO in self.playerList {
            let playerDetail = PlayerDetail()
            playerDetail.fromManagedObject(playerMO: playerMO)
            playerDetailList.append(playerDetail)
        }
        return playerDetailList
    }
    
    public func playerUUIDList(getPlayerMode: GetPlayerMode = .getAll, cutoffDate: Date! = nil, specificPlayerUUIDs: [String] = []) -> [String] {
        var playerUUIDList: [String] = []
        var include = false
        
        for playerMO in self.playerList {
            
            if playerMO.playerUUID != nil && playerMO.playerUUID! != "" {
                
                include = true
                if specificPlayerUUIDs.count != 0 {
                    if specificPlayerUUIDs.firstIndex(where: {($0 == playerMO.playerUUID)}) == nil {
                        include = false
                    }
                }
                
                if include {
                    switch getPlayerMode {
                    case .getExisting:
                        include = (cutoffDate! >= playerMO.localDateCreated! as Date)
                    case .getNew:
                        include = (playerMO.localDateCreated! as Date > cutoffDate!)
                    case .getSyncInProgress:
                        include = (playerMO.syncInProgress)
                    default:
                        include = true
                    }
                    
                    if include {
                        playerUUIDList.append(playerMO.playerUUID!)
                    }
                }
            }
        }
        return playerUUIDList
    }
    
    public func refreshPlayerDetailList(_ playerDetailList: [PlayerDetail]){
        // Refresh a list of player detail records from the associated managed objects
        for playerDetail in playerDetailList {
            playerDetail.fromManagedObject(playerMO: playerDetail.playerMO)
        }
    }
    
    func isDuplicateName(_ playerDetail: PlayerDetail) -> Bool {
        let index = self.playerList.firstIndex(where: {$0.name?.uppercased() == playerDetail.name.uppercased() && $0.objectID != playerDetail.objectID} )
        return (index != nil)
    }
    
    func isDuplicatePlayerUUID(_ playerDetail: PlayerDetail) -> Bool {
        var found = false
        found = (self.playerList.first(where: {$0.playerUUID! == playerDetail.playerUUID && $0.objectID != playerDetail.objectID} ) != nil)
        if !found && playerDetail.tempEmail != nil {
            // Check temp email not duplicate
            found = (self.playerList.first(where: {$0.tempEmail ?? "" != "" && $0.tempEmail!.uppercased() == playerDetail.tempEmail.uppercased() && $0.objectID != playerDetail.objectID} ) != nil)
            if !found && Scorecard.shared.playerEmails.count > 0 {
                // Or check temp email not in list of emails (not guaranteed to be up-to-date)
                found = (self.playerEmails.first(where: {$0.value.uppercased() == playerDetail.tempEmail.uppercased()}) != nil)
            }
        }
        return found
    }
    
    func playerUUID(email: String)->String? {
        // Try to find a player UUID from an email - note xref not guaranteed up-to-date
        return self.playerEmails.first(where: {$0.value.uppercased() == email.uppercased()})?.key
    }
    
    func playerName(_ playerUUID: String) -> String {
        let index = self.playerList.firstIndex(where: {$0.playerUUID!.uppercased() == playerUUID.uppercased()} )
        if index != nil {
            return playerList[index!].name!
        } else {
            return ""
        }
    }
    
    public func getVersion(completion: (()->())? = nil) {
        // Get current software versions
        let dictionary = Bundle.main.infoDictionary!
        Scorecard.version.version = dictionary["CFBundleShortVersionString"] as! String? ?? "0.0"
        Scorecard.version.build = Int(dictionary["CFBundleVersion"] as! String) ?? 0
        
        if (Double(Scorecard.version.lastVersion) ?? 0) == 0 {
            // New install - set to current version
            self.saveVersion()
            completion?()
        } else {
        // Check if upgrade necessary
            if Scorecard.version.version != Scorecard.version.lastVersion {
                if !upgradeToVersion(from: Utility.getActiveViewController()!, completion: completion) {
                    Utility.getActiveViewController()?.alertMessage("Error upgrading to latest version")
                    exit(0)
                }
            } else {
                completion?()
            }
        }
    }
    
    public func upgradeToVersion(from: UIViewController, completion: (()->())? = nil) -> Bool {
        
        func successfulCompletion() {
            // Store version in defaults and update last version
            self.saveVersion()
            
            // Execute any other completion
            completion?()
        }
        
        if Utility.compareVersions(version1: Scorecard.version.lastVersion, version2: "4.1") == .lessThan  {
            if !Upgrade.shared.upgradeTo41(from: from, completion:  successfulCompletion) {
                return false
            }
        } else {
            successfulCompletion()
        }
        
        return true
        
    }
    
    public func saveVersion() {
        UserDefaults.standard.set(Scorecard.version.version, forKey: "version")
        UserDefaults.standard.set(Scorecard.version.build, forKey: "build")
        Scorecard.version.lastVersion = Scorecard.version.version
        Scorecard.version.lastBuild = Scorecard.version.build
    }
        
    public func findPlayerByPlayerUUID(_ playerUUID: String) -> PlayerMO? {
        let index = self.playerList.firstIndex(where: {($0.playerUUID == playerUUID)})
        if index == nil {
            return nil
        } else {
            return self.playerList[index!]
        }
    }

    public static func nameFromPlayerUUID(_ playerUUID: String) -> String? {
        let playerList: [PlayerMO] = CoreData.fetch(from: "Player", filter: NSPredicate(format: "playerUUID = %@", playerUUID), sort: ("name", .ascending))
        if playerList.count > 0 {
            return playerList[0].name
        } else {
            return nil
        }
    }
   
    public func saveMaxScores() {
        
        for player in 1...Scorecard.game.currentPlayers {
            Scorecard.game.player(enteredPlayerNumber: player).saveMaxScore()
        }
    }

    public func exitScorecard(advanceDealer: Bool = false, resetOverrides: Bool, completion: (()->())? = nil) {
        // Save current game (if complete)
        if Scorecard.game.save() {
            // Reset current game
            Scorecard.game.resetValues()
            if advanceDealer {
                // If necessary advance the dealer
                Scorecard.game.nextDealer()
            }
            // Store max scores ready for next game in case we don't go right back to home
            self.saveMaxScores()
            
            if resetOverrides {
                Scorecard.game.reset()
            }
            completion?()
            
        } else {
            Utility.getActiveViewController()!.alertMessage("Error saving game")
        }
    }
    
    public func warnExitGame(from viewController: ScorecardViewController, mode: ScorepadMode, completion: @escaping ()->()) {
        if  mode == .hosting || mode == .scoring {
            viewController.alertDecision("Warning: This will clear the existing score card and start a new game.\n\n Are you sure you want to do this?", title: "Finish Game", okButtonText: "Confirm", okHandler: {
            
                Scorecard.shared.exitScorecard(advanceDealer: false, resetOverrides: true) {
                    Utility.mainThread {
                        completion()
                    }
                }
            })
        } else  {
            viewController.alertDecision(if: mode == .joining, "Warning: This will mean you exit from the game.\n\nAre you sure you want to do this?", okButtonText: "Confirm",
                okHandler: {
                    completion()
                })
        }
    }
    
    public func checkNetworkConnection(action: (()->())? = nil) {
        // First check network
        Utility.mainThread {
            
            if Scorecard.reachability.connected ?? false {
                self.isNetworkAvailable = true
                
                // First act immediately using stored values
                action?()
                
                // Now check icloud asynchronously
                CKContainer.init(identifier: Config.iCloudIdentifier).accountStatus(completionHandler: { (accountStatus, errorMessage) -> Void in
                    self.isLoggedIn = (accountStatus == .available)
                    Utility.mainThread {
                        action?()
                    }
                })
            } else {
                self.isNetworkAvailable = false
                action?()
            }
        }
    }
    
    public var onlineEnabled: Bool {
        get {
            return ((Utility.isDevelopment || (self.isNetworkAvailable && self.isLoggedIn)) &&
                    RabbitMQConfig.rabbitMQUri != "" &&
                    Scorecard.settings.onlineGamesEnabled)
        }
    }
    
    func warnShare(from: ScorecardViewController, enabled: Bool, handler: @escaping (Bool) -> ()) {
        
        func internalHandler(_ enabled: Bool) {
            // Update sync group
            Scorecard.settings.syncEnabled = enabled
            // Save it
            UserDefaults.standard.set(Scorecard.settings.syncEnabled , forKey: "syncEnabled")
            // Call source handler to update controls etc
            handler(enabled)
        }
        
        func oKHandler() {
            internalHandler(true)
        }
        
        func cancelHandler() {
            internalHandler(false)
        }
        
        if enabled {
            // Sync set to enabled - need to warn about privacy
            from.alertDecision("If you enable iCloud sharing any other users of this app on other devices will have access to a player's scores and history entered on this device if they enter the player's unique identifier on their device.\n\nIf you enable iCloud sharing please make sure that the unique identifiers used for players are not in any way private. You should NOT use private data such as ID numbers\n\nAre you sure you want to do this?",
                               title: "Warning", okHandler: oKHandler, cancelHandler: cancelHandler)
        } else {
            // Sync disabled - just do it
            internalHandler(false)
        }
    }
    
    func reCenterPopup(_ viewController: UIViewController) {
        viewController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY), size: CGSize())
    }
    
    func showSummaryImage(_ summaryButton: UIButton) {
        switch ((Scorecard.game.selectedRound - 1) % 5 ) + 1 {
        case 1:
            summaryButton.setImage(UIImage(named: "round summary clubs"), for: .normal)
        case 2:
            summaryButton.setImage(UIImage(named: "round summary diamonds"), for: .normal)
        case 3:
            summaryButton.setImage(UIImage(named: "round summary hearts"), for: .normal)
        case 4:
            summaryButton.setImage(UIImage(named: "round summary spades"), for: .normal)
        default:
            summaryButton.setImage(UIImage(named: "round summary nt"), for: .normal)
        }
    }

    public func syncBeforeGame(allPlayers: Bool = false) {
        if !Scorecard.recovery.recoveryAvailable {
            // If recovery available presumably synced before started the game
            var specificPlayerUUIDs: [String] = []
            if allPlayers {
                for playerNumber in 1...Scorecard.game.currentPlayers {
                    if let playerMO = Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO {
                        specificPlayerUUIDs.append(playerMO.playerUUID!)
                    }
                }
            } else {
                specificPlayerUUIDs = [Scorecard.settings.thisPlayerUUID]
            }
            _ = sync.synchronise(syncMode: .syncBeforeGame, specificPlayerUUIDs: specificPlayerUUIDs, waitFinish: true, mainThread: false)
        }
    }
    
    // MARK: - Functions to return useful iCloud information ================================= -
    
    private func setICloudUserIsMe() {
        
        self.iCloudUserIsMe = false
        let container = CKContainer.init(identifier: Config.iCloudIdentifier)
        container.fetchUserRecordID() {
            recordID, error in
            if error == nil {
                // Check for Marc, Jack, Test1 and Test2 devices
                if recordID?.recordName == "_1e924f27c7b4b89fec7b3d9d7ba2a482" ||
                    recordID?.recordName == "" ||
                    recordID?.recordName == "" ||
                    recordID?.recordName == "" ||
                    recordID?.recordName == "" {
                    self.iCloudUserIsMe = true
                }
            }
        }
    }
    
    // MARK: - Get device name ======================================================================= -
    
    public static var deviceName: String {
        get {
            let result = UIDevice.current.name
            return result
        }
    }
    
    public class func descriptiveUUID(_ type: String) -> String {
        var result: String!
        if RabbitMQConfig.descriptiveIDs {
            if let playerUUID = Scorecard.onlinePlayerUUID() {
                if let name = Scorecard.nameFromPlayerUUID(playerUUID) {
                    let dateString = Utility.dateString(Date(), format: "yyyy-MM-dd-hh-mm-ss", localized: false)
                    result = name + "-" + type + "-" + dateString
                }
            }
        }
        if result == nil {
            result = UUID().uuidString
        }
        return result
    }
    
    public static func onlinePlayerUUID() -> String? {
        let thisPlayerUUID = UserDefaults.standard.string(forKey: "thisPlayerUUID")
        return (thisPlayerUUID == nil || thisPlayerUUID == "" ? nil : thisPlayerUUID)
    }
    
    public func updatePrefersStatusBarHidden(from viewController : ScorecardViewController? = nil) {
        
        if AppDelegate.applicationPrefersStatusBarHidden != Scorecard.settings.prefersStatusBarHidden {
            
            AppDelegate.applicationPrefersStatusBarHidden = Scorecard.settings.prefersStatusBarHidden
            viewController?.setNeedsStatusBarAppearanceUpdate()
            
        }
    }
}

extension Notification.Name {
    static let checkAutoPlayInput = Notification.Name(".checkAutoPlayInput")
}
