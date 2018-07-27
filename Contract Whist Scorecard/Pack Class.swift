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
}
