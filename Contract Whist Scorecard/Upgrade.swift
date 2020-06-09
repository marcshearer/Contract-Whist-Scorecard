  //
//  Upgrade.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 08/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//
// Contains logic to upgrade a device from one version to another

import Foundation
import UIKit
import CoreData

class Upgrade {
    
    class func upgradeTo41(from viewController: UIViewController, completion: (()->())? = nil) -> Bool {
        // Sort out corruption in number of hands that happened back in December 2017 / January 2018
        
        // Reset all games with 25 hands to 13
        DataAdmin.patchLocalDatabase(from: viewController, silent: true)
        
        // Rebuild all players
        let reconcile = Reconcile()
        reconcile.reconcilePlayers(playerMOList: Scorecard.shared.playerList, syncFirst: false)
        
        return true
    }
}
