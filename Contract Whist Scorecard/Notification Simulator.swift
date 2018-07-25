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

class NotificationSimulator: RabbitMQBroadcastDelegate {
    
    var rabbitMQService: RabbitMQService!
    var queue: RabbitMQQueue!
    
    init() {
    }
    
    deinit {
        self.queue = nil
    }
    
    public func start() {
        if Config.rabbitMQUri != "" {
            let email = Scorecard.onlineEmail()
            self.rabbitMQService = RabbitMQService(purpose: .other, type: .queue, serviceID: Config.rabbitMQUri)
            self.queue = self.rabbitMQService.startQueue(delegate: self, queueUUID: "notifications", email: email)
        } else {
            self.queue = nil
        }
    }
    
    public class func sendNotifications(hostEmail: String, hostName: String, inviteEmails: [String]) {
        if Config.pushNotifications_rabbitMQ {
            for email in inviteEmails {
                Utility.appDelegate?.notificationSimulator.sendNotification(email: email, category: "onlineGame", key: "%1$@ has invited you to play online. Go to 'Online Game' and select 'Join a Game' to see the invitation", args: [hostName, hostEmail, Scorecard.deviceName, email])
            }
        }
    }
    
    private func sendNotification(email: String, category: String, key: String, args: [String]) {
        if self.queue != nil {
            let data: [String : Any?] = ["notification" : ["category" : category,
                                                           "key"      : key,
                                                           "args"     : args]]
            
            self.queue.sendBroadcast(data: data, filterBroadcast: email)
        }
    }
    
    internal func didReceiveBroadcast(descriptor: String, data: Any?, from queue: RabbitMQQueue) {
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
