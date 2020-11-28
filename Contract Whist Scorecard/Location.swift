//
//  Location.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 08/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation
import CoreLocation

class Location: NSObject, CLLocationManagerDelegate {
    
    var locationManager: CLLocationManager!
    var successAction: (()->())?
    var failureAction: (()->())?
    
    public func checkUseLocation(refused: ((Bool)->())? = nil, accepted: (()->())? = nil, unknown: (()->())? = nil, request: Bool = false) {
        let authorizationStatus = CLLocationManager.authorizationStatus()
        switch authorizationStatus {
        case .restricted, .denied:
            // Not allowed to use location
            refused?(false)
        case .notDetermined:
            if request {
                self.requestUseLocation(successAction: accepted, failureAction: {refused?(true)})
            } else {
                unknown?()
            }
        default:
            accepted?()
        }
    }
    
    public func requestUseLocation(successAction: (()->())? = nil, failureAction: (()->())? = nil) {
        self.successAction = successAction
        self.failureAction = failureAction
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        // Ask for permission and continue in authorization changed delegate
        locationManager.requestWhenInUseAuthorization()
    }
    
    internal func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Utility.mainThread { [weak self] in
            if status == .authorizedWhenInUse {
                // Authorization granted
                self?.successAction?()
             } else {
                // Permission to use location refused
                self?.failureAction?()
            }
        }
    }
}
