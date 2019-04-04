//
//  Configuration Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 25/09/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation

class Config {
    
    // In development don't use iCloud to notify invitees - hard-code as below
    public static let _debugNoICloudOnline = false
    
    // Choose which rabbitMQ server to use in development mode
    public static let rabbitMQUri_DevMode: RabbitMQUriDevMode = .amqpServer
    
    // Use descriptive rabbitMQ session/connection IDs
    public static let rabbitMQ_DescriptiveIDs = false
    
    // Use rabbitMQ instead of/as well as push notifications - best not to do this if connected to network as will double up
    public static let pushNotifications_rabbitMQ = true
    
    // Queue for log messages - blank to disable
    public static let rabbitMQLogQueue = "WhistLogger"
    
    // Time unit for auto-play testing (in seconds) - card is played every unit
    public static var autoPlayTimeUnit = 0.05
    
    // MARK: - Utility code - should not need to be changed ============================================== -
    
    // MARK: - Debug online games without access to iCloud - always returns invites for Jack and Emma -
    
    public static let debugNoICloudOnline_QueueUUID = "debugNoICloudOnline"
    public static let debugNoICloudOnline_Users = [ InviteReceived(deviceName: "Marc's iPhone",
                                                                   email: "mshearer@waitrose.com",
                                                                   name: "Marc",
                                                                   inviteUUID: Config.debugNoICloudOnline_QueueUUID)]
    
    public static var debugNoICloudOnline: Bool {
        get {
            if Utility.isDevelopment {
                return Config._debugNoICloudOnline
            } else {
                return false
            }
            
        }
    }
    
    // MARK: - rabbitMQ URI string ======================================================================= -
    
    public enum RabbitMQUriDevMode {
        case localhost
        case myServer
        case amqpServer
    }
    
    public static var rabbitMQUri: String {
        get {
            if rabbitMQUri_DevMode == .localhost && Utility.isDevelopment {
                return "amqp://marcshearer:jonathan@localhost/test"
            } else if rabbitMQUri_DevMode == .myServer && Utility.isDevelopment {
                return "amqp://marcshearer:jonathan@marcs-mbp/test"
            } else {
                return Scorecard.settingRabbitMQUri
            }
        }
    }
}
