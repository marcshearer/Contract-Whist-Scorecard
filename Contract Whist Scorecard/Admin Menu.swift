//
//  Admin Menu.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/08/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import UIKit

class AdminMenu {
    
    class func present(options: [(String, ()->(), Bool)]? = nil) {
       
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
        
        if availableOptions || (Scorecard.shared.commsDelegate != nil && Scorecard.shared.commsDelegate?.connectionFramework != .loopback) {
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
            if Scorecard.shared.commsDelegate != nil && Scorecard.shared.commsDelegate!.connectionFramework != .loopback {
                actionSheet.add("Reset connection", handler: {
                    Scorecard.shared.resetConnection()
                })
                actionSheet.add("Show connections", handler: {
                    Scorecard.shared.commsDelegate?.connectionInfo()
                })
            }
            
            // Present the action sheet
            actionSheet.add("Cancel", style: .cancel)
            actionSheet.present()
        }
    }
}
