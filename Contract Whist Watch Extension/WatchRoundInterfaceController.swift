//
//  WatchRoundInterfaceController.swift
//  Contract Whist Watch Extension
//
//  Created by Marc Shearer on 27/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import WatchKit
import WatchConnectivity

class WatchRoundInterfaceController: WKInterfaceController, WatchStateDelegate {
    
    private var watchSession: WCSession?
    
    @IBOutlet weak var trumpSuitLabel: WKInterfaceLabel!
    @IBOutlet weak var overUnderLabel: WKInterfaceLabel!
    @IBOutlet weak var playerTable: WKInterfaceTable!
    
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
        
        if context == nil || !context.inProgress {
            
            trumpSuitLabel.setText("No Game in Progress")
            trumpSuitLabel.setTextColor(UIColor.white)
            overUnderLabel.setText("")
            playerTable.setNumberOfRows(0, withRowType: "")
            
        } else {
        
            let totalBids = context.playerBids.reduce(0, { (x, y) in
                x + (y<0 ? 0 : y)
            })
            let overUnder = context.cards - totalBids
            var overUnderText: String
            if context.playerBids[0] < 0 {
                overUnderText = "\(context.playerNames[0]) to bid"
            } else {
                if overUnder == 0 {
                    overUnderText = "Equal"
                } else if overUnder > 0 {
                    overUnderText = "\(overUnder) Under"
                } else {
                    overUnderText = "\(-overUnder) Over"
                }
            }
            
            let suit = Suit(fromString: context.trumpSuit)
            let suitColor = (context.trumpSuit == "♥︎" || context.trumpSuit == "♦︎" ? UIColor.red : UIColor.white)
            let suitString = NSAttributedString(string: suit.toString(), attributes: [NSAttributedStringKey.foregroundColor: suitColor])
            
            let roundTitle = NSMutableAttributedString()
            roundTitle.append(NSAttributedString(string: "\(context.cards!)", attributes: [NSAttributedStringKey.foregroundColor: UIColor.white]))
            roundTitle.append(suitString)
            
            trumpSuitLabel.setAttributedText(roundTitle)
            overUnderLabel.setText(overUnderText)
            overUnderLabel.setTextColor((overUnder == 0 || context.playerBids[0] < 0 ? UIColor.white : (overUnder > 0 ? UIColor.green : UIColor.red)))
            
            playerTable.setNumberOfRows(context.playerNames.count, withRowType: "Player Row")
            for playerNumber in 1...context.playerNames.count {
                if let controller = playerTable.rowController(at: playerNumber - 1) as? WatchRoundRowController {
                    var playerString: String
                    if context.playerScores[0] < 0 {
                        if context.playerBids[playerNumber - 1] >= 0 {
                            playerString = "\(context.playerNames[playerNumber - 1]) bid \(context.playerBids[playerNumber - 1])"
                        } else {
                            playerString = ""
                        }
                    } else {
                        if context.playerScores[playerNumber - 1] >= 0 {
                            playerString = "\(context.playerNames[playerNumber - 1]) scored \(context.playerScores[playerNumber - 1])"
                        } else {
                            playerString = ""
                        }
                    }
                    controller.player = playerString
                }
            }
        }
    }
}

class WatchRoundRowController: NSObject {
    @IBOutlet var playerLabel: WKInterfaceLabel!
    
    var player:String! {
        didSet {
            if let player = player {
                playerLabel.setText(player)
            }
        }
    }
}
