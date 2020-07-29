//
//  Scorecard Comms Extension.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 19/08/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import Combine

protocol ScorecardAlertDelegate: UIViewController {
    
    func alertUser(reminder: Bool)
    
}

extension Scorecard : CommsStateDelegate, CommsDataDelegate {
    
    // MARK: - Comms mode helpers ======================================================== -
    
    public func setupSharing(playerDelegate: ScorecardAppPlayerDelegate? = nil) {
        if Scorecard.settings.allowBroadcast {
            self.sharingService = CommsHandler.server(proximity: .nearby, mode: .broadcast, serviceID: self.serviceID(), deviceName: Scorecard.deviceName, purpose: .sharing)
            self.resetSharing(playerDelegate: playerDelegate)
        }
    }
    
    public func stopSharing() {
        if self.commsPurpose == .sharing {
            self.sharingService?.stop()
            self.setCommsDelegate(nil)
        }
    }
    
    public func resetSharing(playerDelegate: ScorecardAppPlayerDelegate? = nil) {
        // Make sure current delegate is cleared
        sharingService?.stop() {
            self.setCommsDelegate(nil)
            
            if Scorecard.settings.allowBroadcast {
                // Restore server delegate
                self.setCommsDelegate(self.sharingService, purpose: .sharing, playerDelegate: playerDelegate)
                self.sharingService?.dataDelegate = self
                self.sharingService?.stateDelegate = self
                self.sharingService?.start()
            }
        }
    }
    
    public func setCommsDelegate(_ delegate: CommsServiceDelegate?, purpose: CommsPurpose? = nil, playerDelegate: ScorecardAppPlayerDelegate? = nil) {
        self._commsPurpose = purpose
        self._commsDelegate = delegate
        self._commsPlayerDelegate = playerDelegate
        
        // Subscribe to scores update service to forward to remotes (Note this will only do anything on servers
        if delegate == nil {
            self.commsScoresSubscription?.cancel()
        } else {
            self.commsScoresSubscription = Scorecard.game?.scores.subscribe { (round, playerNumber) in
                self.sendScores(playerNumber: playerNumber, round: round, using: delegate)
            }
        }
    }
    
    public func serviceID() -> String {
        let servicePrefix = (self.database == "development" ? "whdev" : "whist")
        return "\(servicePrefix)"
    }
    
    // MARK: - State and Data delegate implementations ================================== -
    
    public func stateChange(for peer: CommsPeer, reason: String?) {
        switch peer.state {
        case .notConnected:
            // Lost connection
            break
            
        case .connected:
            // New connection - used to send state but now should wait for refresh request
            break
            
        default:
            break
        }
    }
    
    public func didReceiveData(descriptor: String, data: [String : Any?]?, from commsPeer: CommsPeer) {
        
        Utility.mainThread("didReceiveData", execute: { [unowned self] in
            switch descriptor {
            case "refreshRequest":
                // Remote device wants a refresh of the current state
                Scorecard.shared.sendScoringState(from: self.commsPlayerDelegate, to: commsPeer)
            case "requestThumbnail":
                self.sendPlayerThumbnail(playerUUID: data!["playerUUID"] as! String, to: commsPeer)
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
        if vibrate && Scorecard.settings.alertVibrate {
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
        self.viewPresenting = .none
        if Scorecard.game.isHosting || Scorecard.game.isSharing {
            // Refresh state to all devices
            self.commsDelegate?.reset()
            
        } else {
            // Disconnect (and reconnect)
            self.commsDelegate?.reset()
        }
    }
    
    public func dealNextHand() {
        // Deal next hand if necessary - note that deal is sent as part of handstate which should always be sent after a deal
        if Scorecard.game.handState.hand == nil {
            Scorecard.game.handState.hand = self.dealHand(round: Scorecard.game.handState.round)
            // Save hand and (blank) trick in case need to recover
            Scorecard.recovery.saveHands(deal: Scorecard.game.deal, made: Scorecard.game.handState.made, twos: Scorecard.game.handState.twos)
            Scorecard.recovery.saveTrick(toLead: Scorecard.game.handState.toLead, trickCards: [])
            Scorecard.recovery.saveLastTrick(lastToLead: nil, lastCards: nil)
        }
    }
    
    public func playHand(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, sourceView: UIView, animated: Bool = true) -> HandViewController? {
        var handViewController: HandViewController?
        
        if Scorecard.game.isHosting || Scorecard.game.hasJoined {
            // Now play the hand
            if Scorecard.game.isHosting {
                appController?.robotAction(action: .deal)
            }
            if Scorecard.game.handState.hand != nil && (Scorecard.game.handState.hand.cards.count > 0 || Scorecard.game.handState.trickCards.count != 0) {
                handViewController = HandViewController.show(from: viewController, appController: appController, sourceView: sourceView, existing: handViewController, animated: animated)
            } else {
                fatalError("Trying to display hand with no hand setup")
            }
        }
        return handViewController
    }
    
    // MARK: - Routines to send data ======================================================= -
    
    private func settingsData() -> [String: Any] {
        var settings: [String: Any] = [:]

        settings["numberCards"] = Scorecard.activeSettings.cards
        settings["bounceNumberCards"] = Scorecard.activeSettings.bounceNumberCards
        settings["trumpSequence"] = Scorecard.activeSettings.trumpSequence
        settings["bonus2"] = Scorecard.activeSettings.bonus2
        settings["saveHistory"] = Scorecard.activeSettings.saveHistory
        settings["saveStats"] = Scorecard.activeSettings.saveStats
        
        return settings
    }
    
    private func playersData(from playerDelegate: ScorecardAppPlayerDelegate?) -> (String, [String: Any]) {
        var playerList: [String : Any] = [:]
        var descriptor: String
        // Send players
        if let players = playerDelegate?.currentPlayers() {
            // Override list
            for playerNumber in 1...players.count {
                var player: [String : String] = [:]
                player["name"] = players[playerNumber - 1].name
                player["playerUUID"] = players[playerNumber - 1].playerUUID
                player["connected"] = (players[playerNumber - 1].connected ? "true" : "false")
                playerList["\(playerNumber)"] = player
            }
            descriptor = "previewPlayers"
        } else {
            // Use defined players
            for playerNumber in 1...Scorecard.game.currentPlayers {
                var player: [String : String] = [:]
                let playerMO = Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO!
                player["name"] = playerMO.name!
                player["playerUUID"] = playerMO.playerUUID!
                player["connected"] = "true"
                playerList["\(playerNumber)"] = player
            }
            descriptor = "gamePlayers"
        }
        return (descriptor, playerList)
    }
    
    private func dealerData() -> [String : Any] {
        return [ "dealer" : Scorecard.game.dealerIs ]
    }
    
    private func dealData() -> [String : Any] {
        let deal = Scorecard.game.dealHistory[Scorecard.game.handState.round] ?? Deal()
        return [ "round" : Scorecard.game.handState.round,
                 "deal" : deal.toNumbers()]
    }
    
    private func scoresData(playerNumber: Int! = nil, round: Int! = nil, mode: Mode! = nil) -> [String : Any] {
        var scoreList: [String : Any] = [:]
        var playerRange: CountableClosedRange<Int>
        var roundRange: CountableClosedRange<Int>
        
        // Set up ranges
        if playerNumber == nil {
            playerRange = 1...Scorecard.game.currentPlayers
        } else {
            playerRange = playerNumber...playerNumber
        }
        if round == nil {
            roundRange = 1...Scorecard.game.maxEnteredRound
        } else {
            roundRange = round...round
        }
        
        // Scan players
        for playerNumber in playerRange {
            var playerScore: [String : Any] = [:]
            
            // Scan rounds
            for round in roundRange {
                var roundScore: [String : Any] = [:]
                
                let score = Scorecard.game.scores.get(round: round, playerNumber: playerNumber, sequence: .entered)
                
                // Send required values
                if mode == nil || mode == .bid {
                    let bid = score.bid
                    roundScore["bid"] = bid ?? NSNull()
                }
                if mode == nil || mode == .made {
                    let made = score.made
                    roundScore["made"] = made ?? NSNull()
                }
                if mode == nil || mode == .twos {
                    let twos = score.twos
                    roundScore["twos"] = twos ?? NSNull()
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
        return scoreList
    }
    
    private func handStateData() -> [String : Any] {
        var handState: [String:Any] = [:]
        
        if Scorecard.game.handState != nil && !Scorecard.game.handState.finished {
            
            var hands: [String:[String:[Int]]] = [:]
            for playerNumber in 1...Scorecard.game.currentPlayers {
                hands["\(playerNumber)"] = ["cards" : Scorecard.game.deal.hands[playerNumber - 1].toNumbers()]
            }
            
            handState = [ "hands"        : hands,
                          "trick"        : Scorecard.game.handState.trick!,
                          "made"         : Scorecard.game.handState.made!,
                          "twos"         : Scorecard.game.handState.twos!,
                          "trickCards"   : Hand(fromCards: Scorecard.game.handState.trickCards).toNumbers(),
                          "lastCards"    : Hand(fromCards: Scorecard.game.handState.lastCards).toNumbers(),
                          "toLead"       : Scorecard.game.handState.toLead!,
                          "lastToLead"   : Scorecard.game.handState.lastToLead ?? -1,
                          "round"        : Scorecard.game.handState.round,
                          "deal"         : self.dealData()]
        }
        return handState
    }
    
    public func sendHostState(from playerDelegate: ScorecardAppPlayerDelegate?, to commsPeer: CommsPeer! = nil) {
        var state: [String : Any] = [:]
        
        state["settings"] = Scorecard.shared.settingsData()
        let (descriptor, data) = self.playersData(from: playerDelegate)
        state[descriptor] = data
        state["dealer"] = self.dealerData()
        if Scorecard.game.inProgress {
            state["allscores"] = self.scoresData()
            state["autoPlay"] = self.autoPlayData()
            state["handState"] = self.handStateData()
            state["gameUUID"] = ["gameUUID" : Scorecard.game.gameUUID]
            state["playHand"] = [:]
        }
        
        self.commsDelegate?.send("state", state, to: commsPeer)
    }
    
    public func sendScoringState(from playerDelegate: ScorecardAppPlayerDelegate?, to commsPeer: CommsPeer! = nil) {
        var state: [String : Any] = [:]
        
        state["settings"] = Scorecard.shared.settingsData()
        if playerDelegate != nil || Scorecard.game.inProgress {
            let (descriptor, data) = self.playersData(from: playerDelegate)
            state[descriptor] = data
        }
        state["dealer"] = self.dealerData()
        if Scorecard.game.inProgress {
            state["allscores"] = self.scoresData()
        }
        
        self.commsDelegate?.send("state", state, to: commsPeer)
    }
    
    
    public func sendPlayHand(to commsPeer: CommsPeer? = nil) {
        // Should only be sent after all other information - e.g. players, settings, deal - have been sent
        self.sendInstruction("playHand", to: commsPeer)
    }
    
    public func sendPlayers(from playerDelegate: ScorecardAppPlayerDelegate?, to commsPeer: CommsPeer? = nil) {
        
        let (descriptor, data) = self.playersData(from: playerDelegate)
        self.commsDelegate?.send(descriptor, data, to: commsPeer)
        self.sendDealer()
    }
    
    public func sendHandState(to commsPeer: CommsPeer! = nil) {
        self.commsDelegate?.send("handState", self.handStateData(), to: commsPeer)
    }

    public func sendDealer(to commsPeer: CommsPeer! = nil) {
         self.commsDelegate?.send("dealer", self.dealerData(), to: commsPeer)
    }
     
    public func sendStatus(to commsPeer: CommsPeer! = nil, message: String) {
        let status: [String: Any] = [ "status" : message ]
        self.commsDelegate?.send("status", status, to: commsPeer)
    }
    
    public func sendBid(playerNumber: Int, round: Int, to commsPeer: CommsPeer! = nil, using commsDelegate: CommsServiceDelegate? = nil) {
        if !(Scorecard.game.isHosting || Scorecard.game.isSharing) || Scorecard.game.isPlayingComputer {
            // No need to send if hosting/sharing as all changes automatically sent
            self.sendScores(playerNumber: playerNumber, round: round, mode: .bid, to: commsPeer, using: commsDelegate, sendJoined: true)
        }
    }
    
    public func sendScores(playerNumber: Int! = nil, round: Int! = nil, mode: Mode! = nil, to commsPeer: CommsPeer! = nil, using commsDelegate: CommsServiceDelegate? = nil, sendJoined: Bool = false) {
       
        if Scorecard.game.isHosting || Scorecard.game.isSharing || (sendJoined && Scorecard.game.hasJoined) {
       
            let scoreList = scoresData(playerNumber: playerNumber, round: round, mode: mode)
            
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
    
    public func sendCardPlayed(round: Int, trick: Int, playerNumber: Int, card: Card, using commsDelegate: CommsServiceDelegate? = nil) {
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
        
    public func sendRefreshRequest(to commsPeer: CommsPeer! = nil) {
        self.sendInstruction("refreshRequest", to: commsPeer)
    }
    
    public func refreshState(from playerDelegate: ScorecardAppPlayerDelegate?, to commsPeer: CommsPeer! = nil) {
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
            if true || lastRefresh?.timeIntervalSinceNow ?? TimeInterval(-2.0) < TimeInterval(-1.0) {
                
                if Scorecard.game.isHosting {
                    // Hosting online game
                    self.sendHostState(from: playerDelegate, to: commsPeer)
                    
                } else if Scorecard.game.isSharing && Scorecard.game.inProgress {
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
    
    public func processScores(descriptor: String, data: [String : Any?]) -> Int {
        var maxRound = 0
        if descriptor == "allscores" {
            Scorecard.game.resetPlayers()
        }
        for (playerNumberData, playerData) in (data as! [String : [String : Any]]).sorted(by: {$0.key < $1.key})  {
            let playerNumber = Int(playerNumberData)!
            
            for (roundNumberData, roundData) in (playerData as! [String : [String : Any]]).sorted(by: {Int($0.key)! < Int($1.key)!}) {
                let roundNumber = Int(roundNumberData)!
                maxRound = max(maxRound, roundNumber)
                
                if roundData["bid"] != nil {
                    // Ignore if player is on this device - only doing this for bids which are entered locally - scores come down from host
                    if descriptor == "allscores" || (Scorecard.game.handState == nil || playerNumber != Scorecard.game.handState.enteredPlayerNumber) {
                        var bid: Int!
                        if roundData["bid"] is NSNull {
                            bid = nil
                        } else {
                            bid = roundData["bid"] as! Int?
                        }
                        _ = Scorecard.game.scores.set(round: roundNumber, playerNumber: playerNumber, bid: bid)
                        if bid != nil && descriptor == "scores" {
                            Scorecard.shared.bidSubscription.send((roundNumber, playerNumber, bid))
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
                    _ = Scorecard.game.scores.set(round: roundNumber, playerNumber: playerNumber, made: made)
                }
                if roundData["twos"] != nil {
                    var twos: Int!
                    if roundData["twos"] is NSNull {
                        twos = nil
                    } else {
                        twos = roundData["twos"] as! Int?
                    }
                    _ = Scorecard.game.scores.set(round: roundNumber, playerNumber: playerNumber, twos: twos)
                }
            }
            
        }
        return maxRound
    }
    
    public func processCardPlayed(data: [String : Any], from appController: ScorecardAppController) {
        let round = data["round"] as! Int
        let trick = data["trick"] as! Int
        let playerNumber = data["player"] as! Int
        let card = Card(fromNumber: data["card"] as! Int)
        
        if Scorecard.game.handState == nil || playerNumber != Scorecard.game.handState.enteredPlayerNumber {
            // Ignore if from self since should know about it already
            var handViewController: HandViewController?
            if appController.activeView == .hand {
                handViewController = appController.activeViewController as? HandViewController
            }

            // Play the card
            self.playCard(card: card)
            
            // Update view if it is showing
            handViewController?.reflectCardPlayed(round: round, trick: trick, playerNumber: playerNumber, card: card)
            
            // Save current cards played
            let currentTrickCards = Scorecard.game.handState.trickCards.count
            
            // Update state
            self.updateState(alertUser: handViewController == nil)
            
            // Reflect updated state on view if it is showing
            handViewController?.reflectCurrentState(currentTrickCards: currentTrickCards)
            
            if Scorecard.game.isHosting {
                // Reflect it out to other devices
                self.sendCardPlayed(round: round, trick: trick, playerNumber: playerNumber, card: card)
            }
        }
    }
        
    public func playCard(card: Card) {
        _ = Scorecard.game.handState.hand.remove(card: card)
        
        let nextCard = Scorecard.game.handState.trickCards.count
        if nextCard < Scorecard.game.currentPlayers {
            Scorecard.game.handState.trickCards.append(card)
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
            } else if cardPlayed.suit == Scorecard.game.roundSuit(round) && (highTrump == nil || cardPlayed.rank > highTrump) {
                highTrump = cardPlayed.rank
                winner = cardNumber
                win2 = (cardPlayed.toRankString() == "2")
            }
        }
        return (winner, win2)
    }
    
    public func updateState(alertUser: Bool = true) {
        if Scorecard.game.handState.trickCards.count == Scorecard.game.currentPlayers {
            // Hand complete - check who won
            var win2: Bool
            (Scorecard.game.handState.winner, win2) = self.checkWinner(currentPlayers: Scorecard.game.currentPlayers, round: Scorecard.game.handState.round, suits: Scorecard.game.suits, trickCards: Scorecard.game.handState.trickCards)
            
            if Scorecard.game.isHosting {
                // Remove current trick from deal
                for (index, card) in Scorecard.game.handState.trickCards.enumerated() {
                    let playerNumber = Scorecard.game.handState.playerNumber(index + 1)
                    _ = Scorecard.game.deal.hands[playerNumber - 1].remove(card: card)
                }
            }
            
            // Store and reset cards played / who led / trick
            Scorecard.game.handState.nextTrick()
            
            // Set next to lead from winner
            Scorecard.game.handState.toLead = Scorecard.game.handState.playerNumber(Scorecard.game.handState.winner!)
            Scorecard.game.handState.toPlay = Scorecard.game.handState.toLead
            
            // Update tricks made
            Scorecard.game.handState.made[Scorecard.game.handState.toPlay! - 1] += 1
            Scorecard.game.handState.twos[Scorecard.game.handState.toPlay! - 1] += (Scorecard.activeSettings.bonus2 && win2 ? 1 : 0)
            
            // Save deal and current (blank) trick for recovery
            if Scorecard.game.isHosting {
                Scorecard.recovery.saveHands(deal: Scorecard.game.deal, made: Scorecard.game.handState.made,twos: Scorecard.game.handState.twos)
            }
            
            if Scorecard.game.handState.trick > Scorecard.game.roundCards(Scorecard.game.handState.round) {
                // Hand finished - Record scores (in the order they happened)
                for playerNumber in 1...Scorecard.game.currentPlayers {
                    let player = Scorecard.game.player(roundPlayerNumber: playerNumber, round: Scorecard.game.handState.round)
                    _ = Scorecard.game.scores.set(round: Scorecard.game.handState.round, playerNumber: playerNumber, made: Scorecard.game.handState.made[player.playerNumber - 1], sequence: .round)
                    _ = Scorecard.game.scores.set(round: Scorecard.game.handState.round, playerNumber: playerNumber, twos: Scorecard.game.handState.twos[player.playerNumber - 1], sequence: .round)
                }
                Scorecard.game.handState.finished = true
            }
        } else {
            // Work out who should play
            Scorecard.game.handState.toPlay = Scorecard.game.handState.playerNumber(Scorecard.game.handState.trickCards.count + 1)
        }
        if alertUser && Scorecard.game.handState.toPlay == Scorecard.game.handState.enteredPlayerNumber {
            self.alertUser(remindAfter: 10.0)
        }
        if Scorecard.game.isHosting {
            // Save current and last trick for recovery
            Scorecard.recovery.saveTrick(toLead: Scorecard.game.handState.toLead!, trickCards: Scorecard.game.handState.trickCards)
            if Scorecard.game.handState.trick <= 1 {
                Scorecard.recovery.saveLastTrick(lastToLead: nil, lastCards: nil)
            } else {
                Scorecard.recovery.saveLastTrick(lastToLead: Scorecard.game.handState.lastToLead, lastCards: Scorecard.game.handState.lastCards)
            }
        }
    }
    
    
    func updateHandState(toLead: Int?, toPlay: Int?, finished: Bool!) {
        Scorecard.game.handState.toLead = toLead
        Scorecard.game.handState.toPlay = toPlay
        Scorecard.game.handState.finished = finished
    }
    
    private func dealHand(round: Int) -> Hand! {
        if Scorecard.game.isHosting {
            // Deal pack
            Scorecard.game.deal = Pack.deal(numberCards: Scorecard.game.roundCards(round),
                                  numberPlayers: Scorecard.game.currentPlayers)
            // Save in history
            Scorecard.game.dealHistory[Scorecard.game.handState.round] = Scorecard.game.deal.copy() as? Deal
            
            // Save for recovery
            Scorecard.recovery.saveDeal(round: Scorecard.game.handState.round, deal: Scorecard.game.deal)
            
            return Scorecard.game.deal.hands[0]
        } else {
            // Others get their hand via comms layer
            return nil
        }
    }
    
    public func requestPlayerThumbnail(from commsPeer: CommsPeer, playerUUID: String) {
        self.commsDelegate?.send("requestThumbnail", ["playerUUID" : playerUUID], to: commsPeer)
    }
    
    public func sendPlayerThumbnail(playerUUID: String, to commsPeer: CommsPeer) {
        if let playerMO = self.findPlayerByPlayerUUID(playerUUID) {
            if playerMO.thumbnail != nil {
                let imageData = playerMO.thumbnail?.base64EncodedString(options: [])
                self.commsDelegate?.send("thumbnail", [ "playerUUID" : playerUUID,
                                                        "image" : imageData,
                                                        "date"  : Utility.dateString(playerMO.thumbnailDate! as Date,
                                                                                     localized: false)],
                                          to: commsPeer)
            }
        }
    }
    
    public func sendInstruction(_ instruction: String, to commsPeer: CommsPeer? = nil) {
        // No game running - send a wait message
        self.commsDelegate?.send(instruction, [:], to: commsPeer)
    }
    
    public func sendTestConnection() {
        self.commsDelegate?.send("testConnection", [:])
    }
    
    class public func dataLogMessage(propertyList: [String: Any?], fromDeviceName: String, using commsHandler: CommsServiceDelegate) {
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
                if descriptor.right(4).lowercased() == "card" {
                    // Special case - card
                    if let cardNumber = value as? Int {
                        let card = Card(fromNumber: cardNumber)
                        result += "=\(card.toString())"
                        continue
                    }
                }
                if descriptor.right(5).lowercased() == "cards" && descriptor.lowercased != "numbercards" {
                    // Special case - cards array
                    if let handCards = value as? [Int] {
                        let hand = Hand(fromNumbers: handCards, sorted: true)
                        result += "=[\(hand.toString())]"
                        continue
                    }
                }
                if descriptor == "deal" {
                    if let data = value as? [String: Any] {
                        if let round = data["round"] as? Int {
                            if let dealCards = data["deal"] as? [[Int]] {
                                let deal = Deal(fromNumbers: dealCards)
                                result += "(\(round))=" + deal.toString()
                                continue
                            }
                        }
                    }
                }
                if let array = value as? [Any] {
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
    
    // MARK: -  Bid / card changed subscription ============================================================== -
    
    public func subscribeBid(completion: @escaping (Int, Int, Int)->()) -> AnyCancellable {
        return self.bidSubscription
            .receive(on: RunLoop.main)
            .sink() { (round, player, bid) in
                completion(round, player, bid)
        }
    }
}
