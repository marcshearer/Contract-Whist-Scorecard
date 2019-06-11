//
//  DataAdmin.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 25/02/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

class DataAdmin {
    
    class func deleteCloudDatabase(from viewController: UIViewController) {
        
        viewController.alertDecision("This will delete all player, game and participant records in the iCloud database permanently. Are you really sure you want to do this?", title: "WARNING - DATA WILL BE ERASED PERMANENTLY", okButtonText: "Delete", okHandler: {
        
            let alertWaitController = viewController.alertWait("Deleting iCloud database")
            
            DataAdmin.deleteAllCloudRecords(viewController: viewController, recordType: "Participants", completion: {
                
                DataAdmin.deleteAllCloudRecords(viewController: viewController, recordType: "Games", completion: {
                    
                    if DataAdmin.resetGameRecordIds(viewController: viewController) {
                    
                        DataAdmin.deleteAllCloudRecords(viewController: viewController, recordType: "Players", completion: {
                            
                            UserDefaults.standard.removeObject(forKey: "confirmedSyncDate")
                            alertWaitController.dismiss(animated: true, completion: nil)
                            viewController.alertMessage("All records deleted successfully", title: "Complete")
                        })
                    }
                })
            })
        })
    }
    
    class func deleteAllCloudRecords(viewController: UIViewController, recordType: String, cursor: CKQueryOperation.Cursor! = nil, completion: @escaping ()->()) {
        var recordIdList: [CKRecord.ID] = []
        var errors = false
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        var queryOperation:CKQueryOperation
        
        if cursor == nil {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        } else {
            queryOperation = CKQueryOperation(cursor: cursor, qos: .userInteractive)
        }

        queryOperation.queuePriority = .veryHigh
        
        queryOperation.recordFetchedBlock = { (record) -> Void in
            recordIdList.append(record.recordID)
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error != nil {
                viewController.alertMessage("Error getting all '\(recordType)' records")
            } else {
                let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIdList)
                
                deleteOperation.isAtomic = true
                deleteOperation.database = publicDatabase
                
                deleteOperation.perRecordCompletionBlock = { (savedRecord: CKRecord, error: Error?) -> Void in
                    if error != nil {
                        errors = true
                    }
                }
                
                // Assign a completion handler
                deleteOperation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecords: [CKRecord.ID]?, error: Error?) -> Void in
                    if error != nil {
                        errors = true
                    }
                    
                    if errors {
                        viewController.alertMessage("Error deleting all '\(recordType)' records")
                    } else {
                        if cursor != nil {
                            // More to come - recurse
                            deleteAllCloudRecords(viewController: viewController, recordType: recordType, cursor: cursor, completion: completion)
                        } else {
                            // All done - can complete
                            completion()
                        }
                    }
                }
                
                // Add the operation to an operation queue to execute it
                OperationQueue().addOperation(deleteOperation)
            }
        }
        
        // Execute the query
        publicDatabase.add(queryOperation)
    }
    
    class func resetGameRecordIds(viewController: UIViewController) -> Bool {
        let history = History(getParticipants: true, includeBF: true)
        if !CoreData.update(updateLogic: {
            for historyGame in history.games {
                historyGame.gameMO.syncRecordID = nil
                historyGame.gameMO.syncDate = nil
                for historyParticipant in historyGame.participant {
                    historyParticipant.participantMO.syncRecordID = nil
                    historyParticipant.participantMO.syncDate = nil
                }
            }
        }) {
            viewController.alertMessage("Error resetting local game cloud record IDs")
            return false
        }
        return true
    }
   
    class func patchLocalDatabase(from viewController: UIViewController, silent: Bool = false) {
        var participantsUpdated = 0
        let history = History(getParticipants: true, includeBF: false)
        _ = CoreData.update(updateLogic: {
            for historyGame in history.games {
                if historyGame.participant[0].handsPlayed == 25 {
                    var nonBonusScore:Int16 = 0
                    for historyParticipant in historyGame.participant {
                        nonBonusScore += historyParticipant.totalScore - (historyParticipant.handsMade * 10)
                    }
                    let totalTwos = Int16((nonBonusScore - 91) / 10)
                    var twosAllocated:Int16 = 0
                    for participantNumber in 1...historyGame.participant.count {
                        let historyParticipant = historyGame.participant[participantNumber - 1]
                        let myNonBonusScore:Int16 = historyParticipant.totalScore - (historyParticipant.handsMade * 10)
                        var twosMade:Int16
                        if participantNumber == historyGame.participant.count {
                            twosMade = totalTwos - twosAllocated
                        } else {
                            twosMade = Utility.roundQuotient(myNonBonusScore * totalTwos, nonBonusScore)
                        }
                        twosAllocated += twosMade
                        historyParticipant.participantMO.handsPlayed = 13
                        historyParticipant.participantMO.twosMade = twosMade
                        participantsUpdated += 1
                    }
                }
            }
        })
        if !silent {
            viewController.alertMessage("Hands played and twos made patched locally - \(participantsUpdated) participants updated", title: "Complete")
        }
    }
    
    class func resetSyncRecordIDs(from viewController: UIViewController, silent: Bool = false) {
        var participantsUpdated = 0
        let history = History(getParticipants: true, includeBF: false)
        _ = CoreData.update(updateLogic: {
            for historyGame in history.games {
                historyGame.gameMO.syncRecordID = nil
                historyGame.gameMO.syncDate = nil
                for participantNumber in 1...historyGame.participant.count {
                    let historyParticipant = historyGame.participant[participantNumber - 1]
                    historyParticipant.participantMO.syncRecordID = nil
                    historyParticipant.participantMO.syncDate = nil
                    participantsUpdated += 1
                }
            }
        })
        if !silent {
            viewController.alertMessage("Sync Record IDs reset - \(participantsUpdated) participants updated", title: "Complete")
        }
    }
    
    class func removeDuplicates(from viewController: UIViewController) {
        var gamesDeleted = 0
        var participantsDeleted = 0
        let history = History(getParticipants: true, includeBF: true)
        for historyGame in history.games {
            if historyGame.duplicate {
                if !CoreData.update(updateLogic: {
                    var lastEmail: String! = nil
                    historyGame.participant.sort(by: { $0.participantMO!.email! < $1.participantMO!.email! })
                    for historyParticipant in historyGame.participant {
                        if lastEmail != nil && lastEmail == historyParticipant.participantMO.email {
                            CoreData.delete(record: historyParticipant.participantMO)
                            participantsDeleted += 1
                        }
                        lastEmail = historyParticipant.participantMO.email
                    }
                    CoreData.delete(record: historyGame.gameMO)
                    gamesDeleted += 1
                }) {
                    viewController.alertMessage("Error removing duplicates locally")
                    return
                }
            }
        }
        viewController.alertMessage("Duplicates removed successfully - \(gamesDeleted) games and \(participantsDeleted) participants deleted", title: "Complete")
    }
    
    class func resetUserDefaults() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults.standard.synchronize()
    }
    
    class func resetCoreData() {
        DataAdmin.resetCoreDataEntity(entityName: "Game")
        DataAdmin.resetCoreDataEntity(entityName: "Participant")
        DataAdmin.resetCoreDataEntity(entityName: "Player")
    }
    
    class func resetCoreDataEntity(entityName: String) {
        if let context = CoreData.context {
            
            let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)
            do {
                try context.execute(deleteRequest)
                try context.save()
            } catch {
                fatalError("There was an error")
            }
        }
    }
}
