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

class HistoryDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    var scorecard: Scorecard!
    
    // Properties to pass state to / from segues
    var gameDetail: HistoryGame!
    var locationLabel: UILabel!
    var returnSegue: String!
    
    // Local class variables
    let tableRowHeight:CGFloat = 44.0
    var players = 0
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet var participantTableView: UITableView!
    @IBOutlet var locationText: UILabel!
    @IBOutlet var locationBackground: UIView!
    @IBOutlet weak var locationBackgroundHeightConstraint: NSLayoutConstraint!
    @IBOutlet var mapView: MKMapView!
    @IBOutlet weak var participantTableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleNavigationItem: UINavigationItem!
    @IBOutlet weak var updateButton: RoundedButton!
    @IBOutlet weak var finishButton: RoundedButton!
    @IBOutlet weak var actionButton: UIBarButtonItem!
    @IBOutlet weak var bodyView: UIView!
    @IBOutlet weak var excludeStatsView: UIView!
    @IBOutlet weak var excludeStatsHeightConstraint: NSLayoutConstraint!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideUpdateLocation(segue:UIStoryboardSegue) {
        var complete = false
        if let sourceViewController = segue.source as? LocationViewController {
            if sourceViewController.complete {
                complete = true
            }
        }
        if complete {
            saveLocation()
            locationText.text = gameDetail.gameLocation.description
        
            if locationLabel != nil {
                locationLabel.text = gameDetail.gameLocation.description
            }
            dropPin()
        }
    }
    
    // MARK: - IB Actions ============================================================================== -

    @IBAction func finishPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: returnSegue, sender: self)
    }
    
    @IBAction func updatePressed(_ sender: Any) {
        self.performSegue(withIdentifier: "updateLocation", sender: self)
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
        
        if !scorecard.settingSaveLocation {
            locationBackgroundHeightConstraint.constant = 0
            locationText.isHidden = true
            updateButton.isHidden = true
            mapView.isHidden = true
        } else {
            // Only show update button if network available
            scorecard.checkNetworkConnection(button: updateButton, label: nil)
            // NOTE The updateButton will disappear when there is not network
        }
        
        let dateString = DateFormatter.localizedString(from: gameDetail.datePlayed, dateStyle: .medium, timeStyle: .none)
        let timeString = DateFormatter.localizedString(from: gameDetail.datePlayed, dateStyle: .none, timeStyle: .short)
        titleNavigationItem.title = "\(dateString) - \(timeString)"
        players = gameDetail.participant.count
        participantTableViewHeightConstraint.constant = CGFloat(players + 1) * tableRowHeight
        if scorecard.settingSaveLocation {
            locationText.text = gameDetail.gameLocation.description
            dropPin()
        }
        if self.gameDetail.gameMO.excludeStats {
            ScorecardUI.sectionHeadingStyleView(self.excludeStatsView)
        } else {
            self.excludeStatsHeightConstraint.constant = 0
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        scorecard.reCenterPopup(self)
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
        
        switch indexPath.row {
        case 0:
            // Header
            ScorecardUI.sectionHeadingStyle(cell)
            ScorecardUI.sectionHeadingStyle(cell.name)
            ScorecardUI.sectionHeadingStyle(cell.totalScore)
            ScorecardUI.sectionHeadingStyle(cell.handsMade)
            ScorecardUI.sectionHeadingStyle(cell.otherValue)
            
            cell.name.text = "Player"
            cell.totalScore.text = "Score"
            cell.handsMade.text = "Made"
            if scorecard.settingBonus2 {
                cell.otherValue.text = "Twos"
            } else {
                cell.otherValue.text = "Made%"
            }
        default:
            // Player values
            let playerNumber = indexPath.row
            
            ScorecardUI.normalStyle(cell)
            ScorecardUI.normalStyle(cell.name)
            ScorecardUI.normalStyle(cell.totalScore)
            ScorecardUI.normalStyle(cell.handsMade)
            ScorecardUI.normalStyle(cell.otherValue)
            if scorecard.findPlayerByEmail(gameDetail.participant[playerNumber-1].participantMO.email!) == nil {
                // Player not on device - grey them out
                cell.name.textColor = UIColor.lightGray
                cell.totalScore.textColor = UIColor.lightGray
                cell.handsMade.textColor = UIColor.lightGray
                cell.otherValue.textColor = UIColor.lightGray
            }

            cell.name.text = gameDetail.participant[playerNumber-1].name
            cell.totalScore.text = "\(gameDetail.participant[playerNumber-1].totalScore)"
            cell.handsMade.text = "\(gameDetail.participant[playerNumber-1].handsMade)"
            if scorecard.settingBonus2 {
                cell.otherValue.text = "\(gameDetail.participant[playerNumber-1].twosMade)"
            } else {
                let handsMadePercent = Utility.roundPercent(CGFloat(gameDetail.participant[playerNumber-1].handsMade), CGFloat(gameDetail.participant[playerNumber-1].handsPlayed))
                cell.otherValue.text = "\(handsMadePercent) %"
            }
            
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
        
        if gameDetail.gameLocation.location != nil {
            
            let coordinate = gameDetail.gameLocation.location.coordinate
            
            if coordinate.latitude != 0 || coordinate.longitude != 0 {
            
                annotation.coordinate = coordinate
                self.mapView.addAnnotation(annotation)
                
                // Set the zoom level
                let region = MKCoordinateRegion.init(center: annotation.coordinate, latitudinalMeters: 2e5, longitudinalMeters: 2e5)
                self.mapView.setRegion(region, animated: false)
            }
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
            let cloudContainer = CKContainer.default()
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
                            if self.gameDetail.gameLocation.location != nil {
                                let coordinate = self.gameDetail.gameLocation.location.coordinate
                                cloudObject.setValue(coordinate.latitude, forKey: "latitude")
                                cloudObject.setValue(coordinate.longitude, forKey: "longitude")
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
        let cloudContainer = CKContainer.default()
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
            if self.gameDetail.gameLocation.location != nil {
                let coordinate = self.gameDetail.gameLocation.location.coordinate
                gameMO.latitude = coordinate.latitude
                gameMO.longitude = coordinate.longitude
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
        
        highScores = History.getHighScores(type: .totalScore, playerEmailList: self.scorecard.playerEmailList(getPlayerMode: .getAll))
        
        if winningScore == highScores[0].totalScore {
            message = message + " This was a new high score! Congratulations \(winner)."
        }
        
        // Share on Facebook etc
        let activityController = UIActivityViewController(activityItems: [message, image], applicationActivities: nil)
        self.present(activityController, animated: true, completion: nil)
        
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
            
        case "updateLocation":
            
            let destination = segue.destination as! LocationViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.popoverPresentationController?.sourceView
            destination.preferredContentSize = CGSize(width: 400, height: 554)
            destination.gameLocation = self.gameDetail.gameLocation
            destination.scorecard = self.scorecard
            destination.returnSegue = "hideUpdateLocation"
            destination.useCurrentLocation = false
            destination.mustChange = true
            
        default:
            break
        }
    }
}

class HistoryDetailTableCell: UITableViewCell {
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var totalScore: UILabel!
    @IBOutlet weak var handsMade: UILabel!
    @IBOutlet weak var otherValue: UILabel!
}
