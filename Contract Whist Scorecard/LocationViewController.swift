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

class LocationViewController: ScorecardAppViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, CLLocationManagerDelegate {

    // Whist view properties
    override internal var scorecardView: ScorecardView? { return ScorecardView.location }
    public weak var controllerDelegate: ScorecardAppControllerDelegate?
    
    // MARK: - Class Properties ======================================================================== -

    // Properties to pass state
    private var useCurrentLocation = true
    private var mustChange = false
    private var bannerColor: UIColor?
    private var completion: ((GameLocation?)->())?

    // Local class variables
    private var locationManager: CLLocationManager! = nil
    private var geocoderLocations: [CLPlacemark]!
    private var historyLocations: [GameLocation]!
    private var filteredHistoryLocations: [GameLocation]!
    private var newLocation = GameLocation()
    private var currentLocation: GameLocation!
    private var lastLocation: GameLocation!
    private var historyMode = false
    private var testMode = false
    private let rowHeight: CGFloat = 50.0
    private var searchTextField: UITextField!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak private var locationMapView: MKMapView!
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var navigationBar: NavigationBar!
    @IBOutlet weak private var searchBar: UISearchBar!
    @IBOutlet private weak var searchBarBackgroundView: UIView!
    @IBOutlet private weak var bannerContinuationView: BannerContinuation!
    @IBOutlet weak private var locationTableView: UITableView!
    @IBOutlet weak private var continueButton: UIButton!
    @IBOutlet weak private var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak private var locationTableViewHeight: NSLayoutConstraint!
    
    // MARK: - IB Actions ============================================================================== -
 
    @IBAction func finishPressed(_ sender: UIButton) {
        self.dismiss()
    }
    
    @IBAction func continuePressed(_ sender: UIButton) {
        self.dismiss(location: self.newLocation)
    }

     // MARK: - View Overrides ========================================================================== -

    override internal func viewDidLoad() {
        super.viewDidLoad()
        if let testModeValue = ProcessInfo.processInfo.environment["TEST_MODE"] {
            if testModeValue.lowercased() == "true" {
                self.testMode = true
            }
        }
        
        // Make search bar transparent to pick up background - avoids slight translucence
        self.searchBar.backgroundImage = UIImage()
        self.searchBar.backgroundColor = UIColor.clear
        self.searchBar.barTintColor = UIColor.clear
        
        // Setup search text field
        self.searchTextField = searchBar.value(forKey: "searchField") as? UITextField
        self.searchTextField.textColor = Palette.text
        
        if self.newLocation.description != nil && self.newLocation.locationSet && self.newLocation.description != "" && self.newLocation.description != "Online" {
            // Save last location
            self.lastLocation = GameLocation(latitude: self.newLocation.latitude, longitude: self.newLocation.longitude, description: self.newLocation.description)
        }
        
        if self.newLocation.description != "" {
            self.searchBar.text = self.newLocation.description
            historyMode = false
        } else {
            self.getHistoryList()
            if self.historyLocations.count != 0 {
                self.historyMode = true
                self.searchBar.becomeFirstResponder()
            } else {
                self.historyMode = false
            }
        }
        
        if self.useCurrentLocation {
            if !getCurrentLocation() {
                self.historyMode = true
                self.getHistoryList()
                self.searchBar.becomeFirstResponder()
            }
        } else {
            dropPin()
        }
        if self.mustChange || self.newLocation.description == "" {
            hideFinishButtons()
        }
        if historyMode {
            showLocationList()
        } else {
            hideLocationList()
        }
    }
    
    override internal func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        Scorecard.shared.reCenterPopup(self)
        
        // Set colors of banner
        if let bannerColor = self.bannerColor {
            self.bannerPaddingView.bannerColor = bannerColor
            self.navigationBar.bannerColor = bannerColor
            self.bannerContinuationView.bannerColor = bannerColor
            self.bannerContinuationView.borderColor = bannerColor
            self.searchBarBackgroundView.backgroundColor = bannerColor
            self.locationTableView.backgroundColor = bannerColor
        }
        
        
        if self.locationTableViewHeight.constant != 0.0 {
            self.showLocationList()
        }
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        Scorecard.shared.motionBegan(motion, with: event)
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
    
    internal func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return rowHeight
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
            bottomRow = filteredHistoryLocations[indexPath.row-standard].subDescription ?? ""
        }
    
        cell = tableView.dequeueReusableCell(withIdentifier: "Location Table Cell", for: indexPath) as! LocationTableCell
        cell.locationTopLabel.text = topRow
        cell.locationBottomLabel.text = bottomRow
        
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = UIColor.clear
        
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        selectRow(indexPath.row)
    
    }
    
    // MARK: - SearchBar delegate Overrides ============================================================= -
    
    internal func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateSearch()
    }
    
    private func updateSearch() {
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
        Utility.mainThread { [unowned self] in
            var nearby = false
            // Check this isn't the same location as last time
            if self.newLocation.locationSet {
                let distanceInMeters = self.newLocation.distance(from: locations[0])
                nearby = (distanceInMeters <= 3000)
            }
            // Update the current location
            
            
            // If nearby keep current description - otherwise reverse look up
            if !nearby || self.newLocation.description == nil || self.newLocation.description == "" {
                // Get text name for location
                let geoCoder = CLGeocoder()
                geoCoder.reverseGeocodeLocation(locations[0], completionHandler: { placemarks, error in
                    Utility.mainThread { [unowned self] in
                        if error != nil {
                            self.newLocation.description = ""
                            self.searchBar.text = ""
                            self.historyMode = true
                            self.hideFinishButtons()
                        } else {
                            if self.historyLocations != nil && self.historyLocations.count != 0 && self.currentLocation == nil {
                                self.currentLocation = GameLocation(latitude: locations[0].coordinate.latitude, longitude: locations[0].coordinate.longitude, description: (placemarks?[0].locality)!)
                                self.currentLocation.subDescription = "Current location"
                                // Add it to the history list
                                Utility.debugMessage("locationManager", "Inserting current location")
                                self.historyLocations.insert(self.currentLocation, at: 0)
                                if self.historyMode {
                                    self.updateSearch()
                                }
                            } else {
                                self.newLocation = GameLocation(latitude: locations[0].coordinate.latitude, longitude: locations[0].coordinate.longitude, description: (placemarks?[0].locality) ?? "")
                                self.searchBar.text = placemarks?[0].locality
                                self.dropPin()
                                self.showFinishButtons()
                            }
                        }
                        self.resetPlaceholder()
                    }
                })
            } else {
                self.searchBar.text = self.newLocation.description
                self.historyMode = (self.searchBar.text == "")
                self.showFinishButtons()
                self.resetPlaceholder()
            }
        }
    }
    
    internal func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Unable to get current location
        Utility.mainThread { [unowned self] in
            self.searchBar.becomeFirstResponder()
            self.resetPlaceholder()
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    private func showLocationList() {
        let availableHeight = locationMapView.frame.maxY - searchBar.frame.maxY
        self.locationTableViewHeight.constant = CGFloat(Int(availableHeight / 2.0 / rowHeight)) * rowHeight
        hideFinishButtons()
    }
    
    private func hideFinishButtons() {
        if !testMode {
            self.continueButton.isHidden = true
        }
    }
    
    private func hideLocationList() {
        self.locationTableViewHeight.constant = 0.0
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
        
        searchTextField?.attributedPlaceholder = NSAttributedString(string: "Please wait - getting location", attributes: [NSAttributedString.Key.foregroundColor: Palette.text.withAlphaComponent(0.7)])
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
                self.activityIndicator.superview!.bringSubviewToFront(self.activityIndicator)
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
            if self.newLocation.locationSet {
                latitude = self.newLocation.latitude
                longitude = self.newLocation.longitude
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
        searchTextField.attributedPlaceholder = NSAttributedString(string: "Enter description of current location", attributes: [NSAttributedString.Key.foregroundColor: Palette.text.withAlphaComponent(0.5)])
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
            self.newLocation.copy(to: self.lastLocation)
            searchBar.text = self.lastLocation.description
        } else if !historyMode {
            // Searched geocoder location selected
            if geocoderLocations != nil {
                let locationDescription = getLocationDescription(placemark: geocoderLocations![row-standard])
                searchBar.text = locationDescription.topRow
                self.newLocation.setLocation(geocoderLocations![row-standard].location!)
                self.newLocation.description = searchBar.text
            }
        } else {
            // Searched history location selected
            searchBar.text = filteredHistoryLocations[row-standard].description
            filteredHistoryLocations[row-standard].copy(to: self.newLocation)
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
        if self.newLocation.locationSet {
            
            let annotation = MKPointAnnotation()
            
            // Remove existing pins
            let allAnnotations = self.locationMapView.annotations
            self.locationMapView.removeAnnotations(allAnnotations)
            
            annotation.coordinate = CLLocationCoordinate2D(latitude: self.newLocation.latitude, longitude: self.newLocation.longitude)
            self.locationMapView.addAnnotation(annotation)
            
            // Set the zoom level
            let region = MKCoordinateRegion.init(center: annotation.coordinate, latitudinalMeters: 2e5, longitudinalMeters: 2e5)
            self.locationMapView.setRegion(region, animated: false)
        }
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: ScorecardViewController, gameLocation: GameLocation, useCurrentLocation: Bool = true, mustChange: Bool = false, bannerColor: UIColor? = nil, completion: ((GameLocation?)->())? = nil) {
        
        let storyboard = UIStoryboard(name: "LocationViewController", bundle: nil)
        let locationViewController = storyboard.instantiateViewController(withIdentifier: "LocationViewController") as! LocationViewController
        
        locationViewController.preferredContentSize = CGSize(width: 400, height: Scorecard.shared.scorepadBodyHeight)
        locationViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        locationViewController.newLocation = gameLocation
        locationViewController.useCurrentLocation = useCurrentLocation
        locationViewController.mustChange = mustChange
        locationViewController.bannerColor = bannerColor
        locationViewController.completion = completion
        
        viewController.present(locationViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
    }
    
    private func dismiss(location: GameLocation? = nil) {
        self.alertDecision(if: Scorecard.game.isHosting && location == nil, "Warning: This will clear the existing score card and start a new game.\n\n Are you sure you want to do this?", title: "Finish Game", okButtonText: "Confirm", okHandler: {
                self.dismiss(animated: true, completion: {
                    self.completion?(location)
                })
            })
    }
    
    override internal func didDismiss() {
        self.completion?(nil)
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class LocationTableCell: UITableViewCell {
    @IBOutlet weak var locationTopLabel: UILabel!
    @IBOutlet weak var locationBottomLabel: UILabel!
}
