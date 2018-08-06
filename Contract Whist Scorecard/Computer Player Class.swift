//
//  Computer Player Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 31/07/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import Foundation

protocol ComputerPlayerDelegate : class {
    
    func autoBid(completion: (()->())?)
    
    func autoPlay(completion: (()->())?)
    
    func newHand(hand: Hand)
}

extension ComputerPlayerDelegate {
    
    func autoBid() {
        self.autoBid(completion: nil)
    }
    
    func autoPlay() {
        self.autoPlay(completion: nil)
    }
    
}

class ComputerPlayer: NSObject, ComputerPlayerDelegate {
    
    private var scorecard: Scorecard
    private var thisPlayer: String
    private var thisPlayerName: String
    private var thisPlayerNumber: Int!
    private var loopbackClient: LoopbackService
    private var commsDelegate: CommsHandlerDelegate!
    private var hostPeer: CommsPeer
    private var hand: Hand!
    private let autoPlayTimeUnit = 0.05 // TODO Should be 1.0
    
   init(scorecard: Scorecard, email: String, name: String, deviceName: String, hostPeer: CommsPeer, playerNumber: Int) {
        
        Config.autoPlayTimeUnit = 0.05 // TODO Remove this
        
        // Store properties
        self.scorecard = scorecard
        self.thisPlayer = email
        self.thisPlayerName = name
        self.thisPlayerNumber = playerNumber
        self.hostPeer = hostPeer
        
        // Create loopback client service
        self.loopbackClient = LoopbackService(purpose: .playing, type: .client, serviceID: nil, deviceName: deviceName)
        
        // Initialise super-class
        super.init()
        
        // Start the service
        self.commsDelegate = self.loopbackClient
        self.commsDelegate.start(email: email, name: name)
        
        // Connect back to the host
        _ = self.commsDelegate.connect(to: hostPeer, playerEmail: email, playerName: name, reconnect: false)
    }
    
    internal func autoBid(completion: (()->())?) {
        let round = self.scorecard.handState.round
        var bids: [Int] = []
        var runCompletionOnExit = true
        
        for playerNumber in 1...self.scorecard.currentPlayers {
            let bid = scorecard.entryPlayer(playerNumber).bid(round)
            if bid != nil {
                bids.append(bid!)
            }
        }
        
        if self.scorecard.entryPlayerNumber(self.thisPlayerNumber, round: round) == bids.count + 1 {
            
            runCompletionOnExit = false
            
            Utility.executeAfter("autoBid", delay: self.autoPlayTimeUnit, completion: {
                
                let cards = self.scorecard.roundCards(round, rounds: self.scorecard.handState.rounds, cards: self.scorecard.handState.cards, bounce: self.scorecard.handState.bounce)
                var range = ((Double(cards) / Double(self.scorecard.currentPlayers)) * 2) + 1
                range.round()
                var bid = Utility.random(max(2,Int(range))) - 1
                bid = min(bid, cards)
                if self.scorecard.entryPlayerNumber(self.thisPlayerNumber, round: round) == self.scorecard.currentPlayers {
                    // Last to bid - need to avoid remaining
                    let remaining = self.scorecard.remaining(playerNumber: self.scorecard.entryPlayerNumber(self.thisPlayerNumber, round: round), round: round, mode: .bid, rounds: self.scorecard.handState.rounds, cards: self.scorecard.handState.cards, bounce: self.scorecard.handState.bounce)
                    if bid == remaining {
                        if remaining == 0 {
                            bid += 1
                        } else {
                            bid -= 1
                        }
                    }
                }
                self.scorecard.sendScores(playerNumber: self.thisPlayerNumber, round: round, mode: .bid, overrideBid: bid, to: self.hostPeer, using: self.loopbackClient)
                if bids.count == self.scorecard.currentPlayers {
                    self.autoPlay(completion: completion)
                } else {
                    completion?()
                }
            })
        }
        if runCompletionOnExit {
            if bids.count == self.scorecard.currentPlayers {
                self.autoPlay(completion: completion)
            } else {
                completion?()
            }
        }
    }
    
    internal func autoPlay(completion: (()->())?) {
        var runCompletionOnExit = true
        let round = self.scorecard.handState.round
        let roundCards = self.scorecard.roundCards(round)
        let trick = self.scorecard.handState.trick!
        let trickCards = self.scorecard.handState.trickCards
        let cardsPlayed = trickCards!.count
        
        if trick <= roundCards {
            if self.scorecard.handState.toPlay == self.thisPlayerNumber {
                // Me to play
                
                if self.hand.cards.count >= (roundCards - trick + 1) {
                    // Have enough cards to play 1 to this trick (or I am leading having just won but trick may not be up to date
                
                    runCompletionOnExit = false
                    
                    Utility.executeAfter("autoPlay", delay: self.autoPlayTimeUnit, completion: {
                        
                        // Now work out card to play
                        var cardPlayed: Card!
                        
                        // Try to find a card in the suit led if possible - else anything
                        var trySuitLed = ((cardsPlayed) != 0)
                        var loop = 0
                        while loop < 2 && cardPlayed == nil {
                            loop += 1
                            for handSuit in self.hand.handSuits {
                                if handSuit.cards.count > 0 && (cardsPlayed == 0 || handSuit.cards!.last!.suit == trickCards!.first!.suit || !trySuitLed) {
                                    // Choose a random card from this suit
                                    let cardNumber = Utility.random(handSuit.cards.count) - 1
                                    cardPlayed = handSuit.cards[cardNumber]
                                    handSuit.cards.remove(at: cardNumber)
                                    break
                                }
                            }
                            trySuitLed = false
                        }
                        
                        self.scorecard.sendCardPlayed(round: round, trick: trick, playerNumber: self.thisPlayerNumber, card: cardPlayed, using: self.loopbackClient)
                        
                        completion?()
                    })
                }
            }
        }
        if runCompletionOnExit {
            completion?()
        }
    }
    internal func newHand(hand: Hand) {
        self.hand = hand
    }
}

