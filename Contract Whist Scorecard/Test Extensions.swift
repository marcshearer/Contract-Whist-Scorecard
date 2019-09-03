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
    
    class func resetSettings() {
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
                    Scorecard.shared.testResetSettings()
                }
            }
        }
    }
}

extension ScorepadViewController {
    
    internal func testRotationOptions() -> [(String, ()->(), Bool)]? {
        
        if (Scorecard.adminMode || Scorecard.shared.iCloudUserIsMe) && Utility.isDevelopment {
            return [("Auto-play",        self.startAutoPlay,   Scorecard.shared.isHosting),
                    ("Fill scorecard",   self.fillScorecard,   !Scorecard.shared.hasJoined && !Scorecard.shared.isHosting)]
        } else {
            return nil
        }
    }
    
    public func startAutoPlay() {
        // Automatically play the game
        Scorecard.shared.getAutoPlayCount(completion: {
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
            cards = Scorecard.shared.roundCards(round, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            
            totalBid = 0
            for playerNumber in 1...Scorecard.shared.currentPlayers {
                // Random bid
                cardsLeft = cards-totalBid
                playersLeft = Scorecard.shared.currentPlayers - playerNumber + 1
                bid = min(cards,Utility.random(Int(max(1,(cardsLeft*3)/(playersLeft))))-1)
                totalBid += bid
                if playerNumber == Scorecard.shared.currentPlayers && totalBid == cards {
                    bid = (bid == 0 ? 1 : bid-1)
                }
                _ = Scorecard.shared.entryPlayer(playerNumber).setBid(round, bid)
            }
            
            if round != self.rounds {
                totalMade = 0
                for playerNumber in 1...Scorecard.shared.currentPlayers {
                    // Random made
                    cardsLeft = cards - totalMade
                    if playerNumber != Scorecard.shared.currentPlayers {
                        made = max(0, min(cardsLeft,Scorecard.shared.entryPlayer(playerNumber).bid(round)!+Utility.random(3)-2))
                    } else {
                        made = cardsLeft
                    }
                    totalMade+=made
                    Scorecard.shared.entryPlayer(playerNumber).setMade(round, made)
                }
                
                twosLeft = 1
                for playerNumber in 1...Scorecard.shared.currentPlayers {
                    // Random twos
                    if twosLeft != 0 && Utility.random(8) == 1 {
                        twos = 1
                    } else {
                        twos = 0
                    }
                    twosLeft -= twos
                    Scorecard.shared.entryPlayer(playerNumber).setTwos(round, twos, bonus2: self.bonus2)
                }
            } else {
                for playerNumber in 1...Scorecard.shared.currentPlayers {
                    Scorecard.shared.entryPlayer(playerNumber).setMade(round, nil)
                    Scorecard.shared.entryPlayer(playerNumber).setTwos(round, nil, bonus2: self.bonus2)
                }
            }
        }
        Scorecard.shared.maxEnteredRound = self.rounds
    }
    
    func autoDeal() {
        if Scorecard.shared.autoPlayHands != 0 && Scorecard.shared.isHosting {
            // Automatically start the hand
            Utility.executeAfter(delay: 10 * Config.autoPlayTimeUnit, completion: {
                self.scorePressed(self)
            })
        }
    }
}

extension HandViewController {
    
    internal func testRotationOptions() -> [(String, ()->(), Bool)]? {
        
        if (Scorecard.adminMode || Scorecard.shared.iCloudUserIsMe) && Utility.isDevelopment {
            return [("Auto-play",          self.startAutoPlay,   Scorecard.shared.isHosting)]
        } else {
            return nil
        }
    }
    
    public func startAutoPlay() {
        // Automatically play the game
        Scorecard.shared.getAutoPlayCount(completion: {
            if self.bidMode {
                self.autoBid()
            } else {
                self.autoPlay()
            }
        })
    }
    
    func autoBid() {
        if Scorecard.shared.autoPlayHands > 0 && (Scorecard.shared.autoPlayHands > 1 || round <= Scorecard.shared.autoPlayGames) {
            var bids: [Int] = []
            for playerNumber in 1...Scorecard.shared.currentPlayers {
                let bid = Scorecard.shared.entryPlayer(playerNumber).bid(round)
                if bid != nil {
                    bids.append(bid!)
                }
            }
            if Scorecard.shared.entryPlayerNumber(self.enteredPlayerNumber, round: self.round) == bids.count + 1 {
                let cards = Scorecard.shared.roundCards(round, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)
                var range = ((Double(cards) / Double(Scorecard.shared.currentPlayers)) * 2) + 1
                range.round()
                var bid = Utility.random(max(2,Int(range))) - 1
                bid = min(bid, cards)
                if Scorecard.shared.entryPlayerNumber(self.enteredPlayerNumber, round: self.round) == Scorecard.shared.currentPlayers {
                    // Last to bid - need to avoid remaining
                    let remaining = Scorecard.shared.remaining(playerNumber: Scorecard.shared.entryPlayerNumber(self.enteredPlayerNumber, round: self.round), round: self.round, mode: .bid, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)
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
            Scorecard.shared.autoPlayHands = 0
            Scorecard.shared.autoPlayGames = 0
        }
    }
    
    func autoPlay() {
        if Scorecard.shared.autoPlayHands > 0 && (Scorecard.shared.autoPlayHands > 1 || self.round <= Scorecard.shared.autoPlayGames) {
            if self.state.toPlay == self.state.enteredPlayerNumber {
                for suitNumber in 1...self.state.hand.handSuits.count {
                    if self.suitEnabled[suitNumber-1] {
                        if let card = self.state.hand.handSuits[suitNumber-1].cards.last {
                            if self.checkCardAvailable(suitNumber, self.state.hand.handSuits[suitNumber-1].cards.count) {
                                Utility.executeAfter(delay: 1 * Config.autoPlayTimeUnit, completion: {
                                    self.playCard(card: card)
                                })
                            }
                            return
                        }
                    }
                }
            }
        } else {
            Scorecard.shared.autoPlayHands = 0
            Scorecard.shared.autoPlayGames = 0
        }
    }
    
    func checkBidAvailable() -> Bool {
        if Scorecard.shared.commsHandlerMode != .none {
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
        self.handTestData.observer = NotificationCenter.default.addObserver(forName: .clientHandlerCompleted, object: nil, queue: nil) {
            (notification) in
            NotificationCenter.default.removeObserver(self.handTestData.observer!)
            self.checkTestWait()
        }
    }
}

extension ClientViewController {
    
    func checkTestMessages(descriptor: String, data: [String : Any?]?, peer: CommsPeer) -> Bool {
        var handled = false
        
        switch descriptor {
        case "autoPlay":
            let dictionary = data as! [String : Int]
            let hands = Scorecard.shared.autoPlayHands
            let games = Scorecard.shared.autoPlayGames
            if let autoPlayHands = dictionary["hands"] {
                Scorecard.shared.autoPlayHands = autoPlayHands
                if let autoPlayRounds = dictionary["games"] {
                    Scorecard.shared.autoPlayGames = autoPlayRounds
                }
            }
            if hands != Scorecard.shared.autoPlayHands || games != Scorecard.shared.autoPlayGames {
                // Changed - need to play if can
                if let handViewController = self.scorecard.handViewController {
                    if handViewController.state?.toPlay == handViewController.enteredPlayerNumber {
                        // Me to play
                        handViewController.autoPlay()
                    }
                }
            }
            handled = true
        default:
            break
        }
        return handled
    }
}

extension SelectionViewController {
    
    internal func setTestMode() {
        if let testModeValue = ProcessInfo.processInfo.environment["TEST_MODE"] {
            if testModeValue.lowercased() == "true" {
                self.testMode = true
            }
        }
    }
}

extension GameSummaryViewController {
    
    internal func autoNewGame() {
        
        if Scorecard.shared.isHosting {
            Scorecard.shared.autoPlayHands = max(0, Scorecard.shared.autoPlayHands - 1)
            Scorecard.shared.sendAutoPlay()
            if Scorecard.shared.autoPlayHands != 0 {
                // Play another one
                Utility.executeAfter(delay: 20 * Config.autoPlayTimeUnit, completion: {
                    self.finishGame(from: self, returnMode: .newGame, advanceDealer: true, resetOverrides: false, confirm: false)
                })
            }
        }
    }
    
}

extension Scorecard {
    
    public func getAutoPlayCount(completion: (()->())? = nil) {
        ConfirmCountViewController.show(title: "Auto-play", message: "Enter the number of games you want to simulate", minimumValue: 1, handler: { (value) in
            self.autoPlayHands = value
            ConfirmCountViewController.show(title: "Auto-play", message: "Enter the number of hands you want to complete in the \(self.autoPlayHands > 1 ? "final " : "")game", defaultValue: self.rounds, minimumValue: 1, maximumValue: self.rounds, handler: { (value) in
                self.autoPlayGames = value
                    self.sendAutoPlay()
                    completion?()
            })
        })
    }
    
    public func sendAutoPlay(to peer: CommsPeer? = nil) {
        // Tell other players to enter Autoplay mode (for testing)
        self.commsDelegate?.send("autoPlay", ["hands"  : self.autoPlayHands,
                                              "games" : self.autoPlayGames],
                                 to: peer)
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
