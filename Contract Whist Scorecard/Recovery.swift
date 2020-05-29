//
//  Recovery.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 21/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//
//  A library of routines to save a game as it progresses and then to recover from it if necessary

import UIKit
import CoreLocation

class Recovery {
    
    public var recoveryAvailable: Bool = false
    public var gameUUID: String = ""
    public var onlineRecovery: Bool = false
    public var onlinePurpose: CommsPurpose!
    public var onlineType: CommsConnectionType!
    public var onlineProximity: CommsConnectionProximity!
    public var onlineMode: CommsConnectionMode!
    public var connectionUUID: String!
    public var connectionEmail: String!
    public var connectionRemoteEmail: String!
    public var connectionRemoteDeviceName: String!
    public var reloadInProgress = false
    
    public var recovering: Bool = false
    
    init(load: Bool = true) {
        if load {
            self.recoveryAvailable = UserDefaults.standard.bool(forKey: "recoveryGameInProgress")
            if self.recoveryAvailable {
                self.gameUUID = UserDefaults.standard.string(forKey: "recoveryGameUUID") ?? ""
                self.loadOnlineRecovery()
            }
        }
    }
    
    public func saveGameInProgress() {
        var online = ""
        let gameInProgress = Scorecard.game?.inProgress ?? false
        UserDefaults.standard.set(gameInProgress, forKey: "recoveryGameInProgress")
        if gameInProgress {
            UserDefaults.standard.set(Scorecard.game.gameUUID ?? "", forKey: "recoveryGameUUID")
            if let delegate = Scorecard.shared.commsDelegate {
                if Scorecard.shared.commsPurpose == .playing {
                    let purpose = CommsPurpose.playing.rawValue
                    let type = delegate.connectionType.rawValue
                    let proximity = delegate.connectionProximity.rawValue
                    let mode = delegate.connectionMode.rawValue
                    online = "\(purpose)-\(type)-\(proximity)-\(mode)"
                    if delegate.connectionType == .server  {
                        if delegate.connectionMode == .invite {
                            UserDefaults.standard.set(delegate.connectionUUID, forKey: "recoveryConnectionUUID")
                        }
                    }
                    UserDefaults.standard.set(delegate.connectionRemoteDeviceName, forKey: "recoveryConnectionRemoteDevice")
                    UserDefaults.standard.set(delegate.connectionEmail, forKey: "recoveryConnectionEmail")
                    UserDefaults.standard.set(delegate.connectionRemoteEmail, forKey: "recoveryConnectionRemoteEmail")
                }
            }
        }
        UserDefaults.standard.set(online, forKey: "recoveryOnline")
        UserDefaults.standard.synchronize()
    }
       
    public func saveBid(round: Int, playerNumber: Int) {
        let key = "recoveryBid\(round)-\(playerNumber)"
        var bid: Int? = Scorecard.game.scores.get(round: round, playerNumber: playerNumber, sequence: .entered).bid
        if bid == nil {
            bid = -1
        }
        UserDefaults.standard.set(bid, forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    public func saveMade(round: Int, playerNumber: Int) {
        let key = "recoveryMade\(round)-\(playerNumber)"
        var made: Int? = Scorecard.game.scores.get(round: round, playerNumber: playerNumber, sequence: .entered).made
        if made == nil {
            made = -1
        }
        UserDefaults.standard.set(made, forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    public func saveTwos(round: Int, playerNumber: Int) {
        let key = "recoveryTwos\(round)-\(playerNumber)"
        var twos: Int? = Scorecard.game.scores.get(round: round, playerNumber: playerNumber, sequence: .entered).twos
        if twos == nil{
            twos = -1
        }
        UserDefaults.standard.set(twos, forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    public func saveHands(deal: Deal, made: [Int], twos: [Int]) {
        UserDefaults.standard.set(deal.toNumbers(), forKey: "recoveryHands")
        UserDefaults.standard.set(made, forKey: "recoveryMade")
        UserDefaults.standard.set(twos, forKey: "recoveryTwos")
    }
    
    public func saveTrick(toLead: Int, trickCards: [Card]) {
        UserDefaults.standard.set(toLead, forKey: "recoveryToLead")
        UserDefaults.standard.set(Hand(fromCards: trickCards).toNumbers(), forKey: "recoveryTrick")
    }
    
    public func saveLastTrick(lastToLead: Int!, lastCards: [Card]!) {
        UserDefaults.standard.set(lastToLead, forKey: "recoveryLastToLead")
        if lastCards == nil {
            UserDefaults.standard.set(nil, forKey: "recoveryLastTrick")
        } else {
            UserDefaults.standard.set(Hand(fromCards: lastCards).toNumbers(), forKey: "recoveryLastTrick")
        }
    }
    
    public func saveLocationAndDate() {
        UserDefaults.standard.set(Scorecard.game.location.description, forKey: "recoveryLocationText")
        if Scorecard.game.location.locationSet {
            UserDefaults.standard.set(Scorecard.game.location.latitude, forKey: "recoveryLocationLatitude")
            UserDefaults.standard.set(Scorecard.game.location.longitude, forKey: "recoveryLocationLongitude")
        }
        UserDefaults.standard.set(Scorecard.game.datePlayed, forKey: "recoveryDatePlayed")
        UserDefaults.standard.set(Scorecard.game.gameUUID, forKey: "recoveryGameUUID")
    }
    
    public func saveOverride() {
        UserDefaults.standard.set(Scorecard.activeSettings.cards, forKey: "recoveryOverrideCards")
        UserDefaults.standard.set(Scorecard.activeSettings.bounceNumberCards, forKey: "recoveryOverrideBounceNumberCards")
        UserDefaults.standard.set(Scorecard.activeSettings.saveHistory, forKey: "recoveryOverrideSaveHistory")
        UserDefaults.standard.set(Scorecard.activeSettings.saveStats, forKey: "recoveryOverrideSaveStats")
    }
    
    public func saveDeal(round: Int, deal: Deal) {
        UserDefaults.standard.set(deal.toNumbers(), forKey: "recoveryDeal\(round)")
    }
    
    public func saveInitialValues() {
        // Called at the start of a game to clear out any old values
        
        for round in 1...Scorecard.game.rounds {
            
            for playerNumber in 1...Scorecard.shared.maxPlayers {
                
                self.saveBid(round: round, playerNumber: playerNumber)
                self.saveMade(round: round, playerNumber: playerNumber)
                self.saveTwos(round: round, playerNumber: playerNumber)
            }
        }
    }
    
    private func loadOnlineRecovery() {
        // Load online details
        var online: String!
        self.onlineRecovery = false
        online = UserDefaults.standard.string(forKey: "recoveryOnline")
        if online != nil && online != "" {
            self.onlineRecovery = true
            let components = online.split(at: "-")
            self.onlinePurpose = CommsPurpose(rawValue: components[0])
            self.onlineType = CommsConnectionType(rawValue: components[1])
            self.onlineProximity = CommsConnectionProximity(rawValue: components[2])
            self.onlineMode = CommsConnectionMode(rawValue: components[3])
            if self.onlinePurpose == .playing {
                if self.onlineType == .server {
                    if self.onlineMode == .invite {
                        self.connectionUUID = UserDefaults.standard.string(forKey: "recoveryConnectionUUID")
                    }
                }
                self.connectionRemoteDeviceName = UserDefaults.standard.string(forKey: "recoveryConnectionRemoteDevice")
                self.connectionEmail = UserDefaults.standard.string(forKey: "recoveryConnectionEmail")
                self.connectionRemoteEmail = UserDefaults.standard.string(forKey: "recoveryConnectionRemoteEmail")
            } else {
                self.connectionUUID = nil
                self.connectionEmail = nil
                self.connectionRemoteDeviceName = nil
            }
        } else {
            self.onlinePurpose = nil
            self.onlineType = nil
            self.onlineProximity = nil
            self.connectionUUID = nil
            self.connectionEmail = nil
            self.connectionRemoteDeviceName = nil
        }
    }
    
    
    public func loadSavedValues() {
        // Load in the saved values from UserDefaults
        
        self.reloadInProgress = true
        Scorecard.game.setGameInProgress(true, save: false)
        Scorecard.game.maxEnteredRound = 1
        
        if self.onlinePurpose == .playing && self.onlineType == .server {
            // If hosting and hand is in progress need to recover deal
            let deal:[[Int]] = UserDefaults.standard.array(forKey: "recoveryHands") as! [[Int]]
            Scorecard.game?.deal = Deal(fromNumbers: deal)
        }
        
        // Reload scores
        for round in 1...Scorecard.game.rounds {
                        
            for playerNumber in 1...Scorecard.game.currentPlayers {
                let bid = UserDefaults.standard.integer(forKey: "recoveryBid\(round)-\(playerNumber)")
                if bid >= 0 {
                    _ = Scorecard.game.scores.set(round: round, playerNumber: playerNumber, bid: bid)
                    Scorecard.game.maxEnteredRound = max(round, Scorecard.game.maxEnteredRound)
                }
                let made = UserDefaults.standard.integer(forKey: "recoveryMade\(round)-\(playerNumber)")
                if made >= 0 {
                    _ = Scorecard.game.scores.set(round: round, playerNumber: playerNumber, made: made)
                }
                let twos = UserDefaults.standard.integer(forKey: "recoveryTwos\(round)-\(playerNumber)")
                if twos >= 0 {
                    _ = Scorecard.game.scores.set(round: round, playerNumber: playerNumber, twos: twos)
                }
            }
        }
        
        // Update current round
        if Scorecard.game.roundComplete(Scorecard.game.maxEnteredRound) && Scorecard.game.maxEnteredRound < Scorecard.game.rounds {
            // Round complete - move to next
            Scorecard.game.maxEnteredRound = Scorecard.game.maxEnteredRound + 1
        }
        Scorecard.game.selectedRound = Scorecard.game.maxEnteredRound
        
        // Reload location
        Scorecard.game.location.description = UserDefaults.standard.string(forKey: "recoveryLocationText")
        let latitude = UserDefaults.standard.double(forKey: "recoveryLocationLatitude")
        let longitude = UserDefaults.standard.double(forKey: "recoveryLocationLongitude")
        if latitude != 0 || longitude != 0 {
            Scorecard.game.location.setLocation(latitude: latitude, longitude: longitude)
        }
        
        // Reload game unique key / date
        Scorecard.game.datePlayed = UserDefaults.standard.object(forKey: "recoveryDatePlayed") as? Date
        Scorecard.game.gameUUID = UserDefaults.standard.string(forKey: "recoveryGameUUID")
        
        // Reload deal history
        self.loadDealHistory()
        
        // Reload overrides
        if UserDefaults.standard.bool(forKey: "recoveryOverride") {
            Scorecard.activeSettings.cards = UserDefaults.standard.array(forKey: "recoveryOverrideCards")! as! [Int]
            Scorecard.activeSettings.bounceNumberCards = UserDefaults.standard.bool(forKey: "recoveryOverrideBounceNumberCards")
            Scorecard.activeSettings.saveHistory = UserDefaults.standard.bool(forKey: "recoveryOverrideSaveHistory")
            Scorecard.activeSettings.saveStats = UserDefaults.standard.bool(forKey: "recoveryOverrideSaveStats")
        }
        
        // Finished
        self.reloadInProgress = false
        Scorecard.shared.watchManager.updateScores()
    }
    
    public func loadDealHistory() {
        // Load deal history
        if self.onlinePurpose == .playing {
            for round in 1...Scorecard.game.selectedRound {
                if let dealNumbers = UserDefaults.standard.array(forKey: "recoveryDeal\(round)") as? [[Int]] {
                    Scorecard.game?.dealHistory[round] = Deal(fromNumbers: dealNumbers)
                }
            }
        }
    }
    
    public func loadCurrentTrick() {
        // Set up player to lead
        Scorecard.game!.handState.toLead = UserDefaults.standard.integer(forKey: "recoveryToLead")
        // Get trick cards - will never be all cards since then would have been removed from hands
        Scorecard.game!.handState.trickCards = Hand(fromNumbers: UserDefaults.standard.array(forKey: "recoveryTrick") as! [Int]).cards
        Scorecard.game!.handState.toPlay = Scorecard.game?.handState.playerNumber(Scorecard.game!.handState.trickCards.count + 1)
        // Remove cards in current trick from deal
        for (index, card) in Scorecard.game!.handState.trickCards.enumerated() {
            let playerNumber = Scorecard.game!.handState.playerNumber(index + 1)
            _ = Scorecard.game!.deal.hands[playerNumber - 1].remove(card: card)
        }
        // Get number of tricks and twos made
        Scorecard.game?.handState.made = UserDefaults.standard.array(forKey: "recoveryMade") as? [Int]
        Scorecard.game?.handState.twos = UserDefaults.standard.array(forKey: "recoveryTwos") as? [Int]
        
        // Work out trick
        var trick = 0
        for made in Scorecard.game!.handState.made {
            trick += made
        }
        Scorecard.game!.handState.trick = min(trick + 1, Scorecard.game.rounds)
    }
    
    public func loadLastTrick() {
        // Set up last player to lead
        Scorecard.game!.handState.lastToLead = UserDefaults.standard.integer(forKey: "recoveryLastToLead")
        // Get last trick cards
        if Scorecard.game!.handState.lastToLead == nil || Scorecard.game!.handState.lastToLead <= 0 {
            Scorecard.game!.handState.lastCards = []
        } else {
            Scorecard.game!.handState.lastCards = Hand(fromNumbers: UserDefaults.standard.array(forKey: "recoveryLastTrick") as! [Int]).cards
        }
    }
}
