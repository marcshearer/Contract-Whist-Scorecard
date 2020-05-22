//
//  Settings.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 04/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation

class Settings : Equatable {
    
    public var bonus2 = true
    public var cards = [13, 1]
    public var bounceNumberCards: Bool = false
    public var trumpSequence = ["♣︎", "♦︎", "♥︎", "♠︎", "NT"]
    public var syncEnabled = false
    public var saveHistory = true
    public var saveLocation = true
    public var receiveNotifications = false
    public var allowBroadcast = true
    public var alertVibrate = true
    public var onlinePlayerEmail: String!
    public var faceTimeAddress: String!
    public var prefersStatusBarHidden = true
    
    public var saveStats: Bool = true           // Only used in a game (not saved) - initially set to same as saveHistory but can be overridden
    
    public static func == (lhs: Settings, rhs: Settings) -> Bool {
        return (lhs.bonus2                  == rhs.bonus2 &&
                lhs.cards                   == rhs.cards &&
                lhs.bounceNumberCards       == rhs.bounceNumberCards &&
                lhs.trumpSequence           == rhs.trumpSequence &&
                lhs.syncEnabled             == rhs.syncEnabled &&
                lhs.saveHistory             == rhs.saveHistory &&
                lhs.saveLocation            == rhs.saveLocation &&
                lhs.receiveNotifications    == rhs.receiveNotifications &&
                lhs.allowBroadcast          == rhs.allowBroadcast &&
                lhs.alertVibrate            == rhs.alertVibrate &&
                lhs.onlinePlayerEmail       == rhs.onlinePlayerEmail &&
                lhs.faceTimeAddress         == rhs.faceTimeAddress &&
                lhs.prefersStatusBarHidden  == rhs.prefersStatusBarHidden &&
                lhs.saveStats               == rhs.saveStats)
    }

    public func copy() -> Settings {
        let copy = Settings()
        
        copy.bonus2                     = self.bonus2
        copy.cards                      = self.cards
        copy.bounceNumberCards          = self.bounceNumberCards
        copy.trumpSequence              = self.trumpSequence
        copy.syncEnabled                = self.syncEnabled
        copy.saveHistory                = self.saveHistory
        copy.saveLocation               = self.saveLocation
        copy.receiveNotifications       = self.receiveNotifications
        copy.allowBroadcast             = self.allowBroadcast
        copy.alertVibrate               = self.alertVibrate
        copy.onlinePlayerEmail          = self.onlinePlayerEmail
        copy.faceTimeAddress            = self.faceTimeAddress
        copy.prefersStatusBarHidden     = self.prefersStatusBarHidden
        
        return copy
    }
    
    public func load() {
        
        // Load bonus for making a trick with a 2
        self.bonus2 = UserDefaults.standard.bool(forKey: "bonus2")
                
        // Load number of cards & bounce number of cards
        self.cards = UserDefaults.standard.array(forKey: "cards") as! [Int]
        self.bounceNumberCards = UserDefaults.standard.bool(forKey: "bounceNumberCards")
        
        // Load trump sequence
        self.trumpSequence = UserDefaults.standard.array(forKey: "trumpSequence") as! [String]
        
        // Load sync enabled flag
        self.syncEnabled = UserDefaults.standard.bool(forKey: "syncEnabled")
        
        // Load save history settings
        self.saveHistory = UserDefaults.standard.bool(forKey: "saveHistory")
        self.saveLocation = UserDefaults.standard.bool(forKey: "saveLocation")
        
        // Load notification setting
        self.receiveNotifications = UserDefaults.standard.bool(forKey: "receiveNotifications")
        
        // Load alert settings
        self.alertVibrate = UserDefaults.standard.bool(forKey: "alertVibrate")
        
        // Load broadcast setting
        self.allowBroadcast = UserDefaults.standard.bool(forKey: "allowBroadcast")
        
        // Load Online Game settings
        self.onlinePlayerEmail = Scorecard.onlineEmail()
        if self.onlinePlayerEmail != nil {
            self.faceTimeAddress = UserDefaults.standard.string(forKey: "faceTimeAddress")
        }
        
        // Load status bar setting
        self.prefersStatusBarHidden = UserDefaults.standard.bool(forKey: "prefersStatusBarHidden")
    }
    
}
