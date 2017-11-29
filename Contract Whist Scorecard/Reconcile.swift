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
    weak var delegate: ReconcileDelegate?
    
    // Main state properties
    private var scorecard: Scorecard!
    
    // Local state properties
    var playerMOList: [PlayerMO]!
    
    // MARK: - Public class methods ==================================================================== -
    
    func initialise(scorecard: Scorecard) {
        self.scorecard = scorecard
    }
    
    public func reconcilePlayers(playerMOList: [PlayerMO]) {
        self.playerMOList = playerMOList
        
        // First synchronise
        if scorecard.settingSyncEnabled {
            if scorecard.sync.connect() {
                scorecard.sync.delegate = self
                self.reconcileMessage("Sync in progress")
                // Note this starts synchronisation - reconciliation is then initiated from the completion handler
                scorecard.sync.synchronise()
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
        let participantList = History.getParticipantRecordsForPlayer(playerEmail: playerMO.email!)
        
        return CoreData.update(updateLogic: {
            
       
            // Zero values
            playerMO.gamesPlayed = 0
            playerMO.gamesWon = 0
            playerMO.handsPlayed = 0
            playerMO.handsMade = 0
            playerMO.twosMade = 0
            playerMO.totalScore = 0
            playerMO.datePlayed = nil
            
            // zero synced values
            playerMO.syncGamesPlayed = 0
            playerMO.syncGamesWon = 0
            playerMO.syncHandsPlayed = 0
            playerMO.syncHandsMade = 0
            playerMO.syncTwosMade = 0
            playerMO.syncTotalScore = 0

            for participantMO in participantList {
                
                // Add to scores
                playerMO.gamesPlayed += Int64(participantMO.gamesPlayed)
                playerMO.gamesWon += Int64(participantMO.gamesWon)
                playerMO.handsPlayed += Int64(participantMO.handsPlayed)
                playerMO.handsMade += Int64(participantMO.handsMade)
                playerMO.twosMade += Int64(participantMO.twosMade)
                playerMO.totalScore += Int64(participantMO.totalScore)
                
                if playerMO.syncRecordID != nil {
                    // Already synced so add to synced totals
                    playerMO.syncGamesPlayed += Int64(participantMO.gamesPlayed)
                    playerMO.syncGamesWon += Int64(participantMO.gamesWon)
                    playerMO.syncHandsPlayed += Int64(participantMO.handsPlayed)
                    playerMO.syncHandsMade += Int64(participantMO.handsMade)
                    playerMO.syncTwosMade += Int64(participantMO.twosMade)
                    playerMO.syncTotalScore += Int64(participantMO.totalScore)
                }
                
                // Update max scores
                if Int64(participantMO.totalScore) > playerMO.maxScore && participantMO.gamesPlayed == 1 {
                    playerMO.maxScore = Int64(participantMO.totalScore)
                    playerMO.maxScoreDate = participantMO.datePlayed
                }
                if Int64(participantMO.handsMade) > playerMO.maxMade && participantMO.gamesPlayed == 1 {
                    playerMO.maxMade = Int64(participantMO.handsMade)
                    playerMO.maxMadeDate = participantMO.datePlayed
                }
                if Int64(participantMO.twosMade) > playerMO.maxTwos && participantMO.gamesPlayed == 1 {
                    playerMO.maxTwos = Int64(participantMO.twosMade)
                    playerMO.maxTwosDate = participantMO.datePlayed
                }
                
                // Update date last played
                if playerMO.datePlayed == nil || participantMO.datePlayed! as Date > playerMO.datePlayed! as Date {
                    playerMO.datePlayed = participantMO.datePlayed
                }
            }
        })
    }
    
    // MARK: - Sync class delegate methods ===================================================================== -
    
    func syncMessage(_ message: String) {
        Utility.mainThread {
        }
    }
    
    func syncAlert(_ message: String, completion: @escaping ()->()) {
        completion()
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
    
    func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
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
        let delegate = self.delegate!
        
        // Disconnect
        self.delegate = nil
        
        // Call completion delegate
        delegate.reconcileCompletion(errors)
        
    }
}
