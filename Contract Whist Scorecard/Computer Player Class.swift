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
}

extension ComputerPlayerDelegate {
    
    func autoBid() {
        self.autoBid(completion: nil)
    }
    
    func autoPlay() {
        self.autoPlay(completion: nil)
    }
}

class ComputerPlayer: NSObject, CommsDataDelegate, ComputerPlayerDelegate {
    
    private var scorecard: Scorecard
    private var thisPlayer: String
    private var thisPlayerName: String
    private var thisPlayerNumber: Int!
    private var loopbackClient: LoopbackService
    private var commsDelegate: CommsHandlerDelegate!
    private var hostPeer: CommsPeer
    private var handSuits: [HandSuit]!
    
    // Queue
    private var queue: [QueueEntry] = []
    private var pending = false
    private var computerPlayerQueue: DispatchQueue!

    init(scorecard: Scorecard, email: String, name: String, deviceName: String, hostPeer: CommsPeer, playerNumber: Int) {
        
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
        
        // Setup custom queue
        computerPlayerQueue = DispatchQueue.main

        // Take loopback service delegates
        self.loopbackClient.dataDelegate = self

        // Start the service
        self.commsDelegate = self.loopbackClient
        self.commsDelegate.start(email: email, name: name)
        
        // Connect back to the host
        _ = self.commsDelegate.connect(to: hostPeer, playerEmail: email, playerName: name, reconnect: false)
    }
    
    // MARK: - Data delegate handlers  ========================================================================= -

    
    public func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        self.computerPlayerQueueExecute("\(self.thisPlayerName)-didReceiveData", execute: {
            self.scorecard.commsDelegate?.debugMessage("\(descriptor) received from \(peer.deviceName)")
            
             switch descriptor {
                case "hand", "handState", "scores", "played":
                self.queue.append(QueueEntry(descriptor: descriptor, data: data, peer: peer))
             default:
                break}
        
            if !self.pending {
                self.processQueue()
            } else {
                self.loopbackClient.debugMessage("Pending")
            }
        })
    }
    
    func processQueue() {
        
        if self.queue.count > 0 {
            var queueText = ""
            for element in self.queue {
                queueText = queueText + " " + element.descriptor
            }
            self.loopbackClient.debugMessage("Processing queue for \(self.thisPlayerName)\(queueText)")
        }
        
        while self.queue.count > 0  {
            
            // Pop top element off the queue
            var checkState = false
            let descriptor = self.queue.first?.descriptor
            let data = self.queue.first?.data
            var mode: String!
            self.queue.removeFirst()
            
            // Only want to look at hands arriving, bids or cards played
            switch descriptor {
                
            case "hand", "handState":
                // Sort hand
                
                
            // TODO Delete
                
            /*
            case "scores":
                for (playerNumberData, playerData) in (data as! [String : [String : Any]]) {
                    if Int(playerNumberData)! != self.thisPlayerNumber {
                        for (roundNumberData, roundData) in (playerData as! [String : [String : Any]]) {
                            if Int(roundNumberData)! == self.scorecard.handState.round {
                                if roundData["bid"] != nil {
                                    // A bid from someone else
                                    checkState = true
                                }
                            }
                        }
                    }
                }
                
            case "played":
                if data!["player"] as? Int != self.thisPlayerNumber {
                    // Card played by another player
                    checkState = true
                }
            */
            default:
                break
            }
            
            if mode != nil {
                switch mode {
                case "bid":
                    self.autoBid(completion: nil)
                case "play":
                    self.autoPlay(completion: nil)
                default:
                    break
                }
            }
        }
    }

    private func stateController() {
        if self.handSuits == nil {
            // Sort hand if not there already
            let hand = self.scorecard.deal.hands[self.thisPlayerNumber - 1]
            self.handSuits = HandSuit.sortCards(cards: hand.cards)
        }
        
        autoBid(completion: {
            self.pending = false
            self.processQueue()
        })
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
        self.loopbackClient.debugMessage("Player: \(self.thisPlayerNumber!)")
        if self.scorecard.entryPlayerNumber(self.thisPlayerNumber, round: round) == bids.count + 1 {
            
            runCompletionOnExit = false
            
            self.computerPlayerQueueExecute("autoBid", after: 1.0, execute: {
                
                self.loopbackClient.debugMessage(self.thisPlayerName)
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
                self.pending = true
                self.loopbackClient.debugMessage("Bid by \(self.thisPlayerName) of \(bid)")
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
        let rounds = self.scorecard.handState.rounds
        let roundCards = self.scorecard.roundCards(round)
        let trick = self.scorecard.handState.trick!
        let trickCards = self.scorecard.handState.trickCards
        let cardsPlayed = trickCards!.count
        
        if trick <= roundCards {
        
            self.loopbackClient.debugMessage("Checking to play \(self.scorecard.handState.toPlay!) \(self.thisPlayerName) \(cardsPlayed)")
            
            if self.scorecard.handState.toPlay == self.thisPlayerNumber {
                // Me to play
                
                var cardCount = 0
                for handSuit in self.handSuits {
                    cardCount += handSuit.cards.count
                }
                
                if cardCount >= (roundCards - trick + 1) {
                    // Have enough cards to play 1 to this trick (or I am leading having just won but trick may not be up to date
                
                    runCompletionOnExit = false
                    
                    self.computerPlayerQueueExecute("autoPlay", after: 1.0, execute: {
                        
                        // Now work out card to play
                        var cardPlayed: Card!
                        
                        // Try to find a card in the suit led if possible - else anything
                        var trySuitLed = ((cardsPlayed) != 0)
                        var loop = 0
                        while loop < 2 && cardPlayed == nil {
                            loop += 1
                            for handSuit in self.handSuits {
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
                
                        self.pending = true
                        self.loopbackClient.debugMessage("Card played by \(self.thisPlayerName) of \(cardPlayed.toString())")
                        
                        /* TODO Remove
                        // Check if it is me to play again
                        var winner: Int!
                        if round < rounds {
                            if cardsPlayed == self.scorecard.currentPlayers - 1 {

                                (winner, _) = self.scorecard.checkWinner(currentPlayers: self.scorecard.currentPlayers, round: round, suits: self.scorecard.handState.suits, trickCards: trickCards! + [cardPlayed])
                            }
                        }
                        
                        if winner == self.scorecard.currentPlayers {
                            self.autoPlay(completion: completion)
                        } else {
                        */
                        completion?()
                    })
                }
            }
        }
        if runCompletionOnExit {
        completion?()
    }
}
    
    func computerPlayerQueueExecute(_ message: String! = nil, after delay: Double! = nil, execute: @escaping ()->()) {
        if delay == nil {
            if message != nil {
                self.loopbackClient.debugMessage("\(message!) - Execute closure on computer player queue for \(self.thisPlayerName)")
            }
            self.computerPlayerQueue.async {
                execute()
                if message != nil {
                    self.loopbackClient.debugMessage("\(message!) - Completed closure on computer player queue for \(self.thisPlayerName)")
                }
            }
        } else {
            if message != nil {
                self.loopbackClient.debugMessage("\(message!) - Queue closure for \(Int(delay!)) seconds on computer player queue for \(self.thisPlayerName)")
            }
            self.computerPlayerQueue.asyncAfter(deadline: DispatchTime.now() + delay, qos: .userInteractive) {
                if message != nil {
                    self.loopbackClient.debugMessage("\(message!) - Start delayed closure on computer player queue for \(self.thisPlayerName)")
                }
                execute()
                if message != nil {
                    self.loopbackClient.debugMessage("\(message!) - Completed delayed closure on computer player queue for \(self.thisPlayerName)")
                }
            }
        }
    }
}
