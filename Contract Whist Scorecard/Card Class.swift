//
//  Card.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 17/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import Foundation
import UIKit

class Card {
    
    // A simply class to hold details about a card - i.e. its rank and suit and allow that to be manipulated
    
    var suit: Suit!
    var rank: Int!
    
    init(rank: Int, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }
    
    init(fromNumber: Int) {
        self.fromNumber(fromNumber)
    }

    func fromNumber(_ cardNumber: Int) {
        // Convert a card number (1-52) into card
        self.rank = Int((cardNumber - 1) / 4) + 1
        self.suit = Suit(rawValue: Int((cardNumber - 1) % 4) + 1)
    }
    
    func toNumber() -> Int {
        return ((self.rank - 1) * 4) + self.suit.rawValue
    }
    
    private func rankToString(_ rank: Int) -> String {
        var rankString = ""
        switch rank {
        case 10:
            rankString = "J"
        case 11:
            rankString = "Q"
        case 12:
            rankString = "K"
        case 13:
            rankString = "A"
        default:
            rankString = "\(rank+1)"
        }
        
        return rankString
    }
    
    public func toRankString() -> String {
        return rankToString(self.rank)
    }
    
    public func toString() -> String {
        return "\(rankToString(self.rank))\(self.suit.toString())"
    }
    
    func toAttributedString() -> NSMutableAttributedString {
        let suitColor = [NSAttributedStringKey.foregroundColor: self.suit.color]
        return NSMutableAttributedString(string: self.toString(), attributes: suitColor)
    }
}

class Hand : NSObject, NSCopying {
    
    public var cards: [Card]!
    public var handSuits: [HandSuit]!
    public var xrefSuit: [Suit : HandSuit]!
    public var xrefElement: [Suit: Int]!
    
    override init() {
        self.cards = []
        self.handSuits = []
        self.xrefSuit = [:]
        self.xrefElement = [:]
    }
    
    init(fromNumbers cardNumbers: [Int]) {
        super.init()
        self.fromNumbers(cardNumbers)
        self.sort()
    }
    
    init(fromCards cards: [Card]) {
        super.init()
        self.cards = cards
        self.sort()
    }
    
    public func toNumbers() -> [Int] {
        var result: [Int] = []
        for card in self.cards {
            result.append(card.toNumber())
        }
        return result
    }
    
    public func fromNumbers(_ cardNumbers: [Int]) {
        self.cards = []
        for cardNumber in cardNumbers {
            self.cards.append(Card(fromNumber: cardNumber))
        }
    }
    
    public func toString() -> String {
        var sortedCards: [Card] = []
        var result = ""
        for handSuit in self.handSuits {
            for card in handSuit.cards {
                sortedCards.append(card)
            }
        }
        for card in sortedCards {
            let stringCard = card.toString()
            if result == "" {
                result = stringCard
            } else {
                result = result + " " + stringCard
            }
        }
        return result
    }
    
    public func remove(card: Card) -> Bool {
        var result = false
        
        let cardNumber = card.toNumber()
        if let index = self.cards.index(where: {$0.toNumber() == cardNumber}) {
            self.cards.remove(at: index)
            result = true
            let handSuit = self.xrefSuit[card.suit]!
            if let index = handSuit.cards.index(where: {$0.toNumber() == cardNumber}) {
                handSuit.cards.remove(at: index)
            }
        }
        return result
    }
    
    public func find(card: Card) -> (Int, Int)? {
        if let suitNumber = self.xrefElement[card.suit] {
            let cardAsNumber = card.toNumber()
            if let cardNumber = self.handSuits[suitNumber].toNumbers().index(where: {$0 == cardAsNumber}) {
                return (suitNumber, cardNumber)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    private func sort() {
        var handSuits: [HandSuit] = []
        self.xrefSuit = [:]
        self.xrefElement = [:]
        
        // Create empty suits
        for _ in 1...4 {
            let handSuit = HandSuit()
            handSuits.append(handSuit)
        }
        
        // Sort hand
        self.cards = self.cards.sorted(by: { $0.toNumber() > $1.toNumber() })
        
        // Put hand in suits
        for card in self.cards {
            handSuits[card.suit.rawValue-1].cards.append(card)
        }
        
        // Remove empty suits
        for suitNumber in (1...4).reversed() {
            if handSuits[suitNumber - 1].cards.count == 0 {
                handSuits.remove(at: suitNumber - 1)
            }
        }
        
        self.handSuits = handSuits.reversed()
        self.setupXref()
        
    }
    
    private func setupXref() {
        for suitNumber in 0..<self.handSuits.count {
            self.xrefSuit[self.handSuits[suitNumber].cards.first!.suit] = self.handSuits[suitNumber]
            self.xrefElement[self.handSuits[suitNumber].cards.first!.suit] = suitNumber
        }
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        // Copy elements rather than pointers
        let copy = Hand()
        // Copy cards
        for card in self.cards {
            copy.cards.append(card)
        }
        // Copy suits
        if self.handSuits.count > 0 {
            for handSuit in self.handSuits {
                copy.handSuits.append(handSuit.copy() as! HandSuit)
            }
        }
        // Create xref
        for (suit, element) in self.xrefElement {
            copy.xrefSuit[suit] = copy.handSuits[element]
            copy.xrefElement[suit] = element
        }
        return copy
    }
}

class HandSuit: NSObject, NSCopying {
    
    public var cards: [Card]!
    
    override init() {
        cards = []
    }
    
    init(fromNumbers: [Int]) {
        cards = []
        for number in fromNumbers {
            self.cards.append(Card(fromNumber: number))
        }
    }
    
    public func toNumbers() -> [Int] {
        var result: [Int] = []
        for card in self.cards {
            result.append(card.toNumber())
        }
        return result
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        // Copy elements rather than pointers
        let copy = HandSuit(fromNumbers: self.toNumbers())
        return copy
    }
}

class Deal: NSObject, NSCopying {
    
    public var hands: [Hand]!
    
    override init() {
        hands = []
    }
    
    init(fromNumbers cardNumbers: [[Int]]) {
        super.init()
        self.fromNumbers(cardNumbers)
    }
    
    public func toNumbers() -> [[Int]] {
        var result: [[Int]] = []
        for hand in self.hands {
            result.append(hand.toNumbers())
        }
        return result
    }
    
    public func fromNumbers(_ cardNumbers: [[Int]]) {
        self.hands = []
        for cardNumber in cardNumbers {
            self.hands.append(Hand(fromNumbers: cardNumber))
        }
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = Deal()
        for hand in self.hands {
            copy.hands.append(hand.copy() as! Hand)
        }
        return copy
    }
}
    
public enum SuitEnum : Int {
    case noTrump = 0
    case club = 1
    case diamond = 2
    case heart = 3
    case spade = 4
}
    
class Suit : Hashable {
    
    private let suitEnum: SuitEnum
    
    init(rawValue: Int) {
        self.suitEnum = SuitEnum(rawValue: rawValue)!
    }
    
    init(_ suitEnum: SuitEnum) {
        self.suitEnum = suitEnum
    }
    
    init(fromString: String) {
        switch fromString {
        case "♣︎":
            self.suitEnum = .club
        case "♦︎":
            self.suitEnum = .diamond
        case "♥︎":
            self.suitEnum = .heart
        case "♠︎":
            self.suitEnum = .spade
        default:
            self.suitEnum = .noTrump
        }
    }
    
    public var hashValue: Int {
        get {
            return self.suitEnum.hashValue
        }
    }
    
    static func ==(lhs: Suit, rhs: Suit) -> Bool {
        return lhs.suitEnum == rhs.suitEnum
    }
    
    public var color: UIColor {
        get {
            switch self.suitEnum {
            case .diamond, .heart:
                return UIColor.red
            default:
                return UIColor.black
            }
        }
    }
    
    public var rawValue: Int {
        get {
            return suitEnum.rawValue
        }
    }
    
    public func toString() -> String {
        switch suitEnum {
        case .club:
            return "♣︎"
        case .diamond:
            return "♦︎"
        case .heart:
            return "♥︎"
        case .spade:
            return "♠︎"
        case .noTrump:
            return "NT"
        }
    }
    
    func toAttributedString() -> NSAttributedString {
        let suitColor = [NSAttributedStringKey.foregroundColor: self.color]
        return NSMutableAttributedString(string: self.toString(), attributes: suitColor)
    }
}
