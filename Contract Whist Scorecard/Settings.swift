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
    public var thisPlayerEmail: String!
    public var onlineGamesEnabled: Bool = false
    public var faceTimeAddress: String!
    public var prefersStatusBarHidden = true
    public var colorTheme = Themes.defaultName
    
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
                lhs.thisPlayerEmail         == rhs.thisPlayerEmail &&
                lhs.onlineGamesEnabled      == rhs.onlineGamesEnabled &&
                lhs.faceTimeAddress         == rhs.faceTimeAddress &&
                lhs.prefersStatusBarHidden  == rhs.prefersStatusBarHidden &&
                lhs.saveStats               == rhs.saveStats &&
                lhs.colorTheme              == rhs.colorTheme)
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
        copy.thisPlayerEmail            = self.thisPlayerEmail
        copy.onlineGamesEnabled         = self.onlineGamesEnabled
        copy.faceTimeAddress            = self.faceTimeAddress
        copy.prefersStatusBarHidden     = self.prefersStatusBarHidden
        copy.colorTheme                 = self.colorTheme
        
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
        
        // Load this player email
        self.thisPlayerEmail = Scorecard.onlineEmail()
        if self.thisPlayerEmail != nil {
            self.faceTimeAddress = UserDefaults.standard.string(forKey: "faceTimeAddress")
        }
        
        // Load online games enabled
        self.onlineGamesEnabled = UserDefaults.standard.bool(forKey: "onlineGamesEnabled")
        
        // Load status bar setting
        self.prefersStatusBarHidden = UserDefaults.standard.bool(forKey: "prefersStatusBarHidden")
        
        // Load color theme setting
        self.colorTheme = UserDefaults.standard.string(forKey: "colorTheme") ?? Themes.defaultName
    }
    
    public func save() {
        
        // Save bonus for making a trick with a 2
        UserDefaults.standard.set(self.bonus2, forKey: "bonus2")
                
        // Save number of cards & bounce number of cards
        UserDefaults.standard.set(self.cards, forKey: "cards")
        UserDefaults.standard.set(self.bounceNumberCards, forKey: "bounceNumberCards")
        
        // Save trump sequence
        UserDefaults.standard.set(self.trumpSequence, forKey: "trumpSequence")
        
        // Save sync enabled flag
        UserDefaults.standard.set(self.syncEnabled, forKey: "syncEnabled")
        
        // Save save history settings
        UserDefaults.standard.set(self.saveHistory, forKey: "saveHistory")
        UserDefaults.standard.set(self.saveLocation, forKey: "saveLocation")
        
        // Save notification setting
        UserDefaults.standard.set(self.receiveNotifications, forKey: "receiveNotifications")
        
        // Save alert settings
        UserDefaults.standard.set(self.alertVibrate, forKey: "alertVibrate")
        
        // Save broadcast setting
        UserDefaults.standard.set(self.allowBroadcast, forKey: "allowBroadcast")
        
        // Save this player setting
        UserDefaults.standard.set(self.thisPlayerEmail, forKey: "thisPlayerEmail")
        
        // Save online game enabled setting
        UserDefaults.standard.set(self.onlineGamesEnabled, forKey: "onlineGamesEnabled")

        // Save facetime address setting
        UserDefaults.standard.set(self.faceTimeAddress, forKey: "faceTimeAddress")
        
        // Save status bar setting
        UserDefaults.standard.set(self.prefersStatusBarHidden, forKey: "prefersStatusBarHidden")
        
        // Save color theme
        UserDefaults.standard.set(self.colorTheme, forKey: "colorTheme")
    }
}
