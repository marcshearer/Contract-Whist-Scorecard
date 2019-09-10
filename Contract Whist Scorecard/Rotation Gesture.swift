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
        let message = "Selected round: \(Scorecard.shared.selectedRound)\nRound: \(self.state.round)\nCards: \(self.state.hand.toString())\nDealer: \(Scorecard.shared.dealerIs)\nTrick: \(self.state.trick!)\nCards played: \(self.state.trickCards.count)\nTo lead: \(self.state.toLead!)\nTo play: \(self.state.toPlay!)"
        self.alertMessage(message, title: "Hand Information", buttonText: "Continue")
    }
}

extension ClientViewController {
    
    @IBAction internal func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        RotationGesture.adminMenu(recognizer: recognizer, message: "App state: \(self.appState?.rawValue ?? "Unknown")")
    }
}

extension ReviewViewController {
    
    @IBAction internal func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        RotationGesture.adminMenu(recognizer: recognizer)
    }
}
