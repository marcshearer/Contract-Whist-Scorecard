//
//  Contract_Whist_Scorecard_UI_Tests.swift
//  Contract Whist Scorecard UI Tests
//
//  Created by Marc Shearer on 20/10/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import XCTest

class Contract_Whist_Scorecard_UI_Tests: XCTestCase {

    let app = XCUIApplication()
    
    let existsPredicate = NSPredicate(format: "exists == 1", argumentArray: nil)
    let notExistsPredicate = NSPredicate(format: "exists == 0", argumentArray: nil)
    let enabledPredicate = NSPredicate(format: "enabled == 1", argumentArray: nil)
    let notEnabledPredicate = NSPredicate(format: "enabled == 0", argumentArray: nil)
    let hittablePredicate = NSPredicate(format: "hittable == 1", argumentArray: nil)
    let selectedPredicate = NSPredicate(format: "selected == 1", argumentArray: nil)
        
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchEnvironment = ["TEST_MODE" : "TRUE"]
        app.launch()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func test3PlayerGame() {
        
        // Select new game and override resume warning if necessary
        self.selectOption("New Game")
        
        // Select Emma, Jack and Marc
        self.selectPlayers("Emma", "Jack", "Marc")
        
        // Cut for dealer
        self.tap(app.tables.buttons["Cut for Dealer"])
        
        // Move to next dealer
        self.tap(app.tables.buttons["Next Dealer"])
        
        // Start game
        self.tap(app.tables.buttons["scorecard right"])
        
        // Enter location
        self.enterLocation("Abingdon")
        
        // Set up score buttons etc
        let scoreButton = app.navigationBars["Scorecard"].buttons["Score"]
        let tablesQuery = app.tables
        let button0 = tablesQuery.buttons["score0"]
        let button1 = tablesQuery.buttons["score1"]
        let button2 = tablesQuery.buttons["score2"]
        let button3 = tablesQuery.buttons["score3"]
        let button4 = tablesQuery.buttons["score4"]
        let button5 = tablesQuery.buttons["score5"]
        let button6 = tablesQuery.buttons["score6"]
        let button7 = tablesQuery.buttons["score7"]
        let crossWhite = app.buttons["cross white"]
        
        //Round 1 - 13C
        self.tap(scoreButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button4)                       // Player 2 bid
        self.tap(button5)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button4) ; self.tap(button1)   // Player 2 made ; twos
        self.tap(button6) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 1 totals
        checkRunningTotals(13, 24, 6)
    
        //Round 2 - 12D
        self.tap(scoreButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button4)                       // Player 2 bid
        self.tap(button4)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button4) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button5) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 2 totals
        checkRunningTotals(18, 37, 20)
        
        //Round 3 - 11H
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button4)                       // Player 2 bid
        self.tap(button6)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button4) ; self.tap(button1)   // Player 2 made ; twos
        self.tap(button5) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 3 totals
        checkRunningTotals(42, 42, 32)
        
        //Round 4 - 10S
        self.tap(scoreButton)
        self.tap(button7)                       // Player 1 bid
        self.tap(button2)                       // Player 2 bid
        self.tap(button0)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button7) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 4 totals
        checkRunningTotals(59, 54, 33)
        
        //Round 5 - 9NT
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button5)                       // Player 2 bid
        self.tap(button3)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button5) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 5 totals
        checkRunningTotals(61, 66, 48)
        
        //Round 6 - 8C
        self.tap(scoreButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button3)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button3) ; self.tap(button2)   // Player 2 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 6 totals
        checkRunningTotals(94, 68, 61)
        
        //Round 7 - 7D
        self.tap(scoreButton)
        self.tap(button0)                       // Player 1 bid
        self.tap(button3)                       // Player 2 bid
        self.tap(button3)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button0) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button3) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button4) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 7 totals
        checkRunningTotals(104, 81, 65)
        
        //Round 8 -6H
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button2)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 8 totals
        checkRunningTotals(106, 93, 77)
        
        //Round 9 - 5S
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button1)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 9 totals
        checkRunningTotals(117, 95, 89)
        
        //Round 10 - 4NT
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button1)                       // Player 2 bid
        self.tap(button2)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 10 totals
        checkRunningTotals(129, 106, 90)
        
        //Round 11 - 3C
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button1)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 11 totals
        checkRunningTotals(129, 118, 101)
        
        //Round 12 - 2D
        self.tap(scoreButton)
        self.tap(button1)                       // Player 1 bid
        self.tap(button1)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button1) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 12 totals
        checkRunningTotals(140, 118, 112)
        
        //Round 13 - 1H
        self.tap(scoreButton)
        self.tap(button0)                       // Player 1 bid
        self.tap(button0)                       // Player 2 bid
        self.tap(button0)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button0) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check final totals
        checkFinalTotals(150, 128, 113)

        // Game completion - select home button and confirm
        self.tap(app.tables.buttons["bighome"])
        self.tap(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Finish when home screen displayed
        self.waitForHome(timeout: 60)
        
    }
    
    func test3PlayerInterruptedGame() {
        
        // Select new game and override resume warning if necessary
        self.selectOption("New Game")
        
        // Select Emma, Jack and Marc
        self.selectPlayers("Emma", "Jack", "Marc")
        
        // Cut for dealer
        self.tap(app.tables.buttons["Cut for Dealer"])
        
        // Move to next dealer
        self.tap(app.tables.buttons["Next Dealer"])
        
        // Start game
        self.tap(app.tables.buttons["scorecard right"])
        
        // Enter location
        self.enterLocation("Abingdon")
        
        // Set up score buttons etc
        let scoreButton = app.navigationBars["Scorecard"].buttons["Score"]
        let tablesQuery = app.tables
        let button0 = tablesQuery.buttons["score0"]
        let button1 = tablesQuery.buttons["score1"]
        let button2 = tablesQuery.buttons["score2"]
        let button3 = tablesQuery.buttons["score3"]
        let button4 = tablesQuery.buttons["score4"]
        let button5 = tablesQuery.buttons["score5"]
        let button6 = tablesQuery.buttons["score6"]
        let button7 = tablesQuery.buttons["score7"]
        let crossWhite = app.buttons["cross white"]
        
        //Round 1 - 13C
        self.tap(scoreButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button4)                       // Player 2 bid
        self.tap(button5)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button4) ; self.tap(button1)   // Player 2 made ; twos
        self.tap(button6) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 1 totals
        checkRunningTotals(13, 24, 6)
        
        //Round 2 - 12D
        self.tap(scoreButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button4)                       // Player 2 bid
        self.tap(button4)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button4) ; self.tap(button0)   // Player 2 made ; twos
        
        // Restart app after 10 second delay
        self.waitFor(button5)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 10, execute: {
            self.app.terminate()
            self.app.launch()
        })
        self.selectOption("Resume Game", timeout: 60)
        self.tap(scoreButton, timeout: 60)
        self.tap(button5) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 2 totals
        checkRunningTotals(18, 37, 20)
        
        //Round 3 - 11H
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button4)                       // Player 2 bid
        self.tap(button6)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button4) ; self.tap(button1)   // Player 2 made ; twos
        self.tap(button5) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 3 totals
        checkRunningTotals(42, 42, 32)
        
        //Round 4 - 10S
        self.tap(scoreButton)
        self.tap(button7)                       // Player 1 bid
        self.tap(button2)                       // Player 2 bid
        self.tap(button0)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button7) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 4 totals
        checkRunningTotals(59, 54, 33)
        
        //Round 5 - 9NT
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button5)                       // Player 2 bid
        self.tap(button3)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button5) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 5 totals
        checkRunningTotals(61, 66, 48)
        
        //Round 6 - 8C
        self.tap(scoreButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button3)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button3) ; self.tap(button2)   // Player 2 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 6 totals
        checkRunningTotals(94, 68, 61)
        
        //Round 7 - 7D
        self.tap(scoreButton)
        self.tap(button0)                       // Player 1 bid
        self.tap(button3)                       // Player 2 bid
        self.tap(button3)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button0) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button3) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button4) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 7 totals
        checkRunningTotals(104, 81, 65)
        
        //Round 8 -6H
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button2)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 8 totals
        checkRunningTotals(106, 93, 77)
        
        //Round 9 - 5S
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button1)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 9 totals
        checkRunningTotals(117, 95, 89)
        
        //Round 10 - 4NT
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button1)                       // Player 2 bid
        self.tap(button2)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 10 totals
        checkRunningTotals(129, 106, 90)
        
        //Round 11 - 3C
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button1)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 11 totals
        checkRunningTotals(129, 118, 101)
        
        //Round 12 - 2D
        self.tap(scoreButton)
        self.tap(button1)                       // Player 1 bid
        self.tap(button1)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button1) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check round 12 totals
        checkRunningTotals(140, 118, 112)
        
        //Round 13 - 1H
        self.tap(scoreButton)
        self.tap(button0)                       // Player 1 bid
        self.tap(button0)                       // Player 2 bid
        self.tap(button0)                       // Player 3 bid
        self.tap(crossWhite)
        self.tap(button0) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 3 made ; twos
        
        // Check final totals
        checkFinalTotals(150, 128, 113)
        
        // Game completion - select home button and confirm
        self.tap(app.tables.buttons["bighome"])
        self.tap(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Finish when home screen displayed
        self.waitForHome(timeout: 60)
        
    }
    
    func terminate() {
        app.terminate()
    }
    
    func test4PlayerGame() {
        
        // Select new game and override resume warning if necessary
        self.selectOption("New Game")
        
        // Clear selection (if there is any)
        self.tapIfExists(app.toolbars.buttons["Clear Selection"])
        
        // Select Emma, Jack and Marc
        self.selectPlayers("Emma", "Jack", "Marc", "Rachel")
        
        // Cut for dealer
        self.tap(app.tables.buttons["Cut for Dealer"])
        
        // Move to next dealer
        self.tap(app.tables.buttons["Next Dealer"])
        
        // Start game
        self.tap(app.tables.buttons["scorecard right"])
        
        // Enter location
       self.enterLocation("Abingdon")
        
        // Set up score buttons etc
        let scoreButton = app.navigationBars["Scorecard"].buttons["Score"]
        let tablesQuery = app.tables
        let button0 = tablesQuery.buttons["score0"]
        let button1 = tablesQuery.buttons["score1"]
        let button2 = tablesQuery.buttons["score2"]
        let button3 = tablesQuery.buttons["score3"]
        let button4 = tablesQuery.buttons["score4"]
        let button5 = tablesQuery.buttons["score5"]
        let button6 = tablesQuery.buttons["score6"]
        let button7 = tablesQuery.buttons["score7"]
        let crossWhite = app.buttons["cross white"]
        let undoButton = app.buttons["undo"]
        let leftArrowButton = app.buttons["leftarrow"]
        let rightArrowButton = app.buttons["rightarrow"]
        let summaryButton = app.buttons["summary"]
        let doneButton = app.buttons["Done"]
        
        // Round 1 - 13C - with a couple of undos and edits
        self.tap(scoreButton)
        self.tap(button6)                       // Player 1 bid
        self.tap(button7)                       // Player 2 bid
        self.tap(undoButton)
        self.tap(undoButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button3)                       // Player 2 bid
        self.tap(button3)                       // Player 3 bid
        self.tap(button3)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button1)   // Player 1 made ; twos
        self.tap(button3) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button3) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button4) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check round 1 totals
        checkRunningTotals(23, 13, 13, 4)
        
        // Round 2 - 12D - with an exit to scorecard followed by some movement and edits
        self.tap(scoreButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button5)                       // Player 2 bid
        self.tap(button2)                       // Player 3 bid
        self.tap(button3)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button5) ; self.tap(button1)   // Player 2 made ; twos
        self.tap(doneButton)
        self.tap(scoreButton)
        self.tap(leftArrowButton)
        self.tap(leftArrowButton)
        self.tap(rightArrowButton)
        self.tap(button0)                       // Player 2 twos corrected
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check round 2 totals
        checkRunningTotals(25, 26, 28, 16)
        
        // Round 3 - 11H - with a trip to the summary
        self.tap(scoreButton)
        self.tap(button4)                       // Player 1 bid
        self.tap(button5)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(button2)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button4) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button5) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(summaryButton)
        self.tap(crossWhite)
        self.tap(button1) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check round 3 totals
        checkRunningTotals(36, 27, 42, 31)
        
        // Round 4 - 10S
        self.tap(scoreButton)
        self.tap(button5)                       // Player 1 bid
        self.tap(button5)                       // Player 2 bid
        self.tap(button0)                       // Player 3 bid
        self.tap(button2)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button5) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button5) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check round 4 totals
        checkRunningTotals(51, 37, 42, 46)
        
        // Round 5 - 9NT
        self.tap(scoreButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button2)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(button2)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button2) ; self.tap(button1)   // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button3) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check round 5 totals
        checkRunningTotals(64, 59, 53, 49)
        
        // Round 6 - 8C
        self.tap(scoreButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button2)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(button1)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)    // Player 1 made ; twos
        self.tap(button2) ; self.tap(button0)    // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)    // Player 3 made ; twos
        self.tap(button2) ; self.tap(button0)    // Player 4 made ; twos
        
        // Check round 6 totals
        checkRunningTotals(66, 72, 65, 60)
        
        // Round 7 - 7D
        self.tap(scoreButton)
        self.tap(button3)                       // Player 1 bid
        self.tap(button0)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(button2)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button3) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check round 7 totals
        checkRunningTotals(77, 75, 78, 70)
        
        // Round 8 - 6H
        self.tap(scoreButton)
        self.tap(button2)                       // Player 1 bid
        self.tap(button0)                       // Player 2 bid
        self.tap(button2)                       // Player 3 bid
        self.tap(button1)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button2) ; self.tap(button1)   // Player 4 made ; twos
        
        // Check round 8 totals
        checkRunningTotals(87, 87, 90, 82)
        
        // Round 9 - 5S
        self.tap(scoreButton)
        self.tap(button4)                       // Player 1 bid
        self.tap(button0)                       // Player 2 bid
        self.tap(button0)                       // Player 3 bid
        self.tap(button0)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button4) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check round 9 totals
        checkRunningTotals(101, 97, 100, 83)
        
        // Round 10 - 4NT
        self.tap(scoreButton)
        self.tap(button1)                       // Player 1 bid
        self.tap(button0)                       // Player 2 bid
        self.tap(button2)                       // Player 3 bid
        self.tap(button2)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button1) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check round 10 totals
        checkRunningTotals(113, 108, 110, 84)
        
        // Round 11 - 3C
        self.tap(scoreButton)
        self.tap(button0)                       // Player 1 bid
        self.tap(button2)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(button1)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button0) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button2) ; self.tap(button2)   // Player 2 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button1) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check round 11 totals
        checkRunningTotals(113, 119, 120, 116)
        
        // Round 12 - 2D
        self.tap(scoreButton)
        self.tap(button0)                       // Player 1 bid
        self.tap(button0)                       // Player 2 bid
        self.tap(button1)                       // Player 3 bid
        self.tap(button0)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button0) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button2) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check round 12 totals
        checkRunningTotals(123, 121, 130, 126)
        
        // Round 13 - 1H
        self.tap(scoreButton)
        self.tap(button1)                       // Player 1 bid
        self.tap(button0)                       // Player 2 bid
        self.tap(button0)                       // Player 3 bid
        self.tap(button1)                       // Player 4 bid
        self.tap(crossWhite)
        self.tap(button1) ; self.tap(button0)   // Player 1 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 2 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 3 made ; twos
        self.tap(button0) ; self.tap(button0)   // Player 4 made ; twos
        
        // Check final totals
        checkFinalTotals(140, 134, 131, 126)
        
        // Game completion - select home button and confirm
        self.tap(app.tables.buttons["bighome"])
        self.tap(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Finish when home screen displayed
        self.waitForHome(timeout: 60)
        
    }

    
    // MARK: - Utility Routines ======================================================================== -
    
    func checkRunningTotals(_ scores: Int...) {
        for (index, score) in scores.enumerated() {
            let scoreLabel = app.tables["footer"].staticTexts["player\(index+1)total"]
            self.waitFor(scoreLabel)
            XCTAssertEqual("\(score)", scoreLabel.label, "Incorrect score for player \(index+1)")
        }
    }
    
    func checkFinalTotals(_ scores: Int...) {
        for (index, score) in scores.enumerated() {
            let scoreLabel = app.tables["gameSummaryTable"].staticTexts["player\(index+1)total"]
            self.waitFor(scoreLabel)
            XCTAssertEqual("\(score)", scoreLabel.label, "Incorrect final score for player \(index+1)")
        }
    }
}
