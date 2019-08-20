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

enum CommsHandlerMode {
    case none
    case scorepad
    case roundSummary
    case gameSummary
    case playHand
    case dismiss
    case viewTrick
}

class Scorecard {
    
    // Main state class for the application - singleton
    
    public static let shared = Scorecard()
    
    public var suits: [Suit]!
    
    private var player: [Player]? = nil // Keep this private as should access it dependent on index incremented by dealer etc
    
    public var numberPlayers = 0
    public var currentPlayers = 0
    public var maxRounds = 25
    public var rounds = 0
    public var maxEnteredRound = 1
    public var selectedRound = 1
    public var dealerIs = 1
    public var readyToPlay = false
    private var roundError: [Bool] = []
    public var gameInProgress: Bool = false
    public var inScorepad: Bool = false
    public var recoveryMode: Bool = false
    public var recoveryOnlinePurpose: CommsConnectionPurpose!
    public var recoveryOnlineType: CommsConnectionType!
    public var recoveryOnlineMode: CommsConnectionMode!
    public var recoveryConnectionUUID: String!
    public var recoveryConnectionEmail: String!
    public var recoveryConnectionDevice: String!
    public let numberSuits = 4
    public var gameLocation: GameLocation!
    public var gameDatePlayed: Date!
    public var gameUUID: String!
    public var defaultPlayerOnDevice: String!
    public var latestVersion = "0.0"
    public var latestBuild = 0
    
    // Variables for online games
    public var deal: Deal!
    public var handViewController: HandViewController!
    public var handState: HandState!
    public var dealHistory: [Int : Deal] = [:]
    public var commsHandlerMode: CommsHandlerMode = .none
    public var sendScores = false
    public var notificationSimulator: NotificationSimulator!
    internal var lastRefresh: Date?
    internal var lastPeerRefresh: [String : Date] = [:]
    
    // Remote logging
    public var logService: RabbitMQClientService!
    public var logQueue: RabbitMQQueue!
    
    // Variables for test extensions
    public var autoPlayHands: Int = 0
    public var autoPlayRounds: Int = 0
    
    // Variables to store scorepad header and body height to re-center popups correctly
    public var scorepadHeaderHeight: CGFloat = 0
    public var scorepadBodyHeight: CGFloat = 0
    public var scorepadFooterHeight: CGFloat = 0
    
    // Class to pass state to watch
    public var watchManager: WatchManager!
    
    // Settings
    public var settingBonus2 = true
    public var settingCards = [13, 1]
    public var settingBounceNumberCards: Bool = false
    public var settingTrumpSequence = ["♣︎", "♦︎", "♥︎", "♠︎", "NT"]
    public var settingSyncEnabled = false
    public var settingSaveHistory = true
    public var settingSaveLocation = true
    public var settingReceiveNotifications = false
    public var settingAllowBroadcast = true
    public var settingAlertVibrate = true
    public var settingVersion = "0.0"
    public var settingBuild = 0
    public var settingLastVersion = "0.0"
    public var settingLastBuild = 0
    public var settingVersionBlockSync = false
    public var settingVersionBlockAccess = false
    public var settingVersionMessage = ""
    public var settingDatabase = ""
    public static var settingRabbitMQUri = ""
    public var settingNearbyPlaying = false
    public var settingOnlinePlayerEmail: String!
    public var settingFaceTimeAddress: String!
    public var settingPrefersStatusBarHidden = true
    
    // Override Settings
    public var overrideCards: [Int]! = nil
    public var overrideBounceNumberCards: Bool! = nil
    public var overrideExcludeStats: Bool! = nil
    public var overrideExcludeHistory: Bool! = nil
    public var overrideSelected: Bool = false
    
    // Link to recover class
    public var recovery: Recovery!
    
    // Core data variables
    public var playerList:[PlayerMO] = []
    public var gameMO: GameMO!
    
    // Network state
    public var isLoggedIn = false
    public var isNetworkAvailable = false
    public var iCloudUserIsMe = false
    
    // Comms services
    public var sharingService: MultipeerServerService!
    public var commsDelegate: CommsHandlerDelegate?
    
    // Admin mode
    static var adminMode = false
        
    public func initialise(from viewController: UIViewController? = nil, players: Int, maxRounds: Int) {
        
       self.recovery = Recovery()
        
        self.player = []
        if players > 0 {
            for playerNumber in 1...players {
                self.player!.append(Player(playerNumber: playerNumber))
            }
        }

        if maxRounds > 0 {
            for _ in 1...maxRounds {
                self.roundError.append(false)
            }
        }
        self.numberPlayers = players
        self.currentPlayers = players
        
        // Load settings
        loadSettings()
        
        // Reset settings in test mode (unless requested not to)
        TestMode.resetSettings()
        
        // Load defaults
        loadDefaults()
        if viewController != nil {
            self.updatePrefersStatusBarHidden(from: viewController!)
        }
        
        self.maxRounds = (self.maxRounds == 0 ? maxRounds : self.maxRounds)
        
        getPlayerList()
        
        // Setup suit sequence & rounds
        self.setupRounds()
        self.setupSuits()
                
        // Set up game location class
        self.gameLocation = GameLocation()
        
        // Setup sharing object and take broadcast delegates
        self.setupSharing()
        
        // Set icloud user flag
        Scorecard.iCloudUserIsMe()
        
        // Remove any temporary online game notification subscription
        Notifications.removeTemporaryOnlineGameSubscription()
        
        // Set up Watch Manager
        self.watchManager = WatchManager()
        
   }
    
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
    
    public enum GetPlayerMode {
        case getExisting
        case getNew
        case getAll
        case getSyncInProgress
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
        self.settingVersion = dictionary["CFBundleShortVersionString"] as! String? ?? "0.0"
        self.settingBuild = Int(dictionary["CFBundleVersion"] as! String) ?? 0
        
        // Check if upgrade necessary
        if self.settingVersion != self.settingLastVersion {
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
            UserDefaults.standard.set(self.settingVersion, forKey: "version")
            UserDefaults.standard.set(self.settingBuild, forKey: "build")
            self.settingLastVersion = self.settingVersion
            self.settingLastBuild = self.settingBuild
            
            // Execute any other completion
            completion?()
        }
        
        if Utility.compareVersions(version1: self.settingLastVersion, version2: "4.1") == .lessThan  {
            if !Upgrade.upgradeTo41(from: from, completion:  successfulCompletion) {
                return false
            }
        } else {
            successfulCompletion()
        }
        
        return true
        
    }
    
    private func loadSettings() {
        
        // Load bonus for making a trick with a 2
        self.settingBonus2 = UserDefaults.standard.bool(forKey: "bonus2")
                
        // Load number of cards & bounce number of cards
        self.settingCards = UserDefaults.standard.array(forKey: "cards") as! [Int]
        self.settingBounceNumberCards = UserDefaults.standard.bool(forKey: "bounceNumberCards")
        
        // Load trump sequence
        self.settingTrumpSequence = UserDefaults.standard.array(forKey: "trumpSequence") as! [String]
        
        // Load sync enabled flag
        self.settingSyncEnabled = UserDefaults.standard.bool(forKey: "syncEnabled")
        
        // Load save history settings
        self.settingSaveHistory = UserDefaults.standard.bool(forKey: "saveHistory")
        self.settingSaveLocation = UserDefaults.standard.bool(forKey: "saveLocation")
        
        // Load notification setting
        self.settingReceiveNotifications = UserDefaults.standard.bool(forKey: "allowNotifications")
        
        // Load alert settings
        self.settingAlertVibrate = UserDefaults.standard.bool(forKey: "alertVibrate")
        
        // Load broadcast setting
        self.settingAllowBroadcast = UserDefaults.standard.bool(forKey: "allowBroadcast")
        
        // Load nearby playing setting
        self.settingNearbyPlaying = UserDefaults.standard.bool(forKey: "nearbyPlaying")
        
        // Load Online Game settings
        self.settingOnlinePlayerEmail = Scorecard.onlineEmail()
        if self.settingOnlinePlayerEmail != nil {
            self.settingFaceTimeAddress = UserDefaults.standard.string(forKey: "faceTimeAddress")
        }
        
        // Load status bar setting
        self.settingPrefersStatusBarHidden = UserDefaults.standard.bool(forKey: "prefersStatusBarHidden")
        
        // Get previous version and build
        self.settingLastVersion = UserDefaults.standard.string(forKey: "version")!
        self.settingLastBuild = UserDefaults.standard.integer(forKey: "build")
        
        // Get saved access / sync / version message / database and flags
        self.settingVersionBlockAccess = UserDefaults.standard.bool(forKey: "versionBlockAccess")
        self.settingVersionBlockSync = UserDefaults.standard.bool(forKey: "versionBlockSync")
        self.settingVersionMessage = UserDefaults.standard.string(forKey: "versionMessage")!
        self.settingDatabase = UserDefaults.standard.string(forKey: "database")!
        
        // Get saved rabbitMQ URI
        Scorecard.settingRabbitMQUri = UserDefaults.standard.string(forKey: "rabbitMQUri")!
    }
    
    public func loadGameDefaults() {
        // Load saved values from last session
        var playerListNumber = 0
        
        // Number of players
        var currentPlayers = UserDefaults.standard.integer(forKey: "numberPlayers")
        if currentPlayers != 3 && currentPlayers != 4 {
            currentPlayers = 4
        }
        self.currentPlayers = currentPlayers
        
        // Player names
        for player in 1...currentPlayers {
            let prefix = (self.isPlayingComputer ? "computerPlayer" : "player")
            if let defaultPlayerURI = UserDefaults.standard.string(forKey: "\(prefix)\(player)") {
                // Got a URI - search managed objects for a match
                playerListNumber = 1
                
                while playerListNumber <= self.playerList.count {
                    
                    if defaultPlayerURI == playerURI(self.playerList[playerListNumber-1]) {
                        self.player![player-1].playerMO = self.playerList[playerListNumber-1]
                        self.player![player-1].playerNumber = player
                        break
                    }
                    
                    playerListNumber += 1
                    
                }
                
                if self.player![player-1].playerMO == nil && !self.isPlayingComputer {
                    // Might be recovering - recreate player if necessary
                    self.player![player-1].playerMO = CoreData.create(from: "Player") as? PlayerMO
                    self.player![player-1].playerMO!.name = UserDefaults.standard.string(forKey: "\(prefix)\(player)name")
                    self.player![player-1].playerMO!.email = UserDefaults.standard.string(forKey: "\(prefix)\(player)email")
                    self.player![player-1].playerNumber = player
                }
            }
        }
        
        // Dealer is
        self.dealerIs = max(1, UserDefaults.standard.integer(forKey: "dealerIs"))
    }
    
    private func loadDefaults() {
        // Defaut player on device
        self.defaultPlayerOnDevice = UserDefaults.standard.string(forKey: "defaultPlayerOnDevice")
    }
        
    public func reset() {
        // Reset class for a new game
        for playerNumber in 1...numberPlayers {
            self.player![playerNumber-1].reset()
        }
        self.maxEnteredRound = 1
        self.selectedRound = 1
        self.gameInProgress = false
        self.gameDatePlayed = nil
        self.gameUUID = ""
        
        // Reset game managed object
        self.gameMO = nil
    }
    
    
    public func formatRound(_ round: Int) {
    // Loop around all players (not just this one) highlighting errors etc
        for playerLoop in 1...self.currentPlayers {
            
            formatCell(round: round, playerNumber: playerLoop, mode: Mode.bid)
            formatCell(round: round, playerNumber: playerLoop, mode: Mode.made)
            formatCell(round: round, playerNumber: playerLoop, mode: Mode.twos)
        }
    }
    
    public func playerURI(_ playerMO: PlayerMO?) -> String {
        // Returns the Object ID URI for an entry in the player list
        if playerMO == nil {
            return ""
        } else {
            return playerMO!.objectID.uriRepresentation().absoluteString
        }
    }
    
    public func formatCell(round: Int, playerNumber: Int, mode: Mode) {
        let player = self.scorecardPlayer(playerNumber)
        
        switch mode {
        case Mode.bid:
            if player.bidCell[round-1] != nil {
                if self.roundError[round-1] {
                    Palette.inverseErrorStyle(player.bidCell[round-1]!.scorepadCellLabel, errorCondtion: true)
                } else {
                    Palette.normalStyle(player.bidCell[round-1]!.scorepadCellLabel, setFont: false)
                }
            }
        case Mode.made:
            if player.scoreCell[round-1] != nil {
                if self.roundError[round-1] {
                    Palette.inverseErrorStyle(player.scoreCell[round-1]!.scorepadCellLabel, errorCondtion: true)
                } else {
                    if player.bid(round) != nil && player.bid(round) == player.made(round) {
                        Palette.madeContractStyle(player.scoreCell[round-1]!.scorepadCellLabel, setFont: false)
                    } else {
                        if player.bidCell[round-1] == nil{
                            // No bid label so don't need to differentiate
                            Palette.normalStyle(player.scoreCell[round-1]!.scorepadCellLabel, setFont: false)
                        } else {
                            Palette.alternateStyle(player.scoreCell[round-1]!.scorepadCellLabel, setFont: false)
                        }
                    }
                    let imageView = player.scoreCell[round-1]!.scorepadImage!
                    if player.twos(round) != nil && player.twos(round) != 0 {
                        if player.twos(round) == 1 {
                            imageView.image = UIImage(named: "two")!
                        } else {
                            imageView.image = UIImage(named: "twos")!
                        }
                    } else {
                        imageView.image = nil
                    }
                    imageView.superview!.bringSubviewToFront(imageView)
                }
            }
        default:
            break
        }
    }
    
    public func enteredPlayer(email: String) -> Player? {
        if let index = self.player?.firstIndex(where: {$0.playerMO != nil && $0.playerMO!.email == email}) {
            return self.player?[index]
        } else {
            return nil
        }
    }

    public func enteredPlayer(_ playerNumber: Int) -> Player {
        // Returns the players in the sequence they were entered in the Player View - for use in the Player View
        return self.player![(playerNumber - 1)  % self.currentPlayers]
    }
    
    public func scorecardPlayer(_ playerNumber: Int) -> Player {
        // Returns the players with the first dealer first - for use in the Scorepad View
        return self.player![((playerNumber - 1) + (self.dealerIs - 1)) % self.currentPlayers]
    }
    
    public func entryPlayer(_ playerNumber: Int) -> Player {
        // Returns the players with the dealer for the selected round first - for use in the Entry View
        return self.roundPlayer(playerNumber: playerNumber, round: self.selectedRound)
    }
    
    public func roundPlayer(playerNumber: Int, round: Int) -> Player {
        // Returns the players with the dealer for a specific round first
        return self.player![((playerNumber - 1) + (self.dealerIs - 1) + (round - 1)) % self.currentPlayers]
    }
    
    public func enteredIndex(_ objectID: NSManagedObjectID) -> Int? {
        // Find the index of the given object ID in the player array
        for playerNumber in 1...self.currentPlayers {
            if self.player![playerNumber-1].playerMO!.objectID == objectID {
                return playerNumber - 1
            }
        }
        return nil
    }
    
    public func scorecardIndex(_ objectID: NSManagedObjectID) -> Int? {
        // Find the index of the given object ID in the player array and offset it by the dealer
        let enteredIndex = self.enteredIndex(objectID)
        if enteredIndex == nil {
            return nil
        } else {
            return (enteredIndex! + (self.dealerIs - 1)) % self.currentPlayers
        }
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
    
    public func setGameInProgress(_ gameInProgress: Bool, suppressWatch: Bool = false, save: Bool = true) {
        self.gameInProgress = gameInProgress
        if save {
            recovery.saveGameInProgress()
            if !suppressWatch || gameInProgress {
                self.watchManager.updateScores()
            }
        }
    }
    
    public func gameComplete(rounds: Int) -> Bool {
        // Check last score on last round filled in
        return self.roundPlayer(playerNumber: self.currentPlayers,
                                round: rounds).score(rounds) != nil
    }
    
    public func movePlayer(fromPlayerNumber: Int, toPlayerNumber: Int) {
        let playerToMove = self.player![fromPlayerNumber-1]
        self.player!.remove(at: fromPlayerNumber - 1)
        self.player!.insert(playerToMove, at: toPlayerNumber-1)
        
        // Need to sort out any stored sequence dependent values at this point - calling routine should sort out UI
        for playerNumber in 1...self.currentPlayers {
            self.player![playerNumber-1].playerNumber = playerNumber
        }
    }
    
    public func setupSuits() {
        self.suits = []
        for suit in self.settingTrumpSequence {
            self.suits.append(Suit(fromString: suit))
        }
    }
    
    public func setupRounds() {
            self.rounds = self.calculateRounds()
    }
    
    public func calculateRounds(cards: [Int]! = nil, bounce: Bool! = nil) -> Int {
        var cards = cards
        if cards == nil {
            cards = self.settingCards
        }
        var bounce = bounce
        if bounce == nil {
            bounce = self.settingBounceNumberCards
        }
        let range = abs(cards![0] - cards![1]) + 1
        if bounce! {
            return (2 * range) - 1
        } else {
            return range
        }
    }
    
    public func roundTitle(_ round: Int, rankColor: UIColor = UIColor.black, rounds: Int! = nil, cards: [Int]! = nil, bounce: Bool! = nil, suits: [Suit]! = nil) -> NSMutableAttributedString {
        
        let rankColor = [NSAttributedString.Key.foregroundColor: rankColor]
        let rank = NSMutableAttributedString(string: "\(self.roundCards(round, rounds: rounds, cards: cards, bounce: bounce))", attributes: rankColor)
        let suit = self.roundSuit(round, suits: suits)
        let roundTitle = NSMutableAttributedString()
        roundTitle.append(rank)
        roundTitle.append(suit.toAttributedString())
        
        return roundTitle
    }

    public func roundSuit(_ round: Int, suits: [Suit]!) -> Suit {
        var suits = suits
        if suits == nil {
            suits = self.suits
        }
        return suits![(round-1) % suits!.count]
    }
    
    public func roundCards(_ round: Int, rounds: Int! = nil, cards: [Int]! = nil, bounce: Bool! = nil) -> Int {
        var numberCards: Int
        
        var rounds = rounds
        if rounds == nil {
            rounds = self.rounds
        }
        
        var cards = cards
        if cards == nil {
            cards = self.settingCards
        }
        
        var bounce = bounce
        if bounce == nil {
            bounce = self.settingBounceNumberCards
        }
        
        if bounce! {
            numberCards = abs(((rounds!+1) / 2) - round) + 1
        } else {
            numberCards = rounds! - round + 1
        }
        if cards![0] < cards![1] {
            return cards![1] - numberCards + 1
        } else {
            return cards![1] + numberCards - 1
        }
    }

    public func remaining(playerNumber: Int, round: Int, mode: Mode, rounds: Int, cards: [Int], bounce: Bool) -> Int {
        // Returns the number of tricks remaining (excluding a particular player (or 0)
        // i.e. subtracts total bid / made / twos from the number of tricks in the round
        // For twos it caps the number of tricks at 4
        
        // Note that the playernumber is compared with the entered player number
        
        var remaining = roundCards(round, rounds: rounds, cards: cards, bounce: bounce)
        if mode == Mode.twos {
            remaining = min(remaining, self.numberSuits)
        }
        
        for playerLoop in 1...self.currentPlayers {
            if playerLoop != playerNumber && self.entryPlayer(playerLoop).value(round: round, mode: mode) != nil {
                remaining = remaining-self.entryPlayer(playerLoop).value(round: round, mode: mode)!
            }
        }
        
        return remaining
    }
    
    public func updateSelectedPlayers(_ selectedPlayers: [PlayerMO?]) {
        // Update the currently selected players on return from the player selection view
        
        if selectedPlayers.count > 1 {
            self.setCurrentPlayers(players: selectedPlayers.count)
            UserDefaults.standard.set(self.currentPlayers, forKey: "numberPlayers")
            
            for playerNumber in 1...self.currentPlayers {
                let playerMO = selectedPlayers[playerNumber-1]!
                self.enteredPlayer(playerNumber).playerMO = playerMO
                let prefix = (self.isPlayingComputer ? "computerPlayer" : "player")
                UserDefaults.standard.set(self.playerURI(playerMO), forKey: "\(prefix)\(playerNumber)")
                UserDefaults.standard.set(playerMO.name, forKey: "\(prefix)\(playerNumber)name")
                UserDefaults.standard.set(playerMO.email, forKey: "\(prefix)\(playerNumber)email")
            }
        }
    }
    
    public func checkReady() {
        var playerLoop = 1
        self.readyToPlay = true
        
        while playerLoop <= self.currentPlayers {
            if self.player![playerLoop-1].playerMO == nil
            {
                self.readyToPlay = false
                break
                
            } else {
                if playerLoop > 1 {
                    // Check for duplicates
                    for subPlayerLoop in 1...playerLoop - 1 {
                        if self.player![playerLoop-1].playerMO!.name! == self.player![subPlayerLoop-1].playerMO!.name! {
                            self.readyToPlay = false
                            break
                        }
                    }
                }
            }
            playerLoop += 1
        }
    }
    
    public func setCurrentPlayers(players: Int) {
        if players != self.currentPlayers {
            // Changing number of players
            
            self.currentPlayers = players
            if self.dealerIs > self.currentPlayers {
                self.saveDealer(1)
            }
        }
    }
    
    public func roundError(_ round: Int) -> Bool {
        return self.roundError[round-1]
    }
    
    public func setRoundError(_ round: Int, _ errors: Bool) {
        self.roundError[round-1] = errors
        self.formatRound(round)
        recovery.saveRoundError(round: round)
    }
    
    public func nextDealer() {
        self.saveDealer((self.dealerIs % self.currentPlayers) + 1)
    }
    
    public func previousDealer() {
        self.saveDealer(((self.dealerIs + self.currentPlayers - 2) % self.currentPlayers) + 1)
    }
    
    public func randomDealer() {
        self.saveDealer(Int(arc4random_uniform(UInt32(self.currentPlayers))) + 1)
    }
    
    public func saveDealer(_ dealerIs: Int) {
        if self.dealerIs != dealerIs {
            self.dealerIs = dealerIs
            if self.isHosting {
                self.sendDealer()
            }
        }
        UserDefaults.standard.set(self.dealerIs, forKey: "dealerIs")
    }
    
    public func isScorecardDealer() -> Int {
        // Returns the player number of the dealer - for use in the Scorecard view
        return (((self.maxEnteredRound - 1)) % self.currentPlayers) + 1
    }
    
    public func dealerName() -> String {
        return self.player![self.dealerIs-1].playerMO!.name!
    }
    
    public func advanceMaximumRound(rounds: Int) {
        if self.roundComplete(maxEnteredRound) {
            // Have now completed the entire row
            self.maxEnteredRound = min(rounds, maxEnteredRound + 1)
        }
        self.selectedRound = self.maxEnteredRound
    }
    
    public func roundStarted(_ round: Int) -> Bool {
        return self.roundPlayer(playerNumber: 1, round: round).bid(round) != nil
    }
    
    public func roundBiddingComplete(_ round: Int) -> Bool {
        return self.roundPlayer(playerNumber: self.currentPlayers, round: round).bid(round) != nil
    }
    
    public func roundMadeStarted(_ round: Int) -> Bool {
        return self.roundPlayer(playerNumber: 1, round: round).made(round) != nil
    }
    
    public func roundComplete(_ round: Int) -> Bool {
        var result = true
        if self.roundPlayer(playerNumber: self.currentPlayers, round: round).score(round) == nil {
            result = false
        }
        if self.settingBonus2 && self.roundPlayer(playerNumber: self.currentPlayers, round: round).twos(round) == nil {
            result = false
        }
        return result
    }
    
    public func saveMaxScores() {
        
        for player in 1...self.currentPlayers {
            self.enteredPlayer(player).saveMaxScore()
        }
    }

    public func finishGame(from: UIViewController, advanceDealer: Bool = false, rounds: Int, resetOverrides: Bool, returnHome: Bool = false, completion: (()->())? = nil) {
        if !self.gameInProgress {
            exitScorecard(from: from, rounds: rounds, resetOverrides: resetOverrides, completion: completion)
        } else {
            var message: String
            if self.gameComplete(rounds: rounds) {
                // Game is complete
                message = "Your game has been saved. However if you continue you will not be able to return to it."
            } else {
                // Game is still in progress
                message = "Warning: This will clear the existing score card and start a new game."
            }
            let alertController = UIAlertController(title: "Finish Game", message: message + "\n\n Are you sure you want to do this?", preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: "Confirm", style: UIAlertAction.Style.default,
                                                    handler: { (action:UIAlertAction!) -> Void in
                                                        self.exitScorecard(from: from, advanceDealer: advanceDealer, rounds: rounds,
                                                                           resetOverrides: resetOverrides,
                                                                           completion: completion)
                }))
            alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel,
                                                    handler:nil))
            from.present(alertController, animated: true, completion: nil)
            
        }
    }
    
    public func exitScorecard(from: UIViewController, advanceDealer: Bool = false, rounds: Int, resetOverrides: Bool, completion: (()->())? = nil) {
        // Save current game (if complete)
        if self.savePlayers(rounds: rounds) {
            // Reset current game
            self.reset()
            if advanceDealer {
                // If necessary advance the dealer
                self.nextDealer()
            }
            // Store max scores ready for next game in case we don't go right back to home
            self.saveMaxScores()
            
            // Close form and execute completion code
            from.dismiss(animated: true, completion: {
                if resetOverrides {
                    self.resetOverrideSettings()
                }
                completion?()
            })
        } else {
            from.alertMessage("Error saving game")
        }
    }
    
    public func savePlayers(rounds: Int) -> Bool {
        var result = false
        // Only save if last round complete
        if self.gameComplete(rounds: rounds) && !self.isPlayingComputer {
            // Check if need to exclude from stats
            let excludeHistory = (self.overrideSelected && self.overrideExcludeHistory != nil && self.overrideExcludeHistory!)
            let excludeStats = excludeHistory || (self.overrideSelected && self.overrideExcludeStats != nil && self.overrideExcludeStats!)
            // Save the game
            result = self.saveGame(excludeHistory: excludeHistory, excludeStats: excludeStats)
            for player in 1...self.currentPlayers {
                if result {
                    result = self.enteredPlayer(player).save(excludeHistory: excludeHistory, excludeStats: excludeStats)
                }
            }
            if result {
                // Can't recover once we've saved
                self.setGameInProgress(false, suppressWatch: true)
            }
        } else {
            result = true
        }
        return result
    }
    
    public func saveGame(excludeHistory: Bool, excludeStats: Bool) -> Bool {
    // Save the game - participants will be saved with players
        
        if !excludeHistory && self.settingSaveHistory {
            if !CoreData.update(updateLogic: {
                if self.gameMO == nil {
                    // Create the managed object
                    
                    self.gameMO = CoreData.create(from: "Game") as? GameMO
                }
                if self.gameDatePlayed == nil || self.gameUUID == "" {
                    self.gameDatePlayed = Date()
                    self.gameUUID = UUID().uuidString
                }
                self.gameMO.localDateCreated = Date()
                self.gameMO.gameUUID = self.gameUUID
                self.gameMO.datePlayed = self.gameDatePlayed
                self.gameMO.deviceUUID = UIDevice.current.identifierForVendor?.uuidString
                self.gameMO.deviceName = Scorecard.deviceName
                if !self.settingSaveLocation || !self.gameLocation.locationSet {
                    self.gameMO.latitude = 0
                    self.gameMO.longitude = 0
                } else {
                    self.gameMO.latitude = self.gameLocation.latitude
                    self.gameMO.longitude = self.gameLocation.longitude
                }
                if self.settingSaveLocation {
                    self.gameMO.location = self.gameLocation.description
                }
                self.gameMO.excludeStats = excludeStats
            }) {
                // Failed
                return false
            }
        }
        return true
    }
    
    public func checkNetworkConnection(button: RoundedButton!, label: UILabel!, labelHeightConstraint: NSLayoutConstraint? = nil, labelHeight: CGFloat = 0.0, disable: Bool = false) {
        // First check network
        if Reachability.isConnectedToNetwork()
        {
            self.isNetworkAvailable = true
            
            // First look at stored values and act immediately
            self.reflectNetworkConnection(button: button, label: label, labelHeightConstraint: labelHeightConstraint, labelHeight: labelHeight, disable: disable)
            
            // Now check icloud asynchronously
            CKContainer.default().accountStatus(completionHandler: { (accountStatus, errorMessage) -> Void in
                self.isLoggedIn = (accountStatus == .available)
                self.reflectNetworkConnection(button: button, label: label, disable: disable)
            })
        } else {
            self.isNetworkAvailable = false
            self.reflectNetworkConnection(button: button, label: label, labelHeightConstraint: labelHeightConstraint, labelHeight: labelHeight, disable: disable)
        }
    }
    
    public func reflectNetworkConnection(button: RoundedButton!, label: UILabel!, labelHeightConstraint: NSLayoutConstraint? = nil, labelHeight: CGFloat = 0.0, disable: Bool = false) {
        var buttonHidden = true
        var labelText = ""
        var labelHidden = true
        
        if label != nil || button != nil {
            Utility.mainThread {
                if !self.settingSyncEnabled {
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
                    Scorecard.settingRabbitMQUri != "" &&
                    self.settingOnlinePlayerEmail ?? "" != "")
        }
    }
    
    func warnShare(from: UIViewController, enabled: Bool, handler: @escaping (Bool) -> ()) {
        
        func internalHandler(_ enabled: Bool) {
            // Update sync group
            self.settingSyncEnabled = enabled
            // Save it
            UserDefaults.standard.set(self.settingSyncEnabled , forKey: "syncEnabled")
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
    
    func resetOverrideSettings() {
        self.overrideCards = nil
        self.overrideBounceNumberCards = nil
        self.overrideExcludeStats = nil
        self.overrideSelected = false
    }
    
    func checkOverride() -> Bool {
        if self.overrideCards == nil || self.overrideBounceNumberCards == nil || self.overrideExcludeStats == nil {
            self.resetOverrideSettings()
        } else {
            var cardsDifferent = false
            for index in 0..<self.settingCards.count {
                if self.overrideCards[index] != self.settingCards[index] {
                    cardsDifferent = true
                }
            }
            self.overrideSelected = (cardsDifferent ||
                                     self.overrideBounceNumberCards != self.settingBounceNumberCards ||
                                     self.overrideExcludeStats == true)
        }
        
        return self.overrideSelected
    }
        
    func saveScorepadHeights(headerHeight: CGFloat, bodyHeight: CGFloat, footerHeight: CGFloat) {
        if UIScreen.main.bounds.size.height > 600 && UIScreen.main.bounds.size.height < 800 {
            self.scorepadHeaderHeight = headerHeight
            self.scorepadBodyHeight = bodyHeight
            self.scorepadFooterHeight = footerHeight
        } else {
            self.scorepadBodyHeight = 600
        }
    }
    
    func reCenterPopup(_ viewController: UIViewController, ignoreScorepad: Bool = false) {
        // Either recenters in parent or if top provided makes that the vertical top
        var verticalCenter: CGFloat
        
        if !ignoreScorepad && self.scorepadHeaderHeight != 0 && UIScreen.main.bounds.size.height > 600 && UIScreen.main.bounds.size.height < 800 {
            // Positioning just below top
            let formHeight = viewController.preferredContentSize.height
            verticalCenter = self.scorepadHeaderHeight + CGFloat(formHeight / 2) + CGFloat(8.0)
        } else {
            verticalCenter = UIScreen.main.bounds.midY
        }
        
        viewController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: UIScreen.main.bounds.midX, y: verticalCenter), size: CGSize())
    }
    
    func showSummaryImage(_ summaryButton: UIButton) {
        switch ((self.selectedRound - 1) % 5 ) + 1 {
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
    
    class func iCloudUserIsMe() {
        
        Scorecard.shared.iCloudUserIsMe = false
        let container = CKContainer.default()
        container.fetchUserRecordID() {
            recordID, error in
            if error == nil {
                // Check for Marc, Jack, Test1 and Test2 devices
                if recordID?.recordName == "_3221381655df644e1b5a67afaa21d97d" ||
                    recordID?.recordName == "_f0efee7d46bfdafad4e403bd23ab48e6" ||
                    recordID?.recordName == "_6a4c8d69b48141215f9570049dc70f69" ||
                    recordID?.recordName == "_c4c157aa21caf6572e9a9b6fa1349f46" ||
                    recordID?.recordName == "_a3eb2a77f1e670699112be1835571ae0" {
                    Scorecard.shared.iCloudUserIsMe = true
                }
            }
        }
    }
    
    // MARK: - Functions to get view controllers, use main thread and wrapper system level stuff ==============
    
    class func getWelcomeViewController() -> WelcomeViewController? {
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            let childViewControllers = rootViewController.children
            if childViewControllers.count > 0 {
                let welcomeViewController = childViewControllers[0]
                if welcomeViewController is WelcomeViewController {
                    return welcomeViewController as? WelcomeViewController
                }
            }
        }
        return nil
    }
    
    class func dismissChildren(parent: UIViewController, completion: @escaping ()->()) {
        if let navigation = Scorecard.getWelcomeViewController()!.navigationController {
            Scorecard.dismissLastChild(parent: parent, navigation: navigation, child: nil, completion: completion)
        }
    }
    
    class func dismissLastChild(parent: UIViewController, navigation: UINavigationController, child: UIViewController?, completion: @escaping ()->()) {
        var nextChild: UIViewController?
        if child == nil {
            nextChild = navigation.viewControllers.last
        } else {
            nextChild = child
        }
        if let nextChild = nextChild {
            if let presenting = nextChild.presentedViewController {
                presenting.dismiss(animated: true, completion: {
                    dismissLastChild(parent: parent, navigation: navigation, child: nextChild, completion: completion)
                })
            } else {
                if let lastChild = nextChild.children.last {
                    lastChild.dismiss(animated: true, completion: {
                        dismissLastChild(parent: parent, navigation: navigation, child: nextChild, completion: completion)
                    })
                } else {
                    navigation.popToViewController(parent, animated: true)
                    completion()
                }
            }
        }
    }
    
    // MARK: - Get device name ======================================================================= -
    
    public static var deviceName: String {
        get {
            var result = UIDevice.current.name
            var email: String? = nil
            if false && Utility.isSimulator {
                email = Scorecard.onlineEmail()
                if email == nil {
                    email = Scorecard.defaultPlayerOnDevice()
                }
                if email != nil {
                    if let name = Scorecard.nameFromEmail(email!) {
                        result = "\(name)'s iPhone"
                    }
                }
            }
            return result
        }
    }
    
    public class func descriptiveUUID(_ type: String) -> String {
        var result: String!
        if Config.rabbitMQ_DescriptiveIDs {
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
        let onlinePlayerEmail = UserDefaults.standard.string(forKey: "onlinePlayerEmail")
        return (onlinePlayerEmail == nil || onlinePlayerEmail == "" ? nil : onlinePlayerEmail)
    }
    
    public static func defaultPlayerOnDevice() -> String? {
        let defaultPlayerEmail = UserDefaults.standard.string(forKey: "defaultPlayerOnDevice")
        return (defaultPlayerEmail == nil || defaultPlayerEmail == "" ? nil : defaultPlayerEmail)
    }
    
    public func updatePrefersStatusBarHidden(from viewController : UIViewController) {
        
        if AppDelegate.applicationPrefersStatusBarHidden != self.settingPrefersStatusBarHidden {
            
            AppDelegate.applicationPrefersStatusBarHidden = self.settingPrefersStatusBarHidden
            viewController.setNeedsStatusBarAppearanceUpdate()
            
        }
    }
}

// MARK: - Scorecard component classes ============================================================================ -

class GameLocation {
    var latitude: CLLocationDegrees!
    var longitude: CLLocationDegrees!
    var description: String!
    var subDescription: String!
    
    init() {
    }
    
    init(latitude: CLLocationDegrees!, longitude: CLLocationDegrees, description: String, subDescription: String = "") {
        self.latitude = latitude
        self.longitude = longitude
        self.description = description
        self.subDescription = subDescription
    }
    
    public func setLocation(latitude: CLLocationDegrees!, longitude: CLLocationDegrees) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public func setLocation(_ location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
    }
    
    public func copy(to gameLocation: GameLocation!) {
        gameLocation.latitude = self.latitude
        gameLocation.longitude = self.longitude
        gameLocation.description = self.description
        gameLocation.subDescription = self.subDescription
    }
    
    public var locationSet: Bool {
        get {
            return (self.latitude != nil && self.longitude != nil)
        }
    }
    
    public func distance(from location: CLLocation) -> CLLocationDistance {
        let thisLocation = CLLocation(latitude: self.latitude, longitude: self.longitude)
        return thisLocation.distance(from: location)
    }
    
}
