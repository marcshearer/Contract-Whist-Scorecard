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
    public var settings = Settings()
    
    /** Maximum number of players currently supported - currently 4
     - Note try to use this variable throughout since only real limitation should be UI
    */
    public let maxPlayers = 4
    
    /** Number of suits
     - Unlikely to change from 4!
    */
    public let numberSuits = 4

    // Variables for online games
    public var viewPresenting = ScorecardView.none
    public var notificationSimulator: NotificationSimulator!
    public var alertDelegate: ScorecardAlertDelegate?
    internal var reminderTimer: Timer?
    internal var bidSubscription = PassthroughSubject<(Int, Int, Int), Never>()

    // Remote logging
    public var logService: CommsClientServiceDelegate!
    
    // Variables for test extensions
    public var autoPlayHands: Int = 0
    public var autoPlayGames: Int = 0
    
    // Variables to store scorepad header and body height to re-center popups correctly
    public var _scorepadBodyHeight: CGFloat = 0
    public var scorepadHeaderHeight: CGFloat = 0
    public var scorepadFooterHeight: CGFloat = 0
    public var scorepadBodyHeight: CGFloat {
        get {
            return (self._scorepadBodyHeight == 0.0 ? 700.0 : self._scorepadBodyHeight)
        }
        set(newValue) {
            self._scorepadBodyHeight = newValue
        }
    }
    
    // Class to pass state to watch
    public var watchManager: WatchManager!
    
    // Database - production / development
    public var database = ""
        
    // Core data variables
    public var playerList:[PlayerMO] = []
    
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
    internal var lastRefresh: Date?
    internal var lastPeerRefresh: [String : Date] = [:]

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
            return Scorecard.game?.settings ?? Scorecard.shared.settings
        }
    }
        
    // MARK: - Initialisation ================================================================ -

    init() {
        
        // Get last database used
        self.database = UserDefaults.standard.string(forKey: "database")!
        
        // Load settings & version etc
        self.settings.load()
        Scorecard.version.load()
        RabbitMQConfig.load()
        
        // Reset settings in test mode (unless requested not to)
        TestMode.resetSettings()
        
        // Load defaults
        self.updatePrefersStatusBarHidden()
        
        self.getPlayerList()
                
        // Set icloud user flag
        self.setICloudUserIsMe()
        
        // Remove any temporary online game notification subscription
        Notifications.removeTemporaryOnlineGameSubscription()
        
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
    
    public func playerEmailList(getPlayerMode: GetPlayerMode = .getAll, cutoffDate: Date! = nil, specificEmail: [String] = []) -> [String] {
        var playerEmailList: [String] = []
        var include = false
        
        for playerMO in self.playerList {
            
            if playerMO.email != nil && playerMO.email! != "" {
                
                include = true
                if specificEmail.count != 0 {
                    if specificEmail.firstIndex(where: {($0 == playerMO.email)}) == nil {
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
                        playerEmailList.append(playerMO.email!)
                    }
                }
            }
        }
        return playerEmailList
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
    
    func isDuplicateEmail(_ playerDetail: PlayerDetail) -> Bool {
        let index = self.playerList.firstIndex(where: {$0.email!.uppercased() == playerDetail.email.uppercased() && $0.objectID != playerDetail.objectID} )
        return (index != nil)
    }
    
    func playerName(_ playerEmail: String) -> String {
        let index = self.playerList.firstIndex(where: {$0.email!.uppercased() == playerEmail.uppercased()} )
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
    
    public func upgradeToVersion(from: UIViewController, completion: (()->())? = nil) -> Bool {
        
        func successfulCompletion() {
            // Store version in defaults and update last version
            UserDefaults.standard.set(Scorecard.version.version, forKey: "version")
            UserDefaults.standard.set(Scorecard.version.build, forKey: "build")
            Scorecard.version.lastVersion = Scorecard.version.version
            Scorecard.version.lastBuild = Scorecard.version.build
            
            // Execute any other completion
            completion?()
        }
        
        if Utility.compareVersions(version1: Scorecard.version.lastVersion, version2: "4.1") == .lessThan  {
            if !Upgrade.upgradeTo41(from: from, completion:  successfulCompletion) {
                return false
            }
        } else {
            successfulCompletion()
        }
        
        return true
        
    }
        
    public func findPlayerByEmail(_ email: String) -> PlayerMO? {
        let index = self.playerList.firstIndex(where: {($0.email == email)})
        if index == nil {
            return nil
        } else {
            return self.playerList[index!]
        }
    }

    public static func nameFromEmail(_ email: String) -> String? {
        let playerList: [PlayerMO] = CoreData.fetch(from: "Player", filter: NSPredicate(format: "email = %@", email), sort: ("name", .ascending))
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
    
    public func checkNetworkConnection(button: RoundedButton! = nil, label: UILabel! = nil, labelHeightConstraint: NSLayoutConstraint? = nil, labelHeight: CGFloat = 0.0, disable: Bool = false, action: (()->())? = nil) {
        // First check network
        
        if Reachability.isConnectedToNetwork()
        {
            self.isNetworkAvailable = true
            
            // First look at stored values and act immediately
            self.reflectNetworkConnection(button: button, label: label, labelHeightConstraint: labelHeightConstraint, labelHeight: labelHeight, disable: disable, action: action)
            
            // Now check icloud asynchronously
            CKContainer.init(identifier: Config.iCloudIdentifier).accountStatus(completionHandler: { (accountStatus, errorMessage) -> Void in
                self.isLoggedIn = (accountStatus == .available)
                self.reflectNetworkConnection(button: button, label: label, disable: disable, action: action)
            })
        } else {
            self.isNetworkAvailable = false
            self.reflectNetworkConnection(button: button, label: label, labelHeightConstraint: labelHeightConstraint, labelHeight: labelHeight, disable: disable, action: action)
        }
    }
    
    public func reflectNetworkConnection(button: RoundedButton!, label: UILabel!, labelHeightConstraint: NSLayoutConstraint? = nil, labelHeight: CGFloat = 0.0, disable: Bool = false, action: (()->())?) {
        var buttonHidden = true
        var labelText = ""
        var labelHidden = true
        
        if action != nil {
            Utility.mainThread {
                action?()
            }
        } else if label != nil || button != nil {
            Utility.mainThread {
                if !self.settings.syncEnabled {
                    buttonHidden = true
                    labelText = ""
                    labelHidden = true
                } else if self.isNetworkAvailable && self.isLoggedIn {
                    buttonHidden = false
                    labelText = ""
                    labelHidden = true
                } else {
                    // Note that the button should already be disabled initially
                    buttonHidden = true
                    labelHidden = false
                    if self.isNetworkAvailable {
                        labelText = "Login to iCloud to enable sync"
                    } else {
                        labelText = "Join network to enable sync"
                    }
                }
                
                if button != nil {
                    if disable {
                        button.isEnabled(!buttonHidden)
                    } else {
                        button.isHidden = buttonHidden
                    }
                }
                if label != nil {
                    label.text = labelText
                    label.isHidden = labelHidden
                    if labelHeightConstraint != nil {
                        labelHeightConstraint?.constant = (labelHidden ? 0.0 : labelHeight)
                    }
                }
            }
        }
    }
    
    public var onlineEnabled: Bool {
        get {
            return ((Utility.isDevelopment || (self.isNetworkAvailable && self.isLoggedIn)) &&
                    RabbitMQConfig.rabbitMQUri != "" &&
                    self.settings.onlineGamesEnabled)
        }
    }
    
    func warnShare(from: UIViewController, enabled: Bool, handler: @escaping (Bool) -> ()) {
        
        func internalHandler(_ enabled: Bool) {
            // Update sync group
            self.settings.syncEnabled = enabled
            // Save it
            UserDefaults.standard.set(self.settings.syncEnabled , forKey: "syncEnabled")
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
    
    func saveScorepadHeights(headerHeight: CGFloat, bodyHeight: CGFloat, footerHeight: CGFloat) {
        
        if UIScreen.main.bounds.size.height > 600 {
            self.scorepadHeaderHeight = headerHeight
            self.scorepadBodyHeight = bodyHeight
            self.scorepadFooterHeight = footerHeight
        } else {
            self.scorepadBodyHeight = 700
        }
    }
    
    func reCenterPopup(_ viewController: UIViewController, ignoreScorepad: Bool = false) {
        // Either recenters in parent or if top provided makes that the vertical top
        var verticalCenter: CGFloat
        
        
        let midTop = (UIScreen.main.bounds.height - viewController.preferredContentSize.height) / 2
        
        if !ignoreScorepad && self.scorepadHeaderHeight != 0 && viewController.preferredContentSize.height <= self.scorepadBodyHeight && midTop < self.scorepadHeaderHeight {
            // Positioning just below top
            verticalCenter = self.scorepadHeaderHeight + CGFloat(self.scorepadBodyHeight / 2)
        } else {
            verticalCenter = UIScreen.main.bounds.midY
        }
        
        viewController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: UIScreen.main.bounds.midX, y: verticalCenter), size: CGSize())
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

    // MARK: - Functions to return useful iCloud information ================================= -
    
    private func setICloudUserIsMe() {
        
        self.iCloudUserIsMe = false
        let container = CKContainer.init(identifier: Config.iCloudIdentifier)
        container.fetchUserRecordID() {
            recordID, error in
            if error == nil {
                // Check for Marc, Jack, Test1 and Test2 devices
                if recordID?.recordName == "_3221381655df644e1b5a67afaa21d97d" ||
                    recordID?.recordName == "_f0efee7d46bfdafad4e403bd23ab48e6" ||
                    recordID?.recordName == "_6a4c8d69b48141215f9570049dc70f69" ||
                    recordID?.recordName == "_c4c157aa21caf6572e9a9b6fa1349f46" ||
                    recordID?.recordName == "_a3eb2a77f1e670699112be1835571ae0" {
                    self.iCloudUserIsMe = true
                }
            }
        }
    }
    
    // MARK: - Get device name ======================================================================= -
    
    public static var deviceName: String {
        get {
            var result = UIDevice.current.name
            var email: String? = nil
            return result
        }
    }
    
    public class func descriptiveUUID(_ type: String) -> String {
        var result: String!
        if RabbitMQConfig.descriptiveIDs {
            if let email = Scorecard.onlineEmail() {
                if let name = Scorecard.nameFromEmail(email) {
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
    
    public static func onlineEmail() -> String? {
        let thisPlayerEmail = UserDefaults.standard.string(forKey: "thisPlayerEmail")
        return (thisPlayerEmail == nil || thisPlayerEmail == "" ? nil : thisPlayerEmail)
    }
    
    public func updatePrefersStatusBarHidden(from viewController : UIViewController? = nil) {
        
        if AppDelegate.applicationPrefersStatusBarHidden != self.settings.prefersStatusBarHidden {
            
            AppDelegate.applicationPrefersStatusBarHidden = self.settings.prefersStatusBarHidden
            viewController?.setNeedsStatusBarAppearanceUpdate()
            
        }
    }
}

extension Notification.Name {
    static let checkAutoPlayInput = Notification.Name(".checkAutoPlayInput")
}
