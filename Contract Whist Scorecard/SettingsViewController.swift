//
//  SettingsViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 10/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import UserNotifications
import GameKit

class SettingsViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate, UIPopoverPresentationControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, SearchDelegate {
    
    // MARK: - Class Properties ======================================================================== -
        
    // Main state properties
    public var scorecard: Scorecard!
    
    // Properties to pass state to / from segues
    public var returnSegue = ""
    public var backText = "Back"
    public var backImage = "back"
    
    // Other properties
    private var onlineRow: Int!
    private var testMode = false
    
    // Sections
    private let syncSection = 0
    private let saveSection = 1
    private let     saveHistoryRow = 0
    private let     saveLocationRow = 1
    private let broadcastSection = 2
    private let nearbySection = 3
    private let onlineSection = 4
    private let faceTimeSection = 5
    private let alertSection = 6
    private let notificationSection = 7
    private let cardsSection = 8
    private let     cardsStartRow = 0
    private let     cardsEndRow = 1
    private let     cardsBounceRow = 2
    private let bonus2Section = 9
    private let trumpSequenceSection = 10
    private let     trumpSequenceNoTrumpRow = 0
    private let     trumpSequenceSuitRow = 1
    private let prefersStatusBarHiddenSection = 11
    private let aboutSection = 12
    private let     aboutVersionRow = 0
    private let     aboutDatabaseRow = 1
    private let     aboutSubheadingRow = 2
    private let     aboutPlayersRow = 3
    private let     aboutGamesRow = 4
    private let     aboutParticipantsRow = 5
    
    
    // UI component pointers
    private var syncEnabledSelection: UISegmentedControl!
    private var saveHistorySelection: UISegmentedControl!
    private var saveLocationSelection: UISegmentedControl!
    private var receiveNotificationsSelection: UISegmentedControl!
    private var allowBroadcastSelection: UISegmentedControl!
    private var alertVibrateSelection: UISegmentedControl!
    private var bonus2Selection: UISegmentedControl!
    private var cardsSlider: [Int : UISlider] = [:]
    private var cardsValue: [Int : UITextField] = [:]
    private var bounceSelection: UISegmentedControl!
    private var trumpSequenceCollectionView: UICollectionView!
    private var trumpIncludeNoTrumpSelection: UISegmentedControl!
    private var nearbyPlayingSelection: UISegmentedControl!
    private var onlinePlayerLabel: UILabel!
    private var onlinePlayerChangeButton: UIButton!
    private var faceTimeAddressTextField: UITextField!
    private var prefersStatusBarHiddenSelection: UISegmentedControl!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var finishButton: RoundedButton!
    @IBOutlet weak var settingsTableView: UITableView!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: returnSegue, sender: self)
    }
       
    // MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText)
        
        if let testModeValue = ProcessInfo.processInfo.environment["TEST_MODE"] {
            if testModeValue.lowercased() == "true" {
                testMode = true
            }
        }
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
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return aboutSection + 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case saveSection, trumpSequenceSection:
            return 2
        case cardsSection:
            return 3
        case aboutSection:
            return (Scorecard.adminMode || scorecard.iCloudUserIsMe ? 6 : (self.scorecard.settingDatabase == "production" ? 1 : 2))
        default:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case aboutSection:
            return 40
        default:
            return 60
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: SettingsTableCell!
        switch indexPath.section {
        case syncSection:
            // Sync Group
            cell = tableView.dequeueReusableCell(withIdentifier: "Sync Enabled Cell", for: indexPath) as? SettingsTableCell
            syncEnabledSelection = cell.syncEnabledSelection
            cell.syncEnabledSelection.addTarget(self, action: #selector(SettingsViewController.syncEnabledChanged(_:)), for: UIControl.Event.valueChanged)
            // Set sync group field
            switch scorecard.settingSyncEnabled {
            case true:
                syncEnabledSelection.selectedSegmentIndex = 1
            default:
                syncEnabledSelection.selectedSegmentIndex = 0
            }
            
        case saveSection:
            switch indexPath.row {
            case saveHistoryRow:
                // Save History
                cell = tableView.dequeueReusableCell(withIdentifier: "Save History Cell", for: indexPath) as? SettingsTableCell
                saveHistorySelection = cell.saveHistorySelection
                saveHistorySelection.addTarget(self, action: #selector(SettingsViewController.saveHistoryAction(_:)), for: UIControl.Event.valueChanged)
                
                // Set save history
                switch scorecard.settingSaveHistory {
                case true:
                    saveHistorySelection.selectedSegmentIndex = 1
                default:
                    saveHistorySelection.selectedSegmentIndex = 0
                }
                
            case saveLocationRow:
                // Save Location
                cell = tableView.dequeueReusableCell(withIdentifier: "Save Location Cell", for: indexPath) as? SettingsTableCell
                saveLocationSelection = cell.saveLocationSelection
                saveLocationSelection.addTarget(self, action: #selector(SettingsViewController.saveLocationAction(_:)), for: UIControl.Event.valueChanged)
                
                // Set save location
                switch scorecard.settingSaveLocation {
                case true:
                    saveLocationSelection.selectedSegmentIndex = 1
                default:
                    saveLocationSelection.selectedSegmentIndex = 0
                }
                saveLocationSelection.isEnabled = scorecard.settingSaveHistory
                
            default:
                break
            }
            
        case broadcastSection:
            // Allow broadcast
            cell = tableView.dequeueReusableCell(withIdentifier: "Allow Broadcast Cell", for: indexPath) as? SettingsTableCell
            allowBroadcastSelection = cell.allowBroadcastSelection
            allowBroadcastSelection.addTarget(self, action: #selector(SettingsViewController.allowBroadcastAction(_:)), for: UIControl.Event.valueChanged)
            
            // Set allow broadcast
            switch scorecard.settingAllowBroadcast {
            case true:
                allowBroadcastSelection.selectedSegmentIndex = 1
                
            default:
                allowBroadcastSelection.selectedSegmentIndex = 0
            }
            allowBroadcastSelection.isEnabled = scorecard.settingSyncEnabled
            
        case nearbySection:
            // Nearby playing
            cell = tableView.dequeueReusableCell(withIdentifier: "Nearby Playing Cell", for: indexPath) as? SettingsTableCell
            nearbyPlayingSelection = cell.nearbyPlayingSelection
            nearbyPlayingSelection.addTarget(self, action: #selector(SettingsViewController.nearbyPlayingAction(_:)), for: UIControl.Event.valueChanged)
            
            // Set online playing
            switch scorecard.settingNearbyPlaying {
            case true:
                nearbyPlayingSelection.selectedSegmentIndex = 1
            default:
                nearbyPlayingSelection.selectedSegmentIndex = 0
            }
            nearbyPlayingSelection.isEnabled = scorecard.settingSyncEnabled
            
        case onlineSection:
            // Online remote player
            cell = tableView.dequeueReusableCell(withIdentifier: "Online Player Cell", for: indexPath) as? SettingsTableCell
            onlinePlayerLabel = cell.onlinePlayerLabel
            onlinePlayerChangeButton = cell.onlinePlayerChangeButton
            onlinePlayerChangeButton.addTarget(self, action: #selector(SettingsViewController.onlinePlayerChangeAction(_:)), for: UIControl.Event.touchUpInside)
            self.displayOnlineCell()
            
        case faceTimeSection:
            // FaceTime address
            onlineRow = indexPath.row
            cell = tableView.dequeueReusableCell(withIdentifier: "FaceTime Cell", for: indexPath) as? SettingsTableCell
            cell.faceTimeAddressTextField.addTarget(self, action: #selector(SettingsViewController.faceTimeTextFieldChanged), for: UIControl.Event.editingChanged)
            cell.faceTimeAddressTextField.addTarget(self, action: #selector(SettingsViewController.faceTimeTextFieldChanged), for: UIControl.Event.editingDidEnd)
            self.faceTimeAddressTextField = cell.faceTimeAddressTextField
            cell.faceTimeInfoButton.addTarget(self, action: #selector(SettingsViewController.faceTimeInfoPressed(_:)), for: UIControl.Event.touchUpInside)
            self.displayFaceTimeCell()
            
        case alertSection:
            // Alert vibrate
            cell = tableView.dequeueReusableCell(withIdentifier: "Alert Vibrate Cell", for: indexPath) as? SettingsTableCell
            alertVibrateSelection = cell.alertVibrateSelection
            alertVibrateSelection.addTarget(self, action: #selector(SettingsViewController.alertVibrateAction(_:)), for: UIControl.Event.valueChanged)
            
            // Set receive notifications
            switch scorecard.settingAlertVibrate {
            case true:
                alertVibrateSelection.selectedSegmentIndex = 1
            default:
                alertVibrateSelection.selectedSegmentIndex = 0
            }
            alertVibrateSelection.isEnabled = scorecard.settingSyncEnabled && ( scorecard.settingNearbyPlaying || scorecard.settingOnlinePlayerEmail != nil)
            self.enableAlerts()
            
        case notificationSection:
            // Receive notifications
            cell = tableView.dequeueReusableCell(withIdentifier: "Receive Notifications Cell", for: indexPath) as? SettingsTableCell
            receiveNotificationsSelection = cell.receiveNotificationsSelection
            receiveNotificationsSelection.addTarget(self, action: #selector(SettingsViewController.receiveNotificationsAction(_:)), for: UIControl.Event.valueChanged)
            
            // Set receive notifications
            switch scorecard.settingReceiveNotifications {
            case true:
                receiveNotificationsSelection.selectedSegmentIndex = 1
                
            default:
                receiveNotificationsSelection.selectedSegmentIndex = 0
            }
            receiveNotificationsSelection.isEnabled = scorecard.settingSyncEnabled
            
        case cardsSection:
            // Number of cards
            switch indexPath.row {
            case cardsStartRow, cardsEndRow:
                cell = tableView.dequeueReusableCell(withIdentifier: "Number Cards Cell", for: indexPath) as? SettingsTableCell
                let cardsSlider = cell.cardsSlider!
                let cardsValue = cell.cardsValue!
                cardsSlider.tag = indexPath.row
                cardsSlider.addTarget(self, action: #selector(SettingsViewController.cardsSliderAction(_:)), for: UIControl.Event.valueChanged)
                if self.testMode {
                    cardsValue.tag = indexPath.row
                    cardsValue.addTarget(self, action: #selector(SettingsViewController.cardsValueAction(_:)), for: UIControl.Event.editingChanged)
                    cardsValue.addTarget(self, action: #selector(SettingsViewController.cardsValueExit(_:)), for: UIControl.Event.editingDidEndOnExit)
                    cardsValue.accessibilityIdentifier = "cardsValue\(indexPath.row)"
                }
                cardsValue.isUserInteractionEnabled = testMode
                
                // Set number of rounds value and slider
                cell.cardsLabel.text = (indexPath.row == 0 ? "Start:" : "End:")
                cardsValue.text = "\(scorecard.settingCards[indexPath.row])"
                cardsSlider.value = Float(scorecard.settingCards[indexPath.row])
                
                // Store controls
                self.cardsSlider[indexPath.row] = cardsSlider
                self.cardsValue[indexPath.row] = cardsValue
                
            case cardsBounceRow:
                cell = tableView.dequeueReusableCell(withIdentifier: "Bounce Cell", for: indexPath) as? SettingsTableCell
                bounceSelection = cell.bounceSelection
                bounceSelection.addTarget(self, action: #selector(SettingsViewController.bounceAction(_:)), for: UIControl.Event.valueChanged)
                cardsChanged()
                
                // Set bounce number of cards selection
                switch scorecard.settingBounceNumberCards {
                case true:
                    bounceSelection.selectedSegmentIndex = 1
                default:
                    bounceSelection.selectedSegmentIndex = 0
                }
            default:
                break
            }
            
        case bonus2Section:
            // Bonus for winning with a 2
            cell = tableView.dequeueReusableCell(withIdentifier: "Bonus2 Cell", for: indexPath) as? SettingsTableCell
            bonus2Selection = cell.bonus2Selection
            bonus2Selection.addTarget(self, action: #selector(SettingsViewController.bonus2Action(_:)), for: UIControl.Event.valueChanged)
            cell.bonus2Info.addTarget(self, action: #selector(SettingsViewController.twosInfoPressed(_:)), for: UIControl.Event.touchUpInside)
            
            // Set bonus for a 2 selection
            switch scorecard.settingBonus2 {
            case true:
                bonus2Selection.selectedSegmentIndex = 1
            default:
                bonus2Selection.selectedSegmentIndex = 0
            }
        
        case trumpSequenceSection:
            // Trump suit sequence
            switch indexPath.row {
            case trumpSequenceNoTrumpRow:
                cell = tableView.dequeueReusableCell(withIdentifier: "Trump Include No Trump Cell", for: indexPath) as? SettingsTableCell
                trumpIncludeNoTrumpSelection = cell.trumpIncludeNoTrumpSelection
                trumpIncludeNoTrumpSelection.addTarget(self, action: #selector(SettingsViewController.trumpIncludeNoTrumpAction(_:)), for: .valueChanged)
                
                // Set Include No trump selection
                if self.scorecard.suits.firstIndex(where: {$0.toString() == "NT"}) != nil {
                    trumpIncludeNoTrumpSelection.selectedSegmentIndex = 1
                } else {
                    trumpIncludeNoTrumpSelection.selectedSegmentIndex = 0
                }
                
            case trumpSequenceSuitRow:
                cell = tableView.dequeueReusableCell(withIdentifier: "Trump Sequence Cell", for: indexPath) as? SettingsTableCell
                cell.trumpSequenceInfo.addTarget(self, action: #selector(SettingsViewController.trumpSequenceInfoPressed(_:)), for: .touchUpInside)
                
            default:
                break
            }
            
        case prefersStatusBarHiddenSection:
            cell = tableView.dequeueReusableCell(withIdentifier: "Prefers Status Bar Hidden Cell", for: indexPath) as? SettingsTableCell
            prefersStatusBarHiddenSelection = cell.preferStatusBarHiddenSelection
            prefersStatusBarHiddenSelection.addTarget(self, action: #selector(SettingsViewController.prefersStatusBarHiddenAction(_:)), for: UIControl.Event.valueChanged)
            
            // Set prefers status bar hidden selection
            switch scorecard.settingPrefersStatusBarHidden {
            case false:
                prefersStatusBarHiddenSelection.selectedSegmentIndex = 1
            default:
                prefersStatusBarHiddenSelection.selectedSegmentIndex = 0
            }

        case aboutSection:
            switch indexPath.row {
            case aboutVersionRow:
                // Version number
                cell = tableView.dequeueReusableCell(withIdentifier: "About Cell 1 Value", for: indexPath) as? SettingsTableCell
                cell.aboutLabel.text = "Version:"
                cell.aboutValue1.text = "\(self.scorecard.settingVersion) (\(self.scorecard.settingBuild))"
            case aboutDatabaseRow:
                // Database
                cell = tableView.dequeueReusableCell(withIdentifier: "About Cell 1 Value", for: indexPath) as? SettingsTableCell
                cell.aboutLabel.text = "Database:"
                cell.aboutValue1.text = self.scorecard.settingDatabase
            case aboutSubheadingRow:
                // Sub-heading
                cell = tableView.dequeueReusableCell(withIdentifier: "About Cell Heading", for: indexPath) as? SettingsTableCell
                ScorecardUI.highlightStyleView(cell)
            case aboutPlayersRow:
                // Players
                cell = tableView.dequeueReusableCell(withIdentifier: "About Cell 3 Value", for: indexPath) as? SettingsTableCell
                let totalScore = self.scorecard.playerList.reduce(0) { $0 + $1.totalScore }
                cell.aboutLabel.text = "Players:"
                cell.aboutValue1.text = "\(self.scorecard.playerList.count)"
                cell.aboutValue2.text = ""
                Utility.getCloudRecordCount("Players", completion: { (players) in
                    Utility.mainThread {
                        if cell.aboutValue2 != nil && players != nil {
                            cell.aboutValue2.text = "\(players!)"
                        }
                    }
                })
                cell.aboutValue3.text = "\(totalScore)"
            case aboutGamesRow:
                // Games
                cell = tableView.dequeueReusableCell(withIdentifier: "About Cell 3 Value", for: indexPath) as? SettingsTableCell
                let historyGames: [GameMO] = CoreData.fetch(from: "Game")
                cell.aboutLabel.text = "Games:"
                cell.aboutValue1.text = "\(historyGames.count)"
                cell.aboutValue2.text = ""
                Utility.getCloudRecordCount("Games", completion: { (games) in
                    Utility.mainThread {
                        if cell.aboutValue2 != nil && games != nil {
                            cell.aboutValue2.text = "\(games!)"
                        }
                    }
                })
                cell.aboutValue3.text = ""
            case aboutParticipantsRow:
                // Participants
                cell = tableView.dequeueReusableCell(withIdentifier: "About Cell 3 Value", for: indexPath) as? SettingsTableCell
                let historyParticipants: [ParticipantMO] = CoreData.fetch(from: "Participant")
                var totalScore:Int64 = 0
                for participantMO in historyParticipants {
                    totalScore = totalScore + Int64(participantMO.totalScore)
                }
                cell.aboutLabel.text = "Participants:"
                cell.aboutValue1.text = "\(historyParticipants.count)"
                cell.aboutValue2.text = ""
                Utility.getCloudRecordCount("Participants", completion: { (participants) in
                    Utility.mainThread {
                        if cell.aboutValue2 != nil && participants != nil {
                            cell.aboutValue2.text = "\(participants!)"
                        }
                    }
                })
                cell.aboutValue3.text = "\(totalScore)"
            default:
                break
            }
        default:
            break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        switch section {
        case syncSection:
            return "iCloud Sync"
        case saveSection:
            return "Save Options"
        case broadcastSection:
            return "Share Scorecard with Other Devices"
        case nearbySection:
            return "Play Games with Nearby Devices"
        case onlineSection:
            return "Play Games with Remote Devices"
        case faceTimeSection:
            return "FaceTime Calls in Remote Games"
        case alertSection:
            return "Alert on Turn to Play"
        case notificationSection:
            return "Receive Notifications"
        case cardsSection:
            return "Number of cards in hands"
        case bonus2Section:
            return "Bonus for winning a trick with a 2"
        case trumpSequenceSection:
            return "Trump suit sequence"
        case prefersStatusBarHiddenSection:
            return "Status bar preference"			
        case aboutSection:
            return "Contract Whist Scorecard"
        default:
            return ""
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        ScorecardUI.highlightStyleView(header.backgroundView!)
    }
    
    internal func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case trumpSequenceSection:
            switch indexPath.row {
            case trumpSequenceSuitRow:
                // Trump suit sequence
                guard let tableViewCell = cell as? SettingsTableCell else { return }
                tableViewCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
                trumpSequenceCollectionView = tableViewCell.trumpSequenceCollectionView
                // Allow movement
                let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongGesture(gesture:)))
                trumpSequenceCollectionView.addGestureRecognizer(longPressGesture)
            default:
                break
            }
        default:
            break
        }
    }
    
    // MARK: - Action functions from TableView Cells =========================================== -
    
    @objc internal func syncEnabledChanged(_ sender: UISegmentedControl) {
        warnShare()
    }
    
    @objc internal func saveHistoryAction(_ sender: UISegmentedControl) {
        switch saveHistorySelection.selectedSegmentIndex {
        case 1:
            scorecard.settingSaveHistory = true
            saveLocationSelection.isEnabled = true
        default:
            scorecard.settingSaveHistory = false
            
            // Need to clear 'save location' as well
            saveLocationSelection.selectedSegmentIndex = 0
            saveLocationSelection.isEnabled = false
            scorecard.settingSaveLocation = false
            // Save 'save location'
            UserDefaults.standard.set(scorecard.settingSaveLocation, forKey: "saveLocation")
        }
        
        // Save it
        UserDefaults.standard.set(scorecard.settingSaveHistory, forKey: "saveHistory")
    }
    
    @objc internal func saveLocationAction(_ sender: UISegmentedControl) {
        switch saveLocationSelection.selectedSegmentIndex {
        case 1:
            scorecard.settingSaveLocation = true
        default:
            scorecard.settingSaveLocation = false
        }
        
        // Save it
        UserDefaults.standard.set(scorecard.settingSaveLocation, forKey: "saveLocation")
    }
    
    @objc internal func receiveNotificationsAction(_ sender: UISegmentedControl) {
        switch receiveNotificationsSelection.selectedSegmentIndex {
        case 0:
            self.clearReceiveNotifications()
        default:
            scorecard.settingReceiveNotifications = true
            authoriseNotifications(
                successAction: {
                    Notifications.updateHighScoreSubscriptions(scorecard: self.scorecard)
                },
                failureAction: {
                    self.clearReceiveNotifications()
                })
        }
        
        // Save it
        UserDefaults.standard.set(scorecard.settingReceiveNotifications, forKey: "receiveNotifications")
    }
    
    @objc internal func allowBroadcastAction(_ sender: UISegmentedControl) {
        switch allowBroadcastSelection.selectedSegmentIndex {
        case 1:
            scorecard.settingAllowBroadcast = true
            self.scorecard.setupSharing()
        default:
            scorecard.settingAllowBroadcast = false
            self.clearBroadcast()
        }
        
        // Save it
        UserDefaults.standard.set(scorecard.settingAllowBroadcast, forKey: "allowBroadcast")
    }
    
    @objc internal func alertVibrateAction(_ sender: UISegmentedControl) {
        switch alertVibrateSelection.selectedSegmentIndex {
        case 1:
            scorecard.settingAlertVibrate = true
        default:
            scorecard.settingAlertVibrate = false
        }
        
        // Save it
        UserDefaults.standard.set(scorecard.settingAlertVibrate, forKey: "alertVibrate")
    }
    
    @objc internal func twosInfoPressed(_ sender: UIButton) {
        twosInfo()
    }
    
   @objc internal func bonus2Action(_ sender: Any) {
        switch bonus2Selection.selectedSegmentIndex {
        case 0:
            scorecard.settingBonus2 = false
        default:
            scorecard.settingBonus2 = true
        }
        
        // Save it
        UserDefaults.standard.set(scorecard.settingBonus2, forKey: "bonus2")
    }
    
    @objc internal func cardsSliderAction(_ sender: UISlider) {
        let index = sender.tag
        scorecard.settingCards[index] = Int(cardsSlider[index]!.value)
        cardsValue[index]!.text = "\(scorecard.settingCards[index])"
        cardsChanged()
        
        // Save it
        UserDefaults.standard.set(scorecard.settingCards, forKey: "cards")
    }
    
    @objc internal func cardsValueAction(_ sender: UITextField) {
        let index = sender.tag
        if let newValue = Int(cardsValue[index]!.text!) {
            if newValue >= 1 && newValue <= 13 {
                scorecard.settingCards[index] = newValue
                cardsSlider[index]!.value = Float(scorecard.settingCards[index])
                cardsChanged()
            
                // Save it
                UserDefaults.standard.set(scorecard.settingCards, forKey: "cards")
            }
        }
    }
    
    @objc internal func cardsValueExit(_ sender: UITextField) {
        let index = sender.tag
        cardsValue[index]!.resignFirstResponder()
    }
    
    @objc func bounceAction(_ sender: Any) {
        switch bounceSelection.selectedSegmentIndex {
        case 0:
            scorecard.settingBounceNumberCards = false
        default:
            scorecard.settingBounceNumberCards = true
        }
        cardsChanged()
        
        // Save it
        UserDefaults.standard.set(scorecard.settingBounceNumberCards, forKey: "bounceNumberCards")
    }
    
    @objc internal func onlinePlayerChangeAction(_ sender: UIButton) {
        var disableOption: String!
        if self.scorecard.settingOnlinePlayerEmail != nil {
            // Online games already enabled
            disableOption = "Disable Online support"
        }
        identifyOnlinePlayer(disableOption: disableOption)
    }
    
    @objc internal func faceTimeTextFieldChanged(_ sender: UITextField) {
        
        self.scorecard.settingFaceTimeAddress = self.faceTimeAddressTextField.text
        
        // Save it
        UserDefaults.standard.set(self.scorecard.settingFaceTimeAddress, forKey: "faceTimeAddress")
    }
    
    @objc internal func faceTimeInfoPressed(_ sender: UIButton) {
        faceTimeInfo()
    }
    
    @objc internal func nearbyPlayingAction(_ sender: Any) {
        switch nearbyPlayingSelection.selectedSegmentIndex {
        case 0:
            scorecard.settingNearbyPlaying = false
        default:
            scorecard.settingNearbyPlaying = true
        }
        self.enableAlerts()
        
        // Save it
        UserDefaults.standard.set(scorecard.settingNearbyPlaying, forKey: "nearbyPlaying")
    }
    
    @objc func trumpIncludeNoTrumpAction(_ sender: Any) {
        switch trumpIncludeNoTrumpSelection.selectedSegmentIndex {
        case 0:
            // Remove NT
            if let index = self.scorecard.suits.firstIndex(where: {$0.toString() == "NT"}) {
                self.scorecard.settingTrumpSequence.remove(at: index)
            }
        case 1:
            // Add NT
            if self.scorecard.suits.firstIndex(where: {$0.toString() == "NT"}) == nil {
                self.scorecard.settingTrumpSequence.append("NT")
            }
        default:
            scorecard.settingBounceNumberCards = true
        }
        self.scorecard.setupSuits()
        self.refreshTrumpSequence()
        
        // Save it
        UserDefaults.standard.set(scorecard.settingTrumpSequence, forKey: "trumpSequence")
    }
    
    @objc internal func trumpSequenceInfoPressed(_ sender: UIButton) {
        trumpSequenceInfo()
    }
    
    @objc internal func prefersStatusBarHiddenAction(_ sender: UISegmentedControl) {
        switch prefersStatusBarHiddenSelection.selectedSegmentIndex {
        case 1:
            scorecard.settingPrefersStatusBarHidden = false
        default:
            scorecard.settingPrefersStatusBarHidden = true
        }
        
        // Save it
        UserDefaults.standard.set(scorecard.settingPrefersStatusBarHidden, forKey: "prefersStatusBarHidden")
        
        // Update status bar
        scorecard.updatePrefersStatusBarHidden(from: self)
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return self.scorecard.suits.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let height: CGFloat = min(collectionView.bounds.size.height, collectionView.bounds.size.width / 5)
        let width = height
        
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: TrumpCollectionCell
        
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Trump Collection Cell", for: indexPath) as! TrumpCollectionCell
        cell.trumpSuitLabel.attributedText = self.scorecard.suits[indexPath.row].toAttributedString()
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath,
                        to destinationIndexPath: IndexPath) {
        
        // Swap the data
        let selectedSuit = self.scorecard.settingTrumpSequence[sourceIndexPath.row]
        self.scorecard.settingTrumpSequence.remove(at: sourceIndexPath.row)
        self.scorecard.settingTrumpSequence.insert(selectedSuit, at: destinationIndexPath.row)
        self.scorecard.setupSuits()
        
        // Save it
        UserDefaults.standard.set(scorecard.settingTrumpSequence, forKey: "trumpSequence")
    }
    
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        
        switch(gesture.state) {
            
        case UIGestureRecognizer.State.began:
            guard let selectedIndexPath = trumpSequenceCollectionView.indexPathForItem(at: gesture.location(in: trumpSequenceCollectionView)) else {
                break
            }
            trumpSequenceCollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
        case UIGestureRecognizer.State.changed:
            trumpSequenceCollectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
        case UIGestureRecognizer.State.ended:
            trumpSequenceCollectionView.endInteractiveMovement()
        default:
            trumpSequenceCollectionView.cancelInteractiveMovement()
        }
    }
    
    // MARK: - Search delegate routines ================================================================== -
    
    func returnPlayers(complete: Bool, playerMO: [PlayerMO]?, info: [String : Any?]?) {
        var playerEmail: String! = nil
        
        if complete {
            if let playerMO = playerMO {
                playerEmail = playerMO[0].email
                if playerEmail != self.scorecard.settingOnlinePlayerEmail {
                    self.onlinePlayerChangeButton?.isEnabled = false
                    self.onlinePlayerChangeButton?.alpha = 0.4
                    self.authoriseNotifications(
                        successAction: {
                            self.saveOnlineEmailLocally(playerEmail: playerEmail)
                            self.enableAlerts()
                        },
                        failureAction: {
                            self.clearOnline()
                            self.enableAlerts()
                        })
                    self.displayOnlineCell(inProgress: "Enabling")
                }
            } else {
                // Disabling Online games - blank out the player
                self.clearOnline()
                self.displayOnlineCell(inProgress: "Disabling")
                self.enableAlerts()
            }
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -

    func enableAlerts() {
        let enabled = self.scorecard.settingSyncEnabled && (self.scorecard.settingNearbyPlaying || self.scorecard.settingOnlinePlayerEmail != nil)
        ScorecardUI.showSegmented(segmented: self.alertVibrateSelection, isEnabled: enabled)
    }
    
    func cardsChanged() {
        let cards = scorecard.settingCards
        let direction = (cards[1] < cards[0] ? "down" : "up")
        var cardString = (cards[1] == 1 ? "card" : "cards")
        bounceSelection.setTitle("Go \(direction) to \(cards[1]) \(cardString)", forSegmentAt: 0)
        cardString = (cards[0] == 1 ? "card" : "cards")
        bounceSelection.setTitle("Return to \(cards[0]) \(cardString)", forSegmentAt: 1)
        self.scorecard.setupRounds()
    }
    
    func refreshTrumpSequence() {
        self.trumpSequenceCollectionView.reloadData()
    }
    
    func twosInfo() {
        self.alertMessage("This provides support for a special rule whereby if you win a trick with a two, you get an extra bonus of 10 points.\n\nThis has the benefit of allowing players to make up a large gap in scores quickly.", title: "Bonus Winning With a Two")
    }
    
    func trumpSequenceInfo() {
        self.alertMessage("Press and hold a suit and then drag it to a new position to change the trump suit sequence", title: "Trump Suit Sequence")
    }
    
    func faceTimeInfo() {
        self.alertMessage("In an online game you can request the host to call you back on FaceTime audio. You will be called at this address. If you leave this field blank this functionality will not be available.", title: "FaceTime Address")
    }
    
    // MARK: - Utility Routines ======================================================================== -

    func authoriseNotifications(successAction: @escaping ()->(), failureAction: @escaping ()->()) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if error != nil {
                // Failure
                failureAction()
            } else {
                Utility.mainThread {
                    let center = UNUserNotificationCenter.current()
                    center.requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in
                    }
                    UIApplication.shared.registerForRemoteNotifications()
                    if self.scorecard.settingSyncEnabled {
                        // Success
                        successAction()
                    }
                }
            }
        }
    }
    
    func warnShare() {
        scorecard.warnShare(from: self, enabled: (self.syncEnabledSelection.selectedSegmentIndex == 1), handler: { (enabled: Bool) -> () in
            // Set the segmented controller
            if enabled {
                self.syncEnabledSelection.selectedSegmentIndex = 1
                // Enable 'receive notifications' and alerts etc
                self.allowBroadcastSelection?.isEnabled = true
                self.receiveNotificationsSelection?.isEnabled = true
                self.alertVibrateSelection?.isEnabled = true
                self.nearbyPlayingSelection?.isEnabled = true
                self.onlinePlayerChangeButton?.isEnabled = true
                self.onlinePlayerChangeButton?.alpha = 1.0
            } else {
                self.syncEnabledSelection.selectedSegmentIndex = 0
                // Need to clear 'receive notifications' and alert controls as well
                self.clearBroadcast()
                self.clearNearby()
                self.clearReceiveNotifications()
                self.clearAlerts()
                self.clearOnline()
                self.allowBroadcastSelection?.isEnabled = false
                self.nearbyPlayingSelection?.isEnabled = false
                self.receiveNotificationsSelection?.isEnabled = false
                self.alertVibrateSelection?.isEnabled = false
                self.onlinePlayerChangeButton?.isEnabled = false
                self.onlinePlayerChangeButton?.alpha = 0.4
            }
        })
    }
    
    func clearReceiveNotifications() {
        self.receiveNotificationsSelection?.selectedSegmentIndex = 0
        self.scorecard.settingReceiveNotifications = false
        // Save 'receive notifications'
        UserDefaults.standard.set(false, forKey: "receiveNotifications")
        // Delete subscriptions
        Notifications.updateHighScoreSubscriptions(scorecard: self.scorecard)
    }
    
    func clearAlerts() {
        // Reset Alert Vibrate
        self.alertVibrateSelection?.selectedSegmentIndex = 0
        self.scorecard.settingAlertVibrate = false
        UserDefaults.standard.set(self.scorecard.settingAlertVibrate, forKey: "alertVibrate")
    }
    
    func clearOnline() {
        if self.scorecard.settingOnlinePlayerEmail != nil {
            self.scorecard.settingOnlinePlayerEmail = nil
            UserDefaults.standard.set(nil, forKey: "onlinePlayerEmail")
            // Delete FaceTime address
            self.scorecard.settingFaceTimeAddress = nil
            UserDefaults.standard.set(nil, forKey: "faceTimeAddress")
            // Update cell
            self.displayOnlineCell(inProgress: "Disabling")
            // Delete subscriptions
            self.updateOnlineGameSubscriptions()
        }
    }
    
    func clearBroadcast() {
        if self.scorecard.settingAllowBroadcast {
            self.allowBroadcastSelection?.selectedSegmentIndex = 0
            self.scorecard.settingAllowBroadcast = false
            UserDefaults.standard.set(false, forKey: "allowBroadcast")
            self.scorecard.stopSharing()
        }
    }
    
    func clearNearby() {
        if self.scorecard.settingNearbyPlaying {
            self.nearbyPlayingSelection?.selectedSegmentIndex = 0
            self.scorecard.settingNearbyPlaying = false
            UserDefaults.standard.set(false, forKey: "nearbyPlaying")
        }
    }
    
    // MARK: - Online game methods ========================================================== -
    
    func displayOnlineCell(inProgress: String? = nil) {
        if let onlinePlayerEmail = self.scorecard.settingOnlinePlayerEmail {
            if inProgress != nil {
                self.onlinePlayerLabel?.text = inProgress
            } else {
                if let onlinePlayerMO = self.scorecard.findPlayerByEmail(onlinePlayerEmail) {
                    self.onlinePlayerLabel?.text = "Enabled for \(onlinePlayerMO.name!)"
                } else {
                    self.onlinePlayerLabel?.text = "Enabled for unknown"
                }
                self.onlinePlayerLabel?.textColor = UIColor.black
                self.onlinePlayerChangeButton?.setTitle("Change", for: .normal)
            }
        } else {
            self.onlinePlayerLabel?.text = (inProgress != nil  ? inProgress : "Not enabled")
            self.onlinePlayerLabel?.textColor = UIColor.lightGray
            self.onlinePlayerChangeButton?.setTitle("Enable", for: .normal)
        }
        let enabled = (scorecard.settingSyncEnabled && inProgress == nil)
        self.onlinePlayerChangeButton.isEnabled = enabled
        self.onlinePlayerChangeButton.alpha = enabled ? 1.0 : 0.4
        self.displayFaceTimeCell()
    }
    
    private func identifyOnlinePlayer(disableOption: String! = nil) {
        self.scorecard.identifyPlayers(from: self, title: "Link Player", disableOption: disableOption, instructions: "You need to link a player to this device to receive invitations for online games", minPlayers: 1, maxPlayers: 1, insufficientMessage: "No players on this device yet")
    }
    
    private func saveOnlineEmailLocally(playerEmail: String!) {
        // Save the setting and update screen
        self.scorecard.settingOnlinePlayerEmail = playerEmail
        Utility.mainThread {
            UserDefaults.standard.set(playerEmail, forKey: "onlinePlayerEmail")
            self.settingsTableView.reloadRows(at: [IndexPath(row: self.onlineRow, section: 0)] , with: .automatic)
            self.updateOnlineGameSubscriptions()
        }
    }
    
    private func updateOnlineGameSubscriptions() {
        self.onlinePlayerChangeButton?.isEnabled = false
        self.onlinePlayerChangeButton?.alpha = 0.4
        if scorecard.settingSyncEnabled && scorecard.settingOnlinePlayerEmail != nil {
            Notifications.addOnlineGameSubscription(scorecard.settingOnlinePlayerEmail, completion: {
                Utility.mainThread { [unowned self] in
                    if self.onlinePlayerLabel != nil {
                        self.displayOnlineCell()
                    }
                }
            })
        } else {
            Notifications.deleteExistingSubscriptions( "onlineGame", completion: {
                Utility.mainThread { [unowned self] in
                    self.displayOnlineCell()
                }
            })
        }
    }
    
    private func displayFaceTimeCell() {
        if let faceTimeAddressTextField = self.faceTimeAddressTextField {
            faceTimeAddressTextField.text = self.scorecard.settingFaceTimeAddress ?? ""
            if self.scorecard.settingOnlinePlayerEmail ?? "" == "" {
                // Field should have been already cleared - just disable it
                faceTimeAddressTextField.isEnabled = false
                faceTimeAddressTextField.layer.borderWidth = 0.0
            } else {
                // Show the field
                faceTimeAddressTextField.text = self.scorecard.settingFaceTimeAddress ?? ""
                faceTimeAddressTextField.isEnabled = true
                faceTimeAddressTextField.layer.cornerRadius = 5.0
                faceTimeAddressTextField.layer.borderWidth = 0.3
                faceTimeAddressTextField.layer.borderColor = UIColor.blue.cgColor
            }
        }
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class SettingsTableCell: UITableViewCell {
    
    @IBOutlet weak var trumpSequenceCollectionView: UICollectionView!

    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        trumpSequenceCollectionView.delegate = dataSourceDelegate
        trumpSequenceCollectionView.dataSource = dataSourceDelegate
        trumpSequenceCollectionView.tag = row
        trumpSequenceCollectionView.reloadData()
    }
    
    @IBOutlet weak var syncEnabledSelection: UISegmentedControl!
    @IBOutlet weak var saveHistorySelection: UISegmentedControl!
    @IBOutlet weak var saveLocationSelection: UISegmentedControl!
    @IBOutlet weak var receiveNotificationsSelection: UISegmentedControl!
    @IBOutlet weak var allowBroadcastSelection: UISegmentedControl!
    @IBOutlet weak var alertVibrateSelection: UISegmentedControl!
    @IBOutlet weak var bonus2Selection: UISegmentedControl!
    @IBOutlet weak var bonus2Info: UIButton!
    @IBOutlet weak var cardsLabel: UILabel!
    @IBOutlet weak var cardsSlider: UISlider!
    @IBOutlet weak var cardsValue: UITextField!
    @IBOutlet weak var nearbyPlayingSelection: UISegmentedControl!
    @IBOutlet weak var onlinePlayerLabel: UILabel!
    @IBOutlet weak var onlinePlayerChangeButton: UIButton!
    @IBOutlet weak var faceTimeAddressTextField: UITextField!
    @IBOutlet weak var faceTimeInfoButton: UIButton!
    @IBOutlet weak var bounceSelection: UISegmentedControl!
    @IBOutlet weak var trumpSequenceInfo: UIButton!
    @IBOutlet weak var trumpIncludeNoTrumpSelection: UISegmentedControl!
    @IBOutlet weak var aboutLabel: UILabel!
    @IBOutlet weak var aboutValue1: UILabel!
    @IBOutlet weak var aboutValue2: UILabel!
    @IBOutlet weak var aboutValue3: UILabel!
    @IBOutlet weak var preferStatusBarHiddenSelection: UISegmentedControl!
}

class TrumpCollectionCell : UICollectionViewCell {
    @IBOutlet weak var trumpSuitLabel: UILabel!
}

