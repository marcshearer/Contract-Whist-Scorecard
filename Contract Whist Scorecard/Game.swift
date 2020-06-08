//
//  Game.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 04/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

public enum PlayerNumberSequence {
    case entered
    case scorecard
    case entry
    case round
}

class Game {
    
    // Mark: - Properties ======================================================================== -
    
    /** Private version of game settings */
    private var _settings: Settings!
    
    /**
     Read-only game settings
    */
    public var settings: Settings! {
        get {
            return _settings
        }
    }
    
    /** Players array
    - Note: Keep this private as should access it dependent on index incremented by dealer etc */
    private var player: [Player]? = nil
    
    /** Scores structure - contains bid, made and twos values for each player & round */
    public var scores = Scores()
    
    /** Hand state */
    public var handState: HandState!
    
    /** Number of players in current game */
    public var currentPlayers = 0
    
    /** Current dealer player number
     - Note: Based on entered player number */
    public var dealerIs = 1

    /** Maximum round for which scores have been entered */
    public var maxEnteredRound = 1

    /** Currently selected round */
    public var selectedRound = 1
    
    /** Is a game in progress */
    public var inProgress: Bool = false
    
    /** Date on which game in progress started */
    public var datePlayed: Date!
    
    /** UUID for game in progress */
    public var gameUUID: String!

    /** Game location */
    public var location = GameLocation()
    
    /** Managed object for game in progress */
    public var gameMO: GameMO!

    /** Current deal */
    public var deal: Deal!
    
    /** Deal history */
    public var dealHistory: [Int : Deal] = [:]
    
    /** Game complete notification sent */
    public var gameCompleteNotificationSent = false

    // Mark: - Calculated properties =========================================================== -

    /**
     Calculated suits in order given current game settings
    */
    public var suits: [Suit] {
        get {
            var suits: [Suit] = []
            for suit in self.settings.trumpSequence {
                suits.append(Suit(fromString: suit))
            }
            return suits
        }
    }
    
    /**
     Calculated number of rounds given current game settings
    */
    public var rounds: Int {
        get {
            let cards = self.settings.cards
            let bounce = self.settings.bounceNumberCards
            let range = abs(cards[0] - cards[1]) + 1
            if bounce {
                return (2 * range) - 1
            } else {
                return range
            }
        }
    }
    
    /**
     Returns true if this device is sharing it's screen
    */
    public var isSharing: Bool {
        get {
            if let delegate = Scorecard.shared.commsDelegate {
                if delegate.connectionType == .server && Scorecard.shared.commsPurpose == .sharing {
                    return (delegate.connections > 0)
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    /**
     Returns true if this device is viewing a game on another device
    */
    public var isViewing: Bool {
        get {
            if let delegate = Scorecard.shared.commsDelegate {
                return (delegate.connectionType == .client && Scorecard.shared.commsPurpose == .sharing)
            } else {
                return false
            }
        }
    }
    
    /**
     Returns true if this device is hosting a game
    */
    public var isHosting: Bool {
        get {
            if let delegate = Scorecard.shared.commsDelegate {
                return (delegate.connectionType == .server  && Scorecard.shared.commsPurpose == .playing)
            } else {
                return false
            }
        }
    }
    
    /**
     Returns true if this device has joined a remote game
    */
    public var hasJoined: Bool {
        get {
            if let delegate = Scorecard.shared.commsDelegate {
                return (delegate.connectionType == .client  && Scorecard.shared.commsPurpose == .playing)
            } else {
                return false
            }
        }
    }
    
    /**
     Calculated number of rounds given current game settings
    */
    public var isPlayingComputer: Bool {
        get {
            if let delegate = Scorecard.shared.commsDelegate {
                return (delegate.connectionMode == .loopback  && Scorecard.shared.commsPurpose == .playing)
                
            } else {
                return false
            }
        }
    }
    
    
    // Mark: - Initialisation ================================================================= -
       
    init() {
        
        // Setup players
        self.player = []
        for playerNumber in 1...Scorecard.shared.maxPlayers {
            self.player!.append(Player(playerNumber: playerNumber))
        }
        
        // Reset values
        self.reset()
        
    }
    
 // Mark: - Methods =========================================================================== -
    
    /**
     Reset game settings to device settings
    */
    public func reset() {
        self._settings = Scorecard.shared.settings.copy()
        Themes.selectTheme(name: self.settings.colorTheme)
        self.settings.saveStats = self.settings.saveHistory
        self.loadGameDefaults()
        self.resetValues()
    }
    
    /**
     Rest players, round numbers etc
    */
    public func resetValues() {
        self.resetPlayers()
        self.gameCompleteNotificationSent = false
        self.maxEnteredRound = 1
        self.selectedRound = 1
        self.inProgress = false
        self.datePlayed = nil
        self.gameUUID = ""
        self.deal = nil
        
        // Reset game managed object
        self.gameMO = nil
    }
    
    /**
     Reset game values (but not settings etc)
     */
    public func resetPlayers() {
        for playerNumber in 1...Scorecard.shared.maxPlayers {
            self.player![playerNumber-1].reset()
        }
        self.scores.reset()
    }
    
    /**
     Load game defaults from user defaults
      - Parameters:
         -  isPlayingComputer: Overrides the standard flag
    */
    public func loadGameDefaults() {
        // Load saved values from last session
         
        // Number of players
        var currentPlayers = UserDefaults.standard.integer(forKey: "numberPlayers")
        if currentPlayers != 3 && currentPlayers != 4 {
            currentPlayers = 4
        }
        self.currentPlayers = currentPlayers
        
        // Player names
        for player in 1...currentPlayers {
            let prefix = (self.isPlayingComputer ? "robot" : "player")
            if let defaultPlayerURI = UserDefaults.standard.string(forKey: "\(prefix)\(player)") {
                // Got a URI - search player list for a match
                if let playerMO = Scorecard.shared.playerList.first(where: { $0.uri == defaultPlayerURI }) {
                    self.player![player-1].playerMO = playerMO
                    self.player![player-1].playerNumber = player
                }
                    
                if self.player![player-1].playerMO == nil && !self.isPlayingComputer && Scorecard.recovery.recovering {
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
 
    /**
     Check if last round complete
     */
    public func gameComplete() -> Bool {
        // Check last score on last round filled in
        return self.scores.score(round: self.rounds, playerNumber: self.currentPlayers, sequence: .round) != nil
    }

    /**
    Save players and the game to core data
     - Returns: Success true/false
    */
    public func save() -> Bool {
        var result = false
        // Only save if last round complete
        if self.gameComplete() && !(Scorecard.game?.isPlayingComputer ?? false) {
            // Check if need to exclude from stats
            let excludeHistory = !Scorecard.activeSettings.saveHistory
            let excludeStats = excludeHistory || !Scorecard.activeSettings.saveStats
            // Save the game
            result = self.saveGameHeader(excludeHistory: excludeHistory, excludeStats: excludeStats)
            for player in 1...self.currentPlayers {
                if result {
                    result = self.player(enteredPlayerNumber: player).save(excludeHistory: excludeHistory, excludeStats: excludeStats)
                }
            }
            if result {
                // Can't recover once we've saved
                Scorecard.game.setGameInProgress(false, suppressWatch: true)
            }
        } else {
            result = true
        }
        return result
    }
    
    /**
     Save the game - participants will be saved with players
       - Parameters:
         - excludeHistory: Exclude this game from history
         - excludeStats: Exclude this game from the player's statistics
       - Returns: Success true/false
    */
    private func saveGameHeader(excludeHistory: Bool, excludeStats: Bool) -> Bool {
            
        if !excludeHistory && self.settings.saveHistory {
            if !CoreData.update(updateLogic: {
                if self.gameMO == nil {
                    // Create the managed object
                    
                    self.gameMO = CoreData.create(from: "Game") as? GameMO
                }
                if self.datePlayed == nil || self.gameUUID == "" {
                    self.datePlayed = Date()
                    self.gameUUID = UUID().uuidString
                }
                self.gameMO.localDateCreated = Date()
                self.gameMO.gameUUID = self.gameUUID
                self.gameMO.datePlayed = self.datePlayed
                self.gameMO.deviceUUID = UIDevice.current.identifierForVendor?.uuidString
                self.gameMO.deviceName = Scorecard.deviceName
                if !self.settings.saveLocation || !self.location.locationSet {
                    self.gameMO.latitude = 0
                    self.gameMO.longitude = 0
                } else {
                    self.gameMO.latitude = self.location.latitude
                    self.gameMO.longitude = self.location.longitude
                }
                if self.settings.saveLocation {
                    self.gameMO.location = self.location.description
                }
                self.gameMO.excludeStats = excludeStats
            }) {
                // Failed
                return false
            }
        }
        return true
    }
    
    /**
     Trump suit for a given round
     - Parameter round: Round number
     - Returns: The trump suit for the round
    */
    public func roundSuit(_ round: Int) -> Suit {
        let suits = self.suits
        return suits[(round-1) % suits.count]
    }
    
    /**
     Number of cards in a given round
     - Parameter round: Round number
     - Returns: The number of cards in the round
    */
    public func roundCards(_ round: Int) -> Int {
        var numberCards: Int
        
        let rounds = self.rounds
        let cards = self.settings.cards
        let bounce = self.settings.bounceNumberCards
        
        if bounce {
            numberCards = abs(((rounds+1) / 2) - round) + 1
        } else {
            numberCards = rounds - round + 1
        }
        if cards[0] < cards[1] {
            return cards[1] - numberCards + 1
        } else {
            return cards[1] + numberCards - 1
        }
    }
    
    /**
     Attributed string title for a round
     - Parameter round: Round number
     - Parameter rankColor: The color to use for the round number - default is Black
     - Parameter font: The font to use - default is system font
     - Parameter noTrumpScale: The multiplier for the font size for No Trump - default is 0.9
     - Returns: The attributed string title
    */
    public func roundTitle(_ round: Int, rankColor: UIColor = UIColor.black, font: UIFont? = nil, noTrumpScale: CGFloat? = nil) -> NSMutableAttributedString {
        
        let rankColor = [NSAttributedString.Key.foregroundColor: rankColor]
        let rank = NSMutableAttributedString(string: "\(self.roundCards(round))", attributes: rankColor)
        let suit = self.roundSuit(round)
        let roundTitle = NSMutableAttributedString()
        roundTitle.append(rank)
        roundTitle.append(suit.toAttributedString(font: font, noTrumpScale: noTrumpScale))
        
        return roundTitle
    }
    
    /**
     Returns the number remaining to be bid (or twos) (excluding a particular player (or 0))
     - Parameter playerNumber: player to exclude (entered player)
     - Parameter round: round number
     - Parameter mode: bid/twos
     - Returns: The trump suit for the round
    */
    public func remaining(playerNumber: Int, round: Int, mode: Mode) -> Int {
        
        var remaining = self.roundCards(round)
        if mode == Mode.twos {
            remaining = min(remaining, Scorecard.shared.numberSuits)
        }
        
        for playerLoop in 1...self.currentPlayers {
            if playerLoop != playerNumber {
                if let value = self.scores.get(round: round, playerNumber: playerLoop, sequence: .entry, mode: mode) {
                    remaining -= value
                }
            }
        }
        
        return remaining
    }

        /**
     Returns the entered player number given the position this player appears in the scorepad (first dealer first)
     - Parameter scorepadPlayerNumber: 1-4 in order players appear in scorecard
     - Returns: Entered player number
    */
    public func enteredPlayerNumber(scorecardPlayerNumber: Int) -> Int {
        return (((scorecardPlayerNumber - 1) + (self.dealerIs - 1)) % self.currentPlayers) + 1
    }
    
    /**
     Returns the entered player number given the position this player appears in the current round (current round dealer first)
     - Parameter entryPlayerNumber: 1-4 in order players appear in the current round
     - Returns: Entered player number
    */
    public func enteredPlayerNumber(entryPlayerNumber: Int) -> Int {
        return self.enteredPlayerNumber(roundPlayerNumber: entryPlayerNumber, round: self.selectedRound)
    }
    
    /**
     Returns the entered player number given the position this player appears in a given round (given round dealer first)
     - Parameter roundPlayerNumber: 1-4 in order players appear in a specific round
     - Parameter round: Specific round number
     - Returns: Entered player number
    */
    public func enteredPlayerNumber(roundPlayerNumber: Int, round: Int) -> Int {
        return (((roundPlayerNumber - 1) + (self.dealerIs - 1) + (round - 1)) % self.currentPlayers) + 1
    }
    
    /**
     Returns the entered player number for a player number if a given sequence
     - Parameter playerNumber: 1-4 in given sequence
     - Parameter round: Specific round number (if appropriate)
     - Returns: Entered player number
    */
    public func enteredPlayerNumber(playerNumber: Int, sequence: PlayerNumberSequence, round: Int = 0) -> Int {
        switch sequence {
        case .entered:
            return playerNumber
        case .scorecard:
            return self.enteredPlayerNumber(scorecardPlayerNumber: playerNumber)
        case .entry:
            return self.enteredPlayerNumber(entryPlayerNumber: playerNumber)
        case .round:
            return self.enteredPlayerNumber(roundPlayerNumber: playerNumber, round: round)
        }
    }

    /**
     Everything in data is in entered player sequence but the scorepad will be entered offset by the first dealer
     This converts between them
     - Parameter enteredPlayerNumber:   The player number (1-4) in the order they were first entered
      - Returns: Player number (1-4) in scorecard sequence
    */
    public func scorecardPlayerNumber(enteredPlayerNumber: Int) -> Int {
        return self.player(enteredPlayerNumber: enteredPlayerNumber).roundPlayerNumber(round:1)
    }

    
    /**
     Everything in data is in entered player sequence but bids, scores etc will be entered offset by the dealer for the round
     This converts between them
     - Parameter enteredPlayerNumber:   The player number (1-4) in the order they were first entered
     - Parameter round:                 The round for which we want the player number based on the sequence they would be entered in this round (round dealer first)
     - Returns: Player number (1-4) in entry sequence for the given round
    */
    public func roundPlayerNumber(enteredPlayerNumber: Int, round: Int) -> Int {
        return self.player(enteredPlayerNumber: enteredPlayerNumber).roundPlayerNumber(round:round)
    }
    
    /**
     Returns the player class for an email address if that player is in the current game
     - Parameter email: Email address to find
     - Returns: Player class
    */
    public func player(email: String) -> Player? {
        if let index = self.player?.firstIndex(where: {$0.playerMO != nil && $0.playerMO!.email == email}) {
            return self.player?[index]
        } else {
            return nil
        }
    }

    /**
     Returns the player class based on the order in which the players were entered
     - Parameter enteredPlayerNumber: 1-4 in order originally entered
     - Returns: Player class
    */
    public func player(enteredPlayerNumber: Int) -> Player {
        return self.player![(enteredPlayerNumber - 1)]
    }
    
    /**
     Returns the player class based on the order in which the players appear in the scorecard (first dealer first)
     - Parameter playerNumber: 1-4 in order players appear in scorecard
     - Returns: Player class
    */
    public func player(scorecardPlayerNumber: Int) -> Player {
        return self.player![self.enteredPlayerNumber(scorecardPlayerNumber: scorecardPlayerNumber) - 1]
    }
    
    /**
     Returns the player class based on the order in which the players in a specific round (specific round dealer first)
     - Parameter roundPlayerNumber: 1-4 in order scores would be ented in the specific round
     - Parameter round:        specified round
     - Returns: Player class
    */
    public func player(roundPlayerNumber: Int, round: Int) -> Player {
        return self.player![self.enteredPlayerNumber(roundPlayerNumber: roundPlayerNumber, round: round) - 1]
    }

    /**
     Returns the player class based on the order in which the players in the current round (current round dealer first)
     - Parameter entryPlayerNumber: 1-4 in order players appear in current round
     - Returns: Player class
    */
    public func player(entryPlayerNumber: Int) -> Player {
        return self.player(roundPlayerNumber: entryPlayerNumber, round: self.selectedRound)
    }
        
    /**
     Returns the index in the players array for a specific object ID based on the order in which they were originally entered
     - Parameter objectID: Managed object ID of player to search for
     - Returns: Index into player array (0-3)
    */
    public func enteredIndex(_ objectID: NSManagedObjectID) -> Int? {
        return self.player!.firstIndex(where: { $0.playerMO?.objectID == objectID })
    }
    
    /**
     Returns the index in the players array for a specific object ID based on the order in which they appear in the scorecard (first dealer first)
     - Parameter objectID: Managed object ID of player to search for
     - Returns: Index into players (0-3) in order they would be entered in scorecard (first dealer first)
    */
    public func scorecardIndex(_ objectID: NSManagedObjectID) -> Int? {
        let enteredIndex = self.enteredIndex(objectID)
        if enteredIndex == nil {
            return nil
        } else {
            return (enteredIndex! + (self.dealerIs - 1)) % self.currentPlayers
        }
    }
    
    // MARK: - Mainpulate players =========================================================== -
    
    /**
     Saves the provided list of players as the default players on the device
     - Parameters:
        - selectedPlayers: The list of player managed objects to set as default
    */
    public func saveSelectedPlayers(_ selectedPlayers: [PlayerMO?]) {
        // Update the currently selected players on return from the player selection view
        
        if selectedPlayers.count > 1 {
            self.setCurrentPlayers(players: selectedPlayers.count)
            UserDefaults.standard.set(Scorecard.game.currentPlayers, forKey: "numberPlayers")
            
            for playerNumber in 1...Scorecard.game.currentPlayers {
                let playerMO = selectedPlayers[playerNumber-1]!
                Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO = playerMO
                let prefix = ((Scorecard.game?.isPlayingComputer ?? false) ? "robot" : "player")
                UserDefaults.standard.set(playerMO.uri, forKey: "\(prefix)\(playerNumber)")
                UserDefaults.standard.set(playerMO.name, forKey: "\(prefix)\(playerNumber)name")
                UserDefaults.standard.set(playerMO.email, forKey: "\(prefix)\(playerNumber)email")
            }
        }
    }
    
    /**
     Change the current number of players
     - Parameters:
        - players: The new number of players
    */
    public func setCurrentPlayers(players: Int) {
        if players != Scorecard.game.currentPlayers {
            // Changing number of players
            
            Scorecard.game.currentPlayers = players
            if Scorecard.game.dealerIs > Scorecard.game.currentPlayers {
                self.saveDealer(1)
            }
        }
    }
    
        
    /**
     Move a player from one position in the player array to another (all in originally entered sequence)
     - Parameter fromPlayerNumber:   The player number (1-4) of the player to be moved
     - Parameter toPlayerNumber:     The new player number (1-4) for this player
    */
    public func movePlayer(fromPlayerNumber: Int, toPlayerNumber: Int) {
        let playerToMove = self.player![fromPlayerNumber-1]
        self.player!.remove(at: fromPlayerNumber - 1)
        self.player!.insert(playerToMove, at: toPlayerNumber-1)
        
        // Need to sort out any stored sequence dependent values at this point - calling routine should sort out UI
        for playerNumber in 1...self.currentPlayers {
            self.player![playerNumber-1].playerNumber = playerNumber
        }
    }
    
    // MARK: - Start / stop game ================================================================ -
    
    /**
     Toggle the game in progress flag (and possibly save it for recovery)
     - Parameters:
        - gameInProgres: The new value for the game in progress flag
        - suppressWatch: Don't update watch as result of this change
        - save: Save the value to persistent storage for recovery purposes
    */
    public func setGameInProgress(_ gameInProgress: Bool, suppressWatch: Bool = false, save: Bool = true) {
        Scorecard.game?.inProgress = gameInProgress
        if save && (!Scorecard.recovery.recoveryAvailable || gameInProgress == true) {
            Scorecard.recovery.saveGameInProgress()
            if !suppressWatch || gameInProgress {
                Scorecard.shared.watchManager.updateScores()
            }
        }
    }
    
    // MARK: - Dealer manipulation =============================================================== -
    
    public func nextDealer() {
        self.saveDealer((Scorecard.game.dealerIs % Scorecard.game.currentPlayers) + 1)
    }
    
    public func previousDealer() {
        self.saveDealer(((Scorecard.game.dealerIs + Scorecard.game.currentPlayers - 2) % Scorecard.game.currentPlayers) + 1)
    }
    
    public func saveDealer(_ dealerIs: Int) {
        if Scorecard.game.dealerIs != dealerIs {
            Scorecard.game.dealerIs = dealerIs
            if Scorecard.game.isHosting || Scorecard.game.isSharing {
                Scorecard.shared.sendDealer()
            }
        }
        UserDefaults.standard.set(Scorecard.game.dealerIs, forKey: "dealerIs")
    }
    
    public func isScorecardDealer() -> Int {
        // Returns the player number of the dealer - for use in the Scorecard view
        return (((Scorecard.game.maxEnteredRound - 1)) % Scorecard.game.currentPlayers) + 1
    }
    
    // MARK: - Check state of a particular round ======================================================== -
        
    public func roundStarted(_ round: Int) -> Bool {
        return Scorecard.game.scores.get(round: round, playerNumber: 1, sequence: .round).bid != nil
    }
    
    public func roundBiddingComplete(_ round: Int) -> Bool {
        return Scorecard.game.scores.get(round: round, playerNumber: Scorecard.game.currentPlayers, sequence: .round).bid != nil
    }
    
    public func roundMadeStarted(_ round: Int) -> Bool {
        return Scorecard.game.scores.get(round: round, playerNumber: 1, sequence: .round).made != nil
    }
    
    public func roundComplete(_ round: Int) -> Bool {
        var result = true
        if Scorecard.game.scores.score(round: round, playerNumber: Scorecard.game.currentPlayers, sequence: .round) == nil {
            result = false
        }
        if self.settings.bonus2 && Scorecard.game.scores.get(round: round, playerNumber: Scorecard.game.currentPlayers, sequence: .round).twos == nil {
            result = false
        }
        return result
    }
}
