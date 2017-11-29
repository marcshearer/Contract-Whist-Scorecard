//
//  GetStartedViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/03/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class GetStartedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, SyncDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    public var scorecard: Scorecard!
    
    // Properties to pass state to / from segues
    public var cloudPlayerList: [PlayerDetail]!
    
    // Alert controller while waiting for cloud download
    var cloudAlertController: UIAlertController!
    var cloudIndicatorView: UIActivityIndicatorView!
    
    // UI component pointers
    var syncEnabledSelection: UISegmentedControl!
    var syncEmailTextField: UITextField!
    var downloadPlayersButton: RoundedButton!
    var otherSettingsButton: RoundedButton!
    var gameWalkthroughButton: RoundedButton!
    var startPlayingButton: RoundedButton!
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet weak var finishButton: UIButton!
    @IBOutlet private weak var backgroundImage: UIImageView!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideGetStartedSettings(segue:UIStoryboardSegue) {
        if self.scorecard.settingSyncEnabled {
            self.syncEnabledSelection.selectedSegmentIndex = 1
        } else {
            self.syncEnabledSelection.selectedSegmentIndex = 0
        }
        scorecard.checkNetworkConnection(button: self.downloadPlayersButton, label: nil, disable: true)
        enableButtons()
    }
    
    @IBAction func hideGetStartedDownloadPlayers(segue:UIStoryboardSegue) {
        let source = segue.source as! StatsViewController
        if source.selected > 0 {
            var createPlayerList: [PlayerDetail] = []
            for playerNumber in 1...source.playerList.count {
                if source.selection[playerNumber-1] {
                    createPlayerList.append(source.playerList[playerNumber-1])
                }
            }
            createPlayers(newPlayers: createPlayerList)
        }
        enableButtons()
    }
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "hideGetStarted", sender: self)
    }
    

    // MARK: - View Overrides ===================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        ScorecardUI.selectBackground(size: view.frame.size, backgroundImage: backgroundImage)
        scorecard.checkNetworkConnection(button: self.downloadPlayersButton, label: nil, disable: true)
        enableButtons()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        scorecard.reCenterPopup(self)
        ScorecardUI.selectBackground(size: size, backgroundImage: backgroundImage)
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 6
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 0:
            return 60
        case 1:
            return 220
        default:
            return 60
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: GetStartedCell!
        
        switch indexPath.row {
        case 0:
            // Get Started message
            cell = tableView.dequeueReusableCell(withIdentifier: "Get Started Cell", for: indexPath) as! GetStartedCell
            
        case 1:
            // Sync Enabled
            cell = tableView.dequeueReusableCell(withIdentifier: "Sync Enabled Cell", for: indexPath) as! GetStartedCell
            cell.syncInfo.removeTarget(nil, action: nil, for: .allEvents)
            cell.syncInfo.addTarget(self, action: #selector(GetStartedViewController.syncInfoPressed(_:)), for: UIControlEvents.touchUpInside)
            
            // Add handler for change of sync enabled segmented control
            cell.syncEnabledSelection.removeTarget(nil, action: nil, for: .allEvents)
            cell.syncEnabledSelection.addTarget(self, action: #selector(GetStartedViewController.syncEnabledChanged(_:)), for: UIControlEvents.valueChanged)
            syncEnabledSelection = cell.syncEnabledSelection
            
            // Add handler for change / return pressed of sync email text field
            cell.syncEmail.removeTarget(nil, action: nil, for: .allEvents)
            cell.syncEmail.addTarget(self, action: #selector(GetStartedViewController.syncEmailValueChanged), for: UIControlEvents.editingChanged)
            cell.syncEmail.addTarget(self, action: #selector(GetStartedViewController.syncEmailReturnPressed), for: UIControlEvents.editingDidEndOnExit)
            cell.syncEmail.returnKeyType = .search
            syncEmailTextField = cell.syncEmail
            
            // Set sync enabled field value
            if scorecard.settingSyncEnabled {
                syncEnabledSelection.selectedSegmentIndex = 1
            } else {
                syncEnabledSelection.selectedSegmentIndex = 0
            }
        case 2, 3, 4, 5:
           // Action buttons
            cell = tableView.dequeueReusableCell(withIdentifier: "Action Button Cell", for: indexPath) as! GetStartedCell
            cell.actionButton.removeTarget(nil, action: nil, for: .allEvents)
            
            switch indexPath.row {
            case 2:
                // Download from cloud button
                downloadPlayersButton = cell.actionButton
                downloadPlayersButton.setTitle("Download Players from Cloud")
                downloadPlayersButton.addTarget(self, action: #selector(GetStartedViewController.downloadPlayersPressed(_:)), for: UIControlEvents.touchUpInside)
                enableButtons()
            case 3:
                // Other settings button
                otherSettingsButton = cell.actionButton
                otherSettingsButton.setTitle("Other Settings")
                otherSettingsButton.addTarget(self, action: #selector(GetStartedViewController.otherSettingsPressed(_:)), for: UIControlEvents.touchUpInside)
                otherSettingsButton.backgroundColor = ScorecardUI.emphasisColor
            case 4:
                // Game walkthrough button
                gameWalkthroughButton = cell.actionButton
                gameWalkthroughButton.setTitle("Game Walkthrough")
                gameWalkthroughButton.addTarget(self, action: #selector(GetStartedViewController.gameWalkthroughPressed(_:)), for: UIControlEvents.touchUpInside)
                gameWalkthroughButton.backgroundColor = ScorecardUI.emphasisColor
            case 5:
                // Start playing
                startPlayingButton = cell.actionButton
                startPlayingButton.setTitle("Home Screen")
                startPlayingButton.addTarget(self, action: #selector(GetStartedViewController.startPlayingPressed(_:)), for: UIControlEvents.touchUpInside)
                startPlayingButton.backgroundColor = ScorecardUI.totalColor
            default:
                break
            }
        default:
            break
        }
        return cell
    }
    
    // MARK: - Action functions from TableView Cells =========================================== -
    
    @objc func syncEnabledChanged(_ sender: UISegmentedControl) {
        warnShare()
    }
    
    @objc func syncEmailValueChanged(_ sender: UITextField) {
        enableButtons()
    }
    
    @objc func syncEmailReturnPressed(_ sender: UITextField) {
        syncEmailTextField.resignFirstResponder()
        selectCloudPlayers()
        enableButtons()
    }
    
    @objc func downloadPlayersPressed(_ sender: UIButton) {
        selectCloudPlayers()
    }
    
    @objc func otherSettingsPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "showGetStartedSettings", sender: self)
    }
    
    @objc func gameWalkthroughPressed(_ sender: UIButton) {
        walkthrough()
    }
    
    @objc func startPlayingPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "hideGetStarted", sender: self)
    }

    @objc func syncInfoPressed(_ sender: UIButton) {
        let alertController = UIAlertController(title: "iCloud Synchronisation", message: "Contract Whist Scorecard allows you to synchronise player details, history and high scores over iCloud. You need to select 'Sync with iCloud' to enable it.\n\n If you are new to the app you should then select 'New Game' and you will have to create players manually.\n\nIf you have played before on another device, enter your unique ID and press download to download your, and your previous co-players details and history.\n\nSynchronisation will only work if you are on Wifi (or if you have selected 'Use Mobile Data' for iCloud documents and data) and are logged into iCloud.", preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default,
                                                handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
   // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func enableButtons() {
        if downloadPlayersButton != nil {
            if scorecard.playerList.count == 0 && self.syncEmailTextField.text != nil && self.syncEmailTextField.text != "" && scorecard.settingSyncEnabled && scorecard.isNetworkAvailable && scorecard.isLoggedIn {
                downloadPlayersButton.isEnabled(true)
            } else {
                downloadPlayersButton.isEnabled(false)
            }
        }
        if syncEmailTextField != nil {
            if scorecard.playerList.count == 0 && scorecard.settingSyncEnabled && scorecard.isNetworkAvailable && scorecard.isLoggedIn {
                syncEmailTextField.isHidden = false
                syncEmailTextField.layer.borderColor = UIColor.blue.cgColor
                syncEmailTextField.layer.borderWidth = 2
                syncEmailTextField.layer.cornerRadius = 5
            } else {
                syncEmailTextField.isHidden = true
            }
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    func walkthrough() {
        let storyboard = UIStoryboard(name: "WalkthroughPageViewController", bundle: nil)
        if let pageViewController = storyboard.instantiateViewController(withIdentifier: "WalkthroughPageViewController") as? WalkthroughPageViewController {
            present(pageViewController, animated: true, completion: nil)
        }
    }
    
    func warnShare() {
        scorecard.warnShare(from: self, enabled: (self.syncEnabledSelection.selectedSegmentIndex == 1), handler: { (enabled: Bool) -> () in
            // Set the segmented controller
            if enabled {
                self.syncEnabledSelection.selectedSegmentIndex = 1
            } else {
                self.syncEnabledSelection.selectedSegmentIndex = 0
            }
            self.scorecard.checkNetworkConnection(button: self.downloadPlayersButton, label: nil, disable: true)
            self.enableButtons()
        })
    }
    
    func createPlayers(newPlayers: [PlayerDetail]) {
        var imageList: [PlayerMO] = []
        var newPlayers = newPlayers
        
        // Move entered player to top of list
        let index = newPlayers.index(where: {$0.email == self.syncEmailTextField.text})
        if index != nil && index != 0 {
            let playerMO = newPlayers[index!]
            newPlayers.remove(at: index!)
            newPlayers.insert(playerMO, at: 0)
        }
        
        for newPlayerDetail in newPlayers {
            // Reset date created to put entered player first
            newPlayerDetail.localDateCreated = Date()
            let playerMO = newPlayerDetail.createMO()
            if playerMO != nil && newPlayerDetail.thumbnailDate != nil {
                imageList.append(playerMO!)
            }
        }
        if imageList.count > 0 {
            getImages(imageList)
        }
        
        // Add these players to list of subscriptions
        Notifications.updateHighScoreSubscriptions(scorecard: self.scorecard)
    }

    
    // MARK: - Sync routines including the delegate methods ======================================== -
    
    func selectCloudPlayers() -> (){
        self.cloudAlertController = UIAlertController(title: title, message: "Searching Cloud for Available Players\n\n\n\n", preferredStyle: .alert)
        
        self.scorecard.sync.delegate = self
        if self.scorecard.sync.connect() {
            
            //add the activity indicator as a subview of the alert controller's view
            self.cloudIndicatorView =
                UIActivityIndicatorView(frame: CGRect(x: 0, y: 100,
                                                      width: self.cloudAlertController.view.frame.width,
                                                      height: 100))
            self.cloudIndicatorView.activityIndicatorViewStyle = .whiteLarge
            self.cloudIndicatorView.color = UIColor.black
            self.cloudIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.cloudAlertController.view.addSubview(self.cloudIndicatorView)
            self.cloudIndicatorView.isUserInteractionEnabled = true
            self.cloudIndicatorView.startAnimating()
            
            self.present(self.cloudAlertController, animated: true, completion: nil)
            
            self.syncEmailTextField.text! = self.syncEmailTextField.text!.trim()
            self.scorecard.sync.synchronise(syncMode: .syncGetPlayers, specificEmail: [self.syncEmailTextField.text!])
        } else {
            self.alertMessage("Error getting players from iCloud")
        }
    }
    
    func getImages(_ imageFromCloud: [PlayerMO]) {
        self.scorecard.sync.fetchPlayerImagesFromCloud(imageFromCloud)
    }
    
    func syncMessage(_ message: String) {
    }

    func syncAlert(_ message: String, completion: @escaping ()->()) {
        Utility.mainThread {
            self.cloudAlertController.dismiss(animated: true, completion: {
                self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
                    completion()
                })
            })
        }
    }
    
    func syncCompletion(_ errors: Int) {
    }
    
    func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
        Utility.mainThread {
            self.cloudAlertController.dismiss(animated: true, completion: {
                if playerList != nil && playerList.count != 0 {
                    self.cloudPlayerList = playerList
                    self.performSegue(withIdentifier: "showGetStartedDownloadPlayers", sender: self)
                } else {
                    self.alertMessage("Unable to find any games in the Cloud that this player has taken part in. Please check that it is correct and try again.", title: "Download from Cloud", buttonText: "Continue")
                }
            })
        }
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
            
        case "showGetStartedSettings":
            let destination = segue.destination as! SettingsViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.isModalInPopover = true
            destination.popoverPresentationController?.sourceView = self.popoverPresentationController?.sourceView
            destination.preferredContentSize = CGSize(width: 400, height: 600)
            destination.scorecard = self.scorecard
            destination.returnSegue = "hideGetStartedSettings"
            
        case "showGetStartedDownloadPlayers":
            let destination = segue.destination as! StatsViewController
            destination.playerList = self.cloudPlayerList
            destination.scorecard = self.scorecard
            destination.mode = .none
            destination.returnSegue = "hideGetStartedDownloadPlayers"
            destination.backText = "Cancel"
            destination.actionText = "Download"
            destination.actionSegue = "hideGetStartedDownloadPlayers"
            destination.allowSync = false
            
        default:
            break
        }
    }
}

class GetStartedCell: UITableViewCell {
    @IBOutlet weak var syncEnabledSelection: UISegmentedControl!
    @IBOutlet weak var syncEmail: UITextField!
    @IBOutlet weak var syncInfo: RoundedButton!
    @IBOutlet weak var actionButton: RoundedButton!
}
