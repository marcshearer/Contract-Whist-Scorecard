//
//  Reconcile.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/02/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

protocol ReconcileDelegate: class {
    
    // A method to manage an info message from the reconcile controller
    func reconcileMessage(_ message: String)
    
    // A method to manage an error message from the reconcile controller
    func reconcileAlertMessage(_ message: String)
    
    // A method to be called when reconciliation is complete
    func reconcileCompletion(_ errors: Bool)
    
}

class Reconcile: SyncDelegate {
    
    // A class which synchronises the local core data representation with the cloud
    // It has no UI - it expects the calling class to
    
    // MARK: - Class Properties ======================================================================== -
    
    // Delegate for callback protocol
    public weak var delegate: ReconcileDelegate?
    
    // Main state properties
    private let sync = Sync()
    
    // Local state properties
    var playerMOList: [PlayerMO]!
    
    // MARK: - Public class methods ==================================================================== -
    
    public func reconcilePlayers(playerMOList: [PlayerMO]) {
        self.playerMOList = playerMOList
        
        // First synchronise
        if Scorecard.settings.syncEnabled {
            self.sync.delegate = self
            if self.sync.synchronise(waitFinish: true, okToSyncWithTemporaryPlayerUUIDs: true) {
                self.reconcileMessage("Sync in progress")
                // Note this starts synchronisation - reconciliation is then initiated from the completion handler
            } else {
                self.reconcileMessage("Unable to synchronise with iCloud", finish: true)
            }
        } else {
            reconcileRebuildPlayers()
        }
    }
    
    // MARK: - Functions to reconcile a player with participant records  ====================================== -
    
    private func reconcileRebuildPlayers() {
        var errors = false
        self.reconcileMessage((self.playerMOList.count == 1 ? "Rebuilding \(playerMOList[0].name!)" : "Rebuilding players"))
        
        for playerMO in playerMOList {
            
            if !Reconcile.rebuildLocalPlayer(playerMO: playerMO) {
                errors = true
            }
        }
        
        if errors {
            self.reconcileMessage("Error in rebuild")
        } else {
            self.reconcileMessage((self.playerMOList.count == 1 ? "\(playerMOList[0].name!) rebuilt" : "All players rebuilt"))
        }
        self.reconcileCompletion(errors)
    }
    
    class func rebuildLocalPlayer(playerMO: PlayerMO) -> Bool {
        // Load participant records
        let participantList = History.getParticipantRecordsForPlayer(playerUUID: playerMO.playerUUID!, includeBF: true)
        
        return CoreData.update(updateLogic: {
            
            // Zero values
            playerMO.gamesPlayed = 0
            playerMO.gamesWon = 0
            playerMO.handsPlayed = 0
            playerMO.handsMade = 0
            playerMO.twosMade = 0
            playerMO.totalScore = 0
            playerMO.winStreak = 0
            playerMO.maxScore = 0
            playerMO.maxScoreSplit = 0
            playerMO.maxMade = 0
            playerMO.maxMadeSplit = 0
            playerMO.maxTwos = 0
            playerMO.maxTwosSplit = 0
            playerMO.datePlayed = nil

            for participantMO in participantList {
                if !participantMO.excludeStats {
                    // Add to scores
                    playerMO.gamesPlayed += Int64(participantMO.gamesPlayed)
                    playerMO.gamesWon += Int64(participantMO.gamesWon)
                    playerMO.handsPlayed += Int64(participantMO.handsPlayed)
                    playerMO.handsMade += Int64(participantMO.handsMade)
                    playerMO.twosMade += Int64(participantMO.twosMade)
                    playerMO.totalScore += Int64(participantMO.totalScore)
                    playerMO.winStreak = (participantMO.place == 1 ? playerMO.winStreak + 1 : 0)
                    
                    if participantMO.gamesPlayed == 1 {
                        // Update max scores
                        if Int64(participantMO.totalScore) > playerMO.maxScore || (Int64(participantMO.totalScore) == playerMO.maxScore && Int64(participantMO.handsMade) > playerMO.maxScoreSplit) {
                            playerMO.maxScore = Int64(participantMO.totalScore)
                            playerMO.maxScoreSplit = Int64(participantMO.handsMade)
                            playerMO.maxScoreDate = participantMO.datePlayed
                        }
                        if Int64(participantMO.handsMade) > playerMO.maxMade || (Int64(participantMO.handsMade) == playerMO.maxMade && Int64(participantMO.totalScore) > playerMO.maxMadeSplit) {
                            playerMO.maxMade = Int64(participantMO.handsMade)
                            playerMO.maxMadeSplit = Int64(participantMO.totalScore)
                            playerMO.maxMadeDate = participantMO.datePlayed
                        }
                        if playerMO.winStreak > playerMO.maxWinStreak {
                            playerMO.maxWinStreak = playerMO.winStreak
                            playerMO.maxWinStreakDate = participantMO.datePlayed
                        }
                        if Int64(participantMO.twosMade) > playerMO.maxTwos || (Int64(participantMO.twosMade) == playerMO.maxTwos && Int64(participantMO.totalScore) > playerMO.maxTwosSplit) {
                            playerMO.maxTwos = Int64(participantMO.twosMade)
                            playerMO.maxTwosSplit = Int64(participantMO.totalScore)
                            playerMO.maxTwosDate = participantMO.datePlayed
                        }
                    }
                    // Update date last played
                    if playerMO.datePlayed == nil || participantMO.datePlayed! as Date > playerMO.datePlayed! as Date {
                        playerMO.datePlayed = participantMO.datePlayed
                    }
                }
                
                // Avoid sending any differences back up
                playerMO.syncGamesPlayed = playerMO.gamesPlayed
                playerMO.syncGamesWon = playerMO.gamesWon
                playerMO.syncHandsPlayed = playerMO.handsPlayed
                playerMO.syncHandsMade = playerMO.handsMade
                playerMO.syncTwosMade = playerMO.twosMade
                playerMO.syncTotalScore = playerMO.totalScore
                
                // Clear 'dirty' flag
                playerMO.syncInProgress = false
            }
        })
    }
    
    // MARK: - Sync class delegate methods ===================================================================== -
    
    func syncAlert(_ message: String, completion: @escaping ()->()) {
        Utility.mainThread {
            completion()
        }
    }
    
    func syncCompletion(_ errors: Int) {
        Utility.mainThread {
            if errors != 0 {
                self.reconcileMessage("Sync failed", finish: true)
            } else {
                self.reconcileRebuildPlayers()
            }
        }
    }
    
   // MARK: - Utility Routines ======================================================================== -
    
    private func reconcileMessage(_ message: String, finish: Bool = false) {
        // call the delegate message handler if there is one
        if finish {
            self.delegate?.reconcileAlertMessage(message)
            self.reconcileCompletion(true)
        } else {
            self.delegate?.reconcileMessage(message)
        }
    }
        
    private func reconcileCompletion(_ errors: Bool) {
        // Call the delegate completion handler if there is one
        let delegate = self.delegate
        
        // Disconnect
        self.delegate = nil
        
        // Call completion delegate
        if delegate != nil {
            delegate!.reconcileCompletion(errors)
        }
    }
}
