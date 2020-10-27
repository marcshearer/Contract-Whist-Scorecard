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

class LocationViewController: ScorecardViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, CLLocationManagerDelegate, BannerDelegate {
    
    // MARK: - Class Properties ======================================================================== -

    // Properties to pass state
    private var useCurrentLocation = true
    private var mustChange = false
    private var bannerColor: PaletteColor?
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
    private var canFinish = false
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var locationMapView: MKMapView!
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var searchBarBackgroundView: UIView!
    @IBOutlet private weak var locationTableView: UITableView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var locationTableViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var bottomSectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var continueButton: ShadowButton!
    
    // MARK: - IB Actions ============================================================================== -
 
    internal func finishPressed() {
        if let delegate = self.controllerDelegate {
            delegate.didCancel()
        } else {
            self.dismiss(nil)
        }
    }
    
    internal func infoPressed() {
        self.searchBar.resignFirstResponder()
        self.helpView?.show()
    }
    
    @IBAction func continuePressed(_ sender: UIButton) {
        self.continuePressed()
    }
    
    internal func continuePressed() {
        if let delegate = self.controllerDelegate {
            self.newLocation.copy(to: Scorecard.game.location)
            if Scorecard.game.isHosting {
                Scorecard.shared.sendLocation()
            }
            delegate.didProceed()
        } else {
            self.dismiss(self.newLocation)
        }
    }

     // MARK: - View Overrides ========================================================================== -

    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()
        self.setupButtons()

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
        self.searchTextField.textColor = Palette.normal.text
        self.searchTextField.backgroundColor = Palette.normal.background
        
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
        
        // Setup help
        self.setupHelpView()
    }
    
    override internal func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Scorecard.shared.reCenterPopup(self)
        
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Show appropriate continue buttons
        if self.canFinish {
            self.showFinishButtons()
        }
        
        // Set colors of banner
        if let bannerColor = self.bannerColor {
            self.banner.set(backgroundColor: bannerColor, titleColor: Palette.tableTop.text)
            self.searchBarBackgroundView.backgroundColor = bannerColor.background
            self.locationTableView.backgroundColor = bannerColor.background
        }
        
        if self.locationTableViewHeight.constant != 0.0 {
            self.showLocationList()
        }
        
        self.bottomSectionHeightConstraint.constant = ((self.menuController?.isVisible ?? false) ? 75 : 58) + (self.view.safeAreaInsets.bottom == 0 ? 8.0 : 0.0)
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
        // Setup default colors (previously done in StoryBoard)
        self.defaultCellColors(cell: cell)

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
    
    private func setupButtons() {
        
        // Add banner continue button
        self.banner.set(
            rightButtons: [
                BannerButton(image: UIImage(systemName: "questionmark"), action: self.infoPressed, type: .rounded, menuHide: true, id: "info"),
                BannerButton(title: "Continue", image: UIImage(named: "forward"), width: 100, action: self.continuePressed, menuHide: true, id: "continue")])
        
        // Set continue button and title
        self.continueButton.toCircle()
        
        self.hideFinishButtons()
    }
    
    private func showLocationList() {
        let availableHeight = locationMapView.frame.maxY - searchBar.frame.maxY
        self.locationTableViewHeight.constant = CGFloat(Int(availableHeight / 2.0 / rowHeight)) * rowHeight
        hideFinishButtons()
    }
    
    private func hideFinishButtons() {
        if !testMode {
            self.continueButton.isHidden = true
            self.banner.setButton("continue", isHidden: true)
            self.canFinish = false
        }
    }
    
    private func hideLocationList() {
        self.locationTableViewHeight.constant = 0.0
    }
    
    private func showFinishButtons(autoSelect: Bool = false) {
        let bannerContinue = ScorecardUI.landscapePhone()
        self.banner.setButton("continue", isHidden: !bannerContinue)
        self.continueButton.isHidden = bannerContinue
        self.canFinish = true
        if self.testMode && autoSelect {
            // In test mode automatically select continue
            self.continuePressed(self.continueButton)
        }
    }
    // MARK: - Utility Routines ======================================================================== -

    private func getCurrentLocation() -> Bool {
        var result = false
        
        searchTextField?.attributedPlaceholder = NSAttributedString(string: "Please wait - getting location", attributes: [NSAttributedString.Key.foregroundColor: Palette.normal.text.withAlphaComponent(0.7)])
        let authorizationStatus = CLLocationManager.authorizationStatus()
        if authorizationStatus == .restricted || authorizationStatus == .denied {
            // Not allowed to use location - go straight to input
            self.alertMessage("You have chosen not to allow this app to access your location. To change this go to the Whist option in the main Settings app and change the location permissions to 'Allow while using'")
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
        searchTextField.attributedPlaceholder = NSAttributedString(string: "Enter description of current location", attributes: [NSAttributedString.Key.foregroundColor: Palette.normal.text.withAlphaComponent(0.5)])
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
    
    class public func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, gameLocation: GameLocation, useCurrentLocation: Bool = true, mustChange: Bool = false, bannerColor: PaletteColor? = nil, completion: ((GameLocation?)->())? = nil) -> LocationViewController {
        
        if appController != nil && completion != nil {
            fatalError("Completion not used in app controller")
        }
        
        let storyboard = UIStoryboard(name: "LocationViewController", bundle: nil)
        let locationViewController = storyboard.instantiateViewController(withIdentifier: "LocationViewController") as! LocationViewController
        
        locationViewController.newLocation = gameLocation
        locationViewController.useCurrentLocation = useCurrentLocation
        locationViewController.mustChange = mustChange
        locationViewController.bannerColor = bannerColor
        locationViewController.completion = completion
        
        viewController.present(locationViewController, appController: appController, animated: true, container: .mainRight, completion: nil)
        
        return locationViewController
    }
    
    private func dismiss(_ location: GameLocation?) {
        self.dismiss(animated: true, completion: { self.completion?(location) })
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

extension LocationViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.activityIndicator.color = Palette.normal.text
        self.banner.set(backgroundColor: Palette.tableTop)
        self.locationTableView.backgroundColor = Palette.tableTop.background
        self.locationTableView.separatorColor = Palette.normal.background
        self.searchBarBackgroundView.backgroundColor = Palette.tableTop.background
        self.view.backgroundColor = Palette.normal.background
        self.continueButton.setBackgroundColor(Palette.continueButton.background)
        self.continueButton.setTitleColor(Palette.continueButton.text, for: .normal)
    }

    private func defaultCellColors(cell: LocationTableCell) {
        switch cell.reuseIdentifier {
        case "Location Table Cell":
            cell.locationBottomLabel.textColor = Palette.normal.background
            cell.locationTopLabel.textColor = Palette.tableTop.text
        default:
            break
        }
    }

}

extension LocationViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
          
        self.helpView.add("This screen allows you to enter the current location which will be saved to the game history.\nThe current location will be shown on entry if you have allowed the app access to your current location.\nYou can also either select a recent location from the list (when the search bar is empty) or you can enter text in the search bar to search for a location.")
        
        self.helpView.add("Enter text to search for the current location in the @*/Search@*/ bar or set to blank to see a list of recent locations.", views: [self.searchTextField], border: 0, radius: 8)
        
        self.helpView.add("\((self.searchBar.text! != "" ? "Below the @*/Search@*/ bar you will see a list of matching locations. Blank out the search text to see recent locations from this device" : "When the @*/Search@*/ bar is empty you will see a list of the most recent locations where you have played. Enter some text to search for other locations")).", views: [self.locationTableView], radius: 0, shrink: true)
        
        self.helpView.add("The selected location will be shown on the map by a pin. You can zoom in and out using pinch gestures or swipe to move the map.\n\nYou **cannot** select a location from the map", views: [self.locationMapView], radius: 0, shrink: true)
        
        self.helpView.add("\((self.canFinish ? "When you have specified a location the {} will be enabled. " : ""))Click the {} to start the game.", descriptor: "@*/Continue@*/ button", views: [self.continueButton], bannerId: "continue", radius: self.continueButton.frame.height / 2)
        
        self.helpView.add("The {} will abandon the game and take you back to the home screen.", bannerId: Banner.finishButton)
    }
}
