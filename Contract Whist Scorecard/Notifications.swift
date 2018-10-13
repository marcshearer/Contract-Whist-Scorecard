    //
//  Notifications.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 05/03/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation
import CloudKit

class Notifications {
    
    // MARK: - General routines =================================================================== -
    
    public static func deleteExistingSubscriptions(_ category: String? = nil, completion: (()->())? = nil) {
        let database = CKContainer.default().publicCloudDatabase
        
        database.fetchAllSubscriptions(completionHandler: { (subscriptions, error) in
            if error == nil {
                if let subscriptions = subscriptions {
                    for subscription in subscriptions {
                        if category == nil || subscription.notificationInfo?.category == category! {
                            database.delete(withSubscriptionID: subscription.subscriptionID) { str, error in
                                if error != nil {
                                    return
                                }
                            }
                        }
                    }
                }
            }
            if let completion = completion {
                completion()
            }
        })
    }
    
    // MARK: - High score notifications =================================================================== -

    static func updateHighScoreNotificationRecord(winnerEmail: String, message: String) {
        var found = 0
        
        let cloudContainer = CKContainer.default()
        let publicDatabase = cloudContainer.publicCloudDatabase
        
        let predicate = NSPredicate(format: "email == %@", winnerEmail)
        let query = CKQuery(recordType: "Notifications", predicate: predicate)
        let queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        queryOperation.queuePriority = .veryHigh
        
        queryOperation.recordFetchedBlock = { (record) -> Void in
            found += 1
            if found == 1 {
                // Set record and rewrite
                record.setValue(message , forKey: "message")
                publicDatabase.save(record, completionHandler: { (record, error)  -> Void in })
            } else {
                // Remove - duplicate
                publicDatabase.delete(withRecordID: record.recordID, completionHandler: { (record, error)  -> Void in })
            }
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error == nil && found == 0 {
                // Write a new record
                let record = CKRecord(recordType: "Notifications")
                record.setValue(message , forKey: "message")
                record.setValue(winnerEmail , forKey: "email")
                publicDatabase.save(record, completionHandler: { (record, error)  -> Void in })
            }
        }
        
        // Execute the query
        publicDatabase.add(queryOperation)
        
    }
    
    public static func updateHighScoreSubscriptions(scorecard: Scorecard, completion: (()->())? = nil) {
        // First delete any existing high score subscriptions
        Notifications.deleteExistingSubscriptions("highScore", completion: {
            
            if scorecard.settingSyncEnabled && scorecard.settingReceiveNotifications {
                // Now add a notification for each player on this device
                let database = CKContainer.default().publicCloudDatabase
                for email in scorecard.playerEmailList() {
                    let predicate = NSPredicate(format:"email = %@", email)
                    let subscription = CKQuerySubscription(recordType: "Notifications", predicate: predicate, options: [.firesOnRecordCreation, .firesOnRecordUpdate])
                    
                    let notification = CKSubscription.NotificationInfo()
                    notification.alertLocalizationKey = "%1$@"
                    notification.alertLocalizationArgs = ["message"]
                    notification.category = "highScore"
                    subscription.notificationInfo = notification
                    
                    database.save(subscription) { (result, error) in
                        if let completion = completion {
                            completion()
                        }
                    }
                }
            } else {
                if let completion = completion {
                    completion()
                }
            }
        })
    }
    
    // MARK: - Online game subscriptions ========================================================== -
    
    public static func addOnlineGameSubscription(_ inviteEmail: String, category: String = "onlineGame", completion: (()->())? = nil) {
        // First delete any existing subscriptions
        Notifications.deleteExistingSubscriptions(category, completion: {
            
            // Now add a notification for the player linked to this device
            let database = CKContainer.default().publicCloudDatabase
            let predicate = NSPredicate(format:"inviteEmail = %@", inviteEmail)
            let subscription = CKQuerySubscription(recordType: "Invites", predicate: predicate, options: [.firesOnRecordCreation])
            
            let notification = CKSubscription.NotificationInfo()
            notification.alertLocalizationKey = "%1$@ has invited you to play online. Click this notification to accept, or start the Whist app and go to 'Online Game' and select 'Join a Game' to see the invitation"
            notification.alertLocalizationArgs = ["hostName", "hostEmail", "hostDeviceName", "inviteEmail"]
            notification.category = category
            subscription.notificationInfo = notification
            
            database.save(subscription) { result, error in
                if let completion = completion {
                    completion()
                }
            }

        })
    }
    
    public static func removeTemporaryOnlineGameSubscription(completion: (()->())? = nil) {
        if UserDefaults.standard.bool(forKey: "tempOnlineEmail") {
            deleteExistingSubscriptions("onlineGameTemp", completion: {
                UserDefaults.standard.set(false, forKey: "tempOnlineEmail")
                if completion != nil {
                    completion!()
                }
            })
        }
    }
    
    public static func addTemporaryOnlineGameSubscription(email: String, completion: (()->())? = nil) {
        UserDefaults.standard.set(true, forKey: "tempOnlineEmail")
        addOnlineGameSubscription(email, category: "onlineGameTemp", completion: completion)
    }
    
    public static func processOnlineGameNotification(message: String, args: [String], category: String, confirm: Bool = true) {
        var skipNotification = false
        let viewController = Utility.getActiveViewController()
        if viewController is BroadcastViewController {
            let broadcastViewController = viewController as! BroadcastViewController
            // Check that we're looking to play (rather than share) and emails match
            if broadcastViewController.commsPurpose == .playing {
                if broadcastViewController.thisPlayer == args[3] {
                    // Already in the right place and right player - just send notification
                    NotificationCenter.default.post(name: .onlineInviteReceived, object: self, userInfo: nil)
                }
                // Don't give alert if already joining an online game - even if player didn't match
                skipNotification = true
            }
        } else {
            // Do not interrupt a game in progress
            if let scorecard = Scorecard.getScorecard() {
                if scorecard.gameInProgress {
                    skipNotification = true
                }
            }
        }
        if !skipNotification {
            let message = String(format: "%@ has invited you to join an online game of Contract Whist", arguments: args)
            if let welcomeViewController = Scorecard.getWelcomeViewController() {
                if confirm {
                    viewController?.alertDecision(message, title: "Online Invitation", okButtonText: "Accept", okHandler: {
                        Scorecard.dismissChildren(parent: welcomeViewController, completion: {
                            Notifications.launchOnlineGame(welcomeViewController: welcomeViewController, matchDeviceName: args[2])
                        })
                    }, cancelButtonText: "Decline")
                } else {
                    Notifications.launchOnlineGame(welcomeViewController: welcomeViewController, matchDeviceName: args[2])
                }
            } else {
                viewController?.alertMessage(message, title: "Notification")
            }
        }
    }
    
    public static func launchOnlineGame(welcomeViewController: WelcomeViewController, matchDeviceName: String) {
        welcomeViewController.broadcastTitle = "Join Online Game"
        welcomeViewController.broadcastCommsPurpose = .playing
        welcomeViewController.broadcastMatchDeviceName = matchDeviceName
        welcomeViewController.performSegue(withIdentifier: "showBroadcast", sender: welcomeViewController)
    }
}
