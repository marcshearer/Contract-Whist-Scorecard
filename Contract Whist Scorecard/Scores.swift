//
//  Scores.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 06/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation
import Combine

class Scores {
    
    fileprivate var roundScore: [Int : RoundScore] = [:]
    fileprivate var changedRound = PassthroughSubject<(Int, Int), Never>()
    
    public func set(round: Int, playerNumber: Int, value: Int?, mode: Mode, sequence: PlayerNumberSequence = .entered) -> Bool {
        var changed = false
        
        let enteredPlayerNumber = Scorecard.game.enteredPlayerNumber(playerNumber: playerNumber, sequence: sequence, round: round)
        
        if self.roundScore[round] == nil {
            self.roundScore[round] = RoundScore(round: round)
        }
        if self.roundScore[round]?.playerScore[enteredPlayerNumber] == nil {
            self.roundScore[round]?.playerScore[enteredPlayerNumber] = PlayerScore(round: round, player: enteredPlayerNumber)
        }
        switch mode {
        case .bid:
            if self.roundScore[round]?.playerScore[enteredPlayerNumber]?.bid != value {
                self.roundScore[round]?.playerScore[enteredPlayerNumber]?.bid = value
                Scorecard.recovery.saveBid(round: round, playerNumber: enteredPlayerNumber)
                changed = true
            }
       case .made:
            if self.roundScore[round]?.playerScore[enteredPlayerNumber]?.made != value {
                self.roundScore[round]?.playerScore[enteredPlayerNumber]?.made = value
                Scorecard.recovery.saveMade(round: round, playerNumber: enteredPlayerNumber)
                changed = true
            }
        case .twos:
            if Scorecard.activeSettings.bonus2 && self.roundScore[round]?.playerScore[enteredPlayerNumber]?.twos != value {
                self.roundScore[round]?.playerScore[enteredPlayerNumber]?.twos = value
                Scorecard.recovery.saveTwos(round: round, playerNumber: enteredPlayerNumber)
                changed = true
            }
        }
        if changed {
            Scorecard.shared.watchManager.updateScores()
            self.changedRound.send((round, enteredPlayerNumber))
        }
        return changed
    }
    
    public func set(round: Int, playerNumber: Int, bid: Int?, sequence: PlayerNumberSequence = .entered) -> Bool {
        return self.set(round: round, playerNumber: playerNumber, value: bid, mode: .bid, sequence: sequence)
    }
    
    public func set(round: Int, playerNumber: Int, made: Int?, sequence: PlayerNumberSequence = .entered) -> Bool {
        return self.set(round: round, playerNumber: playerNumber, value: made, mode: .made, sequence: sequence)
    }
    
    public func set(round: Int, playerNumber: Int, twos: Int?, sequence: PlayerNumberSequence = .entered) -> Bool {
        return self.set(round: round, playerNumber: playerNumber, value: twos, mode: .twos, sequence: sequence)
    }
    
    public func get(round: Int, playerNumber: Int, sequence: PlayerNumberSequence = .entered) -> (bid: Int?, made: Int?, twos: Int?) {
        var result: (Int?, Int?, Int?)  = (nil, nil, nil)
        if let playerScore = self.roundScore[round]?.playerScore[Scorecard.game.enteredPlayerNumber(playerNumber: playerNumber, sequence: sequence, round: round)] {
            result = (bid: playerScore.bid, made: playerScore.made, twos: playerScore.twos)
        }
        return result
    }
    
    public func get(round: Int, playerNumber: Int, sequence: PlayerNumberSequence = .entered, mode: Mode) -> Int? {
        let playerScore = self.get(round: round, playerNumber: playerNumber, sequence: sequence)
        switch mode {
        case .bid:
            return playerScore.bid
        case .made:
            return playerScore.made
        case .twos:
            return playerScore.twos
        }
    }
    
    public func score(round: Int, playerNumber: Int, sequence: PlayerNumberSequence = .entered) -> Int? {
        var score: Int?
        let bonus2 = Scorecard.activeSettings.bonus2
        
        let playerScore = self.get(round: round, playerNumber: playerNumber, sequence: sequence)
        
        if let bid = playerScore.bid, let made = playerScore.made, let twos = playerScore.twos ?? (bonus2 ? nil : 0) {
            score = made + (bid == made ? 10 : 0)
            if bonus2 {
                score! += (twos * 10)
            }
        } else {
            score = nil
        }

        return score
    }
    
    public func totalScore(playerNumber: Int, sequence: PlayerNumberSequence = .entered) -> Int {
        var total = 0
        var roundScore: Int?
        
        for round in 1...Scorecard.game.rounds {
            roundScore = self.score(round: round, playerNumber: playerNumber, sequence: sequence)
            if roundScore != nil {
                total += roundScore!
            }
        }
        
        return total
    }
    
    public func error(round: Int) -> Bool {
        var result = false
     
        if let tricks = Scorecard.game?.roundCards(round) {
            
            if let roundScore = self.roundScore[round] {
                
                let bid = roundScore.playerScore.map({$0.value.bid})
                let made = roundScore.playerScore.map({$0.value.made})
                let twos = roundScore.playerScore.map({$0.value.made})
                
                if bid.count == Scorecard.game?.currentPlayers {
                    if let bidTotal = bid.reduce(0,{$0==nil || $1==nil ? nil : $0!+$1!}) {
                        if bidTotal == tricks {
                            result = true
                        }
                    }
                }
                
                if made.count == Scorecard.game?.currentPlayers {
                    if let madeTotal = made.reduce(0,{$0==nil || $1==nil ? nil : $0!+$1!}) {
                        if madeTotal != tricks {
                            result = true
                        }
                    }
                }
                
                if twos.count == Scorecard.game?.currentPlayers {
                    if let twosTotal = twos.reduce(0,{$0==nil || $1==nil ? nil : $0!+$1!}) {
                        if twosTotal > tricks {
                            result = true
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    public func reset() {
        self.roundScore = [:]
    }
        
    public func subscribe(dedupPlayer: Bool = false, completion: @escaping (Int, Int)->()) -> AnyCancellable {
        return self.changedRound
            .receive(on: RunLoop.main)
            .sink() { (round, player) in
                completion(round, player)
        }
    }
    
}

class RoundScore {
    
    fileprivate let round: Int
    fileprivate var playerScore: [Int:PlayerScore] = [:]
    
    init(round: Int) {
        self.round = round
    }
}

class PlayerScore {
    
    fileprivate let round: Int
    fileprivate let player: Int
    
    fileprivate var bid: Int?
    fileprivate var made: Int?
    fileprivate var twos: Int?
    
    init(round: Int, player: Int) {
        self.round = round
        self.player = player
    }
}
