//
//  Configuration Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 25/09/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation

class Config {
    
    // iCloud database identifer
    public static let iCloudIdentifier = "iCloud.MarcShearer.Contract-Whist-Scorecard"
    
    // In development don't use iCloud to notify invitees - hard-code as below
    public static let _debugNoICloudOnline = false
       
    // Use an online queue instead of/as well as push notifications - best not to do this if connected to network as will double up
    public static let pushNotifications_onlineQueue = true
    
    // Time unit for auto-play testing (in seconds) - card is played every unit
    public static var autoPlayTimeUnit = 0.2
    
    // Auto-connect clients for quicker testing
    public static let autoConnectClient = false
    
    // Auto-start host for quicker testing
    public static let autoStartHost = false
    
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
}
