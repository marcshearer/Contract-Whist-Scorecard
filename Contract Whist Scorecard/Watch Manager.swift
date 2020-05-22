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
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            watchSession = WCSession.default
            watchSession?.delegate = self
            watchSession?.activate()
        }
    }
    
    public func updateScores() {
        if self.watchSession?.isPaired == true {
            if Scorecard.shared.commsPurpose != .playing {
                var dict: [String: Any] = [:]
                var playerNames: [String] = []
                var playerBids: [Int] = []
                var playerMade: [Int] = []
                var playerScores: [Int?] = []
                var playerTotals: [Int] = []
                var round:Int = Scorecard.game.maxEnteredRound
                var cards:Int = Scorecard.game.roundCards(round)
                let inProgress = ((Scorecard.game?.inProgress ?? false) && !Scorecard.recovery.reloadInProgress)
                
                dict["inProgress"] = inProgress
                
                if inProgress {
                    round = Scorecard.game.maxEnteredRound
                    cards = Scorecard.game.roundCards(round)
                    for playerNumber in 1...Scorecard.game.currentPlayers {
                        let player = Scorecard.game.player(roundPlayerNumber: playerNumber, round: round)
                        let playerScore = Scorecard.game.scores.get(round: round, playerNumber: playerNumber, sequence: .round)
                        playerNames.append(player.playerMO!.name!)
                        playerBids.append(playerScore.bid ?? -1)
                        playerMade.append(playerScore.made ?? -1)
                        playerScores.append(Scorecard.game.scores.score(round: round, playerNumber: playerNumber, sequence: .round) ?? -1)
                        playerTotals.append(Scorecard.game.scores.totalScore(playerNumber: playerNumber, sequence: .round))
                    }
                    
                    dict["complete"] = ((Scorecard.game?.inProgress ?? false) && Scorecard.game.gameComplete())
                    dict["round"] = round
                    dict["cards"] = cards
                    dict["trumpSuit"] = Scorecard.game.roundSuit(round).toString()
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
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Utility.debugMessage("session","Session activation did complete")
    }
    
    public func sessionDidBecomeInactive(_ session: WCSession) {
        Utility.debugMessage("session","Session did become inactive")
    }
    
    public func sessionDidDeactivate(_ session: WCSession) {
        Utility.debugMessage("session","Session did deactivate")
    }
}
