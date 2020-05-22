//
//  Notification Simulator.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 02/10/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//
//  Simulates invite push notifications for offline testing with rabbitMQ

import Foundation
import UIKit

class NotificationSimulator: CommsBroadcastDelegate {
    
    private var onlineQueueService: CommsClientServiceDelegate!
    
    init() {
    }
    
    deinit {
        self.onlineQueueService.stop()
    }
    
    public func start() {
        if RabbitMQConfig.uriDevMode != "" {
            self.onlineQueueService = CommsHandler.client(proximity: .online, mode: .queue, serviceID: "notification", deviceName: Scorecard.deviceName)
            self.onlineQueueService.broadcastDelegate = self
            let filterEmail = Scorecard.onlineEmail()
            self.onlineQueueService.start(queue: "notifications", filterEmail: filterEmail)
        }
    }
    
    public class func sendNotifications(hostEmail: String, hostName: String, inviteEmails: [String]) {
        if Config.pushNotifications_onlineQueue {
            if let simulator = Utility.appDelegate?.notificationSimulator {
                for email in inviteEmails {
                    simulator.sendNotification(email: email, category: "onlineGame", key: "%1$@ has invited you to play online. Go to 'Online Game' and select 'Join a Game' to see the invitation", args: [hostName, hostEmail, Scorecard.deviceName, email])
                }
            }
        }
    }
    
    private func sendNotification(email: String, category: String, key: String, args: [String]) {
        let data: [String : Any?] = ["category" : category,
                                     "key"      : key,
                                     "args"     : args]
        
        self.onlineQueueService.send("notification", data, matchEmail: email)
    }
    
    internal func didReceiveBroadcast(descriptor: String, data: Any?, from: String) {
        if descriptor == "notification" {
            Utility.mainThread {
                let content = data as! [String : Any?]
                let key = content["key"] as! String
                let args = content["args"] as! [String]
                let message = String(format: key, arguments: args)
                let category = content["category"] as! String
                if category == "onlineGame" {
                    Notifications.processOnlineGameNotification(message: message, args: args, category: category)
                }
            }
        }
    }
}
