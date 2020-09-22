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
            return [("Fill scorecard",   self.fillScorecard,   !Scorecard.game.hasJoined && !Scorecard.game.isHosting)]
        } else {
            return nil
        }
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
        
        for round in 1...Scorecard.game.rounds {
            cards = Scorecard.game.roundCards(round)
            
            totalBid = 0
            for playerNumber in 1...Scorecard.game.currentPlayers {
                // Random bid
                cardsLeft = cards-totalBid
                playersLeft = Scorecard.game.currentPlayers - playerNumber + 1
                bid = min(cards,Utility.random(Int(max(1,(cardsLeft*3)/(playersLeft))))-1)
                totalBid += bid
                if playerNumber == Scorecard.game.currentPlayers && totalBid == cards {
                    bid = (bid == 0 ? 1 : bid-1)
                }
                _ = Scorecard.game.scores.set(round: round, playerNumber: playerNumber, bid: bid, sequence: .entry)
                let enteredPlayerNumber = Scorecard.game.enteredPlayerNumber(entryPlayerNumber: playerNumber)
                Scorecard.shared.sendBid(playerNumber: enteredPlayerNumber, round: round)
            }
            
            if round != Scorecard.game.rounds {
                totalMade = 0
                for playerNumber in 1...Scorecard.game.currentPlayers {
                    // Random made
                    cardsLeft = cards - totalMade
                    if playerNumber != Scorecard.game.currentPlayers {
                        made = max(0, min(cardsLeft, (Scorecard.game?.scores.get(round: round + Utility.random(3)-2, playerNumber: playerNumber, sequence: .entry).bid) ?? 0))
                    } else {
                        made = cardsLeft
                    }
                    totalMade+=made
                    _ = Scorecard.game.scores.set(round: round, playerNumber: playerNumber, made: made, sequence: .entry)
                }
                
                twosLeft = 1
                for playerNumber in 1...Scorecard.game.currentPlayers {
                    // Random twos
                    if twosLeft != 0 && Utility.random(8) == 1 {
                        twos = 1
                    } else {
                        twos = 0
                    }
                    twosLeft -= twos
                    _ = Scorecard.game.scores.set(round: round, playerNumber: playerNumber, twos: twos, sequence: .entry)
                }
            } else {
                for playerNumber in 1...Scorecard.game.currentPlayers {
                    _ = Scorecard.game.scores.set(round: round, playerNumber: playerNumber, made: nil, sequence: .entry)
                    _ = Scorecard.game.scores.set(round: round, playerNumber: playerNumber, twos: nil, sequence: .entry)
                }
            }
        }
        Scorecard.game.maxEnteredRound = Scorecard.game.rounds
    }
}

extension HostController {
    
    func autoDeal() {
        if (Scorecard.shared.autoPlayGames > 0 && (Scorecard.shared.autoPlayGames > 1 || Scorecard.game.handState.round <= Scorecard.shared.autoPlayHands)) && Scorecard.game.isHosting {
            // Automatically start the hand
            Utility.executeAfter(delay: 10 * Config.autoPlayTimeUnit, completion: {
                self.present(nextView: .hand)
            })
        }
    }
}

extension HandViewController {
    
    internal func testRotationOptions() -> [(String, ()->(), Bool)]? {
        
        if (Scorecard.adminMode || Scorecard.shared.iCloudUserIsMe) && Utility.isDevelopment {
            return [("Auto-play", self.startAutoPlay, Scorecard.game.isHosting)]
        } else {
            return nil
        }
    }
    
    public func startAutoPlay() {
        // Automatically play the game
        Scorecard.shared.getAutoPlayCount(from: self, completion: {
            if self.bidMode {
                self.autoBid()
            } else {
                self.autoPlay()
            }
        })
    }
    
    func autoBid() {
        if Scorecard.shared.autoPlayGames > 0 && (Scorecard.shared.autoPlayGames > 1 || round <= Scorecard.shared.autoPlayHands) {
            let handsMade = Scorecard.game.scores.bidsMade(round: self.round)
            if Scorecard.game.roundPlayerNumber(enteredPlayerNumber: self.enteredPlayerNumber, round: self.round) == handsMade + 1 {
                let cards = Scorecard.game.roundCards(round)
                var range = ((Double(cards) / Double(Scorecard.game.currentPlayers)) * 2) + 1
                range.round()
                var bid = Utility.random(max(2,Int(range))) - 1
                bid = min(bid, cards)
                if Scorecard.game.roundPlayerNumber(enteredPlayerNumber: self.enteredPlayerNumber, round: self.round) == Scorecard.game.currentPlayers {
                    // Last to bid - need to avoid remaining
                    let remaining = Scorecard.game.remaining(playerNumber: Scorecard.game.roundPlayerNumber(enteredPlayerNumber: self.enteredPlayerNumber, round: self.round), round: self.round, mode: .bid)
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
            Scorecard.shared.autoPlayGames = 0
            Scorecard.shared.autoPlayHands = 0
        }
    }
    
    func autoPlay() {
        if Scorecard.shared.autoPlayGames > 0 && (Scorecard.shared.autoPlayGames > 1 || self.round <= Scorecard.shared.autoPlayHands) {
            if Scorecard.game?.handState.toPlay == Scorecard.game?.handState.enteredPlayerNumber {
                for suitNumber in 1...Scorecard.game!.handState.hand.handSuits.count {
                    if self.suitEnabled[suitNumber-1] {
                        if let card = Scorecard.game?.handState.hand.handSuits[suitNumber-1].cards.last {
                            if self.checkCardAvailable(suitNumber, Scorecard.game.handState.hand.handSuits[suitNumber-1].cards.count) {
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
            Scorecard.shared.autoPlayGames = 0
            Scorecard.shared.autoPlayHands = 0
        }
    }
    
    func checkBidAvailable() -> Bool {
        if Scorecard.shared.viewPresenting != .none && Scorecard.shared.viewPresenting != .processing {
            self.handTestData.waitAutoBid=true
            self.setcheckAutoPlayInputNotification()
        }
        return !self.handTestData.waitAutoBid
    }
    
    func checkCardAvailable(_ suitNumber: Int, _ cardNumber: Int) -> Bool {
        // Loop around waiting for card to be available since collection view might be reloading
        if self.suitCollectionView(suitNumber-1) == nil || suitCollectionView(suitNumber-1)!.numberOfItems(inSection: 0) < cardNumber {
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
    
    func setcheckAutoPlayInputNotification() {
        // Set a notification for handler complete
        self.handTestData.observer = NotificationCenter.default.addObserver(forName: .checkAutoPlayInput, object: nil, queue: nil) {
            (notification) in
            NotificationCenter.default.removeObserver(self.handTestData.observer!)
            self.checkTestWait()
        }
    }
}

extension ClientController {
    
    func checkTestMessages(descriptor: String, data: [String : Any?]?, peer: CommsPeer) -> Bool {
        var handled = false
        
        switch descriptor {
        case "autoPlay":
            let dictionary = data as! [String : Int]
            let hands = Scorecard.shared.autoPlayGames
            let games = Scorecard.shared.autoPlayHands
            if let autoPlayGames = dictionary["games"] {
                Scorecard.shared.autoPlayGames = autoPlayGames
                if let autoPlayRounds = dictionary["hands"] {
                    Scorecard.shared.autoPlayHands = autoPlayRounds
                }
            }
            if hands != Scorecard.shared.autoPlayGames || games != Scorecard.shared.autoPlayHands {
                // Changed - need to play if can
                if self.activeView == .hand {
                    if let handViewController = self.activeViewController as? HandViewController,
                        let enteredPlayerNumber = handViewController.enteredPlayerNumber,
                        let bidMode = handViewController.bidMode {
                        if bidMode {
                            let handsMade = Scorecard.game.scores.bidsMade(round: Scorecard.game.handState.round)
                            if Scorecard.game.roundPlayerNumber(enteredPlayerNumber: enteredPlayerNumber, round: Scorecard.game.handState.round) == handsMade + 1 {
                                // Me to bid
                                handViewController.autoBid()
                            }
                        } else {
                            if Scorecard.game.handState.toPlay == enteredPlayerNumber {
                                // Me to play
                                handViewController.autoPlay()
                            }
                        }
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
        
        if Scorecard.game.isHosting {
            Scorecard.shared.autoPlayGames = max(0, Scorecard.shared.autoPlayGames - 1)
            Scorecard.shared.sendAutoPlay()
            if Scorecard.shared.autoPlayGames != 0 {
                // Play another one
                Utility.executeAfter(delay: 20 * Config.autoPlayTimeUnit, completion: {
                    self.finishGame(returnMode: .newGame, advanceDealer: true, resetOverrides: false, confirm: false)
                })
            }
        }
    }
    
}

extension Scorecard {
    
    public func getAutoPlayCount(from viewController: ScorecardViewController, completion: (()->())? = nil) {
        ConfirmCountViewController.show(from: viewController, title: "Auto-play", message: "Enter the number of games you want to simulate", minimumValue: 1, handler: { (value) in
            self.autoPlayGames = value
            let round = (self.autoPlayGames == 1 ? Scorecard.game.maxEnteredRound : 1)
            let defaultValue = (self.autoPlayGames == 1 ? round : Scorecard.game.rounds)
            ConfirmCountViewController.show(from: viewController, title: "Auto-play", message: "Enter the number of hands you want to complete in the \(self.autoPlayGames > 1 ? "final " : "")game", defaultValue: defaultValue, minimumValue: round, maximumValue: Scorecard.game.rounds, handler: { (value) in
                self.autoPlayHands = value
                    self.sendAutoPlay()
                    completion?()
            })
        })
    }
    
    public func autoPlayData() -> [String : Any] {
        return ["games"  : self.autoPlayGames,
                "hands" : self.autoPlayHands]
    }
    
    public func sendAutoPlay(to peer: CommsPeer? = nil) {
        // Tell other players to enter Autoplay mode (for testing)
        self.commsDelegate?.send("autoPlay", self.autoPlayData(),
                                 to: peer)
    }
    
    func testResetSettings() {
        // Reset all settings to default values - called on entry to app in test mode
        Scorecard.settings.bonus2 = true
        Scorecard.settings.cards = [13, 1]
        Scorecard.settings.bounceNumberCards = false
        Scorecard.settings.trumpSequence = ["♣︎", "♦︎", "♥︎", "♠︎", "NT"]
        Scorecard.settings.syncEnabled = true
        Scorecard.settings.saveHistory = true
        Scorecard.settings.saveLocation = true
        Scorecard.settings.receiveNotifications = false
        Scorecard.settings.allowBroadcast = true
        Scorecard.settings.alertVibrate = true
        Scorecard.settings.thisPlayerUUID = "mshearer@waitrose.com"
        Scorecard.settings.onlineGamesEnabled = true
    }
}

class HandTestData {
    // Class containing additional properties that then HandViewController might be waiting for in test mode
    
    var waitAutoBid = false
    var waitAutoPlay = false
    var observer: NSObjectProtocol!
    
}
