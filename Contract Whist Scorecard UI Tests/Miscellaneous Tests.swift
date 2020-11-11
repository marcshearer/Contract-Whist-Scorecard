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
        
        // Select Players
        self.selectOption("Players")
        
        // Select sync
        self.tap(app.navigationBars.buttons["Sync..."])
        
        // Go to home screen
        self.returnHome(timeout: 180)
        
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
        
        // Enter playerUUID address
        self.typeText(app.tables.textFields["Enter your Unique ID to find players"], "marc@sheareronline.com")
        
        // Select download
        self.tap(app.tables.buttons["Download Players from Cloud"])
        
        // Select all
        self.tap(app.navigationBars["Players"].buttons["All"], timeout: 30)
        
        // Download
        self.tap(app.navigationBars["Players"].buttons["Download"])
        
        // Go to home screen
        self.tap(app.tables.buttons["Home Screen"], timeout: 30)
        
        // Goto history
        self.selectOption("History")
        
        // Sync
        self.tap(app.navigationBars.buttons["Sync..."])
        
        // Back to home screen
        self.returnHome(timeout: 180)
    }
    
    func testPlayerCreateDelete() {
        
        // Select Players
        self.selectOption("Players")
        
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
        
        // Add second player
        self.tap(app.collectionViews.staticTexts["Marc"])

        // Create another player
        self.createNewPlayer(name: "AAA Test", playerUUID: "test@test.com")
        
        // Continue to game preview
        self.tap(app.navigationBars.buttons["Continue"])
     
        // Return to home page
        self.tap(app.navigationBars["Game Preview"].buttons["Back"])
        self.tap(app.navigationBars["Selection"].buttons["home"])
        
        // Go into Players and delete AAA Test player
        self.selectOption("Players")
        self.deletePlayer("AAA Test")
        
        // Return to home screen
        self.returnHome()
    }
}

