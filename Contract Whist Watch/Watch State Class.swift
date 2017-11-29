//
//  Watch State Class.swift
//  Contract Whist Watch Extension
//
//  Created by Marc Shearer on 28/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import WatchConnectivity

public struct WatchStateContext {
    var inProgress: Bool
    var complete: Bool!
    var round: Int!
    var cards: Int!
    var trumpSuit: String!
    var playerNames: [String]!
    var playerBids: [Int]!
    var playerMade: [Int]!
    var playerScores: [Int]!
    var playerTotals: [Int]!
    var switchGame = false
}

protocol WatchStateDelegate {
    func didReceive(context: WatchStateContext!)
}

class WatchState:NSObject, WCSessionDelegate {
    
    private var session: WCSession
    private var delegates: [WatchStateDelegate] = []
    private var inProgress = false
    private var previousInProgress = false
    private var complete = false
    
    override init() {
        session = WCSession.default
        super.init()
        session.delegate = self
        session.activate()
    }
    
    public func attach(_ interfaceController: WatchStateDelegate) {
        delegates.append(interfaceController)
    }
    
    internal func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    internal func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        var context = WatchStateContext(
            inProgress:applicationContext["inProgress"] as! Bool,
            complete: applicationContext["complete"] as! Bool!,
            round: applicationContext["round"] as! Int!,
            cards: applicationContext["cards"] as! Int!,
            trumpSuit: applicationContext["trumpSuit"] as! String!,
            playerNames: applicationContext["playerNames"] as! [String]!,
            playerBids: applicationContext["playerBids"] as! [Int]!,
            playerMade: applicationContext["playerMade"] as! [Int]!,
            playerScores: applicationContext["playerScores"] as! [Int]!,
            playerTotals: applicationContext["playerTotals"] as! [Int]!,
            switchGame: false
        )
        // Switch to game summary?
        context.switchGame = (context.complete != nil && context.complete && !self.complete)
        self.complete = (context.complete != nil && context.complete)
        
        // Change displayed screens if necessary
        self.inProgress = context.inProgress
        if self.inProgress != self.previousInProgress {
            var names = ["Watch Round"]
            var contexts = [context]
            if self.inProgress {
                names.append("Watch Game")
                contexts.append(context)
            }
            self.delegates = []
            WatchRoundInterfaceController.reloadRootPageControllers(withNames: names, contexts: contexts, orientation: .horizontal, pageIndex: 0)
            self.previousInProgress = self.inProgress
        } else {
            for delegate in delegates {
                delegate.didReceive(context: context)
            }
        }
    }
}

