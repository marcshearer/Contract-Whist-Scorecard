//
//  Other Function Tests.swift
//  Contract Whist Scorecard UI Tests
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import XCTest

extension Contract_Whist_Scorecard_UI_Tests {
    
   func testSync() {
        
        // Select Player Stats
        self.selectOption("Player Stats")
        
        // Select sync
        self.tap(app.toolbars.buttons["sync"])
        
        // Go to home screen
        self.returnHome(timeout: 60)
        
    }
    
    func test0GetStarted() {
        
        // Restart app in reset mode - all core data and user defaults will be deleted
        app.launchEnvironment = ["TEST_MODE" : "TRUE",
                                 "RESET_WHIST_APP" : "TRUE",
                                 "RESET_SETTINGS" : "FALSE"]
        app.launch()
        
        // Enable sync
        self.tap(app.tables.buttons["Don't Sync"])
        self.tap(app.tables.buttons["Sync with Cloud"])
        self.tap(app.alerts["Warning"].buttons["OK"])
        
        // Enter email address
        self.typeText(app.tables.textFields["Enter your Unique ID to find players"], "mshearer@waitrose.com")
        
        // Select download
        self.tap(app.tables.buttons["Download Players from Cloud"])
        
        // Select all
        self.tap(app.navigationBars["Select Players"].buttons["All"], timeout: 30)
        
        // Download
        self.tap(app.navigationBars["Select Players"].buttons["Download"])
        
        // Go to home screen
        self.tap(app.tables.buttons["Home Screen"], timeout: 30)
        
        // Goto history
        self.selectOption("History")
        
        // Sync
        self.tap(app.toolbars.buttons["sync"])
        
        // Back to home screen
        self.returnHome(timeout: 60)
        
    }
    
    func testPlayerCreateDelete() {
        
        // Select Player Stats
        self.selectOption("Player Stats")
        
        // Delete Emma (and AAA Test) if exist
        self.deletePlayer("Emma")
        self.deletePlayer("AAA Test")
        
        // Go back to home page
        self.returnHome()
        
        // Select New Game
        self.selectOption("New Game")
        
        // Clear selection
        self.tapIfExists(app.toolbars.buttons["Clear Selection"])
        
        // Download a player from cloud
        self.downloadPlayer("Emma")
        
        // Create another player
        self.createNewPlayer(name: "AAA Test", email: "test@test.com")
        
        // Add third player
        self.tap(app.collectionViews.staticTexts["Marc"])
        
        // Continue to game preview
        self.tap(app.toolbars.buttons["Continue"])
        
        // Return to home page
        self.tap(app.navigationBars["Game Preview"].buttons["Back"])
        self.tap(app.navigationBars["Selection"].buttons["home"])
        
        // Go into player stats and delete AAA Test player
        self.selectOption("Player Stats")
        self.deletePlayer("AAA Test")
        
        // Return to home screen
        self.returnHome()
    }
}

