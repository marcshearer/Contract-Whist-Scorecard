//
//  Rotation Gesture.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 09/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class RotationGesture {
    
    class func adminMenu(recognizer:UIRotationGestureRecognizer, message: String = "", options: [(String, ()->(), Bool)]? = nil) {
        if recognizer.state == .ended {
            AdminMenu.present(message: message, options: options)
        }
    }
}

extension ScorepadViewController {
    
    @IBAction private func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        RotationGesture.adminMenu(recognizer: recognizer, options: self.testRotationOptions())
    }
}

extension HandViewController {
    
    @IBAction internal func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        
        var rotationOptions = [("Show debug info",    self.showDebugInfo,   true)]
        if let testRotationOptions = self.testRotationOptions() {
            rotationOptions = rotationOptions + testRotationOptions
        }
        RotationGesture.adminMenu(recognizer: recognizer, options: rotationOptions)
    }
    
    private func showDebugInfo() {
        let message = "Selected round: \(Scorecard.game.selectedRound)\nRound: \(Scorecard.game.handState.round)\nCards: \(Scorecard.game.handState.hand.toString())\nDealer: \(Scorecard.game.dealerIs)\nTrick: \(Scorecard.game.handState.trick!)\nCards played: \(Scorecard.game.handState.trickCards.count)\nTo lead: \(Scorecard.game.handState.toLead!)\nTo play: \(Scorecard.game.handState.toPlay!)"
        self.alertMessage(message, title: "Hand Information", buttonText: "Continue")
    }
}

extension ReviewViewController {
    
    @IBAction internal func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        RotationGesture.adminMenu(recognizer: recognizer)
    }
}
