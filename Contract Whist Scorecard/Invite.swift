	//
//  Invite.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 16/09/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

enum InvitePhase {
    case phaseFindRecordsToDelete
    case phaseSetupRecordsToCreate
    case phaseUpdateCloud
    case phaseCheckInvitations
    case phaseCompletion
}

class Invite {
    
    private var invitePhase = -1
    private var invitePhases: [InvitePhase]!
    private var hostPlayerUUID: String!
    private var hostName: String!
    private var invitePlayerUUIDs: [String]!
    private var createRecords: [CKRecord]!
    private var deleteRecordIDs: [CKRecord.ID]!
    private var deleteUUIDs: [String]!
    private var inviteUUID: String!
    private var expiryDate: Date!
    private var checkExpiry: Bool!
    private var matchDeviceName: String?
    private var invited: [InviteReceived]!
    private var completionHandler: ((Bool, String?, [InviteReceived]?)->())!
    
    public func sendInvitation(from hostPlayerUUID: String,
                               withName hostName: String,
                               to invitePlayerUUIDs: [String],
                               inviteUUID: String,
                               deleteFirst: Bool = true,
                               completion: @escaping (Bool, String?, [InviteReceived]?)->()) {
        

        self.completionHandler = completion
        
        if Config.debugNoICloudOnline {
            NotificationSimulator.sendNotifications(hostPlayerUUID: hostPlayerUUID, hostName: hostName, invitePlayerUUIDs: invitePlayerUUIDs)
            self.completion(true, nil, nil)
            return
        }
        
        self.hostPlayerUUID = hostPlayerUUID
        self.hostName = hostName
        self.invitePlayerUUIDs = invitePlayerUUIDs
        self.inviteUUID = inviteUUID
        self.expiryDate = Date(timeInterval: 600, since: Date())
        self.invited = []
        self.invitePhases = [.phaseFindRecordsToDelete,
                             .phaseSetupRecordsToCreate,
                             .phaseUpdateCloud,
                             .phaseCompletion]
        
        
        
        self.controller()
    }
    
    public func cancelInvitation(from hostPlayerUUID: String,
                                 completion: @escaping (Bool, String?, [InviteReceived]?)->()) {
        
        self.completionHandler = completion
        
        if Config.debugNoICloudOnline {
            self.completion(true, nil, nil)
            return
        }
        
        self.hostPlayerUUID = hostPlayerUUID
        self.invited = []
        self.invitePhases = [.phaseFindRecordsToDelete,
                             .phaseUpdateCloud,
                             .phaseCompletion]
        self.controller()
    }
    
    func checkInvitations(to invitePlayerUUID: String, checkExpiry: Bool = true, matchDeviceName: String? = nil, completion: @escaping (Bool, String?, [InviteReceived]?)->()) {
        
        self.completionHandler = completion
        
        if Config.debugNoICloudOnline {
            self.completion(true, nil, Config.debugNoICloudOnline_Users)
            return
        }
        
        self.invitePlayerUUIDs = [invitePlayerUUID]
        self.checkExpiry = checkExpiry
        self.matchDeviceName = matchDeviceName
        self.invited = []
        self.invitePhases = [.phaseCheckInvitations,
                             .phaseCompletion]
        self.controller()
    }
    
    func controller() {
        
        invitePhase += 1
        
        if invitePhase < self.invitePhases.count {
            // Next phase
            switch invitePhases[invitePhase] {
            case .phaseFindRecordsToDelete:
                self.FindInviteRecordsToDelete(hostPlayerUUID: self.hostPlayerUUID)
            case .phaseSetupRecordsToCreate:
                self.SetupInviteRecordsToCreate(hostPlayerUUID: self.hostPlayerUUID,
                                         hostName: self.hostName,
                                         expiryDate: self.expiryDate,
                                         inviteUUID: self.inviteUUID,
                                         invitePlayerUUIDs: self.invitePlayerUUIDs)
            case .phaseUpdateCloud:
                self.sendUpdatedRecords(createRecords: self.createRecords, deleteRecordIDs: self.deleteRecordIDs, deleteUUIDs: self.deleteUUIDs)
            case .phaseCheckInvitations:
                self.checkInviteRecords(invitePlayerUUIDs: self.invitePlayerUUIDs, checkExpiry: self.checkExpiry, matchDeviceName: self.matchDeviceName)
            case .phaseCompletion:
                self.completion(true, nil, self.invited)
            }
        }
    }
    
    func FindInviteRecordsToDelete(hostPlayerUUID: String) {
        // Get any existing invite records and queue
        var queryOperation: CKQueryOperation
        var predicate: NSPredicate!
        deleteRecordIDs = []
        deleteUUIDs = []
        
        // Fetch host record from cloud
        let cloudContainer = Sync.cloudKitContainer
        let publicDatabase = cloudContainer.publicCloudDatabase
        predicate = NSPredicate(format: "hostPlayerUUID == %@", hostPlayerUUID)
        let query = CKQuery(recordType: "Invites", predicate: predicate)
        queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        queryOperation.desiredKeys = ["hostPlayerUUID", "inviteUUID"]
        queryOperation.queuePriority = .veryHigh
        
        queryOperation.recordFetchedBlock = { (record) -> Void in
            self.deleteRecordIDs.append(record.recordID)
            self.deleteUUIDs.append(Utility.objectString(cloudObject: record, forKey: "inviteUUID"))
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            Utility.mainThread { [weak self] in
                if error != nil || cursor != nil {
                    var message = "Unable to connect to cloud"
                    if Scorecard.adminMode {
                        message = message + " " + error.debugDescription
                    }
                    self?.completion(false, message)
                    return
                }
                
                // Link back to controller for next phase
                self?.controller()
            }
        }
        
        // Execute the download query
        publicDatabase.add(queryOperation)
    }
    
    func SetupInviteRecordsToCreate(hostPlayerUUID: String, hostName: String, expiryDate: Date, inviteUUID: String, invitePlayerUUIDs: [String]) {
        
        createRecords = []
        
        for invitePlayerUUID in invitePlayerUUIDs {
            let recordID = CKRecord.ID(recordName: "Invites-\(hostPlayerUUID)+\(invitePlayerUUID)+\(inviteUUID)")
            let inviteRecord = CKRecord(recordType: "Invites", recordID: recordID)
            
            inviteRecord.setValue(hostPlayerUUID, forKey: "hostPlayerUUID")
            inviteRecord.setValue(hostName, forKey: "hostName")
            inviteRecord.setValue(Scorecard.deviceName, forKey: "hostDeviceName")
            inviteRecord.setValue(invitePlayerUUID, forKey: "invitePlayerUUID")
            inviteRecord.setValue(expiryDate, forKey: "expires")
            inviteRecord.setValue(inviteUUID, forKey: "inviteUUID")
            
            // Append to records to send
            self.createRecords.append(inviteRecord)
            
            // Remove from deletion list if necessary
            if let index = self.deleteRecordIDs.firstIndex(where: {$0.recordName == recordID.recordName}) {
                self.deleteRecordIDs.remove(at: index)
            }
        }
        
        // Link back to controller for next phase
        self.controller()

    }
    
    func sendUpdatedRecords(createRecords: [CKRecord]!, deleteRecordIDs: [CKRecord.ID]!, deleteUUIDs: [String]!) {
        // Now send back new / updated records
        let cloudContainer = Sync.cloudKitContainer
        let publicDatabase = cloudContainer.publicCloudDatabase
        
        let uploadOperation = CKModifyRecordsOperation(recordsToSave: createRecords, recordIDsToDelete: deleteRecordIDs)
        uploadOperation.isAtomic = false
        uploadOperation.queuePriority = .veryHigh
        uploadOperation.database = publicDatabase
        uploadOperation.savePolicy = .allKeys
        
        // Assign a completion handler
        uploadOperation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecords: [CKRecord.ID]?, error: Error?) -> Void in
            Utility.mainThread {
                if error != nil {
                    self.completion(false, "Unable to connect to iCloud")
                    return
                }
                
                //Send simulated notifications through network
                if self.invitePlayerUUIDs != nil {
                    NotificationSimulator.sendNotifications(hostPlayerUUID: self.hostPlayerUUID, hostName: self.hostName, invitePlayerUUIDs: self.invitePlayerUUIDs)
                }
                
                // Log invites sent
                if self.invitePlayerUUIDs != nil {
                    for playerUUID in self.invitePlayerUUIDs {
                        Utility.debugMessage("invite", "To \(playerUUID) - \(Utility.dateString(self.expiryDate, format: "dd/MM/yyyy HH:mm:ss.ff", localized: false)) - \(self.inviteUUID!)")
                    }
                }
                
                // Link back to controller for next phase
                self.controller()
            }
        }
        
        // Add the operation to an operation queue to execute it
        OperationQueue().addOperation(uploadOperation)
    }
    
    func checkInviteRecords(invitePlayerUUIDs: [String], checkExpiry: Bool, matchDeviceName: String?) {
        // Get any existing invite records and queue
        var queryOperation: CKQueryOperation
        
        // Fetch host record from cloud
        let cloudContainer = Sync.cloudKitContainer
        let publicDatabase = cloudContainer.publicCloudDatabase
        
        // Setup filter
        var predicates = [NSPredicate(format: "invitePlayerUUID == %@", invitePlayerUUIDs[0])]
        if checkExpiry {
            predicates.append(NSPredicate(format: "expires >= %@", NSDate()))
        }
        if let matchDeviceName = matchDeviceName {
            predicates.append(NSPredicate(format: "hostDeviceName == %@", matchDeviceName))
        }
        
        // Setup query
        let query = CKQuery(recordType: "Invites", predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates))
        queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        queryOperation.desiredKeys = ["hostPlayerUUID", "hostName", "hostDeviceName", "expires", "inviteUUID"]
        queryOperation.queuePriority = .veryHigh
        
        queryOperation.recordFetchedBlock = { (record) -> Void in
            let hostPlayerUUID = Utility.objectString(cloudObject: record, forKey: "hostPlayerUUID")!
            let hostName = Utility.objectString(cloudObject: record, forKey: "hostName")!
            let hostDeviceName = Utility.objectString(cloudObject: record, forKey: "hostDeviceName")!
            let inviteUUID = Utility.objectString(cloudObject: record, forKey: "inviteUUID")!
            let expires = Utility.objectDate(cloudObject: record, forKey: "expires")!
    
            self.invited.append(InviteReceived(deviceName: hostDeviceName,
                                               playerUUID: hostPlayerUUID,
                                               name: hostName,
                                               inviteUUID: inviteUUID))
            Utility.debugMessage("invite", "From \(hostPlayerUUID) - \((!checkExpiry ? "no expiry" : Utility.dateString(expires as Date, format: "dd/MM/yyyy HH:mm:ss.ff", localized: false))) - \(inviteUUID)")
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            Utility.mainThread {
                if error != nil || cursor != nil {
                    var message = "Unable to connect to iCloud"
                    if Scorecard.adminMode {
                        message = message + " " + error.debugDescription
                    }
                    self.completion(false, message)
                    return
                }
                // Link back to controller for next phase
                self.controller()
            }
        }
    
        // Execute the download query
        publicDatabase.add(queryOperation)
    }
    
    func completion(_ success: Bool, _ message: String? = nil, _ invited: [InviteReceived]? = nil) {
        Utility.mainThread {
            self.completionHandler?(success, message, invited)
            self.completionHandler = nil
        }
    }
}

class InviteReceived {
    var deviceName: String
    var playerUUID: String
    var name: String
    var inviteUUID: String
    
    init(deviceName: String, playerUUID: String, name: String, inviteUUID: String) {
        self.deviceName = deviceName
        self.playerUUID = playerUUID
        self.name = name
        self.inviteUUID = inviteUUID
    }
}
