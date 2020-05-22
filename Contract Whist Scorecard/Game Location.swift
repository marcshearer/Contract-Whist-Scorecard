//
//  Game Location.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 08/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

class GameLocation {
    var latitude: CLLocationDegrees!
    var longitude: CLLocationDegrees!
    var description: String!
    var subDescription: String!
    
    init() {
    }
    
    init(latitude: CLLocationDegrees!, longitude: CLLocationDegrees, description: String, subDescription: String = "") {
        self.latitude = latitude
        self.longitude = longitude
        self.description = description
        self.subDescription = subDescription
    }
    
    public func setLocation(latitude: CLLocationDegrees!, longitude: CLLocationDegrees) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public func setLocation(_ location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
    }
    
    public func copy(to gameLocation: GameLocation!) {
        gameLocation.latitude = self.latitude
        gameLocation.longitude = self.longitude
        gameLocation.description = self.description
        gameLocation.subDescription = self.subDescription
    }
    
    public var locationSet: Bool {
        get {
            return (self.latitude != nil && self.longitude != nil)
        }
    }
    
    public func distance(from location: CLLocation) -> CLLocationDistance {
        let thisLocation = CLLocation(latitude: self.latitude, longitude: self.longitude)
        return thisLocation.distance(from: location)
    }
    
}
