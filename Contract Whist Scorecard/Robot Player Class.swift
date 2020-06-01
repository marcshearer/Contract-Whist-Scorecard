//
//  Robot Player Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 31/07/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import Foundation

protocol RobotDelegate : class {
    
    func autoBid(completion: (()->())?)
    
    func autoPlay(completion: (()->())?)
    
    func newHand(hand: Hand)
}

extension RobotDelegate {
    
    func autoBid() {
        self.autoBid(completion: nil)
    }
    
    func autoPlay() {
        self.autoPlay(completion: nil)
    }
    
}

enum RobotAction {
    case bid
    case play
    case deal
}

class RobotPlayer: NSObject, RobotDelegate {
    
    private var thisPlayer: String
    private var thisPlayerName: String
    private var thisPlayerNumber: Int!
    private var loopbackService: LoopbackService
    private var hostPeer: CommsPeer
    private var hand: Hand!
    private let autoPlayTimeUnit = 1.0
    
   init(email: String, name: String, deviceName: String, hostPeer: CommsPeer, playerNumber: Int) {
                
        // Store properties
        self.thisPlayer = email
        self.thisPlayerName = name
        self.thisPlayerNumber = playerNumber
        self.hostPeer = hostPeer
        
        // Create loopback client service
        self.loopbackService = LoopbackService(mode:.loopback, type: .client, serviceID: nil, deviceName: deviceName, purpose: .playing)
        
        // Initialise super-class
        super.init()
        
        // Start the service
        self.loopbackService.start(email: email, name: name)
        
        // Connect back to the host
        _ = self.loopbackService.connect(to: hostPeer, playerEmail: email, playerName: name, reconnect: false)
    }
    
    internal func autoBid(completion: (()->())?) {
        let round = Scorecard.game?.handState.round ?? 1
        var bids: [Int] = []
        
        for playerNumber in 1...Scorecard.game.currentPlayers {
            let bid = Scorecard.game.scores.get(round: round, playerNumber: playerNumber, sequence: .entry).bid
            if bid != nil {
                bids.append(bid!)
            }
        }
        
        if Scorecard.game.roundPlayerNumber(enteredPlayerNumber: self.thisPlayerNumber, round: round) == bids.count + 1 {
            
            Utility.executeAfter("autoBid", delay: self.autoPlayTimeUnit, completion: {
                
                let computerBidding = RobotBidding(hand: self.hand, trumpSuit: Scorecard.game.roundSuit(Scorecard.game?.handState.round ?? 1), bids: bids, numberPlayers: Scorecard.game.currentPlayers)
                
                let bid = computerBidding.bid()
                
                _ = Scorecard.game.scores.set(round: round, playerNumber: self.thisPlayerNumber, value: bid, mode: .bid)
                Scorecard.shared.sendBid(playerNumber: self.thisPlayerNumber, round: round, to: self.hostPeer, using: self.loopbackService)
                
                completion?()
            })
            
        } else {
            completion?()
        }
    }
    
    internal func autoPlay(completion: (()->())?) {
        let round = Scorecard.game!.handState.round
        let roundCards = Scorecard.game!.roundCards(round)
        let trick = Scorecard.game!.handState.trick!
        let trickCards = Scorecard.game!.handState.trickCards
        let cardsPlayed = trickCards!.count
        
        if trick <= roundCards && Scorecard.game?.handState.toPlay == self.thisPlayerNumber && self.hand.cards.count >= (roundCards - trick + 1) {
                    
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
                
                Scorecard.shared.sendCardPlayed(round: round, trick: trick, playerNumber: self.thisPlayerNumber, card: cardPlayed, using: self.loopbackService)
                
                completion?()
            })
        } else {
            completion?()
        }
    }
    
    internal func newHand(hand: Hand) {
        self.hand = hand
    }
}

