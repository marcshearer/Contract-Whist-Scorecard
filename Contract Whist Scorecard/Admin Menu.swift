//
//  Admin Menu.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/08/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import UIKit

class AdminMenu {
    
    class func rotationGesture(recognizer:UIRotationGestureRecognizer, scorecard: Scorecard, options: [(String, ()->(), Bool)]? = nil) {
        if recognizer.state == .ended {
            self.present(scorecard: scorecard, options: options)
        }
    }
    
    class func present(scorecard: Scorecard, options: [(String, ()->(), Bool)]? = nil) {
       
        // Check if any additional options
        var availableOptions = false
        if (options != nil && options!.count > 0 ) {
            for (_, _, available) in options! {
                if available {
                    availableOptions = true
                    break
                }
            }
        }
        
        if availableOptions || (scorecard.commsDelegate != nil && scorecard.commsDelegate?.connectionFramework != .loopback) {
            // There are som options to display
            
            let actionSheet = ActionSheet("Admin Options")
            
            if availableOptions {
                for (description, action, available) in options! {
                    if available {
                        actionSheet.add(description, handler: action)
                    }
                }
            }
            
            // Generic options - connections
            if scorecard.commsDelegate != nil && scorecard.commsDelegate!.connectionFramework != .loopback {
                actionSheet.add("Show connections", handler: {
                    scorecard.commsDelegate?.connectionInfo()
                })
            }
            
            // Present the action sheet
            actionSheet.add("Cancel", style: .cancel)
            actionSheet.present()
        }
    }
}
