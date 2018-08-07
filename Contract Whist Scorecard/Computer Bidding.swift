//
//  Computer Bidding.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/08/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import Foundation

class ComputerBidding {
    
    private var hand: Hand
    private var trumpSuit: Suit
    private var bids: [Int]
    private var numberPlayers: Int
    private let cardsInPack = 52
    private let cardsInSuit = 13
    private let suits = 4
   
    private var myTrumps: Int {
        get {
            if self.trumpSuit == Suit(.noTrump) {
                return 0
            } else {
                if let handSuit = self.hand.xrefSuit[self.trumpSuit] {
                    return handSuit.cards.count
                } else {
                    return 0
                }
            }
        }
    }
    private var handCards: Int {
        get {
            return self.hand.cards.count
        }
    }
    private var totalCards: Int {
        get {
            return self.handCards * self.numberPlayers
        }
    }
    private var unseenCardsInPack: Int {
        get {
            return self.cardsInPack - self.handCards
        }
    }
    
    init(hand: Hand, trumpSuit: Suit, bids: [Int], numberPlayers: Int) {
        self.hand = hand
        self.trumpSuit = trumpSuit
        self.bids = bids
        self.numberPlayers = numberPlayers
    }
    
    public func bid() -> Int {
        var bid: Int
        
        let winners = self.countHandWinners()
        bid = Utility.round(winners)
        
        if self.bids.count >= self.numberPlayers - 1 && bid == self.handCards - Utility.sum(bids) {
            // Preferred bid equals number remaining - adjust it
            if Double(bid) < winners || bid == 0 {
                bid += 1
            } else {
                bid -= 1
            }
        }
        
        return bid
    }
    
    func countHandWinners() -> Double {
        var winners: Double = 0.0
        for handSuit in self.hand.handSuits {
            winners += countSuitWinners(handSuit: handSuit)
        }
        return winners
    }
    
    func countSuitWinners(handSuit: HandSuit) -> Double {
        var winners: Double = 0.0
        var lastRank = 14
        var cardNumber = 0
        var missingCards = 0
        
        for card in handSuit.cards {
            cardNumber += 1
            missingCards += lastRank - 1 - card.rank
            lastRank = card.rank
            winners += winnerProbability(gapAbove: missingCards, coverRequired: missingCards+1, card: card)
        }
        
        return winners
    }
    
    private func winnerProbability(gapAbove: Int, coverRequired: Int, card: Card) -> Double {
        var probability: Double
        if gapAbove == 0 {
            if self.mySuitCount(card.suit) < coverRequired {
                probability = 0
            } else {
                probability = pow(holdsAtLeast(cards: coverRequired, in: card.suit), Double(self.numberPlayers-1))
            }
        } else {
            let inPlay = cardInPlayProtected(card: Card(rank: card.rank+gapAbove, suit: card.suit))
            probability = (inPlay *               0.6 * winnerProbability(gapAbove:gapAbove - 1, coverRequired: coverRequired, card:card)) +
                          ((Double(1.0)-inPlay) * winnerProbability(gapAbove:gapAbove - 1, coverRequired: coverRequired - 1, card:card))
        }
        return probability
    }
    
    private func cardInPlayProtected(card: Card) -> Double {
        // Probability a card is in play and protected (ignoring trumps)
        var probability: Double = Double((numberPlayers-1) * self.handCards) / Double(self.unseenCardsInPack)
        let above = self.cardsInSuit - card.rank
        probability *= holdsAtLeast(cards: above, in: card.suit, reducedBy: 1)
        return probability
    }
    
    private func holdsAtLeast(cards: Int, in suit: Suit, reducedBy: Int = 0) -> Double {
        // Probability that a number (usually all) other players have at least a number of cards in a suit
        
        var probability: Double = 1.0
        var cardsLeftInOtherSuits = self.unseenCardsInOtherSuits(suit)
        var cardsLeftInPack = self.unseenCardsInPack - reducedBy
        
        if self.trumpSuit != Suit(.noTrump) && suit != self.trumpSuit && cards > 0 && cards <= handCards - reducedBy {
            // Don't worry about short suits if this is trumps or there are no trumps
            // Calculate the probability of them not having this number of this suit
            // i.e. Work out the probability of them having too many of the other suits and take the inverse
            var inversePlayerProbability:Double = 1.0
            for _ in 1...(handCards - reducedBy - cards + 1) {
                inversePlayerProbability *= (Double(cardsLeftInOtherSuits) / Double(cardsLeftInPack))
                cardsLeftInOtherSuits -= 1
                cardsLeftInPack -= 1
            }
            probability = (1.0 - inversePlayerProbability)
        }
        
        return probability
    }
    
    private func mySuitCount(_ suit: Suit) -> Int {
        return hand.xrefSuit[suit]?.cards.count ?? 0
    }
    
    private func unseenCardsInSuit(_ suit: Suit) -> Int {
        return self.cardsInSuit - self.mySuitCount(suit)
    }
    
    private func unseenCardsInOtherSuits(_ suit: Suit) -> Int {
        return self.unseenCardsInPack - self.unseenCardsInSuit(suit)
    }
}
