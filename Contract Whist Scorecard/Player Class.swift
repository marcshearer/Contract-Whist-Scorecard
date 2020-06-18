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
    
    // MARK: - Properties =================================================================== -

    /** The player number 1-4 in the sequence the players were entered */
    public var playerNumber = 0
    
    /** The managed object for this player */
    public var playerMO: PlayerMO?
    
    /** The participant managed object associated with this player - built up as the game completes*/
    public var participantMO: ParticipantMO?
    
    /** The number of hands played as last saved by the save method - to allow incremental updates */
    private var savedHandsPlayed: Int64 = 0
    
    /** The number of hands made as last saved by the save method - to allow incremental updates */
    private var savedHandsMade: Int64 = 0
    
    /** The number of twos made as last saved by the save method - to allow incremental updates */
    private var savedTwosMade: Int64 = 0
    
    /** The number of games played as last saved by the save method - to allow incremental updates */
    private var savedGamesPlayed: Int64 = 0
    
    /** The number of games won as last saved by the save method - to allow incremental updates */
    private var savedGamesWon: Int64 = 0
    
    /** The total score as last saved by the save method - to allow incremental updates */
    private var savedTotalScore: Int64 = 0

    /**
     The player's high score before the current game
     - Note: read only externally
    */
    public var previousMaxScore: Int64 {
        get {
            return self._previousMaxScore
        }
    }
    private var _previousMaxScore: Int64 = 0

    /**
     The date on which the player achieved their last high score before the current game
     - Note: read only externally
    */
    public var previousMaxScoreDate: Date {
        get {
            return self._previousMaxScoreDate
        }
    }
    private var _previousMaxScoreDate = Date()

    // MARK: - Initialisation ================================================================= -
    
    public init(playerNumber: Int) {
        
        self.playerNumber = playerNumber
        self.playerMO = nil
        self.participantMO = nil
    }
    
    // MARK: - Methods ======================================================================== -
    
    
    /**
     Resets the values for the player to start a new game
    */
    public func reset() {
        // Reset player game values
        
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
    
    /**
     Save the previous high score and date for a player prior to the current game
    */
    public func saveMaxScore() {
        if let playerMO = self.playerMO {
            self._previousMaxScore = playerMO.maxScore
            if playerMO.maxScoreDate != nil {
                self._previousMaxScoreDate = playerMO.maxScoreDate! as Date
            } else {
                self._previousMaxScoreDate = Date()
            }
        }
    }
        
    /**
     Save the player to core data - values are incremented from any previously saved values
     - Parameters:
       - excludeHistory: Allows the player to be updated without a partipant history record being setup
       - excludeStats: Allows the player to be updated without their stats being incremented
     */
    public func save(excludeHistory: Bool, excludeStats: Bool) -> Bool {
        // Save the player to the persistent store
        
        return CoreData.update(updateLogic: {
            var place: Int16
            var roundsMade: Int64
            var twosMade: Int64
            
            // Check if they won this game
            let myScore = Scorecard.game.scores.totalScore(playerNumber: self.playerNumber)
            place = 1
            for otherPlayer in 1...Scorecard.game.currentPlayers {
                if Scorecard.game.player(enteredPlayerNumber: otherPlayer).playerNumber != self.playerNumber {
                    if Scorecard.game.scores.totalScore(playerNumber: otherPlayer) > myScore {
                        place += 1
                    }
                }
            }
            
            // Calculate rounds made and twos made
            roundsMade = 0
            twosMade = 0
            for round in 1...Scorecard.game.rounds {
                let playerScore = Scorecard.game.scores.get(round: round, playerNumber: self.playerNumber)
                if playerScore.bid != nil && playerScore.made != nil && playerScore.bid == playerScore.made {
                    roundsMade += 1
                }
                twosMade += Int64(playerScore.twos ?? 0)
            }
            if !excludeStats {
                
                // Updates hands / games played
                self.playerMO!.handsPlayed += (Int64(Scorecard.game.rounds) - self.savedHandsPlayed)
                self.savedHandsPlayed = Int64(Scorecard.game.rounds)
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
            if !excludeHistory {
                if Scorecard.activeSettings.saveHistory {
                    if self.participantMO == nil {
                        // Create the managed object for this participant in the game
                        self.participantMO = CoreData.create(from: "Participant")
                        self.participantMO?.gameUUID = Scorecard.game.gameUUID
                        self.participantMO?.datePlayed = Scorecard.game.datePlayed
                        self.participantMO?.localDateCreated = Date()
                        self.participantMO?.deviceUUID = UIDevice.current.identifierForVendor?.uuidString
                        self.participantMO?.name = self.playerMO?.name
                        self.participantMO?.playerUUID = self.playerMO?.playerUUID
                        self.participantMO?.playerNumber = Int16(self.scorecardPlayerNumber())
                    }
                    self.participantMO!.handsPlayed = Int16(Scorecard.game.rounds)
                    self.participantMO!.gamesPlayed = 1
                    self.participantMO!.place = place
                    self.participantMO!.gamesWon = (place == 1 ? 1 : 0)
                    self.participantMO!.totalScore = Int16(myScore)
                    self.participantMO!.handsMade = Int16(roundsMade)
                    self.participantMO!.twosMade = Int16(twosMade)
                    self.participantMO!.excludeStats = excludeStats
                }
            }
        })
    }
    
    
    /**
     Return the player number in the sequence the players appear on the scorecard (offset by first dealer)
     - Returns: Player number 1-4 in scorecard sequence
    */
    public func scorecardPlayerNumber() -> Int {
        // Player number starting with first dealer as 1
        return absoluteModulus((self.playerNumber - 1) - (Scorecard.game.dealerIs - 1 ), Scorecard.game.currentPlayers) + 1
    }
    
    /**
     Return the player number in the sequence the players will bid in a particular round (offset by round dealer)
     - Returns: Player number 1-4 in round sequence
    */
    public func roundPlayerNumber(round:Int) -> Int {
        return absoluteModulus((self.playerNumber - 1) - (Scorecard.game.dealerIs - 1 )  - (round - 1), Scorecard.game.currentPlayers) + 1
    }
    
    /**
      Return the modulus where it continues smoothly below zero (up to a point)
    */
    private func absoluteModulus(_ value: Int, _ modulus: Int) -> Int {
        return (value + (100 * modulus)) % modulus
    }
    
}
