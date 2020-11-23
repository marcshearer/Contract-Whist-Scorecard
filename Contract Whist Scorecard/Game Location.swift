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
import MapKit 
class GameLocation: Equatable {
        
    var latitude: CLLocationDegrees!
    var longitude: CLLocationDegrees!
    var description: String!
    var subDescription: String!
    
    init() {
    }
    
    init(latitude: CLLocationDegrees! = 0, longitude: CLLocationDegrees = 0, description: String, subDescription: String = "") {
        self.latitude = latitude
        self.longitude = longitude
        self.description = description
        self.subDescription = subDescription
    }
    
    static func == (lhs: GameLocation, rhs: GameLocation) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude && lhs.description == rhs.description && lhs.subDescription == rhs.subDescription
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
    
    public static func dropPin(_ mapView: MKMapView, location: GameLocation) {
        // Create map annotation - don't do it in test mode since upsets tests
        let annotation = MKPointAnnotation()
        
        // Remove existing pins
        let allAnnotations = mapView.annotations
        mapView.removeAnnotations(allAnnotations)
        
        if location.locationSet {
            if let latitude = location.latitude, let longitude = location.longitude {
                annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                mapView.addAnnotation(annotation)
                
                // Set the zoom level
                let region = MKCoordinateRegion.init(center: annotation.coordinate, latitudinalMeters: 2e5, longitudinalMeters: 2e5)
                mapView.setRegion(region, animated: false)
            }
        }
    }
}
