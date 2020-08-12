//
//  HistoryDetailViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 18/02/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import CloudKit

class HistoryDetailViewController: ScorecardViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Properties to pass state
    private var gameDetail: HistoryGame!
    private var callerCompletion: ((HistoryGame?)->())?
    
    // Local class variables
    let tableRowHeight:CGFloat = 44.0
    var players = 0
    var updated = false
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var participantTableView: UITableView!
    @IBOutlet private weak var locationText: UILabel!
    @IBOutlet private weak var locationBackground: UIView!
    @IBOutlet private weak var locationBackgroundHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var locationBackgroundLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var locationBackgroundTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var participantTableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var navigationBar: NavigationBar!
    @IBOutlet private weak var titleNavigationItem: UINavigationItem!
    @IBOutlet private weak var updateButton: ShadowButton!
    @IBOutlet private weak var finishButton: RoundedButton!
    @IBOutlet private weak var actionButton: UIBarButtonItem!
    @IBOutlet private weak var bodyView: UIView!
    @IBOutlet private weak var excludeStatsView: UIView!
    @IBOutlet private weak var excludeStatsLabel: UILabel!
    @IBOutlet private weak var excludeStatsHeightConstraint: NSLayoutConstraint!
    
    // MARK: - IB Actions ============================================================================== -

    @IBAction func finishPressed(_ sender: UIButton) {
        self.dismiss()
    }
    
    @IBAction func updatePressed(_ sender: Any) {
        self.showLocation()
    }
    
    @IBAction func actionPressed(_ sender: UIBarButtonItem) {
        shareGame()
    }
    
    @IBAction func allSwipe(recognizer:UISwipeGestureRecognizer) {
        finishPressed(finishButton)
    }
    
    // MARK: - View Overrides ========================================================================== -
     
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()

        if !Scorecard.activeSettings.saveLocation {
            locationBackgroundHeightConstraint.constant = 0
            locationText.isHidden = true
            updateButton.isHidden = true
            mapView.isHidden = true
        } else {
            // Only show update button if network available
            Scorecard.shared.checkNetworkConnection {
                let available = Scorecard.shared.isNetworkAvailable && Scorecard.shared.isLoggedIn
                self.updateButton.isHidden = !available
            }
        }
        
        let dateString = DateFormatter.localizedString(from: gameDetail.datePlayed, dateStyle: .medium, timeStyle: .none)
        let timeString = Utility.dateString(gameDetail.datePlayed, format: "HH:mm")
        titleNavigationItem.title = "\(dateString) - \(timeString)"
        players = gameDetail.participant.count
        participantTableViewHeightConstraint.constant = CGFloat(players + 1) * tableRowHeight
        if Scorecard.activeSettings.saveLocation {
            locationText.text = gameDetail.gameLocation.description
            dropPin()
        }
        if self.gameDetail.gameMO.excludeStats {
            Palette.sectionHeadingStyle(view: self.excludeStatsView)
        } else {
            self.excludeStatsHeightConstraint.constant = 0
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Scorecard.shared.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // Allow for safe area in layout indents
        locationBackgroundLeadingConstraint.constant = view.safeAreaInsets.left + 88
        locationBackgroundTrailingConstraint.constant = view.safeAreaInsets.right + 8
        self.participantTableView.reloadData()
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return players + 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableRowHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: HistoryDetailTableCell
        
        cell = tableView.dequeueReusableCell(withIdentifier: "History Detail Cell", for: indexPath) as! HistoryDetailTableCell
        // Setup default colors (previously done in StoryBoard)
        self.defaultCellColors(cell: cell)
        
        switch indexPath.row {
        case 0:
            // Header
            Palette.sectionHeadingStyle(cell)
            Palette.sectionHeadingStyle(cell.name)
            Palette.sectionHeadingStyle(cell.totalScore)
            Palette.sectionHeadingStyle(cell.handsMade)
            Palette.sectionHeadingStyle(cell.otherValue)
            
            cell.name.text = "Player"
            cell.totalScore.text = "Score"
            cell.handsMade.text = "Made"
            if Scorecard.activeSettings.bonus2 {
                cell.otherValue.text = "Twos"
            } else {
                cell.otherValue.text = "Made%"
            }
            
        default:
            // Player values
            let playerNumber = indexPath.row
            
            Palette.normalStyle(cell)
            Palette.normalStyle(cell.name)
            Palette.normalStyle(cell.totalScore)
            Palette.normalStyle(cell.handsMade)
            Palette.normalStyle(cell.otherValue)
            if Scorecard.shared.findPlayerByPlayerUUID(gameDetail.participant[playerNumber-1].participantMO.playerUUID!) == nil {
                // Player not on device - grey them out
                let grayedOut = Palette.normal.text.withAlphaComponent(0.3)
                cell.name.textColor = UIColor.lightGray
                cell.totalScore.textColor = grayedOut
                cell.handsMade.textColor = grayedOut
                cell.otherValue.textColor = grayedOut
            }

            cell.name.text = gameDetail.participant[playerNumber-1].name
            cell.totalScore.text = "\(gameDetail.participant[playerNumber-1].totalScore)"
            cell.handsMade.text = "\(gameDetail.participant[playerNumber-1].handsMade)"
            if Scorecard.activeSettings.bonus2 {
                cell.otherValue.text = "\(gameDetail.participant[playerNumber-1].twosMade)"
            } else {
                let handsMadePercent = Utility.roundPercent(CGFloat(gameDetail.participant[playerNumber-1].handsMade), CGFloat(gameDetail.participant[playerNumber-1].handsPlayed))
                cell.otherValue.text = "\(handsMadePercent) %"
            }
            
        }
        
        if indexPath.row == 0 || indexPath.row == self.players {
            // Hide separator on top row and bottom row
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: max(ScorecardUI.screenWidth, ScorecardUI.screenHeight), bottom: 0.0, right: 0.0)
        }
        
        return cell
    }
    
    // MARK: - Utility Routines ======================================================================== -
   
    func dropPin() {
        // Create map annotation
        let annotation = MKPointAnnotation()
        
        // Remove existing pins
        let allAnnotations = self.mapView.annotations
        self.mapView.removeAnnotations(allAnnotations)
        
        if gameDetail.gameLocation.locationSet {
            
            let gameLocation = gameDetail.gameLocation
        
            annotation.coordinate = CLLocationCoordinate2D(latitude: gameLocation.latitude, longitude: gameLocation.longitude)
            self.mapView.addAnnotation(annotation)
            
            // Set the zoom level
            let region = MKCoordinateRegion.init(center: annotation.coordinate, latitudinalMeters: 2e5, longitudinalMeters: 2e5)
            self.mapView.setRegion(region, animated: false)
        }
    }
    
    func saveLocation() {
        if gameDetail.gameMO.syncRecordID == nil {
            // Not yet synced - just save locally
            saveLocally()
        } else {
            // First retrieve it from the cloud
            let syncDate = Date()
            var cloudObject: CKRecord!
            let cloudContainer = CKContainer.init(identifier: Config.iCloudIdentifier)
            let publicDatabase = cloudContainer.publicCloudDatabase
            let predicate = NSPredicate(format: "gameUUID = %@", gameDetail.gameUUID)
            let query = CKQuery(recordType: "Games", predicate: predicate)
            let queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
            
            queryOperation.queuePriority = .veryHigh
            queryOperation.recordFetchedBlock = { (record) -> Void in
                cloudObject = record
            }
            
            queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
                if error != nil {
                    self.alertMessage("Unable to update location in cloud", title: "Error")
                } else {
                    if cloudObject != nil {
                        if Utility.objectDate(cloudObject: cloudObject, forKey: "syncDate") < syncDate {
                            // Update to cloud
                            cloudObject.setValue((self.gameDetail.gameLocation.description == "Unknown" ? "" : self.gameDetail.gameLocation.description), forKey: "location")
                            if self.gameDetail.gameLocation.locationSet {
                                cloudObject.setValue(self.gameDetail.gameLocation.latitude, forKey: "latitude")
                                cloudObject.setValue(self.gameDetail.gameLocation.longitude, forKey: "longitude")
                            }
                            cloudObject.setValue(syncDate, forKey: "syncDate")
                            publicDatabase.save(cloudObject, completionHandler: { (cloudObject, error) in
                                if error != nil {
                                    self.alertMessage("Unable to update location in cloud", title: "Error")
                                } else {
                                    // Now save it locally
                                    self.saveLocally()
                                    // And update sync date on participants to trigger download to other devices
                                    self.saveParticipants(gameUUID: self.gameDetail.gameUUID, syncDate: syncDate)
                                }
                            })
                        }
                    } else {
                        // Failed to read - probably not synced yet - just save locally
                        self.saveLocally()
                    }
                }
            }
            
            // Execute the query
            publicDatabase.add(queryOperation)
        }
    }

    func saveParticipants(gameUUID: String, syncDate: Date) {
        // Retrieve participants of game and set sync date
        var cloudObjectList: [CKRecord] = []
        let cloudContainer = CKContainer.init(identifier: Config.iCloudIdentifier)
        let publicDatabase = cloudContainer.publicCloudDatabase
        let predicate = NSPredicate(format: "gameUUID = %@", gameUUID)
        let query = CKQuery(recordType: "Participants", predicate: predicate)
        let queryOperation = CKQueryOperation(query: query, qos: .userInteractive)
        
        queryOperation.queuePriority = .veryHigh
        queryOperation.recordFetchedBlock = { (record) -> Void in
            cloudObjectList.append(record)
        }
        
        queryOperation.queryCompletionBlock = { (cursor, error) -> Void in
            if error == nil {
                for cloudObject in cloudObjectList {
                    // Update to cloud
                    if Utility.objectDate(cloudObject: cloudObject, forKey: "syncDate") < syncDate {
                        cloudObject.setValue(syncDate, forKey: "syncDate")
                        publicDatabase.save(cloudObject, completionHandler: { (cloudObject, error) in
                            // No action required
                        })
                    }
                }
            }
        }
        
        // Execute the query
        publicDatabase.add(queryOperation)
    }
    
    func saveLocally() {
        if !CoreData.update(updateLogic: {
            // Copy back updated location
            let gameMO = self.gameDetail.gameMO!
            gameMO.location = (self.gameDetail.gameLocation.description == "Unknown" ? "" : self.gameDetail.gameLocation.description)
            if self.gameDetail.gameLocation.locationSet {
                gameMO.latitude = self.gameDetail.gameLocation.latitude
                gameMO.longitude = self.gameDetail.gameLocation.longitude
            }
        }) {
            // Ignore errors - should come back down again anyway with new sync date
        }
    }
    
    func shareGame() {
        var message = ""
        var winners = 0
        var winner = ""
        var highScores: [ParticipantMO]!
        
        // Get screen dump image
        UIGraphicsBeginImageContext(bodyView.frame.size)
        bodyView.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let winningScore = gameDetail.participant[0].totalScore
        for playerNumber in 1...players {
            let name = gameDetail.participant[playerNumber-1].name
            if playerNumber == 1 {
                message = name
            } else if playerNumber == players {
                message = message + " and " + name
                
            } else {
                message = message + ", " + name
            }
            
            if  gameDetail.participant[playerNumber-1].totalScore == winningScore {
                winners += 1
                if winners == 1 {
                    winner = name
                } else {
                    winner = winner + " and " + name
                }
            }
        }
        
        let locationDescription = gameDetail.gameLocation.description
        message = message + " just finished a game of Contract Whist"
        if locationDescription != nil && locationDescription! != "" {
            if locationDescription == "Online" {
                message = message + " online"
            } else {
                message = message + " in " + locationDescription!
            }
        }
        message = message + ". " + winner + " won with a score of \(winningScore)."
        
        highScores = History.getHighScores(type: .totalScore, playerUUIDList: Scorecard.shared.playerUUIDList(getPlayerMode: .getAll))
        
        if winningScore == highScores[0].totalScore {
            message = message + " This was a new high score! Congratulations \(winner)."
        }
        
        // Share on Facebook etc
        let activityController = UIActivityViewController(activityItems: [message, image], applicationActivities: nil)
        self.present(activityController, animated: true, completion: nil)
        
    }
    
    // MARK: - Show other views ======================================================= -
    
    private func showLocation() {
        
        _ = LocationViewController.show(from: self, gameLocation: self.gameDetail.gameLocation, useCurrentLocation: false, mustChange: true, bannerColor: Palette.banner.background, completion: { (location) in
            if let location = location {
                // Copy location back
                self.gameDetail.gameLocation = location
                
                // Save location
                self.saveLocation()
                if self.locationText.text != self.gameDetail.gameLocation.description {
                    self.locationText.text = self.gameDetail.gameLocation.description
                    self.updated = true
                }
                
                self.dropPin()
            }
        })
    }
    
    // MARK: - method to show and dismiss this view controller ============================================================================== -
    
    static public func show(from sourceViewController: ScorecardViewController, gameDetail: HistoryGame, sourceView: UIView?, completion: ((HistoryGame?)->())? = nil) {
        let storyboard = UIStoryboard(name: "HistoryDetailViewController", bundle: nil)
        let historyDetailViewController = storyboard.instantiateViewController(withIdentifier: "HistoryDetailViewController") as! HistoryDetailViewController

        historyDetailViewController.preferredContentSize = CGSize(width: 400, height: 700)
        historyDetailViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        historyDetailViewController.gameDetail = gameDetail
        historyDetailViewController.callerCompletion = completion

        sourceViewController.present(historyDetailViewController, sourceView: sourceView, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: { self.callerCompletion?((self.updated ? self.gameDetail : nil)) })
    }
    
    override internal func didDismiss() {
        self.callerCompletion?((self.updated ? self.gameDetail : nil))
    }
    
}

class HistoryDetailTableCell: UITableViewCell {
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var totalScore: UILabel!
    @IBOutlet weak var handsMade: UILabel!
    @IBOutlet weak var otherValue: UILabel!
}

extension HistoryDetailViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.excludeStatsLabel.textColor = Palette.banner.contrastText
        self.finishButton.setTitleColor(Palette.banner.text, for: .normal)
        self.locationBackground.backgroundColor = Palette.darkHighlight.background
        self.locationText.textColor = Palette.darkHighlight.text
        self.navigationBar.textColor = Palette.banner.text
        self.participantTableView.separatorColor = Palette.separator.background
        self.updateButton.setTitleColor(Palette.buttonFace.text, for: .normal)
        self.updateButton.setBackgroundColor(Palette.buttonFace.background)
        self.view.backgroundColor = Palette.normal.background
    }

    private func defaultCellColors(cell: HistoryDetailTableCell) {
        switch cell.reuseIdentifier {
        case "History Detail Cell":
            cell.handsMade.textColor = Palette.normal.text
            cell.name.textColor = Palette.normal.text
            cell.otherValue.textColor = Palette.normal.text
            cell.totalScore.textColor = Palette.normal.text
        default:
            break
        }
    }

}
