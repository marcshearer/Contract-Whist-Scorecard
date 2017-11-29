//
//  Pack Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/06/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation

class Pack {
    
    private static let packSize = 52
    
    public class func shuffle() -> [Int] {
        var pack: [Int] = []
        var unshuffled = Array(1...packSize)
        for _ in 1...packSize {
            let choose = Utility.random(unshuffled.count)
            pack.append(unshuffled[choose - 1])
            unshuffled.remove(at: choose - 1)
        }
        return pack
    }
    
    public class func deal(numberCards: Int, numberPlayers: Int) -> Deal {
        let pack = Pack.shuffle()
        let deal = Deal()
        for handNumber in 0...numberPlayers - 1 {
            let hand = Hand(fromNumbers: Array(pack[(handNumber * numberCards)...(((handNumber + 1) * numberCards) - 1)]))
            deal.hands.append(hand)
        }
        return deal
    }
    
    public class func sortHand(hand: Hand) -> [HandSuit] {
        var suits: [HandSuit] = []
        
        // Create empty suits
        for _ in 1...4 {
            suits.append(HandSuit())
        }
        
        // Sort hand
        hand.cards = hand.cards.sorted(by: { $0.toNumber() > $1.toNumber() })
        
        // Put hand in suits
        for card in hand.cards {
            suits[card.suit.rawValue-1].cards.append(card)
        }
        
        // Remove empty suits
        for suitNumber in (1...4).reversed() {
            if suits[suitNumber - 1].cards.count == 0 {
                suits.remove(at: suitNumber - 1)
            }
        }
        
        return suits.reversed()
    }
    
    public class func findCard(hand: [HandSuit], card: Card) -> (Int, Int)? {
        var suitNumber: Int!
        var cardNumber: Int!
        
        let cardAsNumber = card.toNumber()
        if hand.count > 0 {
            for suit in 0...hand.count-1 {
                let index = hand[suit].toNumbers().index(where: {$0 == cardAsNumber})
                if index != nil {
                    suitNumber = suit
                    cardNumber = index!
                    break
                }
            }
        }
        if suitNumber == nil {
            return nil
        } else {
            return (suitNumber, cardNumber)
        }
    }
    
    public class func findCard(hand: Hand, card: Card) -> Int? {
        let cardAsNumber = card.toNumber()
        let index = hand.toNumbers().index(where: {$0 == cardAsNumber})
        return index
    }
    
}
