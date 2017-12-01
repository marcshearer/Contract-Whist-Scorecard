//
//  Watch Manager Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 27/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import WatchConnectivity

class WatchManager: NSObject, WCSessionDelegate {
    
    fileprivate var watchSession: WCSession?
    private let scorecard: Scorecard
    
    init(_ scorecard: Scorecard) {
        self.scorecard = scorecard
        super.init()
        if WCSession.isSupported() {
            watchSession = WCSession.default
            watchSession?.delegate = self
            watchSession?.activate()
        }
    }
    
    public func updateScores() {
        var dict: [String: Any] = [:]
        var playerNames: [String] = []
        var playerBids: [Int] = []
        var playerMade: [Int] = []
        var playerScores: [Int?] = []
        var playerTotals: [Int] = []
        var round:Int = scorecard.maxEnteredRound
        var cards:Int = scorecard.roundCards(round)
        let inProgress = (self.scorecard.gameInProgress && !self.scorecard.recovery.recoveryInProgress)
        
        dict["inProgress"] = inProgress
        
        if inProgress {
            round = scorecard.maxEnteredRound
            cards = scorecard.roundCards(round)
            for playerNumber in 1...self.scorecard.currentPlayers {
                let player = self.scorecard.roundPlayer(playerNumber: playerNumber, round: round)
                playerNames.append(player.playerMO!.name!)
                playerBids.append(player.bid(round) ?? -1)
                playerMade.append(player.made(round) ?? -1)
                playerScores.append(player.score(round) ?? -1)
                playerTotals.append(player.totalScore())
            }
            
            dict["complete"] = (self.scorecard.gameInProgress && self.scorecard.gameComplete(rounds: scorecard.rounds))
            dict["round"] = round
            dict["cards"] = cards
            dict["trumpSuit"] = self.scorecard.roundSuit(round, suits: self.scorecard.suits).toString()
            dict["playerNames"] = playerNames
            dict["playerBids"] = playerBids
            dict["playerMade"] = playerMade
            dict["playerScores"] = playerScores
            dict["playerTotals"] = playerTotals
        }
        
        do {
            try self.watchSession?.updateApplicationContext(dict)
        } catch {
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Utility.debugMessage("Session","Session activation did complete")
    }
    
    public func sessionDidBecomeInactive(_ session: WCSession) {
        Utility.debugMessage("Session","Session did become inactive")
    }
    
    public func sessionDidDeactivate(_ session: WCSession) {
        Utility.debugMessage("Session","Session did deactivate")
    }
}
