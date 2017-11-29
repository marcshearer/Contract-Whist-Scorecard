//
//  Other Function Tests.swift
//  Contract Whist Scorecard UI Tests
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import XCTest

extension Contract_Whist_Scorecard_UI_Tests {
    
    func testStats() {
        
        // Select Player Stats
        self.selectOption("Player Stats")
        
        // Select Becky
        self.selectPlayer("Becky")
            
        // Tap more info button
        self.tap(app.tables.buttons["More Info"])
        
        // Clear popup
        self.tap(app.alerts["Hidden Entry"].buttons["OK"])
        
        // Return to Player Stats
        self.tap(app.navigationBars["Becky"].buttons["Back"])
        
        // Go into select mode
        self.tap(app.navigationBars["Select Players"].buttons["Select"])
        
        // Select Cath & Emma
        self.selectPlayer("Cath")
        self.selectPlayer("Emma")
        
        // De-select Cath
        self.selectPlayer("Cath")
        
        // Select Jack
        self.selectPlayer("Jack")
        
        // Cancel select
        self.tap(app.toolbars.buttons["Cancel"])
        
        // Go back to home page
        self.returnHome()
        
    }
    
    func testCompare() {
        
        // Select Player Stats
        self.selectOption("Player Stats")
        
        // Go into select mode
        self.tap(app.navigationBars["Select Players"].buttons["Select"])
        
        // Select Becky, Cath & Emma
        self.selectPlayer("Becky")
        self.selectPlayer("Cath")
        self.selectPlayer("Emma")
        
        // Go into compare
        self.tap(app.navigationBars["Select Players"].buttons["Compare"])
        
        // Go back to stats
        self.tap(app.navigationBars["Player Comparison"].buttons["Back"])
        
        // Select all players & Compare
        self.tap(app.navigationBars["Select Players"].buttons["Select"])
        self.tap(app.navigationBars["Select Players"].buttons["All"])
        self.tap(app.navigationBars["Select Players"].buttons["Compare"])
        
        // Select player detail for Becky & then exit
        self.tap(app.tables.cells.containing(.staticText, identifier: "Becky").buttons["More Info"])
        self.tap(app.navigationBars["Becky"].buttons["Back"])
        
        // Select graph for Cath
        self.tap(app.tables.cells.containing(.staticText, identifier: "Cath").buttons["graph"])
            
        // Select detail
        self.tap(app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .button).element(boundBy: 5))
            
        // Exit from detail
        self.tap(app.navigationBars.buttons["Item"])
        
        // Exit from graph
        self.tap(app.buttons["cross white"])
        
        // Sort by games won
        self.tap(app.tables.staticTexts["Games Won"])
        
        // Return to stats
        self.tap(app.navigationBars["Player Comparison"].buttons["Back"])
        
        // Go back to home page
        self.returnHome()
    }
    
    func testHistory() {
        
        // Select History
        self.selectOption("History")
        
        // First element detail
        let window = app.children(matching: .window).element(boundBy: 0)
        self.tap(window.children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .table).element(boundBy: 1)
            .children(matching: .cell).element(boundBy: 0)
            .buttons["More Info"])
        
        // Select update location
        self.tap(app.buttons["Update"])
        
        // Amend location
        let searchText = app.searchFields["Revised location for game"]
        self.tap(searchText, timeout: 60)
        self.tapIfExists(searchText.buttons["Clear text"])
        self.typeText(searchText, "Abingdon", timeout: 30)
        
        // Cancel back to detail
        self.tap(app.navigationBars["Location"].buttons["Cancel"], timeout: 30)
        
        // Exit from detail
        self.tap(app.navigationBars.buttons["Item"])
        
        // Sort by location
        self.tap(app.tables.staticTexts["Location"])
        
        // Go back to home page
        self.returnHome()
    }
    
    func testHighScores() {
        
        // Select High Scores
        self.selectOption("High Scores")
        
        // Select detail - relies on their being a 12 (in games won)
        self.tap(app.tables.cells.containing(.staticText, identifier: "12").staticTexts.firstMatch)
        
        // Go back to High Scores
        app.navigationBars.buttons["Item"].tap()
        
        // Go back to home page
        self.returnHome()
        
    }
    
    func testWalkthrough() {
        
        // Select Walkthrough
        self.tap(app.navigationBars["Contract Whist"].buttons["More Info"])
        
        // Move forward 2 pages and back 1
        let walkthroughPage = app.children(matching: .window).element(boundBy: 0).children(matching: .other).element
        self.swipeLeft(walkthroughPage)
        self.swipeLeft(walkthroughPage)
        self.swipeRight(walkthroughPage)
        
        // Go back to home page
        self.returnHome()
        
    }
}
