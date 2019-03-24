//
//  Setting Tests.swift
//  Contract Whist Scorecard UI Tests
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import XCTest

extension Contract_Whist_Scorecard_UI_Tests {
    
    func testSettingSync() {
        
        // Select Settings
        self.selectSettings()
        
        // Clear Sync with Cloud
        self.tap(app.tables.buttons["Don't Sync"])
        
        // Check that sharing, alerts, online and notifications disable
        self.assertNotEnabled(app.tables.buttons["Allow Sharing"])
        self.assertSelected(app.tables.buttons["No Sharing"])
        self.assertExists(app.tables.buttons["Enable"])
        self.assertNotEnabled(app.tables.buttons["Enable"])
        self.assertNotEnabled(app.tables.buttons["Vibrate"])
        self.assertSelected(app.tables.buttons["Don't Vibrate"])
        self.assertNotEnabled(app.tables.buttons["Receive Notifications"])
        self.assertSelected(app.tables.buttons["No Notifications"])
        
        // Return to main menu
        self.returnHome()
        
        // Check that online game and view game aren't available
        self.assertNotExists(app.tables.buttons["Online Game"])
        self.assertNotExists(app.navigationBars["Contract Whist"].buttons["broadcast"])
        
        // Go into Players and check Sync not available
        self.selectOption("Players")
        self.assertNotExists(app.toolbars.buttons["Sync..."])
        
        // Go into Comparison and check Sync not available
        self.tap(app.navigationBars["Players"].buttons["Select"], timeout: 20)
        self.tap(app.navigationBars["Players"].buttons["All"])
        self.tap(app.navigationBars["Players"].buttons["Compare"])
        self.assertNotExists(app.toolbars.buttons["Sync..."])
        
        // Go back to Home Screen
        self.tap(app.navigationBars["Statistics"].buttons["Back"])
        self.returnHome()
        
        // Go into History and check Sync not available
        self.selectOption("History")
        self.assertNotExists(app.toolbars.buttons["Sync..."])
        
        // Go back to Home Screen
        self.returnHome(timeout: 60)
        
        // Go back into Settings
        self.selectSettings()
        
        // Set Sync with Cloud
        self.tap(app.tables.buttons["Sync with Cloud"])
        self.tap(app.alerts["Warning"].buttons["OK"])
        
        // Check that sharing, alerts, online and notifications disable
        self.assertEnabled(app.tables.buttons["Allow Sharing"])
        self.assertEnabled(app.tables.buttons["Nearby Playing Enabled"])
        self.assertEnabled(app.tables.buttons["Vibrate"])
        self.assertEnabled(app.tables.buttons["Receive Notifications"])
        
        // Switch sharing and nearby playing back on
        self.tap(app.tables.buttons["Allow Sharing"])
        self.tap(app.tables.buttons["Nearby Playing Enabled"])
        
        // Enable for Marc
        let enable = app.tables.buttons["Enable"]
        self.tap(enable)
        self.tap(app.tables.staticTexts["Marc"])
        
        // Return to main menu
        self.returnHome()
        
        // Check that online game and view game are available
        self.assertEnabled(app.tables.buttons["Online Game"])
        self.assertEnabled(app.navigationBars["Contract Whist"].buttons["broadcast"])
        
        // Go into Players and check Sync available
        self.selectOption("Players")
        self.assertEnabled(app.toolbars.buttons["Sync..."])
        self.returnHome()
        
        // Go into Comparison and check Sync available
        self.selectOption("Statistics")
        self.assertEnabled(app.toolbars.buttons["Sync..."])
        
        // Go back to Home Screen
        self.returnHome()
        
        // Go into History and check Sync available
        self.selectOption("History")
        self.assertEnabled(app.toolbars.buttons["Sync..."])
        
        // Go back to Home Screen
        self.returnHome(timeout: 60)
    }
    
    func testSettingHistory() {
        
        // Select Settings
        self.selectSettings()
    
        // Clear Save Game History
        self.tap(app.tables.buttons["Don't Save History"])
        self.assertNotEnabled(app.tables.buttons["Save Game Location"])
        self.assertSelected(app.tables.buttons["Don't Save Location"])
        
        // Return to main menu
        self.returnHome()
        
        // Check that History and High Scores aren't available
        self.assertNotExists(app.tables.buttons["History"])
        self.assertNotExists(app.tables.buttons["High Scores"])
        
        // Go back into Settings
        self.selectSettings()
        
        // Set Save Game History (and Location)
        self.tap(app.tables.buttons["Save Game History"])
        self.tap(app.tables.buttons["Save Game Location"])
        
        // Return to home page
        self.returnHome()
        
        // Check that History and High Scores available
        self.assertExists(app.tables.buttons["History"])
        self.assertExists(app.tables.buttons["High Scores"])
        
    }
    
    func testSettingLocation() {
        
        // Select Settings
        self.selectSettings()
        
        // Clear Save Game Location
        self.tap(app.tables.buttons["Don't Save Location"])
        
        // Return to main menu
        self.returnHome()
        
        // Go into History and check no location column
        self.selectOption("History")
        self.assertNotExists(app.tables.staticTexts["Location"])
        
        // Go into first element of detail
        let window = app.children(matching: .window).element(boundBy: 0)
        self.tap(window.children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .table).element(boundBy: 1)
            .children(matching: .cell).element(boundBy: 0)
            .buttons["More Info"])
        
        // Check update location doesn't exist
        self.assertNotExists(app.buttons["Update"])
        
        // Exit from detail
        self.tap(app.navigationBars.buttons["Item"])
        
        // Return to main menu
        self.returnHome(timeout: 60)
        
        // Go back into Settings
        self.selectSettings()
        
        // Set Save Game Location
        self.tap(app.tables.buttons["Save Game Location"])
        
        // Return to main menu
        self.returnHome()
        
        // Go into History and check no location column
        self.selectOption("History")
        self.assertExists(app.tables.staticTexts["Location"])
        
        // Go into first element of detail
        self.tap(window.children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .table).element(boundBy: 1)
            .children(matching: .cell).element(boundBy: 0)
            .buttons["More Info"])
        
        // Check update location doesn't exist
        self.assertExists(app.buttons["Update"])
        
        // Exit from detail
        self.tap(app.navigationBars.buttons["Item"])
        
        // Return to home page
        self.returnHome(timeout: 60)
        
    }
    
    func testSettingSharing() {
        
        // Select Settings
        self.selectSettings()
        
        // Don't Allow Sharing
        self.tap(app.tables.buttons["No Sharing"])
        
        // Return to main menu
        self.returnHome()
        
        // Check that Broadcast button doesn't exist
        self.assertNotExists(app.navigationBars.buttons["broadcast"])
        
        // Go back into Settings
        self.selectSettings()
        
        // Allow Sharing
        self.tap(app.tables.buttons["Allow Sharing"])
        
        // Return to home page
        self.returnHome()
        
        // Go into Broadcast option
        self.tap(app.navigationBars.buttons["broadcast"])
        
        // Return to home page
        self.returnHome()
        
    }
    
    func testSettingOnline() {
        
        // Select Settings
        self.selectSettings()
        
        // Disable nearby and online game
        self.tap(app.tables.buttons["No Nearby Playing"])
        self.tap(app.tables.buttons["Change"])
        self.tap(app.tables.staticTexts["Disable Online support"])
        self.waitFor(app.tables.buttons["Enable"])
        
        // Return to home page
        self.returnHome()
        
        // Check online game not visible
        self.assertNotExists(app.tables.buttons["Online Game"])
        
        // Go back into settings
        self.selectSettings()
        
        // Enable nearby game
        self.tap(app.tables.buttons["Nearby Playing Enabled"])
        
        // Return to home page
        self.returnHome()
        
        // Go into Online Game and check no 'Invite player online' option
        self.selectOption("Online Game")
        self.tap(app.sheets.buttons["Host a Game"])
        self.assertNotExists(app.tables.staticTexts["Invite players online"])
        
        // Exit back to home page
        self.returnHome()
        
        // Go back into settings
        self.selectSettings()
        
        // Enable for Marc
        self.tap(app.tables.buttons["Enable"])
        self.tap(app.tables.staticTexts["Marc"])
        
        // Return to home page
        self.returnHome()
        
        // Go into Online Game and Invite players
        self.selectOption("Online Game")
        self.tap(app.sheets.buttons["Host a Game"])
        let invite = app.tables.staticTexts["Invite players online"]
        if invite.exists {
            // Enabled - go into it
            self.tap(invite)
            self.assertExists(app.staticTexts["Choose 2 or 3 players to invite to the game"])
            self.tap(app.navigationBars.buttons["Cancel"])
        } else {
            // Disabled - offline
            self.assertExists(app.tables.staticTexts["Invite players online (offline)"])
        }
        
        // Exit back to home page
        self.returnHome()
        
        // Go back into settings
        self.selectSettings()
        
        // Disable Nearby playing
        self.tap(app.tables.buttons["No Nearby Playing"])
        
        // Return to home page
        self.returnHome()
        
        // Go into Online Game - should go straigh to invite
        if self.tryOption("Online Game") {
            self.tap(app.sheets.buttons["Host a Game"])
            self.assertExists(app.staticTexts["Choose 2 or 3 players to invite to the game"])
            
            // Exit back to home page
            self.tap(app.navigationBars.buttons["Cancel"])
        }
        
        // Go back into settings
        self.selectSettings()
        
        // Enable Nearby playing
        self.tap(app.tables.buttons["Nearby Playing Enabled"])
        
        // Go back to home page
        self.returnHome()
        
    }
    
    func testSettingBonus2() {
        
        // Select Settings
        self.selectSettings()
        
        // Switch off Location
        self.tap(app.tables.buttons["Don't Save Location"])
        
        // Swipe up to get to next options
        self.swipeUp(app.tables.buttons["Don't Vibrate"])
        
        // Clear Bonus for 2
        self.tap(app.tables.buttons["No Bonus"])
        
        // Return to main menu
        self.returnHome()
        
        // Go into High Scores and check no twos shown
        self.selectOption("High Scores")
        self.assertNotExists(app.tables.staticTexts["Most Twos Made"])
        
        // Return to home page
        self.returnHome()
        
        // Go into history detail and check no twos shown
        self.selectOption("History")
        
        // Go into first element of detail
        let window = app.children(matching: .window).element(boundBy: 0)
        self.tap(window.children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .table).element(boundBy: 1)
            .children(matching: .cell).element(boundBy: 0)
            .buttons["More Info"], timeout: 60)
        self.assertNotExists(app.tables.staticTexts["Twos"])
 
        // Exit from detail
        self.tap(app.navigationBars.buttons["Item"])
        
        // Return to main menu
        self.returnHome(timeout: 60)
        
        // Go into Players and check no Twos shown
        self.selectOption("Players")
        self.assertNotExists(app.tables.staticTexts["Twos made %"])
        
        // Select Becky and check Twos not shown
        self.selectPlayer("Becky")
        self.assertNotExists(app.tables.staticTexts["Twos made %"])
        
        // Return to Players
        self.tap(app.navigationBars["Becky"].buttons["Back"])
        
        // Return to home page
        self.returnHome()
        
        // Select new game
        self.selectOption("New Game")
        
        // Select Emma, Jack and Marc and continue to Game Preview
        self.selectPlayers("Emma", "Jack", "Marc")
        
        // Start game
        self.tap(app.navigationBars.buttons["Continue"])

        // Go into score and enter bids
        self.tap(app.navigationBars.buttons["Continue"])
        self.tap(app.tables.buttons["score4"])
        self.tap(app.tables.buttons["score5"])
        self.tap(app.tables.buttons["score6"])
        
        // Dismiss round summary
        self.tap(app.buttons["cross white"])
        
        // Check that twos are not shown and enter scores
        self.assertNotExists(app.tables.staticTexts["Twos"])
        self.tap(app.tables.buttons["score4"])
        self.tap(app.tables.buttons["score5"])
        self.tap(app.tables.buttons["score4"])
        
        // Exit to Game Preview
        self.tap(app.navigationBars.buttons["Exit"])
        self.tapIfExists(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Go back to selection page
        self.tap(app.navigationBars.buttons["Back"])
        
        // Return to home page
        self.returnHome()
        
        // Go back into Settings
        self.selectSettings()

        // Swipe up to get to next options
        self.swipeUp(app.tables.buttons["Don't Vibrate"])
        
        // Switch on 10-point bonus for 2
        self.tap(app.tables.buttons["10 Point Bonus"])
        
        // Return to home page
        self.returnHome()
        
        // Go into history detail and check no twos shown
        self.selectOption("History")
        
        // Go into first element of detail
        self.tap(window.children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .other).element
            .children(matching: .table).element(boundBy: 1)
            .children(matching: .cell).element(boundBy: 0)
            .buttons["More Info"])
        self.assertExists(app.tables.staticTexts["Twos"])
        
        // Exit from detail
        self.tap(app.navigationBars.buttons["Item"])
        
        // Return to main menu
        self.returnHome(timeout: 60)
        
        // Go into Players
        self.selectOption("Players")
        // No longer visible on iPhone
        // self.assertExists(app.collectionViews.staticTexts["Twos made %"])
        
        // Select Becky and check Twos not shown
        self.selectPlayer("Becky")
        self.assertExists(app.tables.staticTexts["Twos made %"])
        
        // Return to Players
        self.tap(app.navigationBars.buttons["Back"])
        
        // Return to home page
        self.returnHome()
        
        // Select new game
        self.selectOption("New Game")
        
        // Select Emma, Jack and Marc and continue to Game Preview
        self.selectPlayers("Emma", "Jack", "Marc")
        
        // Start game
        self.tap(app.navigationBars.buttons["Continue"])

        // Go into score and enter bids
        self.tap(app.navigationBars.buttons["Continue"])
        self.tap(app.tables.buttons["score4"])
        self.tap(app.tables.buttons["score5"])
        self.tap(app.tables.buttons["score6"])
        
        // Dismiss round summary
        self.tap(app.buttons["cross white"])
        
        // Check that twos are shown and enter scores and twos
        self.assertExists(app.tables.staticTexts["Twos"])
        self.tap(app.tables.buttons["score4"])
        self.tap(app.tables.buttons["score0"])
        self.tap(app.tables.buttons["score5"])
        self.tap(app.tables.buttons["score1"])
        self.tap(app.tables.buttons["score4"])
        self.tap(app.tables.buttons["score0"])
        
        // Exit to Game Preview
        self.tap(app.navigationBars.buttons["Exit"])
        self.tapIfExists(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Go back to selection page
        self.tap(app.navigationBars.buttons["Back"])
        
        // Return to home page
        self.returnHome()
        
        // Go back into settings
        self.selectSettings()
        
        // Switch off Location
        self.tap(app.tables.buttons["Save Game Location"])
        
        // Return to home page
        self.returnHome()
        
    }
    
    func testSettingCards() {
        
        // Select Settings
        self.selectSettings()
        
        // Switch off Location
        self.tap(app.tables.buttons["Don't Save Location"])
        
        // Swipe up to get to next options
        self.swipeUp(app.tables.buttons["Don't Vibrate"])
        
        // Set sliders to 7 -> 1
        let roundsValue0 = app.tables.textFields["cardsValue0"]
        self.typeText(roundsValue0,  "7\n")
        let roundsValue1 = app.tables.textFields["cardsValue1"]
        self.typeText(roundsValue1,  "1\n")
        
        // Set to no bounce
        self.tap(app.tables.buttons["Return to 7 cards"])
        self.tap(app.tables.buttons["Go down to 1 card"])
        
        // Return to home page
        self.returnHome()
        
        // Select new game
        self.selectOption("New Game")
        
        // Select Emma, Jack and Marc and continue to Game Preview
        self.selectPlayers("Emma", "Jack", "Marc")
        
        // Start game
        self.tap(app.navigationBars.buttons["Continue"])

        // Check 7 rows in body
        self.waitFor(app.tables.staticTexts["Total"])
        XCTAssertEqual(app.tables["body"].cells.count, 7)
        
        // Go into score and check 7 button exists, but not 8
        self.tap(app.navigationBars.buttons["Continue"])
        self.assertExists(app.tables.buttons["score7"])
        self.assertNotExists(app.tables.buttons["score8"])
        
        // Check can't make total add up to 7
        self.tap(app.tables.buttons["score2"])
        self.tap(app.tables.buttons["score2"])
        self.assertNotEnabled(app.tables.buttons["score3"])
        self.tap(app.tables.buttons["score2"])
        
        // Dismiss round summary
        self.tap(app.buttons["cross white"])
        
        // Check that have to make total add up to 7
        self.tap(app.tables.buttons["score2"])
        self.tap(app.tables.buttons["score0"])
        self.tap(app.tables.buttons["score2"])
        self.tap(app.tables.buttons["score0"])
        self.assertEnabled(app.tables.buttons["score3"])
        
        // Exit back to scorepad
        self.tap(app.toolbars.buttons["Done"])
        
        // Exit to Game Preview
        self.tap(app.navigationBars.buttons["Exit"])
        self.tapIfExists(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Go back to selection page
        self.tap(app.navigationBars.buttons["Back"])
        
        // Return to home page
        self.returnHome()
        
        // Select Settings
        self.selectSettings()
        
        // Switch off Location
        self.tap(app.tables.buttons["Don't Save Location"])
        
        // Swipe up to get to next options
        self.swipeUp(app.tables.buttons["Don't Vibrate"])
        
        // Set sliders to 7 -> 1
        self.typeText(roundsValue0,  "7\n")
        self.typeText(roundsValue1,  "1\n")
        
        // Set to bounce
        self.tap(app.tables.buttons["Return to 7 cards"])
        
        // Return to home page
        self.returnHome()
        
        // Select new game
        self.selectOption("New Game")
        
        // Select Emma, Jack and Marc and continue to Game Preview
        self.selectPlayers("Emma", "Jack", "Marc")
        
        // Start game
        self.tap(app.navigationBars.buttons["Continue"])

        // Check 13 rows in body
        self.waitFor(app.tables.staticTexts["Total"])
        XCTAssertEqual(app.tables["body"].cells.count, 13)
        
        // Go into score and check 7 button exists but not 8
        self.tap(app.navigationBars.buttons["Continue"])
        self.assertExists(app.tables.buttons["score7"])
        self.assertNotExists(app.tables.buttons["score8"])
        
        // Check can't make total add up to 7
        self.tap(app.tables.buttons["score2"])
        self.tap(app.tables.buttons["score2"])
        self.assertNotEnabled(app.tables.buttons["score3"])
        self.tap(app.tables.buttons["score2"])
        
        // Dismiss round summary
        self.tap(app.buttons["cross white"])
        
        // Check that have to make total add up to 7
        self.tap(app.tables.buttons["score2"])
        self.tap(app.tables.buttons["score0"])
        self.tap(app.tables.buttons["score2"])
        self.tap(app.tables.buttons["score0"])
        self.assertEnabled(app.tables.buttons["score3"])
        
        // Exit back to scorepad
        self.tap(app.toolbars.buttons["Done"])
        
        // Exit to Game Preview
        self.tap(app.navigationBars.buttons["Exit"])
        self.tapIfExists(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Go back to selection page
        self.tap(app.navigationBars.buttons["Back"])
        
        // Return to home page
        self.returnHome()
        
        // Select Settings
        self.selectSettings()
        
        // Switch off Location
        self.tap(app.tables.buttons["Don't Save Location"])
        
        // Swipe up to get to next options
        self.swipeUp(app.tables.buttons["Don't Vibrate"])
        
        // Set sliders to 1 -> 13
        self.typeText(roundsValue0,  "1\n")
        self.typeText(roundsValue1,  "13\n")
        
        // Set to no bounce
        self.tap(app.tables.buttons["Return to 1 card"])
        self.tap(app.tables.buttons["Go up to 13 cards"])
        
        // Return to home page
        self.returnHome()
        
        // Select new game
        self.selectOption("New Game")
        
        // Select Emma, Jack and Marc and continue to Game Preview
        self.selectPlayers("Emma", "Jack", "Marc")
        
        // Start game
        self.tap(app.navigationBars.buttons["Continue"])

        // Check 1 rows in body
        self.waitFor(app.tables.staticTexts["Total"])
        XCTAssertEqual(app.tables["body"].cells.count, 13)
        
        // Go into score and check 1 button exists but not 2
        self.tap(app.navigationBars.buttons["Continue"])
        self.assertExists(app.tables.buttons["score1"])
        self.assertNotExists(app.tables.buttons["score2"])
        
        // Check can't make total add up to 1
        self.tap(app.tables.buttons["score1"])
        self.tap(app.tables.buttons["score0"])
        self.assertNotEnabled(app.tables.buttons["score0"])
        self.tap(app.tables.buttons["score1"])
        
        // Dismiss round summary
        self.tap(app.buttons["cross white"])
        
        // Check that have to make total add up to 11
        self.tap(app.tables.buttons["score0"])
        self.tap(app.tables.buttons["score0"])
        self.tap(app.tables.buttons["score0"])
        self.tap(app.tables.buttons["score0"])
        self.assertEnabled(app.tables.buttons["score1"])
        
        // Exit back to scorepad
        self.tap(app.toolbars.buttons["Done"])
        
        // Exit to Game Preview
        self.tap(app.navigationBars.buttons["Exit"])
        self.tapIfExists(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Go back to selection page
        self.tap(app.navigationBars.buttons["Back"])
        
        // Return to home page
        self.returnHome()
        
        // Select Settings
        self.selectSettings()
        
        // Switch off Location
        self.tap(app.tables.buttons["Don't Save Location"])
        
        // Swipe up to get to next options
        self.swipeUp(app.tables.buttons["Don't Vibrate"])
        
        // Set sliders to 13 -> 1
        self.typeText(roundsValue0,  "13\n")
        self.typeText(roundsValue1,  "1\n")
        
        // Set to no bounce
        self.tap(app.tables.buttons["Return to 13 cards"])
        self.tap(app.tables.buttons["Go down to 1 card"])
        
        // Return to home page
        self.returnHome()
        
        // Select new game
        self.selectOption("New Game")
        
        // Select Emma, Jack and Marc and continue to Game Preview
        self.selectPlayers("Emma", "Jack", "Marc")
        
        // Start game
        self.tap(app.navigationBars.buttons["Continue"])

        // Check 13 rows in body
        self.waitFor(app.tables.staticTexts["Total"])
        XCTAssertEqual(app.tables["body"].cells.count, 13)
        
        // Go into score and check 13 button exists
        self.tap(app.navigationBars.buttons["Continue"])
        self.assertExists(app.tables.buttons["score13"])
        
        // Check can't make total add up to 13
        self.tap(app.tables.buttons["score4"])
        self.tap(app.tables.buttons["score4"])
        self.assertNotEnabled(app.tables.buttons["score5"])
        self.tap(app.tables.buttons["score6"])
        
        // Dismiss round summary
        self.tap(app.buttons["cross white"])
        
        // Check that have to make total add up to 13
        self.tap(app.tables.buttons["score4"])
        self.tap(app.tables.buttons["score0"])
        self.tap(app.tables.buttons["score4"])
        self.tap(app.tables.buttons["score0"])
        self.assertEnabled(app.tables.buttons["score5"])
        
        // Exit back to scorepad
        self.tap(app.toolbars.buttons["Done"])
        
        // Exit to Game Preview
        self.tap(app.navigationBars.buttons["Exit"])
        self.tapIfExists(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Go back to selection page
        self.tap(app.navigationBars.buttons["Back"])
        
        // Return to home page
        self.returnHome()
        
        // Go back into settings
        self.selectSettings()
        
        // Switch Location back on
        self.tap(app.tables.buttons["Save Game Location"])
        
        // Return to home page
        self.returnHome()
    }
    
    func testSettingTrumpSequence() {
        
        // Select Settings
        self.selectSettings()
        
        // Switch off Location
        self.tap(app.tables.buttons["Don't Save Location"])
        
        // Swipe up to get to next options
        self.swipeUp(app.tables.buttons["Don't Vibrate"])
        self.swipeUp(app.tables.buttons["10 Point Bonus"])
        
        self.tap(app.tables.buttons["Don't Include NT"])
        
        // Return to home page
        self.returnHome()
        
        // Select new game
        self.selectOption("New Game")
        
        // Select Emma, Jack and Marc and continue to Game Preview
        self.selectPlayers("Emma", "Jack", "Marc")
        
        // Start game
        self.tap(app.navigationBars.buttons["Continue"])

        // Set up score buttons etc
        let scoreButton = app.navigationBars["Scorecard"].buttons["Continue"]
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
        self.tap(button3)                               // Player 1 bid
        self.tap(button4)                               // Player 2 bid
        self.tap(button5)                               // Player 3 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)               // Player 1 made ; twos
        self.tap(button4) ; self.tap(button1)               // Player 2 made ; twos
        self.tap(button6) ; self.tap(button0)               // Player 3 made ; twos
        
        //Round 2 - 12D
        self.tap(scoreButton)
        self.tap(button3)                               // Player 1 bid
        self.tap(button4)                               // Player 2 bid
        self.tap(button4)                               // Player 3 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)               // Player 1 made ; twos
        self.tap(button4) ; self.tap(button0)               // Player 2 made ; twos
        self.tap(button5) ; self.tap(button0)               // Player 3 made ; twos
        
         //Round 3 - 11H
        self.tap(scoreButton)
        self.tap(button2)                               // Player 1 bid
        self.tap(button4)                               // Player 2 bid
        self.tap(button6)                               // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)               // Player 1 made ; twos
        self.tap(button4) ; self.tap(button1)               // Player 2 made ; twos
        self.tap(button5) ; self.tap(button0)               // Player 3 made ; twos
        
        //Round 4 - 10S
        self.tap(scoreButton)
        self.tap(button7)                               // Player 1 bid
        self.tap(button2)                               // Player 2 bid
        self.tap(button0)                               // Player 3 bid
        self.tap(crossWhite)
        self.tap(button7) ; self.tap(button0)               // Player 1 made ; twos
        self.tap(button2) ; self.tap(button0)               // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)               // Player 3 made ; twos
        
        // Check round 4 totals
        checkRunningTotals(59, 54, 33)
        
        //Round 5 - 9NT
        self.tap(scoreButton)
        self.assertNotExists(app.toolbars.staticTexts["9NT"])
        
        // Exit back to scorepad
        self.tap(app.toolbars.buttons["Done"])
        
        // Exit to Game Preview
        self.tap(app.navigationBars.buttons["Exit"])
        self.tapIfExists(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Go back to selection page
        self.tap(app.navigationBars.buttons["Back"])
        
        // Return to home page
        self.returnHome()
        
        // Select Settings
        self.selectSettings()
        
        // Switch off Location
        self.tap(app.tables.buttons["Don't Save Location"])
        
        // Swipe up to get to next options
        self.swipeUp(app.tables.buttons["Don't Vibrate"])
        self.swipeUp(app.tables.buttons["10 Point Bonus"])
        
        self.tap(app.tables.buttons["Include No Trumps"])
        
        // Return to home page
        self.returnHome()
        
        // Select new game
        self.selectOption("New Game")
        
        // Select Emma, Jack and Marc and continue to Game Preview
        self.selectPlayers("Emma", "Jack", "Marc")
        
        // Start game
        self.tap(app.navigationBars.buttons["Continue"])

        //Round 1 - 13C
        self.tap(scoreButton)
        self.tap(button3)                               // Player 1 bid
        self.tap(button4)                               // Player 2 bid
        self.tap(button5)                               // Player 3 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)               // Player 1 made ; twos
        self.tap(button4) ; self.tap(button1)               // Player 2 made ; twos
        self.tap(button6) ; self.tap(button0)               // Player 3 made ; twos
        
        //Round 2 - 12D
        self.tap(scoreButton)
        self.tap(button3)                               // Player 1 bid
        self.tap(button4)                               // Player 2 bid
        self.tap(button4)                               // Player 3 bid
        self.tap(crossWhite)
        self.tap(button3) ; self.tap(button0)               // Player 1 made ; twos
        self.tap(button4) ; self.tap(button0)               // Player 2 made ; twos
        self.tap(button5) ; self.tap(button0)               // Player 3 made ; twos
        
        //Round 3 - 11H
        self.tap(scoreButton)
        self.tap(button2)                               // Player 1 bid
        self.tap(button4)                               // Player 2 bid
        self.tap(button6)                               // Player 3 bid
        self.tap(crossWhite)
        self.tap(button2) ; self.tap(button0)               // Player 1 made ; twos
        self.tap(button4) ; self.tap(button1)               // Player 2 made ; twos
        self.tap(button5) ; self.tap(button0)               // Player 3 made ; twos
        
        //Round 4 - 10S
        self.tap(scoreButton)
        self.tap(button7)                               // Player 1 bid
        self.tap(button2)                               // Player 2 bid
        self.tap(button0)                               // Player 3 bid
        self.tap(crossWhite)
        self.tap(button7) ; self.tap(button0)               // Player 1 made ; twos
        self.tap(button2) ; self.tap(button0)               // Player 2 made ; twos
        self.tap(button1) ; self.tap(button0)               // Player 3 made ; twos
        
        // Check round 4 totals
        checkRunningTotals(59, 54, 33)
        
        //Round 5 - 9NT
        self.tap(scoreButton)
        self.assertExists(app.toolbars.staticTexts["9NT"])
        
        // Exit back to scorepad
        self.tap(app.toolbars.buttons["Done"])
        
        // Exit to Game Preview
        self.tap(app.navigationBars.buttons["Exit"])
        self.tapIfExists(app.alerts["Finish Game"].buttons["Confirm"])
        
        // Go back to selection page
        self.tap(app.navigationBars.buttons["Back"])
         
        // Return to home page
        self.returnHome()
        
        // Go back into settings
        self.selectSettings()
        
        // Switch Location back on
        self.tap(app.tables.buttons["Save Game Location"])
        
        // Return home
        self.returnHome()
        
    }
}
