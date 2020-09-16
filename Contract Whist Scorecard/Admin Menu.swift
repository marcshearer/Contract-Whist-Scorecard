//
//  Admin Menu.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/08/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import UIKit

class AdminMenu {
    
    class func present(message: String, options: [(String, ()->(), Bool)]? = nil) {
       
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
        
        if availableOptions || Scorecard.adminMode || (Scorecard.shared.commsDelegate != nil && Scorecard.shared.commsDelegate?.connectionMode != .loopback) {
            // There are some options to display
            
            let viewController = Utility.getActiveViewController()!
            let actionSheet = ActionSheet("Admin Options", sourceView:  viewController.view, sourceRect: CGRect( origin: viewController.view.center, size: CGSize()), direction: UIPopoverArrowDirection())
            
            if availableOptions {
                for (description, action, available) in options! {
                    if available {
                        actionSheet.add(description, handler: action)
                    }
                }
            }
            
            // Generic options - connections
            if Scorecard.shared.commsDelegate != nil && Scorecard.shared.commsDelegate!.connectionMode != .loopback {
                actionSheet.add("Reset connection", handler: {
                    Scorecard.shared.resetConnection()
                })
                
                if (Scorecard.adminMode || Scorecard.shared.iCloudUserIsMe || Utility.isDevelopment) {
                    actionSheet.add("Test connection", handler: {
                        Scorecard.shared.sendTestConnection()
                    })
                    actionSheet.add("Show connections", handler: {
                        Scorecard.shared.commsDelegate?.connectionInfo(message: message)
                    })
                }
            }
            
            if Scorecard.adminMode {
                actionSheet.add("Leave admin mode", handler: {
                    Scorecard.adminMode = false
                })
            }
                        
            // Present the action sheet
            actionSheet.add("Cancel", style: .cancel)
            actionSheet.present(from: viewController)
        }
    }
}
