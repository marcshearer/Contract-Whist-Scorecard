//
//  Scorecard Comms Extension.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 19/08/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

protocol ScorecardAlertDelegate: UIViewController {
    
    func alertUser(reminder: Bool)
    
}

extension Scorecard : CommsStateDelegate, CommsDataDelegate {
    
    // MARK: - Comms mode helpers ======================================================== -
    
    public var isSharing: Bool {
        get {
            if let delegate = self.commsDelegate {
                if self.commsDelegate!.connectionType == .server && delegate.connectionPurpose == .sharing {
                    return (delegate.connections > 0)
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    public var isViewing: Bool {
        get {
            return (self.commsDelegate != nil && self.commsDelegate!.connectionType == .client && self.commsDelegate!.connectionPurpose == .sharing)
        }
    }
    
    public var isHosting: Bool {
        get {
            return (self.commsDelegate != nil && self.commsDelegate!.connectionType == .server  && self.commsDelegate!.connectionPurpose == .playing)
        }
    }
    
    public var hasJoined: Bool {
        get {
            return (self.commsDelegate != nil && self.commsDelegate!.connectionType == .client  && self.commsDelegate!.connectionPurpose == .playing)
        }
    }
    
    public var isPlayingComputer: Bool {
        get {
            return (self.commsDelegate != nil && self.commsDelegate!.connectionMode == .loopback  && self.commsDelegate!.connectionPurpose == .playing)
        }
    }
    
    public func setupSharing() {
        if self.settingAllowBroadcast {
            self.sharingService = MultipeerServerService(purpose: .sharing, serviceID: self.serviceID(.sharing))
            self.resetSharing()
        }
    }
    
    public func stopSharing() {
        if let delegate = self.commsDelegate {
            if delegate.connectionPurpose == .sharing {
                self.sharingService?.stop()
                self.commsDelegate = nil
            }
        }
    }
    
    public func resetSharing() {
        // Make sure current delegate is cleared
        sharingService?.stop()
        self.commsDelegate = nil
            
        if self.settingAllowBroadcast {
            // Restore server delegate
            self.commsDelegate = self.sharingService
            self.sharingService?.dataDelegate = self
            self.sharingService?.stateDelegate = self
            self.sharingService?.start()
        }
    }
    
    public func serviceID(_ purpose: CommsConnectionPurpose) -> String {
        let servicePrefix = (self.settingDatabase == "development" ? "whdev" : "whist")
        var purposeString: String
        if purpose == .playing {
            purposeString = "playing"
        } else {
            purposeString = "sharing"
        }
        return "\(servicePrefix)-\(purposeString)"
    }
    
    // MARK: - State and Data delegate implementations ================================== -
    
    public func stateChange(for peer: CommsPeer, reason: String?) {
        switch peer.state {
        case .notConnected:
            // Lost connection
            break
            
        case .connected:
            // New connection - resend state
            Utility.mainThread("stateChange", execute: { [unowned self] in
                if self.gameInProgress {
                    // Only here when sharing
                    if self.isHosting || self.hasJoined {
                        fatalError("Assert violation: Should never happen")
                    }
                    self.sendPlayersOverrideSettings(to: peer)
                    self.sendScores(to: peer)
                } else {
                    self.sendInstruction("wait", to: peer)
                }
            })
            
        default:
            break
        }
    }
    
    public func didReceiveData(descriptor: String, data: [String : Any?]?, from commsPeer: CommsPeer) {
        
        Utility.mainThread("didReceiveData", execute: { [unowned self] in
            switch descriptor {
            case "requestThumbnail":
                self.sendPlayerThumbnail(playerEmail: data!["email"] as! String, to: commsPeer)
            case "testConnection":
                self.commsDelegate?.send("testResponse", nil, to: commsPeer)
                Utility.getActiveViewController()?.alertMessage("Connection test received from \(commsPeer.playerName!).\nResponse sent", title: "Connection Test")
            case "testResponse":
                Utility.getActiveViewController()?.alertMessage("Connection test response received from \(commsPeer.playerName!)", title: "Connection Test")
            default:
                break
            }
        })
    }
    
    // MARK: - Alert handlers ================================================================= -
    
    public func alertUser(vibrate: Bool = true, remindAfter: TimeInterval? = nil, remindVibrate: Bool? = nil, reminder: Bool = false) {
        if vibrate && self.settingAlertVibrate {
            Utility.getActiveViewController()?.alertVibrate()
        }
        self.alertDelegate?.alertUser(reminder: reminder)
        if let remindAfter = remindAfter {
            self.startReminderTimer(interval: remindAfter, vibrate: remindVibrate ?? vibrate)
        }
    }
    
    public func cancelReminder() -> TimeInterval {
        return self.stopReminderTimer()
    }
    
    public func restartReminder(remindAfter: TimeInterval) {
        self.startReminderTimer(interval: remindAfter)
    }
    
    private func startReminderTimer(interval: TimeInterval, vibrate: Bool = true) {
        _ = self.stopReminderTimer()
        self.reminderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: { (_) in
            self.alertUser(vibrate: vibrate, reminder: true)
        })
    }
    
    private func stopReminderTimer() -> TimeInterval {
        var timeLeft: TimeInterval = 0.0
        
        if let timer = self.reminderTimer {
            timeLeft = timer.fireDate.timeIntervalSinceNow
            timer.invalidate()
            self.reminderTimer = nil
        }
        return timeLeft
    }
    
    // MARK: - Utility routines =============================================================== -
    
    public func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            
            // Play sound
            Utility.getActiveViewController()?.alertSound()
            self.resetConnection()
            
        }
    }
    
    public func resetConnection() {
        self.commsHandlerMode = .none
        if self.isHosting || self.isSharing {
            // Refresh state to all devices
            self.commsDelegate?.reset()
            
        } else {
            // Disconnect (and reconnect)
            self.commsDelegate?.reset()
        }
    }
    
    public func dealHand() {
        if self.isHosting && self.handState.hand == nil {
            // Need to deal next hand
            self.handState.hand = self.dealHand(cards: self.roundCards(self.handState.round, rounds: self.handState.rounds, cards: self.handState.cards, bounce: self.handState.bounce))
            // Save hand and (blank) trick in case need to recover
            self.recovery.saveHands(deal: self.deal, made: self.handState.made, twos: self.handState.twos)
            self.recovery.saveTrick(toLead: self.handState.toLead, trickCards: [])
            self.recovery.saveLastTrick(lastToLead: nil, lastCards: nil)
        }
    }
    
    public func playHand(from viewController: CustomViewController, sourceView: UIView, computerPlayerDelegate: [Int : ComputerPlayerDelegate?]? = nil) {
        if self.isHosting || self.hasJoined {
            // Now play the hand
            if self.isHosting {
                if self.handState.hand == nil {
                    // Need to deal next hand
                    self.handState.hand = self.dealHand(cards: self.roundCards(self.handState.round, rounds: self.handState.rounds, cards: self.handState.cards, bounce: self.handState.bounce))
                }
                
                // Set up hands in computer player mode
                if computerPlayerDelegate != nil {
                    for (playerNumber, computerPlayerDelegate) in computerPlayerDelegate! {
                        computerPlayerDelegate?.newHand(hand: self.deal.hands[playerNumber-1])
                    }
                }
            }
            if self.handState.hand != nil && (self.handState.hand.cards.count > 0 || self.handState.trickCards.count != 0) {
                let storyboard = UIStoryboard(name: "HandViewController", bundle: nil)
                let handViewController = storyboard.instantiateViewController(withIdentifier: "HandViewController") as! HandViewController

                handViewController.preferredContentSize = CGSize(width: 400, height: Scorecard.shared.scorepadBodyHeight)
               
                handViewController.delegate = viewController as? HandStatusDelegate
                handViewController.computerPlayerDelegate = computerPlayerDelegate
                
                Utility.mainThread("playHand", execute: {
                    viewController.present(handViewController, sourceView: sourceView, animated: true, completion: nil)
                })
                self.handViewController = handViewController
            } else if self.commsHandlerMode == .playHand {
                // Notify client controller that hand display already complete
                self.commsHandlerMode = .none
                NotificationCenter.default.post(name: .clientHandlerCompleted, object: self, userInfo: nil)
            }
        } else if self.isSharing {
            self.sendPlayersOverrideSettings()
            self.sendScores = true
        }
    }
    
    private func sendPlayersOverrideSettings(to peer: CommsPeer! = nil) {
        let gameSettings = self.currentGameSettings()

        self.sendPlay(rounds: gameSettings.rounds, cards: gameSettings.cards, bounce: gameSettings.bounceNumberCards, bonus2: self.settingBonus2, suits: self.suits, to: peer)

    }
    
    public func sendPlay(rounds: Int, cards: [Int], bounce: Bool, bonus2: Bool, suits: [Suit], to commsPeer: CommsPeer! = nil) {
        
        if self.isSharing || self.isHosting {
            // Send general settings
            var settings: [String: Any] = [:]
            settings["rounds"] = rounds
            settings["cards"] = cards
            settings["bounce"] = bounce
            settings["bonus2"] = bonus2
            var suitStrings: [String] = []
            for suit in suits {
                suitStrings.append(suit.toString())
            }
            settings["suits"] = suitStrings
            settings["gameUUID"] = self.gameUUID!
            var round = self.selectedRound
            if self.entryPlayer(self.currentPlayers).score(round) != nil {
                // Round complete - prepare for next round
                round = min(round + 1, self.rounds)
            }
            settings["round"] = round
            self.commsDelegate?.send("settings", settings, to: commsPeer)
            
            // Send players with directive to play
            self.sendPlayers(descriptor: "play", to: commsPeer)
            self.sendScores = true
        }
    }
            
    public func sendPlayers(descriptor: String = "players", players: [(email: String, name: String, connected: Bool)]? = nil, to commsPeer: CommsPeer! = nil) {
        var playerList: [String : Any] = [:]
        // Send players
        if let players = players {
            // List passed in
            for playerNumber in 1...players.count {
                var player: [String : String] = [:]
                player["name"] = players[playerNumber - 1].name
                player["email"] = players[playerNumber - 1].email
                player["connected"] = (players[playerNumber - 1].connected ? "true" : "false")
                playerList["\(playerNumber)"] = player
            }
        } else {
            // Use defined players
            for playerNumber in 1...self.currentPlayers {
                var player: [String : String] = [:]
                let playerMO = enteredPlayer(playerNumber).playerMO!
                player["name"] = playerMO.name!
                player["email"] = playerMO.email!
                player["connected"] = "true"
                playerList["\(playerNumber)"] = player
            }
        }
        self.commsDelegate?.send(descriptor, playerList, to: commsPeer)
        self.sendDealer()
    }
    
    public func sendStatus(to commsPeer: CommsPeer! = nil, message: String) {
        let status: [String: Any] = [ "status" : message ]
        self.commsDelegate?.send("status", status, to: commsPeer)
    }
    
    
    public func sendDealer(to commsPeer: CommsPeer! = nil) {
        let dealer: [String: Any] = [ "dealer" : self.dealerIs ]
        self.commsDelegate?.send("dealer", dealer, to: commsPeer)
    }
    
    public func sendScores(playerNumber: Int! = nil, round: Int! = nil, mode: Mode! = nil, overrideBid: Int? = nil, to commsPeer: CommsPeer! = nil, using commsDelegate: CommsHandlerDelegate? = nil) {
        var scoreList: [String : Any] = [:]
        var playerRange: CountableClosedRange<Int>
        var roundRange: CountableClosedRange<Int>
        
        if self.sendScores {
            
            // Set up ranges
            if playerNumber == nil {
                playerRange = 1...self.currentPlayers
            } else {
                playerRange = playerNumber...playerNumber
            }
            if round == nil {
                roundRange = 1...self.maxEnteredRound
            } else {
                roundRange = round...round
            }
            
            // Scan players
            for playerNumber in playerRange {
                var playerScore: [String : Any] = [:]
                
                // Scan rounds
                for round in roundRange {
                    var roundScore: [String : Any] = [:]
                    
                    // Send required values
                    if mode == nil || mode == .bid {
                        var bid = overrideBid
                        if bid == nil {
                            // Will only be overridden by computer player
                            bid = self.enteredPlayer(playerNumber).bid(round)
                        }
                        if bid != nil {
                            roundScore["bid"] = bid
                        } else {
                            roundScore["bid"] = NSNull()
                        }
                    }
                    if mode == nil || mode == .made {
                        let made = self.enteredPlayer(playerNumber).made(round)
                        if made != nil {
                            roundScore["made"] = made
                        } else {
                            roundScore["made"] = NSNull()
                        }
                    }
                    if mode == nil || mode == .twos {
                        let twos = self.enteredPlayer(playerNumber).twos(round)
                        if twos != nil {
                            roundScore["twos"] = twos
                        } else {
                            roundScore["twos"] = NSNull()
                        }
                    }
                    
                    // Send round if non-nil scores
                    if roundScore.count != 0 {
                        playerScore["\(round)"] = roundScore
                    }
                    
                }
                
                // Send player if non-nil scores
                if playerScore.count != 0 {
                    scoreList["\(playerNumber)"] = playerScore
                }
            }
            // Send if non-nil scores
            if scoreList.count != 0 {
                // Setup comms handler
                var commsDelegate = commsDelegate
                if commsDelegate == nil {
                    commsDelegate = self.commsDelegate
                }
                commsDelegate?.send((playerNumber == nil && round == nil && mode == nil ? "allscores" : "scores"), scoreList, to: commsPeer)
            }
        }
    }
    
    public func sendDeal(to commsPeer: CommsPeer! = nil) {
        // Send other players their cards
        
        self.commsDelegate?.send("deal", [ "round" : self.handState.round,
                                           "deal" : self.deal.toNumbers()])
        
    }
    
    public func sendCut(cutCards: [Card], playerNames: [String], to commsPeer: CommsPeer! = nil) {
        var slot = 1
        var cardNumbers: [Int] = []
        var names: [String] = []
        for card in cutCards {
            cardNumbers.append(card.toNumber())
            names.append(playerNames[slot])
            slot = (slot + 1) % playerNames.count
        }
        self.commsDelegate?.send("cut", ["cards": cardNumbers,
                                         "names": playerNames],
                                 to: commsPeer)
    }
    
    public func sendCardPlayed(round: Int, trick: Int, playerNumber: Int, card: Card, using commsDelegate: CommsHandlerDelegate? = nil) {
        // Setup comms handler
        var commsDelegate = commsDelegate
        if commsDelegate == nil {
            commsDelegate = self.commsDelegate
        }
        commsDelegate?.send("played", [ "round"           : round,
                                        "trick"           : trick,
                                        "player"          : playerNumber,
                                        "card"            : card.toNumber() ])
    }
    
    public func sendHandState(to commsPeer: CommsPeer! = nil) {
        if self.handState != nil && !self.handState.finished {
            for playerNumber in 2...self.currentPlayers {
                let hand = self.deal.hands[playerNumber - 1]
                self.commsDelegate?.send("handState", [ "cards"        : hand.toNumbers(),
                                                        "trick"        : self.handState.trick,
                                                        "made"         : self.handState.made,
                                                        "twos"         : self.handState.twos,
                                                        "trickCards"   : Hand(fromCards: self.handState.trickCards).toNumbers(),
                                                        "lastCards"    : Hand(fromCards: self.handState.lastCards).toNumbers(),
                                                        "toLead"       : self.handState.toLead,
                                                        "lastToLead"   : self.handState.lastToLead ?? -1,
                                                        "round"        : self.handState.round],
                                          to: commsPeer,
                                          matchEmail: self.enteredPlayer(playerNumber).playerMO!.email!)
                Utility.debugMessage("sendHandState", "\(playerNumber) \(commsPeer?.deviceName ?? "all") \(self.enteredPlayer(playerNumber).playerMO!.email!)")
                self.sendAutoPlay(to: commsPeer)
            }
        }
    }
    
    public func sendRefreshRequest(to commsPeer: CommsPeer! = nil) {
        self.sendInstruction("refreshRequest", to: commsPeer)
    }
    
    public func refreshState(to commsPeer: CommsPeer! = nil) {
        Utility.mainThread {
            var lastRefresh = self.lastRefresh
            if commsPeer != nil {
                if let lastPeerRefresh = self.lastPeerRefresh[commsPeer.deviceName] {
                    if lastRefresh == nil || lastPeerRefresh > lastRefresh! {
                        lastRefresh = lastPeerRefresh
                    }
                } else {
                    // No previous refresh to this device
                    lastRefresh = Date(timeIntervalSinceReferenceDate: 0.0)
                }
            }
            
            // Only send 1 refresh a second to a particular device!
            if lastRefresh?.timeIntervalSinceNow ?? TimeInterval(-2.0) < TimeInterval(-1.0) {
                
                if self.isHosting {
                    // Hosting online game
                    
                    if !self.gameInProgress || self.handState == nil {
                        // Game not started yet - wait
                        self.sendInstruction("wait", to: commsPeer)
                        self.sendAutoPlay(to: commsPeer)
                    } else {
                        // Game in progress - need to resend state - luckily have what we need in handState
                        self.sendPlay(rounds: self.handState.rounds, cards: self.handState.cards, bounce: self.handState.bounce, bonus2: self.handState.bonus2, suits: self.handState.suits, to: commsPeer)
                        self.sendScores(to: commsPeer)
                        self.sendHandState(to: commsPeer)
                    }
                    
                } else if self.isSharing {
                    // Sharing
                    
                    self.sendScores(to: commsPeer)
                }
                
                // Update last refresh
                if commsPeer == nil {
                    // Have updated all peers
                    self.lastRefresh = Date()
                } else {
                    self.lastPeerRefresh[commsPeer.deviceName] = Date()
                }
            }
        }
    }
    
    public func processScores(descriptor: String, data: [String : Any?], bonus2: Bool) -> Int {
        var maxRound = 0
        self.commsDelegate?.debugMessage("Processing scores")
        for (playerNumberData, playerData) in (data as! [String : [String : Any]]).sorted(by: {$0.key < $1.key})  {
            let playerNumber = Int(playerNumberData)!
            if descriptor == "allscores" {
                self.enteredPlayer(playerNumber).reset()
            }
            
            for (roundNumberData, roundData) in (playerData as! [String : [String : Any]]).sorted(by: {Int($0.key)! < Int($1.key)!}) {
                let roundNumber = Int(roundNumberData)!
                maxRound = max(maxRound, roundNumber)
                
                if roundData["bid"] != nil {
                    // Ignore if player is on this device - only doing this for bids which are entered locally - scores come down from host
                    if descriptor == "allscores" || (self.handState == nil || playerNumber != self.handState.enteredPlayerNumber) {
                        var bid: Int!
                        if roundData["bid"] is NSNull {
                            bid = nil
                        } else {
                            bid = roundData["bid"] as! Int?
                        }
                        if self.enteredPlayer(playerNumber).setBid(roundNumber, bid, bonus2: bonus2) {
                            if self.handViewController != nil {
                                self.handViewController.reflectBid(round: roundNumber, enteredPlayerNumber: playerNumber)
                            } else {
                                if descriptor == "scores" && self.handState != nil {
                                    // Check if this makes it your bid
                                    if (playerNumber % self.currentPlayers) + 1 == self.handState.enteredPlayerNumber {
                                        self.alertUser(remindAfter: 10.0)
                                    }
                                }
                            }
                        }
                    }
                }
                if roundData["made"] != nil {
                    var made: Int!
                    if roundData["made"] is NSNull {
                        made = nil
                    } else {
                        made = roundData["made"] as! Int?
                    }
                    self.enteredPlayer(playerNumber).setMade(roundNumber, made, bonus2: bonus2)
                }
                if roundData["twos"] != nil {
                    var twos: Int!
                    if roundData["twos"] is NSNull {
                        twos = nil
                    } else {
                        twos = roundData["twos"] as! Int?
                    }
                    self.enteredPlayer(playerNumber).setTwos(roundNumber, twos, bonus2: bonus2)
                }
            }
            
        }
        return maxRound
    }
    
    public func processCardPlayed(data: [String : Any]) {
        let round = data["round"] as! Int
        let trick = data["trick"] as! Int
        let playerNumber = data["player"] as! Int
        let card = Card(fromNumber: data["card"] as! Int)
        
        self.commsDelegate?.debugMessage("Processing card played \(card.toString()) from \(self.enteredPlayer(playerNumber).playerMO!.name!)")
        
        if self.handState == nil || playerNumber != self.handState.enteredPlayerNumber {
            // Ignore if from self since should know about it already
            
            // Update state
            self.playCard(card: card)
            
            if self.isHosting {
                // Reflect it out to other devices
                self.sendCardPlayed(round: round, trick: trick, playerNumber: playerNumber, card: card)
            }
            
            if self.handViewController != nil {
                // Play the card on the view
                self.handViewController.reflectCardPlayed(round: round, trick: trick, playerNumber: playerNumber, card: card)
            } else {
                // State won't be updated in view so do it here
                self.updateState()
            }
        }
    }
    
    public func playCard(card: Card) {
        _ = self.handState.hand.remove(card: card)
        
        let nextCard = self.handState.trickCards.count
        if nextCard < self.currentPlayers {
            self.handState.trickCards.append(card)
        }
    }
    
    func checkWinner(currentPlayers: Int, round: Int, suits: [Suit], trickCards: [Card]) -> (Int?, Bool) {
        var winner = 1
        let cardLed = trickCards.first!
        var highLed = cardLed.rank
        var highTrump: Int!
        var win2 = (cardLed.toRankString() == "2")
        for cardNumber in 2...currentPlayers {
            let cardPlayed = trickCards[cardNumber - 1]
            if cardPlayed.suit == cardLed.suit {
                if cardPlayed.rank > highLed! && highTrump == nil {
                    // Highest card in suit led and no trumps played
                    highLed = cardPlayed.rank
                    winner = cardNumber
                    win2 = (cardPlayed.toRankString() == "2")
                }
            } else if cardPlayed.suit == self.roundSuit(round, suits: suits) && (highTrump == nil || cardPlayed.rank > highTrump) {
                highTrump = cardPlayed.rank
                winner = cardNumber
                win2 = (cardPlayed.toRankString() == "2")
            }
        }
        return (winner, win2)
    }
    
    public func updateState(alertUser: Bool = true) {
        if self.handState.trickCards.count == self.currentPlayers {
            // Hand complete - check who won
            var win2: Bool
            (self.handState.winner, win2) = self.checkWinner(currentPlayers: self.currentPlayers, round: self.handState.round, suits: self.handState.suits, trickCards: self.handState.trickCards)
            
            if self.isHosting {
                // Remove current trick from deal
                for (index, card) in self.handState.trickCards.enumerated() {
                    let playerNumber = self.handState.playerNumber(index + 1)
                    _ = self.deal.hands[playerNumber - 1].remove(card: card)
                }
            }
            
            // Store and reset cards played / who led / trick
            self.handState.nextTrick()
            
            // Set next to lead from winner
            self.handState.toLead = self.handState.playerNumber(self.handState.winner!)
            self.handState.toPlay = self.handState.toLead
            
            // Update tricks made
            self.handState.made[self.handState.toPlay! - 1] += 1
            self.handState.twos[self.handState.toPlay! - 1] += (self.handState.bonus2 && win2 ? 1 : 0)
            
            // Save deal and current (blank) trick for recovery
            if self.isHosting {
                self.recovery.saveHands(deal: self.deal, made: self.handState.made,twos: self.handState.twos)
            }
            
            if self.handState.trick > self.roundCards(self.handState.round, rounds: self.handState.rounds, cards: self.handState.cards, bounce: self.handState.bounce) {
                // Hand finished
                if self.isHosting {
                    // Record scores (in the order they happened)
                    for playerNumber in 1...self.currentPlayers {
                        let player = self.roundPlayer(playerNumber: playerNumber, round: self.handState.round)
                        player.setMade(self.handState.round, self.handState.made[player.playerNumber - 1])
                        player.setTwos(self.handState.round, self.handState.twos[player.playerNumber - 1], bonus2: self.handState.bonus2)
                    }
                }
                self.handState.finished = true
            }
        } else {
            // Work out who should play
            self.handState.toPlay = self.handState.playerNumber(self.handState.trickCards.count + 1)
        }
        if alertUser && self.handState.toPlay == self.handState.enteredPlayerNumber {
            self.alertUser(remindAfter: 10.0)
        }
        if self.isHosting {
            // Save current and last trick for recovery
            self.recovery.saveTrick(toLead: self.handState.toLead!, trickCards: self.handState.trickCards)
            if self.handState.trick <= 1 {
                self.recovery.saveLastTrick(lastToLead: nil, lastCards: nil)
            } else {
                self.recovery.saveLastTrick(lastToLead: self.handState.lastToLead, lastCards: self.handState.lastCards)
            }
        }
    }
    
    
    func updateHandState(toLead: Int?, toPlay: Int?, finished: Bool!) {
        self.handState.toLead = toLead
        self.handState.toPlay = toPlay
        self.handState.finished = finished
    }
    
    public func dealHand(cards: Int) -> Hand! {
        if self.isHosting {
            // Deal pack
            self.deal = Pack.deal(numberCards: cards,
                                  numberPlayers: self.currentPlayers)
            // Save in history
            self.dealHistory[self.handState.round] = self.deal.copy() as? Deal
            
            // Save for recovery
            self.recovery.saveDeal(round: self.handState.round, deal: self.deal)
            
            // Send hands to other players
            sendDeal()
            
            return self.deal.hands[0]
        } else {
            return nil
        }
    }
    
    public func requestPlayerThumbnail(from commsPeer: CommsPeer, playerEmail: String) {
        self.commsDelegate?.send("requestThumbnail", ["email" : playerEmail], to: commsPeer)
    }
    
    public func sendPlayerThumbnail(playerEmail: String, to commsPeer: CommsPeer) {
        if let playerMO = self.findPlayerByEmail(playerEmail) {
            if playerMO.thumbnail != nil {
                let imageData = playerMO.thumbnail?.base64EncodedString(options: [])
                self.commsDelegate?.send("thumbnail", [ "email" : playerEmail,
                                                        "image" : imageData,
                                                        "date"  : Utility.dateString(playerMO.thumbnailDate! as Date,
                                                                                     localized: false)],
                                          to: commsPeer)
            }
        }
    }
    
    public func sendInstruction(_ instruction: String, to commsPeer: CommsPeer? = nil) {
        // No game running - send a wait message
        self.commsDelegate?.send(instruction, nil, to: commsPeer)
    }
    
    public func sendTestConnection() {
        self.commsDelegate?.send("testConnection", nil)
    }
    
    func entryPlayerNumber(_ enteredPlayerNumber: Int, round: Int) -> Int {
        // Everything in data is in entered player sequence but bids will be in entry player sequence this converts between them
        return self.enteredPlayer(enteredPlayerNumber).entryPlayerNumber(round: round)
    }
    
    class public func dataLogMessage(propertyList: [String: Any?], fromDeviceName: String, using commsHandler: CommsHandlerDelegate) {
        // Log message
        var dataMessageLogged = false
        if let type = propertyList["type"] as? String , let content = propertyList["content"] as? [String:[String:Any?]] {
            if type == "data" {
                for (descriptor, detail) in content {
                    let serialised = Scorecard.serialise(detail, skipDescriptors: ["type", "fromDeviceName"])
                    commsHandler.debugMessage("Received \(descriptor)(\(serialised)) from \(fromDeviceName)")
                    dataMessageLogged = true
                }
            }
        }
        if !dataMessageLogged {
            commsHandler.debugMessage("Received \(Scorecard.serialise(propertyList)) from \(fromDeviceName)")
        }
    }
    
    class public func serialise(_ data: [String : Any?], skipDescriptors: [String] = []) -> String {
        var result = ""
        var first = true
        for (descriptor, value) in data {
            if !skipDescriptors.contains(descriptor) {
                if !first {
                    result += ", "
                }
                first = false
                result += descriptor
                if descriptor.right(5).lowercased() == "cards" {
                    // Special case - cards array
                    if let handCards = value as? [Int] {
                        let hand = Hand(fromNumbers: handCards, sorted: true)
                        result += "=[\(hand.toString())]"
                    }
                    
                } else if descriptor == "deal" {
                    if let dealCards = value as? [[Int]] {
                        let deal = Deal(fromNumbers: dealCards)
                        result += "=" + deal.toString()
                    }
                } else if let array = value as? [Any] {
                    // Other array
                    result += "=["
                    for (index, element) in array.enumerated() {
                        if index != 0 {
                            result += ", "
                        }
                        result += "\(element)"
                    }
                    result += "]"
                    
                } else if let dictionary = value as? [String : Any?] {
                    // Sub-dictionary
                    result += "=(\(Scorecard.serialise(dictionary)))"
                    
                } else {
                    // Plain value
                    result += "=\(value ?? "")"
                    
                }
            }
        }
        return result
    }
}
