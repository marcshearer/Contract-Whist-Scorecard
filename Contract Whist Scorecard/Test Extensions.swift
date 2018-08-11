//
//  Test Extensions.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 04/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation
import UIKit

class TestMode {
    
    class func resetApp() {
        if let testMode = ProcessInfo.processInfo.environment["TEST_MODE"] {
            if testMode.lowercased() == "true" {
                if let reset = ProcessInfo.processInfo.environment["RESET_WHIST_APP"] {
                    if reset.lowercased() == "true" {
                        // Called in reset mode (from a test script) - reset user defaults and core data
                        DataAdmin.resetUserDefaults()
                        DataAdmin.resetCoreData()
                    }
                }
            }
        }
    }
    
    class func resetSettings(_ scorecard: Scorecard) {
        if let testMode = ProcessInfo.processInfo.environment["TEST_MODE"] {
            if testMode.lowercased() == "true" {
                var testResetSettings = true
                if let resetSettings = ProcessInfo.processInfo.environment["TEST_RESET_SETTINGS"] {
                    if resetSettings.lowercased() == "false" {
                        testResetSettings = false
                    }
                }
                if testResetSettings {
                    // In test mode - reset settings
                    scorecard.testResetSettings()
                }
            }
        }
    }
}

extension ScorepadViewController {
    
    @IBAction private func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        
        let adminMode = (Scorecard.adminMode || self.scorecard.iCloudUserIsMe)
        AdminMenu.rotationGesture(recognizer: recognizer, scorecard: self.scorecard, options:
              [("Auto-play",        self.startAutoPlay,   adminMode && self.scorecard.isHosting),
               ("Fill scorecard",   self.fillScorecard,   adminMode && !self.scorecard.hasJoined)])
    }
    
    public func startAutoPlay() {
        // Automatically play the game
        self.scorecard.getAutoPlayCount(completion: {
            self.autoDeal()
        })
    }
    
    public func fillScorecard() {
        // Debug routine to fill the scorecard randomly
        var totalBid = 0
        var totalMade = 0
        var cards = 0
        var bid = 0
        var made = 0
        var twos = 0
        var cardsLeft = 0
        var playersLeft = 0
        var twosLeft = 0
        
        for round in 1...self.rounds {
            cards = self.scorecard.roundCards(round, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            
            totalBid = 0
            for playerNumber in 1...scorecard.currentPlayers {
                // Random bid
                cardsLeft = cards-totalBid
                playersLeft = scorecard.currentPlayers - playerNumber + 1
                bid = min(cards,Utility.random(Int(max(1,(cardsLeft*3)/(playersLeft))))-1)
                totalBid += bid
                if playerNumber == scorecard.currentPlayers && totalBid == cards {
                    bid = (bid == 0 ? 1 : bid-1)
                }
                scorecard.entryPlayer(playerNumber).setBid(round, bid)
            }
            
            if round != self.rounds {
                totalMade = 0
                for playerNumber in 1...scorecard.currentPlayers {
                    // Random made
                    cardsLeft = cards - totalMade
                    if playerNumber != scorecard.currentPlayers {
                        made = max(0, min(cardsLeft,scorecard.entryPlayer(playerNumber).bid(round)!+Utility.random(3)-2))
                    } else {
                        made = cardsLeft
                    }
                    totalMade+=made
                    scorecard.entryPlayer(playerNumber).setMade(round, made)
                }
                
                twosLeft = 1
                for playerNumber in 1...scorecard.currentPlayers {
                    // Random twos
                    if twosLeft != 0 && Utility.random(8) == 1 {
                        twos = 1
                    } else {
                        twos = 0
                    }
                    twosLeft -= twos
                    scorecard.entryPlayer(playerNumber).setTwos(round, twos, bonus2: self.bonus2)
                }
            } else {
                for playerNumber in 1...scorecard.currentPlayers {
                    scorecard.entryPlayer(playerNumber).setMade(round, nil)
                    scorecard.entryPlayer(playerNumber).setTwos(round, nil, bonus2: self.bonus2)
                }
            }
        }
        scorecard.maxEnteredRound = self.rounds
    }
    
    func autoDeal() {
        if self.scorecard.autoPlayHands != 0 && self.scorecard.isHosting {
            Utility.executeAfter(delay: 10 * Config.autoPlayTimeUnit, completion: {
                self.scorePressed(self)
            })
        }
    }
    
}

extension HandViewController {
    
    @IBAction private func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        
        let adminMode = (Scorecard.adminMode || self.scorecard.iCloudUserIsMe)
        AdminMenu.rotationGesture(recognizer: recognizer, scorecard: self.scorecard, options:
            [("Auto-play",          self.startAutoPlay,   adminMode && self.scorecard.isHosting),
             ("Show debug info",    self.showDebugInfo,   true)])
    }
    
    private func showDebugInfo() {
        let message = "Selected round: \(self.scorecard.selectedRound)\nRound: \(self.state.round)\nCards: \(self.state.hand.toString())\nDealer: \(self.scorecard.dealerIs)\nTrick: \(self.state.trick!)\nCards played: \(self.state.trickCards.count)\nTo lead: \(self.state.toLead!)\nTo play: \(self.state.toPlay!)"
        self.alertMessage(message, title: "Hand Information", buttonText: "Continue")
    }
    
    public func startAutoPlay() {
        // Automatically play the game
        self.scorecard.getAutoPlayCount(completion: {
            if self.bidMode {
                self.autoBid()
            } else {
                self.autoPlay()
            }
        })
    }
}

extension BroadcastViewController {
    
    @IBAction private func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        
        AdminMenu.rotationGesture(recognizer: recognizer, scorecard: self.scorecard)
    }
    
    func checkTestMessages(descriptor: String, data: [String : Any?]?, peer: CommsPeer) {
        switch descriptor {
        case "autoPlay":
            let dictionary = data as! [String : Int]
            if let autoPlayHands = dictionary["hands"] {
                self.scorecard.autoPlayHands = autoPlayHands
                if let autoPlayRounds = dictionary["rounds"] {
                    self.scorecard.autoPlayRounds = autoPlayRounds
                }
            }
        default:
            break
        }
    }
}

extension HostViewController {
    
    @IBAction private func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        
        AdminMenu.rotationGesture(recognizer: recognizer, scorecard: self.scorecard)
    }
}

extension HandViewController {
    
    func autoBid() {
        if self.scorecard.autoPlayHands > 0 && (self.scorecard.autoPlayHands > 1 || round <= self.scorecard.autoPlayRounds) {
            var bids: [Int] = []
            for playerNumber in 1...self.scorecard.currentPlayers {
                let bid = scorecard.entryPlayer(playerNumber).bid(round)
                if bid != nil {
                    bids.append(bid!)
                }
            }
            if self.entryPlayerNumber(self.enteredPlayerNumber) == bids.count + 1 {
                let cards = self.scorecard.roundCards(round, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)
                var range = ((Double(cards) / Double(self.scorecard.currentPlayers)) * 2) + 1
                range.round()
                var bid = Utility.random(max(2,Int(range))) - 1
                bid = min(bid, cards)
                if self.entryPlayerNumber(self.round) == self.scorecard.currentPlayers {
                    // Last to bid - need to avoid remaining
                    let remaining = scorecard.remaining(playerNumber: entryPlayerNumber(self.enteredPlayerNumber), round: self.round, mode: .bid, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)
                    if bid == remaining {
                        if remaining == 0 {
                            bid += 1
                        } else {
                            bid -= 1
                        }
                    }
                }
                if self.checkBidAvailable() {
                    Utility.executeAfter(delay: 1 * Config.autoPlayTimeUnit, completion: {
                        self.makeBid(bid)
                    })
                }
            }
        } else {
            self.scorecard.autoPlayHands = 0
            self.scorecard.autoPlayRounds = 0
        }
    }
    
    func autoPlay() {
        if self.scorecard.autoPlayHands > 0 && (self.scorecard.autoPlayHands > 1 || round <= self.scorecard.autoPlayRounds) {
            if self.state.toPlay == self.state.enteredPlayerNumber {
                for suitNumber in 1...self.state.handSuits.count {
                    if suitEnabled[suitNumber-1] {
                        if let card = self.state.handSuits[suitNumber-1].cards.last {
                            if self.checkCardAvailable(suitNumber, self.state.handSuits[suitNumber-1].cards.count) {
                                Utility.executeAfter(delay: 1 * Config.autoPlayTimeUnit, completion: {
                                    self.scorecard.sendCardPlayed(round: self.round, trick: self.state.trick, playerNumber: self.enteredPlayerNumber, card: card)
                                    self.playCard(card: card)
                                })
                            }
                            return
                        }
                    }
                }
            }
        } else {
            self.scorecard.autoPlayHands = 0
            self.scorecard.autoPlayRounds = 0
        }
    }
    
    func checkBidAvailable() -> Bool {
        if self.scorecard.commsHandlerMode != .none {
            self.handTestData.waitAutoBid=true
            self.setHandlerCompleteNotification()
        }
        return !self.handTestData.waitAutoBid
    }
    
    func checkCardAvailable(_ suitNumber: Int, _ cardNumber: Int) -> Bool {
        // Loop around waiting for card to be available since collection view might be reloading
        if self.suitCollectionView[suitNumber-1] == nil || suitCollectionView[suitNumber-1]!.numberOfItems(inSection: 0) < cardNumber {
            self.handTestData.waitAutoPlay = true
        }
        return !self.handTestData.waitAutoPlay
    }
    
    func checkTestWait() {
        if self.handTestData.waitAutoBid {
            self.handTestData.waitAutoBid = false
            self.autoBid()
        }
        if self.handTestData.waitAutoPlay {
            self.handTestData.waitAutoPlay = false
            self.autoPlay()
        }
    }
    
    func setHandlerCompleteNotification() {
        // Set a notification for handler complete
        self.handTestData.observer = NotificationCenter.default.addObserver(forName: .broadcastHandlerCompleted, object: nil, queue: nil) {
            (notification) in
            NotificationCenter.default.removeObserver(self.handTestData.observer)
            self.checkTestWait()
        }
    }
}

extension GameSummaryViewController {
    
    internal func autoNewGame() {
        
        if self.scorecard.isHosting {
            self.scorecard.autoPlayHands = max(0, self.scorecard.autoPlayHands - 1)
            self.scorecard.sendAutoPlay()
            if self.scorecard.autoPlayHands != 0 {
                // Play another one
                Utility.executeAfter(delay: 20 * Config.autoPlayTimeUnit, completion: {
                    self.finishGame(from: self, toSegue: "newGame", advanceDealer: true, resetOverrides: false, confirm: false)
                })
            }
        }
    }
    
}

extension Scorecard {
    
    public func getAutoPlayCount(completion: (()->())? = nil) {
        let confirmHands = ConfirmCount()
        let backColor = UIColor(red: CGFloat(0.0), green: CGFloat(0.5), blue: CGFloat(0.5), alpha: CGFloat(0.8))
        confirmHands.show(title: "Auto-play", message: "Enter the number of games you want to simulate", minimumValue: 1, backColor: backColor, handler: { (value) in
            self.autoPlayHands = value
            let confirmRounds = ConfirmCount()
            confirmRounds.show(title: "Auto-play", message: "Enter the number of hands you want to simulate in the final round", defaultValue: self.rounds, minimumValue: 1, maximumValue: self.rounds, backColor: backColor, handler: { (value) in
                self.autoPlayRounds = value
                    self.sendAutoPlay()
                    completion?()
            })
        })
    }
    
    public func sendAutoPlay() {
        // Tell other players to enter Autoplay mode (for testing)
        self.commsDelegate?.send("autoPlay", ["hands"  : self.autoPlayHands,
                                              "rounds" : self.autoPlayRounds])
    }
    
    func testResetSettings() {
        // Reset all settings to default values - called on entry to app in test mode
        self.settingBonus2 = true
        self.settingCards = [13, 1]
        self.settingBounceNumberCards = false
        self.settingTrumpSequence = ["♣︎", "♦︎", "♥︎", "♠︎", "NT"]
        self.settingSyncEnabled = true
        self.settingSaveHistory = true
        self.settingSaveLocation = true
        self.settingReceiveNotifications = false
        self.settingAllowBroadcast = true
        self.settingAlertVibrate = true
        self.settingNearbyPlaying = true
        self.settingOnlinePlayerEmail = "mshearer@waitrose.com"
    }
}

class HandTestData {
    // Class containing additional properties that then HandViewController might be waiting for in test mode
    
    var waitAutoBid = false
    var waitAutoPlay = false
    var observer: NSObjectProtocol!
    
}
