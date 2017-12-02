//
//  Player Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 02/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class Player {
    
    // A class to store all our data about players in the current game
    
    private var bid = [Int?]()
    private var made = [Int?]()
    private var twos = [Int?]()
    public var playerNumber = 0
    public var rounds = 0
    private var scorecard: Scorecard
    private var recovery: Recovery? = nil
    public var bidCell = [ScorepadCollectionViewCell!]()
    public var scoreCell = [ScorepadCollectionViewCell!]()
    public var totalLabel: UILabel?
    public var playerMO: PlayerMO?
    public var participantMO: ParticipantMO?
    private var savedHandsPlayed: Int64 = 0
    private var savedGamesPlayed: Int64 = 0
    private var savedGamesWon: Int64 = 0
    private var savedTotalScore: Int64 = 0
    private var savedHandsMade: Int64 = 0
    private var savedTwosMade: Int64 = 0
    public var previousMaxScore: Int64 = 0
    public var previousMaxScoreDate = Date()
    
    public init(rounds: Int, scorecard: Scorecard, playerNumber: Int, recovery: Recovery) {
        
        self.scorecard = scorecard
        self.recovery = recovery
                
        if rounds > 0 {
            
            for _ in 1...rounds {
                
                self.bid.append(nil)
                self.made.append(nil)
                self.twos.append(nil)
                self.bidCell.append(nil)
                self.scoreCell.append(nil)
                
            }
            self.rounds = rounds
        }
        self.playerNumber = playerNumber
        self.totalLabel = nil
        self.playerMO = nil
        self.participantMO = nil
    }
    
    public func reset() {
        // Reset game values
        for loop in 1...rounds {
            self.bid[loop-1] = nil
            self.made[loop-1] = nil
            self.twos[loop-1] = nil
        }
        
        // Reset saved values - allows incremental updates
        self.savedHandsPlayed = 0
        self.savedGamesPlayed = 0
        self.savedGamesWon = 0
        self.savedTotalScore = 0
        self.savedHandsMade = 0
        self.savedTwosMade = 0
        
        // Reset the participant managed object
        self.participantMO = nil
    }
    
    public func setBidCell(_ round: Int, cell: ScorepadCollectionViewCell!) {
        bidCell[round-1] = cell
    }
    
    public func setScoreCell(_ round: Int, cell: ScorepadCollectionViewCell) {
        scoreCell[round-1] = cell
    }
    
    public func setTotalLabel(label: UILabel?) {
        totalLabel = label
    }

    private func updateScore(_ round: Int, bonus2: Bool! = nil) {
        if self.scoreCell[round-1] != nil {
            let score = self.score(round)
            self.scoreCell[round-1]?.scorepadCellLabel.text = (score == nil ? "" : "\(score!)")
            if self.totalLabel != nil {
                let totalScore = self.totalScore(bonus2: bonus2)
                self.totalLabel?.text = "\(totalScore)"
            }
            scorecard.formatRound(round)
        }
    }
    
    public func bid(_ round: Int) -> Int? {
        return self.bid[round-1]
    }
    
    public func setBid(_ round: Int,_ bid: Int!, bonus2: Bool! = nil) {
        if self.bid[round-1] != bid {
            self.bid[round-1] = bid
            self.scorecard.sendScores(playerNumber: self.playerNumber, round: round, mode: .bid)
            if bidCell[round-1] != nil {
                bidCell[round-1].scorepadCellLabel.text = (bid == nil ? "" : "\(bid!)")
            }
            self.updateScore(round, bonus2: bonus2)
            recovery!.saveBid(round: round, playerNumber: self.playerNumber)
            self.scorecard.watchManager.updateScores()
        }
    }
    
    public func made(_ round: Int) -> Int? {
        return self.made[round-1]
    }
    
    public func setMade(_ round: Int,_ made: Int!, bonus2: Bool! = nil) {
        if self.made[round-1] != made {
            self.made[round-1] = made
            self.scorecard.sendScores(playerNumber: self.playerNumber, round: round, mode: .made)
            self.updateScore(round, bonus2: bonus2)
            recovery!.saveMade(round: round, playerNumber: self.playerNumber)
            self.scorecard.watchManager.updateScores()
        }
    }
    
    public func twos(_ round: Int) -> Int? {
        return self.twos[round-1]
    }
    
    public func setTwos(_ round: Int,_ twos: Int!, bonus2: Bool! = nil) {
        if self.twos[round-1] != twos {
            self.twos[round-1] = twos
            self.scorecard.sendScores(playerNumber: self.playerNumber, round: round, mode: .twos)
            self.updateScore(round, bonus2: bonus2)
            recovery!.saveTwos(round: round, playerNumber: self.playerNumber)
            self.scorecard.watchManager.updateScores()
        }
    }
    
    public func value(round: Int, mode: Mode) -> Int? {
        switch mode {
        case Mode.bid:
            return self.bid(round)
        case Mode.made:
            return self.made(round)
        case Mode.twos:
            return self.twos(round)
        }
    }
    
    public func score(_ round: Int, bonus2: Bool! = nil) -> Int? {
        var score: Int?
        let bonus2 = (bonus2 == nil ? scorecard.settingBonus2 : bonus2!)

        if self.bid[round-1] == nil || self.made[round-1] == nil ||
                (bonus2 && self.twos[round-1] == nil) {
            score = nil
        } else {
            score = self.made[round-1]! + (self.bid[round-1] == self.made[round-1] ? 10 : 0)
            if bonus2 {
                score! += (self.twos[round-1]! * 10)
            }
        }
        return score
    }
    
    public func totalScore(bonus2: Bool! = nil) -> Int {
        var total = 0
        var roundScore: Int?
        
        for round in 1...self.rounds {
            roundScore = score(round, bonus2: bonus2)
            if roundScore != nil {
                total += roundScore!
            }
        }
        
        return total
    }
    
    public func saveMaxScore() {
        self.previousMaxScore = self.playerMO!.maxScore
        if self.playerMO!.maxScoreDate != nil {
            self.previousMaxScoreDate = self.playerMO!.maxScoreDate! as Date
        } else {
            self.previousMaxScoreDate = Date()
        }
    }
        
    public func save(excludeStats: Bool) -> Bool {
        // Save the player to the persistent store
        
        return CoreData.update(updateLogic: {
            var place: Int16
            var roundsMade: Int64
            var twosMade: Int64
            
            // Check if they won this game
            let myScore = self.totalScore()
            place = 1
            for otherPlayer in 1...scorecard.currentPlayers {
                if scorecard.enteredPlayer(otherPlayer).playerNumber != self.playerNumber {
                    if self.scorecard.enteredPlayer(otherPlayer).totalScore() > myScore {
                        place += 1
                    }
                }
            }
            
            // Calculate rounds made and twos made
            roundsMade = 0
            twosMade = 0
            for round in 1...self.rounds {
                if self.bid(round) != nil && self.made(round) != nil && self.bid(round) == self.made(round) {
                    roundsMade += 1
                }
                if self.twos(rounds) != nil {
                    twosMade += Int64(self.twos(round)!)
                }
            }
            if !excludeStats {
                
                // Updates hands / games played
                self.playerMO!.handsPlayed += (Int64(self.rounds) - self.savedHandsPlayed)
                self.savedHandsPlayed = Int64(self.rounds)
                self.playerMO!.gamesPlayed += (1 - savedGamesPlayed)
                self.savedGamesPlayed = 1
            
                // Update games won and totals
                self.playerMO!.gamesWon += ((place == 1 ? 1 : 0) - self.savedGamesWon)
                self.savedGamesWon = (place == 1 ? 1 : 0)
                
                self.playerMO!.totalScore += (Int64(myScore) - self.savedTotalScore)
                self.savedTotalScore = Int64(myScore)
            
                // Update hands made and twos made
                self.playerMO!.handsMade += (roundsMade - self.savedHandsMade)
                self.savedHandsMade = roundsMade
                self.playerMO!.twosMade += (twosMade - self.savedTwosMade)
                self.savedTwosMade = twosMade
                
                // Update high scores
                if Int64(myScore) > self.playerMO!.maxScore {
                    self.playerMO!.maxScore = Int64(myScore)
                    self.playerMO!.maxScoreDate = Date()
                }
                if Int64(roundsMade) > self.playerMO!.maxMade {
                    self.playerMO!.maxMade = roundsMade
                    self.playerMO!.maxMadeDate = Date()
                }
                if Int64(twosMade) > self.playerMO!.maxTwos {
                    self.playerMO!.maxTwos = twosMade
                    self.playerMO!.maxTwosDate = Date()
                }
                
                // Upate date last played
                self.playerMO!.datePlayed = Date()
            }
            
            // Update game participant for history
            if self.scorecard.settingSaveHistory {
                if self.participantMO == nil {
                    // Create the managed object for this participant in the game
                    self.participantMO = CoreData.create(from: "Participant")
                    self.participantMO?.gameUUID = scorecard.gameUUID
                    self.participantMO?.datePlayed = scorecard.gameDatePlayed
                    self.participantMO?.localDateCreated = Date()
                    self.participantMO?.deviceUUID = UIDevice.current.identifierForVendor?.uuidString
                    self.participantMO?.name = self.playerMO?.name
                    self.participantMO?.email = self.playerMO?.email
                    self.participantMO?.playerNumber = Int16(self.scorecardPlayerNumber())
                }
                self.participantMO!.handsPlayed = Int16(self.rounds)
                self.participantMO!.gamesPlayed = 1
                self.participantMO!.place = place
                self.participantMO!.gamesWon = (place == 1 ? 1 : 0)
                self.participantMO!.totalScore = Int16(myScore)
                self.participantMO!.handsMade = Int16(roundsMade)
                self.participantMO!.twosMade = Int16(twosMade)
                self.participantMO!.excludeStats = excludeStats
            }
            
        })
    }
    
    func scorecardPlayerNumber() -> Int {
        // Player number starting with first dealer as 1
        return absoluteModulus((self.playerNumber - 1) - (scorecard.dealerIs - 1 ), scorecard.currentPlayers) + 1
    }
    
    func entryPlayerNumber(round: Int) -> Int {
        // Player number starting with first dealer as 1
        return absoluteModulus((self.playerNumber - 1) - (scorecard.dealerIs - 1 )  - (round - 1), scorecard.currentPlayers) + 1
    }
    
    func absoluteModulus(_ value: Int, _ modulus: Int) -> Int {
        // Return the modulus where it continue smoothly below zero (up to a point)
        return (value + (100 * modulus)) % modulus
    }
    
}
