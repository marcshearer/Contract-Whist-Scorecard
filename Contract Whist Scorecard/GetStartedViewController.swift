//
//  GetStartedViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/03/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class GetStartedViewController: CustomViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    private let scorecard = Scorecard.shared
    
    // Variables to pass state
    private var completion: (()->()?)!
    
    // UI component pointers
    private var syncEnabledSelection: UISegmentedControl!
    private var syncEmailTextField: UITextField!
    private var downloadPlayersButton: RoundedButton!
    private var otherSettingsButton: RoundedButton!
    private var gameWalkthroughButton: RoundedButton!
    private var startPlayingButton: RoundedButton!
    private var syncLabel: UILabel!
    private var syncLabelHeightConstraint: NSLayoutConstraint!
    private var syncLabelHeight: CGFloat = 20.0
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet weak var finishButton: UIButton!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.dismiss()
    }

    // MARK: - View Overrides ===================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        scorecard.checkNetworkConnection(button: self.downloadPlayersButton, label: self.syncLabel, labelHeightConstraint: self.syncLabelHeightConstraint, labelHeight: self.syncLabelHeight, disable: true)
        enableButtons()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 6
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 0:
            return 130
        case 1:
            return 220
        default:
            return min(60, max(50, (tableView.frame.height - 130 - 220) / 5.0))
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: GetStartedCell!
        
        switch indexPath.row {
        case 0:
            // Get Started message
            cell = tableView.dequeueReusableCell(withIdentifier: "Get Started Cell", for: indexPath) as? GetStartedCell
            self.syncLabel = cell.headerSyncLabel
            self.syncLabelHeightConstraint = cell.headerSyncLabelHeightConstraint
            self.scorecard.reflectNetworkConnection(button: self.downloadPlayersButton, label: self.syncLabel, labelHeightConstraint: self.syncLabelHeightConstraint, labelHeight: self.syncLabelHeight)
            
        case 1:
            // Sync Enabled
            cell = tableView.dequeueReusableCell(withIdentifier: "Sync Enabled Cell", for: indexPath) as? GetStartedCell
            cell.syncInfo.removeTarget(nil, action: nil, for: .allEvents)
            cell.syncInfo.addTarget(self, action: #selector(GetStartedViewController.syncInfoPressed(_:)), for: UIControl.Event.touchUpInside)
            
            // Add handler for change of sync enabled segmented control
            cell.syncEnabledSelection.removeTarget(nil, action: nil, for: .allEvents)
            cell.syncEnabledSelection.addTarget(self, action: #selector(GetStartedViewController.syncEnabledChanged(_:)), for: UIControl.Event.valueChanged)
            syncEnabledSelection = cell.syncEnabledSelection
            
            // Add handler for change / return pressed of sync email text field
            cell.syncEmail.removeTarget(nil, action: nil, for: .allEvents)
            cell.syncEmail.addTarget(self, action: #selector(GetStartedViewController.syncEmailValueChanged), for: UIControl.Event.editingChanged)
            cell.syncEmail.addTarget(self, action: #selector(GetStartedViewController.syncEmailReturnPressed), for: UIControl.Event.editingDidEndOnExit)
            cell.syncEmail.returnKeyType = .search
            syncEmailTextField = cell.syncEmail
            
            // Set sync enabled field value
            if scorecard.settingSyncEnabled {
                syncEnabledSelection.selectedSegmentIndex = 1
            } else {
                syncEnabledSelection.selectedSegmentIndex = 0
            }
            
            if scorecard.settingSyncEnabled && scorecard.isNetworkAvailable && scorecard.isLoggedIn {
                cell.instructionLabel.text = "This app uses iCloud to sync data across devices. Click the info button to find out more. If you have used the app on another device enter your unique ID and press download to download your, and your co-players details and history. Otherwise press start playing and add players manually"
            } else {
                cell.instructionLabel.text = "This app uses iCloud to sync data across devices. Click the info button to find out more. You must be be connected to the internet and be logged into iCloud to use this option. Otherwise press start playing and add players manually"
            }
        case 2, 3, 4, 5:
           // Action buttons
            cell = tableView.dequeueReusableCell(withIdentifier: "Action Button Cell", for: indexPath) as? GetStartedCell
            cell.actionButton.removeTarget(nil, action: nil, for: .allEvents)
            
            switch indexPath.row {
            case 2:
                // Download from cloud button
                downloadPlayersButton = cell.actionButton
                downloadPlayersButton.setTitle("Download Players from Cloud")
                downloadPlayersButton.addTarget(self, action: #selector(GetStartedViewController.downloadPlayersPressed(_:)), for: UIControl.Event.touchUpInside)
                Palette.emphasisStyle(downloadPlayersButton)
                enableButtons()
            case 3:
                // Other settings button
                otherSettingsButton = cell.actionButton
                otherSettingsButton.setTitle("Other Settings")
                otherSettingsButton.addTarget(self, action: #selector(GetStartedViewController.otherSettingsPressed(_:)), for: UIControl.Event.touchUpInside)
                Palette.highlightStyle(otherSettingsButton)
            case 4:
                // Game walkthrough button
                gameWalkthroughButton = cell.actionButton
                gameWalkthroughButton.setTitle("Game Walkthrough")
                gameWalkthroughButton.addTarget(self, action: #selector(GetStartedViewController.gameWalkthroughPressed(_:)), for: UIControl.Event.touchUpInside)
                Palette.highlightStyle(gameWalkthroughButton)
            case 5:
                // Start playing
                startPlayingButton = cell.actionButton
                startPlayingButton.setTitle("Home Screen")
                startPlayingButton.addTarget(self, action: #selector(GetStartedViewController.startPlayingPressed(_:)), for: UIControl.Event.touchUpInside)
                Palette.darkHighlightStyle(startPlayingButton)
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
        self.showSettings()
    }
    
    @objc func gameWalkthroughPressed(_ sender: UIButton) {
        walkthrough()
    }
    
    @objc func startPlayingPressed(_ sender: UIButton) {
        self.dismiss()
    }

    @objc func syncInfoPressed(_ sender: UIButton) {
        let alertController = UIAlertController(title: "iCloud Synchronisation", message: "Contract Whist Scorecard allows you to synchronise player details, history and high scores over iCloud. You need to select 'Sync with iCloud' to enable it.\n\n If you are new to the app you should then select 'New Game' and you will have to create players manually.\n\nIf you have played before on another device, enter your unique ID and press download to download your, and your previous co-players details and history.\n\nSynchronisation will only work if you are on Wifi (or if you have selected 'Use Mobile Data' for iCloud documents and data) and are logged into iCloud.", preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default,
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
                syncEmailTextField.layer.borderColor = Palette.textMessage.cgColor
                syncEmailTextField.layer.borderWidth = 2
                syncEmailTextField.layer.cornerRadius = 5
                syncEmailTextField.becomeFirstResponder()
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
            self.scorecard.checkNetworkConnection(button: self.downloadPlayersButton, label: self.syncLabel, labelHeightConstraint: self.syncLabelHeightConstraint, labelHeight: self.syncLabelHeight, disable: true)
            self.enableButtons()
        })
    }
    
    private func showSelectPlayers() {
        
        SelectPlayersViewController.show(from: self, specificEmail: self.syncEmailTextField.text!, descriptionMode: .lastPlayed, allowOtherPlayer: false, allowNewPlayer: false, completion: { (selected, playerList, selection) in
            if let selected = selected, let playerList = playerList, let selection = selection {
                if selected > 0 {
                    var createPlayerList: [PlayerDetail] = []
                    for playerNumber in 1...playerList.count {
                        if selection[playerNumber-1] {
                            createPlayerList.append(playerList[playerNumber-1])
                        }
                    }
                    self.createPlayers(newPlayers: createPlayerList)
                }
                self.enableButtons()
            }
        })
    }
    
    private func createPlayers(newPlayers: [PlayerDetail]) {
        var newPlayers = newPlayers
        
        // Move entered player to top of list
        if let index = newPlayers.firstIndex(where: {$0.email == self.syncEmailTextField.text}) {
            if index != 0 {
                let playerMO = newPlayers[index]
                newPlayers.remove(at: index)
                newPlayers.insert(playerMO, at: 0)
            }
        }
        
        // Add these players to list of subscriptions
        Notifications.updateHighScoreSubscriptions()
    }
    
    // MARK: - Sync routines including the delegate methods ======================================== -
    
    func selectCloudPlayers() -> () {
        
        self.showSelectPlayers()
    }
    
    // MARK: - Show other views ================================================================== -
    
    private func showSettings() {
        SettingsViewController.show(from: self, completion: {
            if self.scorecard.settingSyncEnabled {
                self.syncEnabledSelection.selectedSegmentIndex = 1
            } else {
                self.syncEnabledSelection.selectedSegmentIndex = 0
            }
            self.scorecard.checkNetworkConnection(button: self.downloadPlayersButton, label: self.syncLabel, labelHeightConstraint: self.syncLabelHeightConstraint, labelHeight: self.syncLabelHeight, disable: true)
            self.enableButtons()
        })
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: CustomViewController, completion: (()->())? = nil){
        
        let storyboard = UIStoryboard(name: "GetStartedViewController", bundle: nil)
        let getStartedViewController: GetStartedViewController = storyboard.instantiateViewController(withIdentifier: "GetStartedViewController") as! GetStartedViewController
        
        getStartedViewController.preferredContentSize = CGSize(width: 400, height: 700)
        getStartedViewController.completion = completion
        
        viewController.present(getStartedViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: { self.completion?() })
    }
    
}

class GetStartedCell: UITableViewCell {
    @IBOutlet weak var syncEnabledSelection: UISegmentedControl!
    @IBOutlet weak var syncEmail: UITextField!
    @IBOutlet weak var syncInfo: RoundedButton!
    @IBOutlet weak var actionButton: RoundedButton!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var headerSyncLabel: UILabel!
    @IBOutlet weak var headerSyncLabelHeightConstraint: NSLayoutConstraint!
}
