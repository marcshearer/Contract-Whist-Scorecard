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
    
    func returnHome(timeout: TimeInterval = 30) {
        self.tap(app.navigationBars.buttons["home"], timeout: timeout)
        waitForHome(timeout: timeout)
    }
    
    func waitForHome(timeout: TimeInterval = 30) {
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
    
    func enterLocation(_ location: String, _ confirm: Bool = true) {
        // Assumes you are in the location screen
        let searchText = app.otherElements["searchBar"]
        self.tap(searchText, timeout: 60)
        self.tap(searchText.buttons["Clear text"], timeout: 30)
        self.typeText(searchText, location, timeout: 30)
        
        // Confirm location
        self.tap(app.tables.cells.containing(.staticText, identifier:"New description for current location").staticTexts[location], timeout: 30)
        
        // Let things stabilise a while
        sleep(10)
        if confirm {
            // Continue
            self.tap(app.navigationBars.buttons["continueButton"], timeout: 60)
        } else {
            // Cancel
            self.tap(app.navigationBars.buttons["Cancel"], timeout: 30)
        }
    }
}

