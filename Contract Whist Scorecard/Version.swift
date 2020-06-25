//
//  Version.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 08/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation

class Version {
    
    public var version = "0.0"
    public var build = 0
    public var lastVersion = "0.0"
    public var lastBuild = 0
    public var blockSync = false
    public var blockAccess = false
    public var message = ""
    public var latestVersion = "0.0"
    public var latestBuild = 0
    
    public func load() {
        // Get previous version and build
        self.lastVersion = UserDefaults.standard.string(forKey: "version")!
        self.lastBuild = UserDefaults.standard.integer(forKey: "build")
        
        // Get saved access / sync / version message / database and flags
        self.blockAccess = UserDefaults.standard.bool(forKey: "blockAccess")
        self.blockSync = UserDefaults.standard.bool(forKey: "blockSync")
        self.message = UserDefaults.standard.string(forKey: "message")!
    }
}
