//
//  Player Managed Object.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 05/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation

extension PlayerMO {
    
    /** A uri string for the managed object */
    public var uri: String {
        get {
            // Returns the Object ID URI for a player managed object
            return self.objectID.uriRepresentation().absoluteString
        }
    }
       
}
