//
//  LocationViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/02/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class LocationViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, CLLocationManagerDelegate {

    // MARK: - Class Properties ======================================================================== -

    // Main state properties
    var scorecard: Scorecard!
    
    // Properties to pass state to / from segues
    public var gameLocation: GameLocation!
    public var useCurrentLocation = true
    public var returnSegue = ""
    public var complete = false
    public var mustChange = false

    // Local class variables
    private var locationManager: CLLocationManager! = nil
    private var geocoderLocations: [CLPlacemark]!
    private var historyLocations: [GameLocation]!
    private var filteredHistoryLocations: [GameLocation]!
    private var newLocation = GameLocation()
    private var lastLocation: GameLocation!
    private var historyMode = false
    private var testMode = false
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak private var locationMapView: MKMapView!
    @IBOutlet weak private var searchBar: UISearchBar!
    @IBOutlet weak private var locationTableView: UITableView!
    @IBOutlet weak private var locationSeparator: UIView!
    @IBOutlet weak private var continueButton: UIButton!
    @IBOutlet weak private var activityIndicator: UIActivityIndicatorView!

    
    // MARK: - IB Actions ============================================================================== -
 
    @IBAction func finishPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: self.returnSegue, sender: self)
    }
    
    @IBAction func continuePressed(_ sender: UIButton) {
        self.complete = true
        self.newLocation.copy(to: self.gameLocation)
        self.performSegue(withIdentifier: self.returnSegue, sender: self)
    }

     // MARK: - View Overrides ========================================================================== -

    override internal func viewDidLoad() {
        super.viewDidLoad()
        if let testModeValue = ProcessInfo.processInfo.environment["TEST_MODE"] {
            if testModeValue.lowercased() == "true" {
                self.testMode = true
            }
        }
    }
    
    override internal func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.gameLocation.copy(to: self.newLocation)
        
        if self.newLocation.description != nil && self.newLocation.location != nil && self.newLocation.description != "" && self.newLocation.description != "Online" {
            // Save last location
            self.lastLocation = GameLocation(location: self.newLocation.location!, description: self.newLocation.description)
        }
        
        self.searchBar.text = self.newLocation.description
        historyMode = (self.searchBar.text == "")
        if self.useCurrentLocation {
            if !getCurrentLocation() {
                historyMode = true
                getHistoryList()
                self.searchBar.becomeFirstResponder()
            }
        } else {
            dropPin()
        }
        if self.searchBar.text == "" || self.mustChange {
            hideFinishButtons()
        }
        hideLocationList()
    }
    
    override internal func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        scorecard.reCenterPopup(self)
        
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var standard = 0
        
        if historyMode && filteredHistoryLocations == nil {
            return 1
        } else if !historyMode && geocoderLocations == nil {
            return 1
        } else {
            if self.lastLocation != nil && self.lastLocation.description != self.searchBar.text {
                standard += 1
            }
            if searchBar.text != "" {
                standard += 1
            }
            
            if historyMode {
                return filteredHistoryLocations.count + standard
            } else {
                return geocoderLocations.count + standard
            }
        }
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: LocationTableCell
        var topRow = ""
        var bottomRow = ""
        var standard = 0
        
        if self.lastLocation != nil && self.lastLocation.description != self.searchBar.text {
            standard += 1
        }
        if searchBar.text != "" {
            standard += 1
        }
        
        if indexPath.row == 0 && self.searchBar.text! != "" {
            // Allow selection of text as typed
            topRow = self.searchBar.text!
            bottomRow = "New description for current location"
        } else if indexPath.row < standard {
            // Include previous
            topRow = self.lastLocation.description
            bottomRow = "Last location"
        } else if !historyMode && geocoderLocations != nil {
            // Show entry in list returned by geocoder
            let locationDescription = getLocationDescription(placemark: geocoderLocations[indexPath.row-standard])
            topRow = locationDescription.topRow
            bottomRow = locationDescription.bottomRow
        } else  if historyMode && filteredHistoryLocations != nil {
            // Show entry in list from game history
            topRow = filteredHistoryLocations[indexPath.row-standard].description
            bottomRow = ""
        }
    
        cell = tableView.dequeueReusableCell(withIdentifier: "Location Table Cell", for: indexPath) as! LocationTableCell
        cell.locationTopLabel.text = topRow
        cell.locationBottomLabel.text = bottomRow
        
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        selectRow(indexPath.row)
    
    }
    
    // MARK: - SearchBar delegate Overrides ============================================================= -
    
    internal func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if self.searchBar.text!.count > 4 {
            historyMode = false
            getGeocoderList()
        } else {
            historyMode = true
            getHistoryList()
        }
    }
    
    // MARK: - Location delegate Overrides ========================================================================== -

    internal func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Utility.mainThread { [unowned self] in
            if status == .authorizedWhenInUse {
                // Authorization granted
                // Ask for location and continue in did update locations delegate or did fail with error delegate
                self.locationManager.requestLocation()
            }
        }
    }

    internal func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        var nearby = false
        // Check this isn't the same location as last time
        if self.newLocation.location != nil {
            let distanceInMeters = self.newLocation.location.distance(from: locations[0])
            nearby = (distanceInMeters <= 3000)        }
        // Update the location
        self.newLocation.location = locations[0]
        self.dropPin()
        
        // If nearby keep current description - otherwise reverse look up
        if !nearby || self.newLocation.description == nil || self.newLocation.description == "" {
            // Get text name for location
            let geoCoder = CLGeocoder()
            geoCoder.reverseGeocodeLocation(self.newLocation.location, completionHandler: { placemarks, error in
                if error != nil {
                    self.newLocation.description = ""
                    self.searchBar.text = ""
                    self.historyMode = true
                    self.hideFinishButtons()
                } else {
                    self.newLocation.description = placemarks?[0].locality
                    self.searchBar.text = placemarks?[0].locality
                    self.historyMode = (self.searchBar.text == "")
                    self.showFinishButtons()
                }
                self.resetPlaceholder()
            })
        } else {
            self.searchBar.text = self.newLocation.description
            self.historyMode = (self.searchBar.text == "")
            self.showFinishButtons()
            self.resetPlaceholder()
        }
        
    }
    
    internal func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Unable to get current location
        self.searchBar.becomeFirstResponder()
        resetPlaceholder()
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    private func showLocationList() {
        self.locationTableView.isHidden = false
        self.locationMapView.isHidden = true
        self.locationSeparator.isHidden = false
        hideFinishButtons()
    }
    
    private func hideFinishButtons() {
        if !testMode {
            self.continueButton.isHidden = true
        }
    }
    
    private func hideLocationList() {
        self.locationTableView.isHidden = true
        self.locationMapView.isHidden = false
        self.locationSeparator.isHidden = true
    }
    
    private func showFinishButtons(autoSelect: Bool = false) {
        self.continueButton.isHidden = false
        if self.testMode && autoSelect {
            // In test mode automatically select continue
            self.continuePressed(self.continueButton)
        }
    }
    // MARK: - Utility Routines ======================================================================== -

    private func getCurrentLocation() -> Bool {
        var result = false
        
         searchBar.placeholder = "Please wait - getting location"
        let authorizationStatus = CLLocationManager.authorizationStatus()
        if authorizationStatus == .restricted || authorizationStatus == .denied {
            // Not allowed to use location - go straight to input
            result = false
            
        } else {
            
            locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            if authorizationStatus == .notDetermined {
                // Ask for permission and continue in authorization changed delegate
                locationManager.requestWhenInUseAuthorization()
            } else {
                // Ask for location and continue in did update locations delegate or did fail with error delegate
                self.activityIndicator.startAnimating()
                self.activityIndicator.isHidden = false
                self.activityIndicator.superview!.bringSubview(toFront: self.activityIndicator)
                self.searchBar.isUserInteractionEnabled = false
                self.locationManager.requestLocation()
            }
            result = true
        }
        
        return result
    }
    
    private func getGeocoderList() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchBar.text!, completionHandler: { placemarks, error in
            if error == nil && placemarks != nil {
                self.geocoderLocations = placemarks
            } else {
                self.geocoderLocations = nil
            }
            self.locationTableView.reloadData()
            self.showLocationList()
        })
    }
    
    private func getHistoryList() {
        if self.historyLocations == nil {
            var latitude: CLLocationDegrees = 0.0
            var longitude: CLLocationDegrees = 0.0
            if self.newLocation.location != nil {
                latitude = self.newLocation.location.coordinate.latitude
                longitude = self.newLocation.location.coordinate.longitude
            }
            // Load the full list since not got it already
            self.historyLocations = History.getGameLocations(latitude: latitude,
                                                             longitude: longitude,
                                                             skipLocation: (lastLocation == nil ? "" : lastLocation.description))
        }
        if self.searchBar.text == "" {
            // No filter - use whole list
            self.filteredHistoryLocations = historyLocations
        } else if self.historyLocations.count != 0 {
            // Try filter
            self.filteredHistoryLocations = []
            for historyLocation in self.historyLocations {
                if historyLocation.description.left(self.searchBar.text!.length).lowercased() == self.searchBar.text?.lowercased() {
                    filteredHistoryLocations.append(historyLocation)
                }
            }
        }
        if (filteredHistoryLocations == nil || filteredHistoryLocations.count == 0) && self.searchBar.text != "" {
            // Nothing in list - revert to geocoder list if have some characters
            historyMode = false
            getGeocoderList()
        }
        self.locationTableView.reloadData()
        self.showLocationList()
    }
    
    private func getLocationDescription(placemark: CLPlacemark) -> (topRow: String, bottomRow: String) {
        var topRow = ""
        var bottomRow = ""
        
         if placemark.subLocality != nil {
            topRow = placemark.subLocality!
            if placemark.locality != nil {
                if placemark.country != nil {
                    bottomRow = "\(placemark.locality!), \(placemark.country!)"
                } else {
                    bottomRow = placemark.locality!
                }
            }
        } else if placemark.locality != nil{
            topRow = placemark.locality!
        } else if placemark.name != nil {
            topRow = placemark.name!
        }
        
        if placemark.country != nil {
            if topRow == "" {
                topRow = placemark.country!
            } else if bottomRow == "" {
                bottomRow = placemark.country!
            }
        }
        
        return (topRow, bottomRow)
    }
    
    private func resetPlaceholder() {
        searchBar.placeholder = "Enter description of current location"
        self.searchBar.isUserInteractionEnabled = true
        self.activityIndicator.stopAnimating()
    }
    
    private func selectRow(_ row: Int) {
        var standard = 0
        var autoSelect = false
        
        if self.lastLocation != nil && self.lastLocation.description != self.searchBar.text {
            standard += 1
        }
        if searchBar.text != "" {
            standard += 1
        }
        
        if row == 0 && self.searchBar.text! != "" {
            // Top row selected - take new description and leave location as is
            self.newLocation.description = searchBar.text
            autoSelect = true
        } else if row < standard {
            // Last location
            self.newLocation.description = self.lastLocation.description
            self.newLocation.location = self.lastLocation.location
            searchBar.text = self.lastLocation.description
        } else if !historyMode {
            // Searched geocoder location selected
            if geocoderLocations != nil {
                let locationDescription = getLocationDescription(placemark: geocoderLocations![row-standard])
                searchBar.text = locationDescription.topRow
                self.newLocation.location = geocoderLocations![row-standard].location
                self.newLocation.description = searchBar.text
            }
        } else {
            // Searched history location selected
            searchBar.text = filteredHistoryLocations[row-standard].description
            self.newLocation.location = filteredHistoryLocations[row-standard].location
            self.newLocation.description = searchBar.text
        }
        historyMode = (self.searchBar.text == "")
        self.hideLocationList()
        searchBar.resignFirstResponder()
        dropPin()
        self.showFinishButtons(autoSelect: autoSelect)
    }
    
    private func dropPin() {
        // Create map annotation - don't do it in test mode since upsets tests
        if self.newLocation.location != nil {
            
            let annotation = MKPointAnnotation()
            
            // Remove existing pins
            let allAnnotations = self.locationMapView.annotations
            self.locationMapView.removeAnnotations(allAnnotations)
            
            annotation.coordinate = self.newLocation.location.coordinate
            self.locationMapView.addAnnotation(annotation)
            
            // Set the zoom level
            let region = MKCoordinateRegionMakeWithDistance(annotation.coordinate, 2e5, 2e5)
            self.locationMapView.setRegion(region, animated: false)
        }
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class LocationTableCell: UITableViewCell {
    @IBOutlet weak var locationTopLabel: UILabel!
    @IBOutlet weak var locationBottomLabel: UILabel!
}
