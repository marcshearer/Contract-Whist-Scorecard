//
//  WatchGameInterfaceController.swift
//  Contract Whist Watch Extension
//
//  Created by Marc Shearer on 28/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import WatchKit
import WatchConnectivity

class WatchGameInterfaceController: WKInterfaceController, WatchStateDelegate {
    
    private var watchSession: WCSession?
    
    @IBOutlet weak var titleLabel: WKInterfaceLabel!
    @IBOutlet weak var titleImage: WKInterfaceImage!
    @IBOutlet weak var winnerTable: WKInterfaceTable!
    @IBOutlet weak var otherTable: WKInterfaceTable!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Attach to state delegate
        if let extensionDelegate = (WKExtension.shared().delegate as? ExtensionDelegate) {
            extensionDelegate.watchState.attach(self)
        }
        
        // Update interface
        self.didReceive(context: context as! WatchStateContext?)
    }
    
    func didReceive(context: WatchStateContext!) {
        
        if context != nil && context.inProgress {
            
            var winners: [Int] = []
            var others: [Int] = []
            
            // Sort scores
            var scores: [(score: Int, xref: Int)] = []
            for index in 0..<context.playerTotals.count {
                scores.append((context.playerTotals[index], index))
            }
            scores.sort(by: {$0.score > $1.score})
            
            // Format title
            if context.complete {
                titleLabel.setHidden(true)
                titleImage.setHidden(false)
            } else {
                let suitColor = (context.trumpSuit == "♥︎" || context.trumpSuit == "♦︎" ? UIColor.red : UIColor.white)
                let suitString = NSAttributedString(string: context.trumpSuit, attributes: [NSAttributedString.Key.foregroundColor: suitColor])
                
                let roundTitle = NSMutableAttributedString()
                roundTitle.append(NSAttributedString(string: "\(context.cards!)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.white]))
                roundTitle.append(suitString)
                roundTitle.append(NSAttributedString(string: " Totals", attributes: [NSAttributedString.Key.foregroundColor: UIColor.white]))
                
                titleLabel.setAttributedText(roundTitle)
                titleLabel.setHidden(false)
                titleImage.setHidden(true)
            }
            
            // Show scores
            let maxScore = scores[0].score
            for index in 0..<scores.count {
                if !context.complete || context.playerTotals[scores[index].xref] == maxScore {
                    winners.append(scores[index].xref)
                } else {
                    others.append(scores[index].xref)
                }
            }
        
            winnerTable.setNumberOfRows(winners.count, withRowType: "Winner Row")
            otherTable.setNumberOfRows(others.count, withRowType: "Other Row")
            if winners.count > 0 {
                for row in 0..<winners.count {
                    let index = winners[row]
                    if let controller = winnerTable.rowController(at: row) as? WatchGameRowController {
                        controller.winner = context.complete
                        controller.playerName = context.playerNames[index]
                        controller.playerScore = context.playerTotals[index]
                    }
                }
            }
            if others.count > 0 {
                for row in 0..<others.count {
                    let index = others[row]
                    if let controller = otherTable.rowController(at: row) as? WatchGameRowController {
                        controller.winner = false
                        controller.playerName = context.playerNames[index]
                        controller.playerScore = context.playerTotals[index]
                    }
                }
            }
            if context.switchGame {
                self.becomeCurrentPage()
            }
        }
    }
}

class WatchGameRowController: NSObject {
    @IBOutlet weak var playerNameLabel: WKInterfaceLabel!
    @IBOutlet weak var playerScoreLabel: WKInterfaceLabel!
    var winner = false
    
    var playerName:String! {
        didSet {
            if let playerName = playerName {
                playerNameLabel.setText(playerName)
                if self.winner {
                    playerNameLabel.setTextColor(UIColor.white)
                } else {
                    playerNameLabel.setTextColor(UIColor.lightGray)
                }
            }
        }
    }
    var playerScore:Int! {
        didSet {
            if let playerScore = playerScore {
                playerScoreLabel.setText("\(playerScore)")
            }
            if self.winner {
                playerScoreLabel.setTextColor(UIColor.white)
            } else {
                playerScoreLabel.setTextColor(UIColor.lightGray)
            }
        }
    }
}

