//
//  Whist Test Utility Class.swift
//  Contract Whist Scorecard UI Tests
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import XCTest

extension Contract_Whist_Scorecard_UI_Tests {
    
    func selectOption(_ option: String, timeout: TimeInterval = 10) {
        // Selects option from home page
        self.tap(app.tables.buttons[option], timeout: timeout)
        self.tapIfExists(app.alerts["Warning"].buttons["Continue"])
    }
    
    func tryOption(_ option: String, timeout: TimeInterval = 10) -> Bool {
        // Selects option from home page if available
        if app.tables.buttons[option].isEnabled {
            self.tap(app.tables.buttons[option], timeout: timeout)
            self.tapIfExists(app.alerts["Warning"].buttons["Continue"])
            return true
        } else {
            return false
        }
    }
    
    func selectSettings() {
        self.tap(app.navigationBars["Contract Whist"].buttons["settings"])
    }
    
    func returnHome(timeout: TimeInterval = 10) {
        self.tap(app.navigationBars.buttons["home"], timeout: timeout)
        waitForHome()
    }
    
    func waitForHome(timeout: TimeInterval = 10) {
        self.waitFor(app.tables.buttons["New Game"], timeout: timeout)
    }
    
    func deletePlayer(_ name: String) {
        // Assumes you are already in Player Stats and player cell exists
        let playerLabel = app.collectionViews.staticTexts[name]
        if playerLabel.exists {
            self.tap(playerLabel)
            self.tap(app.navigationBars[name].buttons["Delete"])
            self.tap(app.alerts["Warning"].buttons["Confirm"])
        }
    }
    
    func createNewPlayer(name: String, email: String) {
        // Assumes you are in the player selection screen
        self.tap(app.collectionViews.staticTexts["New"])
        self.tap(app.sheets["Add Player"].buttons["Create player manually"])
        // Enter new player details
        let nameTextField = app.tables.textFields["Player name - Must not be blank"]
        self.typeText(nameTextField, name)
        let uniqueIdentifierTextField = app.tables.textFields["Unique identifier - Must not be blank"]
        self.typeText(uniqueIdentifierTextField, email)
        // Create it
        self.tap(app.navigationBars["New Player"].buttons["Create"])
    }
    
    func downloadPlayer(_ name: String) {
        // Assumes you are in the player selection screen
        self.tap(app.collectionViews.staticTexts["New"])
        // Select download from cloud
        self.tap(app.sheets["Add Player"].buttons["Find existing player"])
        // Select Emma
        self.tap(app.collectionViews.staticTexts[name], timeout: 30)
        self.tap(app.navigationBars["Select Players"].buttons["Download"])
    }
    
    func selectPlayer(_ name: String) {
        // Assumes you are in the Player Stats screen and player cell exists
        let playerLabel = app.collectionViews.staticTexts[name]
        self.tap(playerLabel)
    }
    
    func selectPlayers(_ playerNames: String...) {
        // Assumes you are in the player selection screen
        
        // Clear selection (if there is any)
        self.tapIfExists(app.toolbars.buttons["Clear Selection"])
        
        // Try to get the players
        let collectionViewsQuery = app.collectionViews
        for playerName in playerNames {
            let playerButton = collectionViewsQuery.staticTexts[playerName]
            if playerButton.exists {
                // Player exists - use them
                self.tap(playerButton)
            } else {
                // Player not there - try to add them in
                self.downloadPlayer(playerName)
            }
        }
        
        // Start the game
        self.tap(app.toolbars.buttons["Continue"])
    }
    
    func resetSettings(force: Bool = false) {
        
        if !Contract_Whist_Scorecard_UI_Tests.settingsReset || force {
        
            self.tap(app.navigationBars["Contract Whist"].buttons["settings"])
            
            // Clear and reset Sync with Cloud
            self.tap(app.tables.buttons["Don't Sync"])
            self.tap(app.tables.buttons["Sync with Cloud"])
            self.tap(app.alerts["Warning"].buttons["OK"])
            
            // Clear and set Save Game History
            self.tap(app.tables.buttons["Don't Save History"])
            self.tap(app.tables.buttons["Save Game History"])
            
            // Clear and set Save Game Location
            self.tap(app.tables.buttons["Don't Save Location"])
            self.tap(app.tables.buttons["Save Game Location"])
            
            // Clear and set Allow Sharing
            self.tap(app.tables.buttons["No Sharing"])
            self.tap(app.tables.buttons["Allow Sharing"])
            
            // Clear and set Nearby playing
            self.tap(app.tables.buttons["No Nearby Playing"])
            self.tap(app.tables.buttons["Nearby Playing Enabled"])
            
            // If Online Game Invitations not enabled - enable it
            let enable = app.tables.buttons["Enable"]
            if enable.isEnabled {
                self.tap(enable)
                self.tap(app.tables.staticTexts["Marc"])
            }
            
             // Clear and set Vibrate
            self.tap(app.tables.buttons["Don't Vibrate"])
            self.tap(app.tables.buttons["Vibrate"])
            
            // Swipe up to get to next options
            self.swipeUp(app.tables.buttons["Don't Vibrate"])
            
            // Set and clear Flash
            self.tap(app.tables.buttons["Flash"])
            self.tap(app.tables.buttons["Don't Flash"])
            
            // Clear and set Receive Notifications
            self.tap(app.tables.buttons["No Notifications"])
            self.tap(app.tables.buttons["Receive Notifications"])
            
            // Clear and set Highlight Dealer
            self.tap(app.tables.buttons["None"])
            self.tap(app.tables.buttons["Highlight"])
            
            // Set starting number of cards to 8 and then back to 13
            let cardsValue0 = app.tables.textFields["cardsValue0"]
            self.typeText(cardsValue0, "8\n")
            self.typeText(cardsValue0, "13\n")
            
            // Set ending number of cards to 8 and then back to 13
            let cardsValue1 = app.tables.textFields["cardsValue1"]
            self.typeText(cardsValue1, "8\n")
            self.typeText(cardsValue1, "1\n")
            
            // Set bounce and then unset
            self.tap(app.tables.buttons["Return to 13 cards"])
            self.tap(app.tables.buttons["Go down to 1 card"])
            
            // Swipe up to get to next options
            self.swipeUp(app.tables.buttons["Above Players"])
            
            // Clear and set Bonus for 2
            self.tap(app.tables.buttons["No Bonus"])
            self.tap(app.tables.buttons["10 Point Bonus"])
            
            // Clear and set NT in trump sequence
            self.tap(app.tables.buttons["Don't Include NT"])
            self.tap(app.tables.buttons["Include No Trumps"])
            
            // Return to home page
            self.returnHome()
            
            // Contract_Whist_Scorecard_UI_Tests.settingsReset = true
            
        }
    }
}

