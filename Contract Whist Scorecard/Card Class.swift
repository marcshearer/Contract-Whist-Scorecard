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

class Hand {
    
    public var cards: [Card]!
    
    init() {
        self.cards = []
    }
    
    init(fromNumbers cardNumbers: [Int]) {
        self.fromNumbers(cardNumbers)
    }
    
    init(fromCards cards: [Card]) {
        self.cards = cards
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
        var result = ""
        for card in self.cards {
            let stringCard = card.toString()
            if result == "" {
                result = stringCard
            } else {
                result = result + " " + stringCard
            }
        }
        return result
    }
    
    public func removeCard(_ card: Card) -> Bool {
        let cardNumber = card.toNumber()
        if let index = self.cards.index(where: {$0.toNumber() == cardNumber}) {
            self.cards.remove(at: index)
            return true
        }
        return false
    }
}

class HandSuit {
    
    public var cards: [Card]!
    
    init() {
        cards = []
    }
    
    public func toNumbers() -> [Int] {
        var result: [Int] = []
        for card in self.cards {
            result.append(card.toNumber())
        }
        return result
    }
}

class Deal {
    
    public var hands: [Hand]!
    
    init() {
        hands = []
    }
    
    init(fromNumbers cardNumbers: [[Int]]) {
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
}
    
private enum SuitEnum : Int {
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
