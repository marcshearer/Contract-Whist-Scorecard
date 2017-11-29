//
//  Upgrade.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 08/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//
// Contains logic to upgrade a device from one version to another

import Foundation
import UIKit
import CoreData

class Upgrade {
    
    class func upgradeTo11(from: UIViewController, scorecard: Scorecard) -> Bool {
        // Note this should only be run once on a device that contains all data locally and then synced
        // Other devices should be initialised and re-installed
        var updated = false
        
        if !scorecard.iCloudUserIsMe {
            from.alertMessage("This version upgrade is not allowed. Delete the app and re-install it.")
        }
        
        guard let context = Scorecard.context else { return false }
        
        let historyGames: [GameMO] = CoreData.fetch(from: "Game")
        
        for gameMO in historyGames {
            
            let gameUUID = (gameMO.deviceUUID == "" ? "B/F" : UUID().uuidString)
            
            let historyParticipants: [ParticipantMO] = CoreData.fetch(from: "Participant",
                                                                      filter: NSPredicate(format: "deviceUUID = %@ and datePlayed = %@",
                                                                                          gameMO.deviceUUID!, gameMO.datePlayed! as NSDate))
            
            // Set game UUID and local date created
            gameMO.gameUUID = gameUUID
            gameMO.localDateCreated = gameMO.datePlayed
            
            // Reset sync record ID & date
            gameMO.syncDate = nil
            gameMO.syncRecordID = nil
            
            if historyParticipants.count > 0 {
            
                for participantMO in historyParticipants {
                    
                    // Set participant game UUID and local date created
                    participantMO.gameUUID = gameUUID
                    participantMO.localDateCreated = gameMO.datePlayed
                    
                    // Reset sync record ID & date
                    participantMO.syncDate = nil
                    participantMO.syncRecordID = nil
                    
                }
            }
            
            // Save to persistent store
            do {
                try context.save()
            } catch {
                return false
            }
            updated = true
        }
        
        if scorecard.playerList.count > 0 {
            
            for playerMO in scorecard.playerList {
                // Set date created locally
                playerMO.localDateCreated = playerMO.dateCreated
                
                // Reset synced values
                playerMO.syncGamesPlayed = 0
                playerMO.syncGamesPlayed = 0
                playerMO.syncGamesWon = 0
                playerMO.syncTotalScore = 0
                playerMO.syncHandsPlayed = 0
                playerMO.syncHandsMade = 0
                playerMO.syncTwosMade = 0
                
                // Reset sync record ID & date
                playerMO.syncDate = nil
                playerMO.syncRecordID = nil
            }
            
            // Save to persistent store
            do {
                try context.save()
            } catch {
                return false
            }
            updated = true
        }
        
        if updated {
            from.alertMessage("Now clear the iCloud database and sync this device")
        }
        
        // Reset last successful sync date so everything syncs
        UserDefaults.standard.set(Date(timeIntervalSinceReferenceDate: -1), forKey: "confirmedSyncDate")
        
        // Migrate syncGroup to new syncEnabled
        let syncGroup = UserDefaults.standard.string(forKey: "syncGroup")
        if syncGroup != nil {
            if syncGroup != "" {
                scorecard.settingSyncEnabled = true
                UserDefaults.standard.set(true, forKey: "syncEnabled")
            }
            UserDefaults.standard.removeObject(forKey: "syncGroup")
        }
        
        return true
    }
}
