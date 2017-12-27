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
    
    var scorecard: Scorecard!
    var recoveryInProgress = false
    
    func initialise(scorecard: Scorecard) {
        self.scorecard = scorecard
    }
    
    func saveGameInProgress() {
        var online = ""
        UserDefaults.standard.set(scorecard.gameInProgress, forKey: "recoveryGameInProgress")
        if scorecard.gameInProgress {
            if let delegate = self.scorecard.commsDelegate {
                if delegate.connectionPurpose == .playing {
                    let purpose = delegate.connectionPurpose.rawValue
                    let type = delegate.connectionType.rawValue
                    let mode = delegate.connectionMode.rawValue
                    online = purpose +  "-" + type + "-" + mode
                    if delegate.connectionPurpose == .playing && delegate.connectionMode == .invite {
                        if delegate.connectionType == .server  {
                            UserDefaults.standard.set(delegate.connectionUUID, forKey: "recoveryConnectionUUID")
                        } else {
                            UserDefaults.standard.set(delegate.connectionEmail, forKey: "recoveryConnectionEmail")
                            UserDefaults.standard.set(delegate.connectionDevice, forKey: "recoveryConnectionDevice")
                        }
                    }
                }
            }
        }
        UserDefaults.standard.set(online, forKey: "recoveryOnline")
    }
    
    func saveRoundError(round: Int) {
        UserDefaults.standard.set(scorecard.roundError(round), forKey: "recoveryRoundError\(round)")
    }
    
    func saveBid(round: Int, playerNumber: Int) {
        let key = "recoveryBid\(round)-\(playerNumber)"
        var bid: Int? = scorecard.enteredPlayer(playerNumber).bid(round)
        if bid == nil {
            bid = -1
        }
        UserDefaults.standard.set(bid, forKey: key)
    }
    
    func saveMade(round: Int, playerNumber: Int) {
        let key = "recoveryMade\(round)-\(playerNumber)"
        var made: Int? = scorecard.enteredPlayer(playerNumber).made(round)
        if made == nil {
            made = -1
        }
        UserDefaults.standard.set(made, forKey: key)
    }
    
    func saveTwos(round: Int, playerNumber: Int) {
        let key = "recoveryTwos\(round)-\(playerNumber)"
        var twos: Int? = scorecard.enteredPlayer(playerNumber).twos(round)
        if twos == nil{
            twos = -1
        }
        UserDefaults.standard.set(twos, forKey: key)
    }
    
    func saveHands(deal: Deal, made: [Int], twos: [Int]) {
        UserDefaults.standard.set(deal.toNumbers(), forKey: "recoveryHands")
        UserDefaults.standard.set(made, forKey: "recoveryMade")
        UserDefaults.standard.set(twos, forKey: "recoveryTwos")
    }
    
    func saveTrick(toLead: Int, trickCards: [Card]) {
        UserDefaults.standard.set(toLead, forKey: "recoveryToLead")
        var trickNumbers: [Int] = []
        for card in trickCards {
            trickNumbers.append(card.toNumber())
        }
        UserDefaults.standard.set(trickNumbers, forKey: "recoveryTrick")
    }
    
    func saveLocationAndDate() {
        UserDefaults.standard.set(scorecard.gameLocation.description, forKey: "recoveryLocationText")
        if scorecard.gameLocation.location != nil {
            UserDefaults.standard.set(scorecard.gameLocation.location.coordinate.latitude, forKey: "recoveryLocationLatitude")
            UserDefaults.standard.set(scorecard.gameLocation.location.coordinate.longitude, forKey: "recoveryLocationLongitude")
        }
        UserDefaults.standard.set(scorecard.gameDatePlayed, forKey: "recoveryDatePlayed")
        UserDefaults.standard.set(scorecard.gameUUID, forKey: "recoveryGameUUID")
    }
    
    func saveInitialValues() {
        // Called at the start of a game to clear out any old values
        
        for round in 1...scorecard.rounds {
            
            self.saveRoundError(round: round)
            
            for playerNumber in 1...scorecard.numberPlayers {
                
                self.saveBid(round: round, playerNumber: playerNumber)
                self.saveMade(round: round, playerNumber: playerNumber)
                self.saveTwos(round: round, playerNumber: playerNumber)
            }
        }
    }
    
    func checkRecovery() -> Bool {
        let gameInProgress = UserDefaults.standard.bool(forKey: "recoveryGameInProgress")
        return gameInProgress
    }
    
    func checkOnlineRecovery() -> (Bool, Bool) {
        var online = ""
        let gameInProgress = checkRecovery()
        if gameInProgress {
            online = UserDefaults.standard.string(forKey: "recoveryOnline") ?? ""
        }
        return (gameInProgress, online != "")
    }
    
    
    func loadSavedValues() {
        // Load in the saved values from UserDefaults
        
        self.recoveryInProgress = true
        scorecard.setGameInProgress(true, save: false)
        scorecard.maxEnteredRound = 1
        
        for round in 1...scorecard.rounds {
            
            scorecard.setRoundError(round, UserDefaults.standard.bool(forKey: "recoveryRoundError\(round)"))
            
            for playerNumber in 1...scorecard.currentPlayers {
                let bid = UserDefaults.standard.integer(forKey: "recoveryBid\(round)-\(playerNumber)")
                if bid >= 0 {
                    scorecard.enteredPlayer(playerNumber).setBid(round, bid)
                    scorecard.maxEnteredRound = max(round, scorecard.maxEnteredRound)
                }
                let made = UserDefaults.standard.integer(forKey: "recoveryMade\(round)-\(playerNumber)")
                if made >= 0 {
                    scorecard.enteredPlayer(playerNumber).setMade(round, made)
                }
                let twos = UserDefaults.standard.integer(forKey: "recoveryTwos\(round)-\(playerNumber)")
                if twos >= 0 {
                    scorecard.enteredPlayer(playerNumber).setTwos(round, twos)
                }
            }
        }
        
        if scorecard.roundPlayer(playerNumber: scorecard.currentPlayers, round: scorecard.maxEnteredRound).made(scorecard.maxEnteredRound) != nil && scorecard.maxEnteredRound <= scorecard.rounds {
            // Round complete - move to next
            scorecard.maxEnteredRound = scorecard.maxEnteredRound + 1
        }
        scorecard.selectedRound = scorecard.maxEnteredRound
        
        scorecard.gameLocation.description = UserDefaults.standard.string(forKey: "recoveryLocationText")
        let latitude = UserDefaults.standard.double(forKey: "recoveryLocationLatitude")
        let longitude = UserDefaults.standard.double(forKey: "recoveryLocationLongitude")
        if latitude != 0 || longitude != 0 {
            scorecard.gameLocation.location = CLLocation(latitude: latitude, longitude: longitude)
        }
        
        scorecard.gameDatePlayed = UserDefaults.standard.object(forKey: "recoveryDatePlayed") as? Date
        scorecard.gameUUID = UserDefaults.standard.string(forKey: "recoveryGameUUID")
        
        // Load online details
        var online: String!
        online = UserDefaults.standard.string(forKey: "recoveryOnline")
        if online != nil && online != "" {
            let components = online.split(at: "-")
            scorecard.recoveryOnlinePurpose = CommsConnectionPurpose(rawValue: components[0])
            scorecard.recoveryOnlineType = CommsConnectionType(rawValue: components[1])
            scorecard.recoveryOnlineMode = CommsConnectionMode(rawValue: components[2])
            if scorecard.recoveryOnlinePurpose == .playing && scorecard.recoveryOnlineMode == .invite {
                if scorecard.recoveryOnlineType == .server {
                    scorecard.recoveryConnectionUUID = UserDefaults.standard.string(forKey: "recoveryConnectionUUID")
                } else {
                    scorecard.recoveryConnectionEmail = UserDefaults.standard.string(forKey: "recoveryConnectionEmail")
                    scorecard.recoveryConnectionDevice = UserDefaults.standard.string(forKey: "recoveryConnectionDevice")
                }
            } else {
                scorecard.recoveryConnectionUUID = nil
                scorecard.recoveryConnectionEmail = nil
                scorecard.recoveryConnectionDevice = nil
            }
            if scorecard.recoveryOnlinePurpose == .playing && scorecard.recoveryOnlineType == .server {
                // If hosting and hand is in progress need to recover deal
                let deal:[[Int]] = UserDefaults.standard.array(forKey: "recoveryHands") as! [[Int]]
                self.scorecard.deal = Deal(fromNumbers: deal)
            }
        } else {
            scorecard.recoveryOnlinePurpose = nil
            scorecard.recoveryOnlineType = nil
            scorecard.recoveryOnlineMode = nil
            scorecard.recoveryConnectionUUID = nil
            scorecard.recoveryConnectionEmail = nil
            scorecard.recoveryConnectionDevice = nil
        }
        self.recoveryInProgress = false
        self.scorecard.watchManager.updateScores()
    }
    
    public func loadCurrentTrick() {
        // Set up player to lead
        scorecard.handState.toLead = UserDefaults.standard.integer(forKey: "recoveryToLead")
        // Get trick cards - will never be all cards since then would have been removed from hands
        let trickCardNumbers: [Int] = UserDefaults.standard.array(forKey: "recoveryTrick") as! [Int]
        scorecard.handState.trickCards = trickCardNumbers.map({Card(fromNumber: $0)})
        scorecard.handState.toPlay = scorecard.handState.playerNumber(trickCardNumbers.count + 1)
        // Remove cards in current trick from deal
        for (index, card) in self.scorecard.handState.trickCards.enumerated() {
            let playerNumber = self.scorecard.handState.playerNumber(index + 1)
            _ = self.scorecard.deal.hands[playerNumber - 1].removeCard(card)
        }
        // Get number of tricks and twos made
        scorecard.handState.made = UserDefaults.standard.array(forKey: "recoveryMade") as! [Int]
        scorecard.handState.twos = UserDefaults.standard.array(forKey: "recoveryTwos") as! [Int]
        
        // Work out trick
        var trick = 0
        for made in scorecard.handState.made {
            trick += made
        }
        scorecard.handState.trick = min(trick + 1, self.scorecard.rounds)
    }
}
