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
    case phaseDelete
    case phaseCreate
    case phaseUpdateCloud
    case phaseCheck
    case phaseCompletion
}

class Invite {
    
    private var invitePhase = -1
    private var invitePhases: [InvitePhase]!
    private var hostEmail: String!
    private var hostName: String!
    private var inviteEmails: [String]!
    private var createRecords: [CKRecord]!
    private var deleteRecordIDs: [CKRecord.ID]!
    private var deleteUUIDs: [String]!
    private var inviteUUID: String!
    private var expiryDate: Date!
    private var checkExpiry: Bool!
    private var invited: [InviteReceived]!
    private var completionHandler: ((Bool, String?, [InviteReceived]?)->())!
    
    public func sendInvitation(from hostEmail: String,
                               withName hostName: String,
                               to inviteEmails: [String],
                               inviteUUID: String,
                               deleteFirst: Bool = true,
                               completion: @escaping (Bool, String?, [InviteReceived]?)->()) {
        

        self.completionHandler = completion
        
        if Config.debugNoICloudOnline {
            NotificationSimulator.sendNotifications(hostEmail: hostEmail, hostName: hostName, inviteEmails: inviteEmails)
            self.completion(true, nil, nil)
            return
        }
        
        self.hostEmail = hostEmail
        self.hostName = hostName
        self.inviteEmails = inviteEmails
        self.inviteUUID = inviteUUID
        self.expiryDate = Date(timeInterval: 600, since: Date())
        self.invited = []
        self.invitePhases = [.phaseDelete,
                             .phaseCreate,
                             .phaseUpdateCloud,
                             .phaseCompletion]
        
        
        
        self.controller()
    }
    
    public func cancelInvitation(from hostEmail: String,
                                 completion: @escaping (Bool, String?, [InviteReceived]?)->()) {
        
        self.completionHandler = completion
        
        if Config.debugNoICloudOnline {
            self.completion(true, nil, nil)
            return
        }
        
        self.hostEmail = hostEmail
        self.invited = []
        self.invitePhases = [.phaseDelete,
                             .phaseUpdateCloud,
                             .phaseCompletion]
        self.controller()
    }
    
    func checkInvitations(to inviteEmail: String, checkExpiry: Bool = true, completion: @escaping (Bool, String?, [InviteReceived]?)->()) {
        
        self.completionHandler = completion
        
        if Config.debugNoICloudOnline {
            self.completion(true, nil, Config.debugNoICloudOnline_Users)
            return
        }
        
        self.inviteEmails = [inviteEmail]
        self.checkExpiry = checkExpiry
        self.invited = []
        self.invitePhases = [.phaseCheck,
                             .phaseCompletion]
        self.controller()
    }
    
    func controller() {
        
        invitePhase += 1
        
        if invitePhase < self.invitePhases.count {
            // Next phase
            switch invitePhases[invitePhase] {
            case .phaseDelete:
                self.deleteInviteRecords(hostEmail: self.hostEmail)
            case .phaseCreate:
                self.createInviteRecords(hostEmail: self.hostEmail,
                                         hostName: self.hostName,
                                         expiryDate: self.expiryDate,
                                         inviteUUID: self.inviteUUID,
                                         inviteEmails: self.inviteEmails)
            case .phaseUpdateCloud:
                self.sendUpdatedRecords(createRecords: self.createRecords, deleteRecordIDs: self.deleteRecordIDs, deleteUUIDs: self.deleteUUIDs)
            case .phaseCheck:
                self.checkInviteRecords(inviteEmails: self.inviteEmails, checkExpiry: self.checkExpiry)
            case .phaseCompletion:
                self.completion(true, nil, self.invited)
            }
        }
    }
    
    func deleteInviteRecords(hostEmail: String) {
        // Get any existing invite records and queue
        var queryOperation: CKQueryOperation
        var predicate: NSPredicate!
        deleteRecordIDs = []
        deleteUUIDs = []
        
        // Fetch host record from cloud
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        predicate = NSPredicate(format: "hostEmail == %@", hostEmail)
        let query = CKQuery(recordType: "Invites", predicate: predicate)
        queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        queryOperation.desiredKeys = ["hostEmail", "inviteUUID"]
        queryOperation.queuePriority = .veryHigh
        
        queryOperation.recordFetchedBlock = { (record) -> Void in
            self.deleteRecordIDs.append(record.recordID)
            self.deleteUUIDs.append(Utility.objectString(cloudObject: record, forKey: "inviteUUID"))
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            Utility.mainThread { [unowned self] in
                if error != nil || cursor != nil {
                    var message = "Unable to connect to cloud"
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
    
    func createInviteRecords(hostEmail: String, hostName: String, expiryDate: Date, inviteUUID: String, inviteEmails: [String]) {
        
        createRecords = []
        
        for inviteEmail in inviteEmails {
            
            let inviteRecord = CKRecord(recordType: "Invites")
            
            inviteRecord.setValue(hostEmail, forKey: "hostEmail")
            inviteRecord.setValue(hostName, forKey: "hostName")
            inviteRecord.setValue(Scorecard.deviceName, forKey: "hostDeviceName")
            inviteRecord.setValue(inviteEmail, forKey: "inviteEmail")
            inviteRecord.setValue(expiryDate, forKey: "expires")
            inviteRecord.setValue(inviteUUID, forKey: "inviteUUID")
            
            // Append to records to send
            self.createRecords.append(inviteRecord)
        }
        
        // Link back to controller for next phase
        self.controller()

    }
    
    func sendUpdatedRecords(createRecords: [CKRecord]!, deleteRecordIDs: [CKRecord.ID]!, deleteUUIDs: [String]!) {
        // Now send back new / updated records
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        
        let uploadOperation = CKModifyRecordsOperation(recordsToSave: createRecords, recordIDsToDelete: deleteRecordIDs)
        uploadOperation.isAtomic = false
        uploadOperation.queuePriority = .veryHigh
        uploadOperation.database = publicDatabase
        
        // Assign a completion handler
        uploadOperation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecords: [CKRecord.ID]?, error: Error?) -> Void in
            Utility.mainThread {
                if error != nil {
                    self.completion(false, "Unable to connect to iCloud")
                    return
                }
                
                //Send simulated notifications through network
                if self.inviteEmails != nil {
                    NotificationSimulator.sendNotifications(hostEmail: self.hostEmail, hostName: self.hostName, inviteEmails: self.inviteEmails)
                }
                
                // Log invites sent
                if self.inviteEmails != nil {
                    for email in self.inviteEmails {
                        Utility.debugMessage("invite", "To \(email) - \(Utility.dateString(self.expiryDate, format: "dd/MM/yyyy HH:mm:ss.ff", localized: false)) - \(self.inviteUUID!)")
                    }
                }
                
                // Link back to controller for next phase
                self.controller()
            }
        }
        
        // Add the operation to an operation queue to execute it
        OperationQueue().addOperation(uploadOperation)
    }
    
    func checkInviteRecords(inviteEmails: [String], checkExpiry: Bool) {
        // Get any existing invite records and queue
        var queryOperation: CKQueryOperation
        var predicate: NSPredicate!

        // Fetch host record from cloud
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        var expiry: NSDate?
        if checkExpiry {
            expiry = NSDate()
            predicate = NSPredicate(format: "inviteEmail == %@ AND expires >= %@", inviteEmails[0], expiry!)
        } else {
            predicate = NSPredicate(format: "inviteEmail == %@", inviteEmails[0])
        }
        let query = CKQuery(recordType: "Invites", predicate: predicate)
        queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        queryOperation.desiredKeys = ["hostEmail", "hostName", "hostDeviceName", "expires", "inviteUUID"]
        queryOperation.queuePriority = .veryHigh
        
        queryOperation.recordFetchedBlock = { (record) -> Void in
            let hostEmail = Utility.objectString(cloudObject: record, forKey: "hostEmail")!
            let hostName = Utility.objectString(cloudObject: record, forKey: "hostName")!
            let hostDeviceName = Utility.objectString(cloudObject: record, forKey: "hostDeviceName")!
            let inviteUUID = Utility.objectString(cloudObject: record, forKey: "inviteUUID")!
            let expires = Utility.objectDate(cloudObject: record, forKey: "expires")!
    
            self.invited.append(InviteReceived(deviceName: hostDeviceName,
                                               email: hostEmail,
                                               name: hostName,
                                               inviteUUID: inviteUUID))
            Utility.debugMessage("invite", "From \(hostEmail) - \((!checkExpiry ? "no expiry" : Utility.dateString(expires as Date, format: "dd/MM/yyyy HH:mm:ss.ff", localized: false))) - \(inviteUUID)")
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
        }
    }
}

class InviteReceived {
    var deviceName: String
    var email: String
    var name: String
    var inviteUUID: String
    
    init(deviceName: String, email: String, name: String, inviteUUID: String) {
        self.deviceName = deviceName
        self.email = email
        self.name = name
        self.inviteUUID = inviteUUID
    }
}
