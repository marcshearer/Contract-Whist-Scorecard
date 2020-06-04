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
import CoreLocation

class SettingsViewController: ScorecardViewController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, CLLocationManagerDelegate {
    
    // MARK: - Class Properties ======================================================================== -
        
    // Properties to pass state
    private var backText = "Back"
    private var backImage = "back"
    private var completion: (()->())?
    
    // Other properties
    private var testMode = false
    private var generalInfoExpanded = false
    private var dataInfoExpanded = false
    private var trumpSequenceEdit = false
    private var onlineEnabled = false
    private var facetimeEnabled = false
    private var rowHeight: CGFloat = 35.0
    private var infoHeight: CGFloat = 20.0
    private var reload = false
    private var notificationsRefused = false
    private var locationManager: CLLocationManager! = nil
    private var useLocation: Bool?
    private var themeNames: [String] = Array(Themes.themes.keys)
    private var themesDisplayed: CGFloat = 5.0 // Must be odd
    private var endCells = 0
    
    // Sections
    private enum Sections: Int, CaseIterable {
        case sync = 0
        case saveHistory = 1
        case theme = 2
        case inGame = 3
        case displayStatus = 4
        case generalInfo = 5
        case dataInfo = 6
    }
    
    // Options
    private enum SyncOptions : Int, CaseIterable {
        case vibrateAlert = 0
        case facetimeCalls = 1
        case facetimeAddress = 2
        case shareScorecard = 3
        case receiveNotifications = 4
    }
    
    private enum SaveHistoryOptions : Int, CaseIterable {
        case saveGameLocation = 0
    }
    
    private enum ThemeOptions : Int, CaseIterable {
        case colorTheme = 0
    }
    
    private enum InGameOptions : Int, CaseIterable {
        case cardsInHandSubheading = 0
        case cardsInHandStart = 1
        case cardsInHandEnd = 2
        case cardsInHandBounce = 3
        case spacer1 = 4
        case bonus2Subheading = 5
        case bonus2 = 6
        case spacer2 = 7
        case includeNoTrump = 8
        case trumpSequenceEdit = 9
        case trumpSequenceSuits = 10
    }
        
    private enum GeneralInfoOptions : Int, CaseIterable {
        case version = 0
        case database = 1
    }
    
    private enum DataInfoOptions : Int, CaseIterable {
        case header = 0
        case players = 1
        case games = 2
        case participants = 3
    }
    
    private enum SettingsCollectionViews: Int {
        case trumpSuit = 1
        case colorTheme = 2
    }
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var finishButton: RoundedButton!
    @IBOutlet private weak var settingsTableView: UITableView!
    @IBOutlet private weak var navigationBar: NavigationBar!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.dismiss()
    }
       
    // MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()

        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText)
        
        if let testModeValue = ProcessInfo.processInfo.environment["TEST_MODE"] {
            if testModeValue.lowercased() == "true" {
                testMode = true
            }
        }
        
        self.onlineEnabled = Scorecard.shared.settings.syncEnabled && (Scorecard.shared.settings.onlinePlayerEmail ?? "") != ""
        self.facetimeEnabled = Scorecard.shared.settings.syncEnabled && Scorecard.shared.settings.faceTimeAddress != nil
        
        // Set observer for entering foreground
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        self.themeNames.sort(by: {$0 < $1})
        self.endCells = Int(themesDisplayed - 1) / 2
    }
    
    @objc internal func willEnterForeground() {
        // Check if can receive notifications and switch off options dependent on it if not available
        self.checkReceiveNotifications()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Scorecard.shared.reCenterPopup(self)
        self.reload = true
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if reload {
            self.settingsTableView.reloadData()
        }
        self.reload = false
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Sections.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if let section = Sections(rawValue: section) {
            switch section {
            case .sync:
                return (Scorecard.shared.playerList.count == 0 ? 0 : SyncOptions.allCases.count)
                
            case .saveHistory:
                return SaveHistoryOptions.allCases.count
            
            case .theme:
                return ThemeOptions.allCases.count
                
            case .inGame:
                return InGameOptions.allCases.count
                
            case .displayStatus:
                return 0
                
            case .generalInfo:
                return GeneralInfoOptions.allCases.count
                
            case .dataInfo:
                return DataInfoOptions.allCases.count
            }
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        var height: CGFloat = 0.0
        
        if let section = Sections(rawValue: section) {
            switch section {
            default:
                height = 70.0
            }
        }
        return height
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0.0
        
        if let section = Sections(rawValue: indexPath.section) {
            switch section {
            case .sync:
                if let option = SyncOptions(rawValue: indexPath.row) {
                    switch option {
                    case .facetimeAddress:
                        height = (facetimeEnabled ? self.rowHeight : 0.0)
                    default:
                        height =  self.rowHeight
                    }
                }
                
            case .inGame:
                if let option = InGameOptions(rawValue: indexPath.row) {
                    switch option {
                    case .trumpSequenceSuits:
                        height = 60.0
                    case .spacer1, .spacer2:
                        height = 10.0
                    case .cardsInHandBounce, .bonus2:
                        height = 50.0
                    default:
                        height = self.rowHeight
                    }
                }
                
            case .theme:
                if let option = ThemeOptions(rawValue: indexPath.row) {
                    switch option {
                    case .colorTheme:
                        height = 120.0
                    }
                }
                
            case .generalInfo:
                height = (self.generalInfoExpanded ? self.infoHeight : 0.0)
                
            case .dataInfo:
                height = (self.dataInfoExpanded ? self.infoHeight : 0.0)
                
            default:
                height = self.rowHeight
            }
        } else {
            height =  self.rowHeight
        }
        
        return height
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let section = Sections(rawValue: section) {
            switch section {
            case .sync:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Switch") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                let header = SettingsHeaderFooterView(cell)
                cell.label.text = "Enable online games"
                cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.onlineGamesChanged(_:)), for: .valueChanged)
                cell.toggleSwitch.isOn = Scorecard.shared.settings.onlinePlayerEmail != nil
                cell.setEnabled(enabled: Scorecard.shared.settings.syncEnabled)
                return header
                
            case .saveHistory:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Switch") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                let header = SettingsHeaderFooterView(cell)
                cell.label.text = "Save Game History"
                cell.toggleSwitch.isHidden = true
                cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.saveHistoryChanged(_:)), for: .valueChanged)
                cell.toggleSwitch.isOn = Scorecard.shared.settings.saveHistory
                cell.setEnabled(enabled: !Scorecard.shared.settings.syncEnabled)
                return header
                
            case .theme:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Switch") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                let header = SettingsHeaderFooterView(cell)
                cell.label.text = "Colour theme"
                cell.toggleSwitch.isHidden = true
                return header
                
            case .displayStatus:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Switch") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                let header = SettingsHeaderFooterView(cell)
                cell.label.text = "Show Status Bar"
                cell.toggleSwitch.isHidden = false
                cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.displayStatusChanged(_:)), for: .valueChanged)
                cell.toggleSwitch.isOn = !Scorecard.shared.settings.prefersStatusBarHidden
                return header
                
            case .inGame:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Switch") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                let header = SettingsHeaderFooterView(cell)
                cell.label.text = "In Game"
                cell.toggleSwitch.isHidden = true
                return header
                
            case .generalInfo:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Collapse") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                let header = SettingsHeaderFooterView(cell)
                cell.collapseButton.setImage(UIImage(named: (generalInfoExpanded ? "arrow down" : "arrow right")), for: .normal)
                cell.label.text = "About"
                cell.collapseButton.addTarget(self, action: #selector(SettingsViewController.generalInfoClicked(_:)), for: .touchUpInside)
                return header
                
            case .dataInfo:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Collapse") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                let header = SettingsHeaderFooterView(cell)
                cell.collapseButton.setImage(UIImage(named: (dataInfoExpanded ? "arrow down" : "arrow right")), for: .normal)
                cell.label.text = "Data"
                cell.collapseButton.addTarget(self, action: #selector(SettingsViewController.dataInfoClicked(_:)), for: .touchUpInside)
                return header
                
            }
        } else {
            return nil
        }
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: SettingsTableCell!
        if let section = Sections(rawValue: indexPath.section) {
            switch section {
            case .sync:
                if let option = SyncOptions(rawValue: indexPath.row) {
                    switch option {
                    case .vibrateAlert:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)

                        cell.resizeSwitch(0.75)
                        cell.label.text = "Vibrate when turn to play"
                        cell.labelLeadingConstraint.constant = 40
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.vibrateAlertChanged(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = Scorecard.shared.settings.alertVibrate
                        self.enableAlerts(cell: cell)
                        
                    case .facetimeCalls:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Facetime calls in online games"
                        cell.labelLeadingConstraint.constant = 40
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.facetimeCallsClicked(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = self.facetimeEnabled
                        cell.setEnabled(enabled: Scorecard.shared.settings.syncEnabled && (Scorecard.shared.settings.onlinePlayerEmail ?? "") != "")
                        
                    case .facetimeAddress:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Text Field") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.textField.addTarget(self, action: #selector(SettingsViewController.facetimeAddressChanged(_:)), for: UIControl.Event.editingChanged)
                        cell.textField.addTarget(self, action: #selector(SettingsViewController.facetimeAddressEndEdit(_:)), for: UIControl.Event.editingDidEnd)
                        cell.textField.addTarget(self, action: #selector(SettingsViewController.facetimeAddressBeginEdit(_:)), for: UIControl.Event.editingDidBegin)
                        cell.textField.attributedPlaceholder = NSAttributedString(string: "Enter Facetime address", attributes:[NSAttributedString.Key.foregroundColor: Palette.inputControlPlaceholder])
                        cell.textField.text = Scorecard.shared.settings.faceTimeAddress ?? ""
                        cell.setEnabled(enabled: self.facetimeEnabled)
                        
                    case .shareScorecard:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Share scorecard"
                        cell.labelLeadingConstraint.constant = 20.0
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.shareScorecardChanged(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = true // Todo
                        
                    case .receiveNotifications:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Receive game notifications"
                        cell.labelLeadingConstraint.constant = 20.0
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.receiveNotificationsChanged(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = Scorecard.shared.settings.receiveNotifications
                        cell.setEnabled(enabled: Scorecard.shared.settings.syncEnabled)
                    }
                }
                
            case .saveHistory:
                if let option = SaveHistoryOptions(rawValue: indexPath.row) {
                    switch option {
                    case .saveGameLocation:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Save game location"
                        cell.labelLeadingConstraint.constant = 20.0
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.saveGameLocationChanged(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = Scorecard.shared.settings.saveLocation
                        cell.setEnabled(enabled: Scorecard.shared.settings.saveHistory)
                    }
                }
                
            case .theme:
                // No sub-options
                if let option = ThemeOptions(rawValue: indexPath.row) {
                    switch option {
                    case .colorTheme:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Color Theme") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                    }
                }
                
            case .inGame:
                if let option = InGameOptions(rawValue: indexPath.row) {
                    switch option {
                    case .cardsInHandSubheading:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Sub Heading") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.subHeadingLabel.text = "Number of cards in hands"
                        
                    case .cardsInHandStart, .cardsInHandEnd:
                        let index = (option == .cardsInHandStart ? 0 : 1)
                        cell = tableView.dequeueReusableCell(withIdentifier: "Slider") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)

                        cell.slider.tag = index
                        cell.sliderLabel.text = (index == 0 ? "Start:" : "End:")
                        cell.slider.addTarget(self, action: #selector(SettingsViewController.cardsSliderChanged(_:)), for: .valueChanged)
                        cell.sliderValue.text = "\(Scorecard.shared.settings.cards[index])"
                        cell.slider.value = Float(Scorecard.shared.settings.cards[index])
                        
                    case .cardsInHandBounce:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Segmented") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        self.cardsChanged(bounceSegmentedControl: cell.segmentedControl)
                        cell.segmentedControl.addTarget(self, action: #selector(SettingsViewController.cardsInHandBounceChanged(_:)), for: .valueChanged)
                        cell.segmentedControl.selectedSegmentIndex = (Scorecard.shared.settings.bounceNumberCards ? 1 : 0)
                        
                    case .bonus2Subheading:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Sub Heading") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.subHeadingLabel.text = "Bonus for winning a trick with a 2"
                        
                    case .bonus2:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Segmented") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.segmentedControl.setTitle("No bonus", forSegmentAt: 0)
                        cell.segmentedControl.setTitle("10 Point Bonus", forSegmentAt: 1)
                        cell.segmentedControl.addTarget(self, action: #selector(SettingsViewController.bonus2Changed(_:)), for: .valueChanged)
                        cell.segmentedControl.selectedSegmentIndex = (Scorecard.shared.settings.bonus2 ? 1 : 0)
                        
                    case .includeNoTrump:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Include No Trump (NT)"
                        cell.labelLeadingConstraint.constant = 20.0
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.includeNoTrumpChanged(_:)), for: .valueChanged)
                        let index = Scorecard.shared.settings.trumpSequence.firstIndex(where: {$0 == "NT"})
                        cell.toggleSwitch.isOn = (index != nil)
                        
                    case .trumpSequenceEdit:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Edit Button") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.editLabel.text = "Trump suit sequence"
                        cell.editButton.addTarget(self, action: #selector(SettingsViewController.trumpSequenceEditClicked(_:)), for: .touchUpInside)
                        
                    case .trumpSequenceSuits:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Trump Collection") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.setEnabled(enabled: false)
                        
                    case .spacer1, .spacer2:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Spacer") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                    }

                }
                
            case .generalInfo:
                if let option = GeneralInfoOptions(rawValue: indexPath.row) {
                    switch option {
                    case .version:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Info Single") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.infoLabel.text = "Version:"
                        cell.infoValue1.text = "\(Scorecard.version.version) (\(Scorecard.version.build))"
                        
                    case .database:
                        // Database
                        cell = tableView.dequeueReusableCell(withIdentifier: "Info Single") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.infoLabel.text = "Database:"
                        cell.infoValue1.text = Scorecard.shared.database
                    }
                }
                
            case .displayStatus:
                // No sub-options
                break
                
            case .dataInfo:
                if let option = DataInfoOptions(rawValue: indexPath.row) {
                    switch option {
                    case .header:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Info Three Heading") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.infoLabel.text = "Table Sizes"
                        cell.infoValue1.text = "Local"
                        cell.infoValue2.text = "Cloud"
                        cell.infoValue3.text = "Score"
                        
                    case .players:
                         cell = tableView.dequeueReusableCell(withIdentifier: "Info Three") as? SettingsTableCell
                         // Setup default colors (previously done in StoryBoard)
                         self.defaultCellColors(cell: cell)
                         
                        let totalScore = Scorecard.shared.playerList.reduce(0) { $0 + $1.totalScore }
                        cell.infoLabel.text = "Players:"
                        cell.infoValue1.text = "\(Scorecard.shared.playerList.count)"
                        cell.infoValue2.text = ""
                        Utility.getCloudRecordCount("Players", completion: { (players) in
                            Utility.mainThread {
                                if cell.infoValue2 != nil && players != nil {
                                    cell.infoValue2.text = "\(players!)"
                                }
                            }
                        })
                        cell.infoValue3.text = "\(totalScore)"
                        
                    case .games:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Info Three") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        let historyGames: [GameMO] = CoreData.fetch(from: "Game")
                        cell.infoLabel.text = "Games:"
                        cell.infoValue1.text = "\(historyGames.count)"
                        cell.infoValue2.text = ""
                        Utility.getCloudRecordCount("Games", completion: { (games) in
                            Utility.mainThread {
                                if cell.infoValue2 != nil && games != nil {
                                    cell.infoValue2.text = "\(games!)"
                                }
                            }
                        })
                        cell.infoValue3.text = ""
                        
                    case .participants:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Info Three") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        let historyParticipants: [ParticipantMO] = CoreData.fetch(from: "Participant")
                        var totalScore:Int64 = 0
                        for participantMO in historyParticipants {
                            totalScore = totalScore + Int64(participantMO.totalScore)
                        }
                        cell.infoLabel.text = "Participants:"
                        cell.infoValue1.text = "\(historyParticipants.count)"
                        cell.infoValue2.text = ""
                        Utility.getCloudRecordCount("Participants", completion: { (participants) in
                            Utility.mainThread {
                                if cell.infoValue2 != nil && participants != nil {
                                    cell.infoValue2.text = "\(participants!)"
                                }
                            }
                        })
                        cell.infoValue3.text = "\(totalScore)"
                    }
                }
            }
        }
        
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = UIColor.clear
        
        return cell
    
    }
    
    internal func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let section = Sections(rawValue: indexPath.section) {
        switch section {
        case .inGame:
            if let option = InGameOptions(rawValue: indexPath.row) {
                switch option {
                case .trumpSequenceSuits:
                    // Trump suit sequence
                    guard let tableViewCell = cell as? SettingsTableCell else { return }
                    tableViewCell.setCollectionViewDataSourceDelegate(tableViewCell.trumpSequenceCollectionView, self, forRow: indexPath.row)
                    // Allow movement
                    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongGesture(gesture:)))
                    tableViewCell.trumpSequenceCollectionView.addGestureRecognizer(longPressGesture)
                    tableViewCell.trumpSequenceCollectionView.tag = SettingsCollectionViews.trumpSuit.rawValue
                    
                default:
                    break
                }
            }
        case .theme:
            if let option = ThemeOptions(rawValue: indexPath.row) {
                switch option {
                case .colorTheme:
                    // Color theme
                    guard let tableViewCell = cell as? SettingsTableCell else { return }
                    tableViewCell.setCollectionViewDataSourceDelegate(tableViewCell.colorThemeCollectionView, self, forRow: indexPath.row)
                    tableViewCell.colorThemeCollectionView.tag = SettingsCollectionViews.colorTheme.rawValue

                }
            }
        default:
            break
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        self.view.endEditing(true)
        if let section = Sections(rawValue: indexPath.section) {
            switch section {
            case .generalInfo:
                // Expand general info if touch any part of section
                self.generalInfoClicked()
            case .dataInfo:
                // Expand data info if touch any part of section
                self.dataInfoClicked()
            default:
                break
            }
        }
        return nil
    }
    
    // MARK: - Action functions from TableView Cells =========================================== -
    
    @objc internal func saveHistoryChanged(_ saveHistorySwitch: UISwitch) {
        
        Scorecard.shared.settings.saveHistory = saveHistorySwitch.isOn
        
        if Scorecard.shared.settings.saveHistory {
            self.setOptionEnabled(section: Sections.saveHistory.rawValue, option: SaveHistoryOptions.saveGameLocation.rawValue, enabled: true)
        } else {
            // Need to clear 'save location' as well
            self.setOptionValue(section: Sections.saveHistory.rawValue, option: SaveHistoryOptions.saveGameLocation.rawValue, value: false)
            self.setOptionEnabled(section: Sections.saveHistory.rawValue, option: SaveHistoryOptions.saveGameLocation.rawValue, enabled: false)
            Scorecard.shared.settings.saveLocation = false
            // Save 'save location'
            UserDefaults.standard.set(Scorecard.shared.settings.saveLocation, forKey: "saveLocation")
        }
        
        // Save it
        UserDefaults.standard.set(Scorecard.shared.settings.saveHistory, forKey: "saveHistory")
    }
    
    @objc internal func generalInfoClicked(_ collapseButton: UIButton) {
        self.generalInfoClicked()
    }
            
    private func generalInfoClicked() {
        self.generalInfoExpanded = !self.generalInfoExpanded
        self.settingsTableView.reloadSections(IndexSet(arrayLiteral: Sections.generalInfo.rawValue), with: .automatic)
        self.scrollToBottom()
    }
    
    @objc internal func dataInfoClicked(_ collapseButton: UIButton) {
        self.dataInfoClicked()
    }
    
    private func dataInfoClicked() {
        self.dataInfoExpanded = !self.dataInfoExpanded
        self.settingsTableView.reloadSections(IndexSet(arrayLiteral: Sections.dataInfo.rawValue), with: .automatic)
        self.scrollToBottom()
    }
    
    @objc internal func saveGameLocationChanged(_ saveGameLocationSwitch: UISwitch) {
 
        if saveGameLocationSwitch.isOn {
            // Check if can switch it on
            self.checkUseLocation(prompt: true)
        } else {
            // Switch it off
            self.setSaveGameLocation(value: false)
        }
    }
    
    @objc internal func shareScorecardChanged(_ shareScorecardSwitch: UISwitch) {
        
        Scorecard.shared.settings.allowBroadcast = shareScorecardSwitch.isOn
            
        // Save it
        UserDefaults.standard.set(Scorecard.shared.settings.allowBroadcast, forKey: "allowBroadcast")
    }
    
    @objc internal func onlineGamesChanged(_ onlineGamesSwitch: UISwitch) {
        self.onlineEnabled = onlineGamesSwitch.isOn
        if self.onlineEnabled {
            self.authoriseNotifications(
                successAction: {
                    self.identifyOnlinePlayer()
            },
                failureAction: {
                    self.clearOnline()
                    self.clearReceiveNotifications()
            })
        } else {
            self.clearOnline()
        }
    }
    
    @objc internal func onlinePlayerClicked(_ onlinePlayerClicked: UIButton) {
        self.identifyOnlinePlayer()
    }

    @objc internal func vibrateAlertChanged(_ vibrateAlertSwitch: UISwitch) {
        
        Scorecard.shared.settings.alertVibrate = vibrateAlertSwitch.isOn
        
        // Save it
        UserDefaults.standard.set(Scorecard.shared.settings.alertVibrate, forKey: "alertVibrate")
    }

    @objc internal func facetimeCallsClicked(_ facetimeCallsSwitch: UISwitch) {
        
        self.facetimeEnabled = facetimeCallsSwitch.isOn
        
        if self.facetimeEnabled {
            // Enabled - edit address
            self.setOptionEnabled(section: Sections.sync.rawValue, option: SyncOptions.facetimeAddress.rawValue, enabled: true)
        } else {
            // Disabled blank out address
            Scorecard.shared.settings.faceTimeAddress = ""
            self.setOptionValue(section: Sections.sync.rawValue, option: SyncOptions.facetimeCalls.rawValue, value: false)
            self.setOptionEnabled(section: Sections.sync.rawValue, option: SyncOptions.facetimeAddress.rawValue, enabled: false)
            
            // Save it
            UserDefaults.standard.set(Scorecard.shared.settings.faceTimeAddress, forKey: "facetimeAddress")
        }
        
        self.refreshFaceTimeAddress()
        if self.facetimeEnabled {
            self.setOptionFirstResponder(section: Sections.sync.rawValue, option: SyncOptions.facetimeAddress.rawValue)
        }
    }
    
    @objc internal func facetimeAddressChanged(_ facetimeAddressTextField: UITextField) {
        
        Scorecard.shared.settings.faceTimeAddress = facetimeAddressTextField.text
        
        // Save it
        UserDefaults.standard.set(Scorecard.shared.settings.faceTimeAddress, forKey: "facetimeAddress")
        
    }
    
    @objc internal func facetimeAddressBeginEdit(_ facetimeAddressTextField: UITextField) {
        facetimeAddressTextField.layer.borderColor = Palette.text.cgColor
    }
    
    @objc internal func facetimeAddressEndEdit(_ facetimeAddressTextField: UITextField) {
        
        self.facetimeAddressChanged(facetimeAddressTextField)
        
        // If blank then unset facetime calls switch and disable address
        if Scorecard.shared.settings.faceTimeAddress == "" {
            self.facetimeEnabled = false
            self.setOptionValue(section: Sections.sync.rawValue, option: SyncOptions.facetimeCalls.rawValue, value: false)
            self.setOptionEnabled(section: Sections.sync.rawValue, option: SyncOptions.facetimeAddress.rawValue, enabled: false)
            self.refreshFaceTimeAddress()
        }
        self.resignFirstResponder()
        facetimeAddressTextField.layer.borderColor = Palette.emphasis.cgColor
    }
     
    @objc internal func receiveNotificationsChanged(_ receiveNotificationsSwitch: UISwitch) {
        if receiveNotificationsSwitch.isOn {
            Scorecard.shared.settings.receiveNotifications = true
            authoriseNotifications(
                successAction: {
                    Notifications.updateHighScoreSubscriptions()
                    // Save it
                    UserDefaults.standard.set(Scorecard.shared.settings.receiveNotifications, forKey: "receiveNotifications")
                },
                failureAction: {
                    self.clearReceiveNotifications()
                })
        } else {
            self.clearReceiveNotifications()
        }
    }
    
    @objc internal func cardsSliderChanged(_ cardsSlider: UISlider) {
        let index = cardsSlider.tag
        let option = (index == 0 ? InGameOptions.cardsInHandStart : InGameOptions.cardsInHandEnd)
        Scorecard.shared.settings.cards[index] = Int(cardsSlider.value)
        self.setOptionValue(section: Sections.inGame.rawValue, option: option.rawValue, value: Scorecard.shared.settings.cards[index])
        self.cardsChanged()
        
        // Save it
        UserDefaults.standard.set(Scorecard.shared.settings.cards, forKey: "cards")
    }
    
    @objc func cardsInHandBounceChanged(_ cardsInHandBounceSegmentedControl: UISegmentedControl) {
        
        Scorecard.shared.settings.bounceNumberCards = (cardsInHandBounceSegmentedControl.selectedSegmentIndex == 1)
        self.cardsChanged()
        
        // Save it
        UserDefaults.standard.set(Scorecard.shared.settings.bounceNumberCards, forKey: "bounceNumberCards")
    }

    @objc internal func bonus2Changed(_ bonus2SegmentedControl: UISegmentedControl) {
        
        Scorecard.shared.settings.bonus2 = (bonus2SegmentedControl.selectedSegmentIndex == 1)
        
        // Save it
        UserDefaults.standard.set(Scorecard.shared.settings.bonus2, forKey: "bonus2")
    }
    
    @objc func includeNoTrumpChanged(_ includeNoTrumpSwitch: UISwitch) {
        if includeNoTrumpSwitch.isOn {
            // Add NT
            if Scorecard.shared.settings.trumpSequence.firstIndex(where: {$0 == "NT"}) == nil {
                Scorecard.shared.settings.trumpSequence.append("NT")
            }
        } else {
            // Remove NT
            if let index = Scorecard.shared.settings.trumpSequence.firstIndex(where: {$0 == "NT"}) {
                Scorecard.shared.settings.trumpSequence.remove(at: index)
            }
        }
        self.refreshTrumpSequence()
    }
    
    @objc func trumpSequenceEditClicked(_ trumpSequenceEditButton: UIButton) {
        if trumpSequenceEdit {
            // Leaving edit mode - save it
            self.refreshTrumpSequence()
            
            // Save it
            UserDefaults.standard.set(Scorecard.shared.settings.trumpSequence, forKey: "trumpSequence")
            
            // Disable suit buttons
            self.setOptionEnabled(section: Sections.inGame.rawValue, option: InGameOptions.trumpSequenceSuits.rawValue, enabled: false)
            
            // Rename edit button
            trumpSequenceEditButton.setTitle("Edit", for: .normal)
            
            // Stop wiggle and enable other options
            self.stopWiggle()
            self.enableAll()
            self.settingsTableView.isScrollEnabled = true
            
            trumpSequenceEdit = false
            
        } else {
            // Entering edit mode - Enable suit buttons
            self.setOptionEnabled(section: Sections.inGame.rawValue, option: InGameOptions.trumpSequenceSuits.rawValue, enabled: true)
            
            // Rename edit button
            trumpSequenceEditButton.setTitle("Done", for: .normal)
            
            // Make sure that trump suit is in view
            let indexPath = IndexPath(row: InGameOptions.trumpSequenceSuits.rawValue, section: Sections.inGame.rawValue)
            self.settingsTableView.scrollToRow(at: indexPath, at: .none, animated: true)
            
            // Start wiggling suits and disable everything else
            self.startWiggle()
            self.disableAll(exceptSection: Sections.inGame.rawValue, exceptOptions: InGameOptions.trumpSequenceEdit.rawValue,
                                                                                    InGameOptions.trumpSequenceSuits.rawValue)
            self.settingsTableView.isScrollEnabled = false
            
            trumpSequenceEdit = true
        
        }
    }

    @objc internal func displayStatusChanged(_ displayStatusSwitch: UISwitch) {
        Scorecard.shared.settings.prefersStatusBarHidden = !displayStatusSwitch.isOn

        // Save it
        UserDefaults.standard.set(Scorecard.shared.settings.prefersStatusBarHidden, forKey: "prefersStatusBarHidden")
        
        // Update status bar
        Scorecard.shared.updatePrefersStatusBarHidden(from: self)
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        switch SettingsCollectionViews(rawValue: collectionView.tag) {
        case .trumpSuit:
            return Scorecard.shared.settings.trumpSequence.count
        case .colorTheme:
            return self.themeNames.count + Int(themesDisplayed) - 1
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        switch SettingsCollectionViews(rawValue: collectionView.tag) {
        case .trumpSuit:
            let height: CGFloat = min(collectionView.bounds.size.height, collectionView.bounds.size.width / 5)
            return CGSize(width: height, height: height)
            
        case .colorTheme:
            let height: CGFloat = collectionView.bounds.size.height
            let width: CGFloat = (collectionView.bounds.size.width / self.themesDisplayed)
            return CGSize(width: width, height: height)
            
        default:
            return CGSize()
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        switch SettingsCollectionViews(rawValue: collectionView.tag) {
        case .trumpSuit:
            var cell: TrumpCollectionCell
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Trump Collection Cell", for: indexPath) as! TrumpCollectionCell
            // Setup default colors (previously done in StoryBoard)
            self.defaultCellColors(cell: cell)
            
            cell.trumpSuitLabel.attributedText = Suit(fromString: Scorecard.shared.settings.trumpSequence[indexPath.row]).toAttributedString(font: UIFont.systemFont(ofSize: 36.0), noTrumpScale: 0.8)
            if self.trumpSequenceEdit {
                self.startCellWiggle(cell: cell)
            }
            
            return cell
            
        case .colorTheme:
            var cell: ColorThemeCollectionCell
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Color Theme Cell", for: indexPath) as! ColorThemeCollectionCell
            
            if indexPath.item < self.endCells || indexPath.item >= themeNames.count + self.endCells {
                // Dummy cell
                cell.nameLabel.text = ""
                cell.sample.isHidden = true
            } else {
                let theme = Themes.themes[self.themeNames[indexPath.item - self.endCells]]!
                cell.nameLabel.text = theme.description
                cell.nameLabel.textColor = theme.color(.gameBanner, .current)
                cell.sample.setColors(theme: theme)
                cell.sample.isHidden = false
            }
            
            return cell
            
        default:
            return UICollectionViewCell()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        switch SettingsCollectionViews(rawValue: collectionView.tag) {
        case .trumpSuit:
            return true
        default:
            return false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath,
                        to destinationIndexPath: IndexPath) {
        switch SettingsCollectionViews(rawValue: collectionView.tag) {
        case .trumpSuit:
            // Swap the data and restart wiggling
            let selectedSuit = Scorecard.shared.settings.trumpSequence[sourceIndexPath.row]
            Scorecard.shared.settings.trumpSequence.remove(at: sourceIndexPath.row)
            Scorecard.shared.settings.trumpSequence.insert(selectedSuit, at: destinationIndexPath.row)
            
            // Save it
            UserDefaults.standard.set(Scorecard.shared.settings.trumpSequence, forKey: "trumpSequence")
            
        default:
            break
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch SettingsCollectionViews(rawValue: collectionView.tag) {
        case .colorTheme:
            if indexPath.item < self.endCells || indexPath.item >= themeNames.count + self.endCells {
                return false
            } else {
                return true
            }
        default:
            return false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch SettingsCollectionViews(rawValue: collectionView.tag) {
        case .colorTheme:
            self.selectColorTheme(item: indexPath.item - self.endCells)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        default:
            break
        }
    }
    
    internal func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        Utility.mainThread {
            if let collectionView = scrollView as? UICollectionView {
                switch SettingsCollectionViews(rawValue: collectionView.tag) {
                case .colorTheme:
                    let offset = collectionView.contentOffset.x
                    let item = Utility.round(Double(offset / (collectionView.frame.width / self.themesDisplayed)))
                    self.selectColorTheme(item: item)
                default:
                    break
                }
            }
        }
    }
    
    private func selectColorTheme(item: Int) {
        Themes.selectTheme(name: self.themeNames[item])
        self.defaultViewColors()
        self.view.setNeedsDisplay()
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        self.settingsTableView.reloadData()
    }
    
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        
        if let trumpSuitCollectionView = getTrumpSuitCollectionView() {
        
            switch(gesture.state) {
            case UIGestureRecognizer.State.began:
                guard let selectedIndexPath = trumpSuitCollectionView.indexPathForItem(at: gesture.location(in: trumpSuitCollectionView)) else {
                    break
                }
                trumpSuitCollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
            case UIGestureRecognizer.State.changed:
                trumpSuitCollectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
            case UIGestureRecognizer.State.ended:
                trumpSuitCollectionView.endInteractiveMovement()
            default:
                trumpSuitCollectionView.cancelInteractiveMovement()
            }
        }
    }
    
    // MARK: - Search return routine ================================================================== -
    
    private func identifyPlayerCompletion(return: Bool, playerMO: [PlayerMO]?) {
        var playerEmail: String! = nil
        var refresh = false
        
        if let playerMO = playerMO {
            if Scorecard.shared.settings.onlinePlayerEmail ?? "" == "" {
                refresh = true
            }
            playerEmail = playerMO[0].email
            self.saveOnlineEmailLocally(playerEmail: playerEmail)
            self.enableOnline()
            self.displayOnlineCell(inProgress: "Enabling for \(playerMO[0].name!)")
            
        } else if Scorecard.shared.settings.onlinePlayerEmail ?? "" == "" {
            // Cancelled and no previous value
            self.clearOnline()
        }
        if refresh {
            self.refreshOnlinePlayer()
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -

    private func enableAlerts(cell: SettingsTableCell? = nil, switchOn: Bool = false) {
        if let cell = cell {
            cell.setEnabled(enabled: self.onlineEnabled)
        } else {
            self.setOptionEnabled(section: Sections.sync.rawValue, option: SyncOptions.vibrateAlert.rawValue, enabled: self.onlineEnabled)
        }
        if switchOn {
            Scorecard.shared.settings.alertVibrate = true
            UserDefaults.standard.set(Scorecard.shared.settings.alertVibrate, forKey: "alertVibrate")
            if let cell = cell {
                self.setOptionValue(cell: cell, value: true)
            } else {
                self.setOptionValue(section: Sections.sync.rawValue, option: SyncOptions.vibrateAlert.rawValue, value: true)
            }
        }
    }
    
    private func cardsChanged(bounceSegmentedControl: UISegmentedControl? = nil) {
        if let bounceSegmentedControl = bounceSegmentedControl ?? self.getCardsInHandBounceSegmentedControl() {
            let cards = Scorecard.shared.settings.cards
            let direction = (cards[1] < cards[0] ? "down" : "up")
            var cardString = (cards[1] == 1 ? "card" : "cards")
            bounceSegmentedControl.setTitle("Go \(direction) to \(cards[1]) \(cardString)", forSegmentAt: 0)
            cardString = (cards[0] == 1 ? "card" : "cards")
            bounceSegmentedControl.setTitle("Return to \(cards[0]) \(cardString)", forSegmentAt: 1)
        }
    }
    
    private func refreshTrumpSequence() {
        if let trumpSuitCollectionView = self.getTrumpSuitCollectionView() {
            trumpSuitCollectionView.reloadData()
        }
    }
    
    private func refreshOnlinePlayer() {
        // Reload whole section to avoid dodgy animation
        self.settingsTableView.reloadSections(IndexSet(arrayLiteral: Sections.sync.rawValue), with: .automatic)
    }
    
    private func refreshFaceTimeAddress() {
        // Reload row as height might have changed
        let indexPath = IndexPath(row: SyncOptions.facetimeAddress.rawValue, section: Sections.sync.rawValue)
        self.settingsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    private func scrollToBottom() {
        let sections = self.numberOfSections(in: self.settingsTableView)
        let options = self.tableView(self.settingsTableView, numberOfRowsInSection: sections - 1)
        self.settingsTableView.scrollToRow(at: IndexPath(row: options - 1, section: sections - 1), at: .bottom, animated: true)
    }
    
    private func startWiggle() {
        if let collection = self.getTrumpSuitCollectionView() {
            let numberSuits = Scorecard.shared.settings.trumpSequence.count
            for item in 0..<numberSuits {
                if let cell = collection.cellForItem(at: IndexPath(item: item, section: 0)) {
                    self.startCellWiggle(cell: cell)
                }
            }
        }
    }
    
    private func startCellWiggle(cell: UICollectionViewCell) {
        let animation  = CAKeyframeAnimation(keyPath:"transform")
        animation.values  = [NSValue(caTransform3D: CATransform3DMakeRotation(0.1, 0.0, 0.0, 1.0)),
                             NSValue(caTransform3D: CATransform3DMakeRotation(-0.1, 0.0, 0.0, 1.0))]
        animation.autoreverses = true
        animation.duration  = 0.1
        animation.repeatCount = Float.infinity
        cell.layer.add(animation, forKey: "transform")
    }
    
    public func stopWiggle() {
        if let collection = self.getTrumpSuitCollectionView() {
            let numberSuits = Scorecard.shared.settings.trumpSequence.count
            for item in 0..<numberSuits {
                if let cell = collection.cellForItem(at: IndexPath(item: item, section: 0)) {
                    cell.layer.removeAllAnimations()
                }
            }
        }
    }
    
    private func disableAll(exceptSection: Int, exceptOptions: Int...) {
        self.forEachSection() { (section) in
            self.setSectionEnabled(section: section, enabled: false)
        }
        self.forEachOption(exceptSection: exceptSection, exceptOptions: exceptOptions) { (section, option) in
            self.setOptionEnabled(section: section, option: option, enabled: false)
        }
    }
    
    private func enableAll() {
        // Difficult to tell what should be enabled - just refresh table
        self.settingsTableView.reloadData()
    }
    
    private func forEachSection(action: (Int)->()) {
        for section in Sections.allCases {
            action(section.rawValue)
        }
    }
    
    private func forEachOption(exceptSection: Int, exceptOptions: [Int], action: (Int, Int)->()) {
        var options: Int
        
        for section in Sections.allCases {
            
            options = tableView(self.settingsTableView, numberOfRowsInSection: section.rawValue)
            
            if options != 0 {
                for option in 0..<options {
                    if section.rawValue != exceptSection || exceptOptions.firstIndex(where: {$0 == option}) == nil {
                        action(section.rawValue, option)
                    }
                }
            }
        }
    }
    
    // MARK: - Location delegate ========================================================================= -
    
    private func checkUseLocation(prompt: Bool) {
        let authorizationStatus = CLLocationManager.authorizationStatus()
        switch authorizationStatus {
        case .restricted, .denied:
            // Not allowed to use location
            self.useLocation = false
            if prompt {
                self.alertMessage("You have previously refused permission for this app to use your location. To change this, please allow location access 'While Using the App' in the Whist section of the main Settings App", title: "Error")
            }
        case .notDetermined:
            self.useLocation = nil
            if prompt {
                locationManager = CLLocationManager()
                locationManager.delegate = self
                // Ask for permission and continue in authorization changed delegate
                locationManager.requestWhenInUseAuthorization()
            }
        default:
            self.useLocation = true
            Scorecard.shared.settings.saveLocation = true
            // Save it
            UserDefaults.standard.set(Scorecard.shared.settings.saveLocation, forKey: "saveLocation")
        }
    }
    
    private func setSaveGameLocation(value: Bool) {
        Scorecard.shared.settings.saveLocation = value
        self.setOptionValue(section: Sections.saveHistory.rawValue, option: SaveHistoryOptions.saveGameLocation.rawValue, value: value)
        UserDefaults.standard.set(value, forKey: "saveLocation")
    }
 
    internal func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Utility.mainThread { [unowned self] in
            if status == .authorizedWhenInUse {
                // Authorization granted
                self.useLocation = true
             } else {
                // Permission to use location refused
                self.useLocation = false
            }
            self.setSaveGameLocation(value: self.useLocation ?? false)
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -

    private func checkReceiveNotifications() {
        let current = UNUserNotificationCenter.current()
        current.getNotificationSettings(completionHandler: { (settings) in
            switch settings.authorizationStatus {
            case .notDetermined, .provisional :
                // Notification permission has not been asked yet, will ask if switch on relevant options
                self.notificationsRefused = false
            case .denied:
                // Notification permission was previously denied, switch off relevant options
                self.notificationsRefused = true
                self.clearReceiveNotifications()
                self.clearOnline()
            case .authorized:
                // Notification permission was already granted
                self.notificationsRefused = false
            @unknown default:
                fatalError("Unexpected value for UNAuthorizationStatus")
            }
        })
    }
    
    private func authoriseNotifications(successAction: @escaping ()->(), failureAction: @escaping ()->()) {
        if self.notificationsRefused {
            failureAction()
            self.alertMessage("You have previously refused permission for this app to send you notifications. To change this, please authorise notifications in the Whist section of the main Settings App", title: "Error")
        } else {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in
                if error != nil || !granted {
                    Utility.mainThread {
                        failureAction()
                    }
                }
                Utility.mainThread {
                    UIApplication.shared.registerForRemoteNotifications()
                    if Scorecard.shared.settings.syncEnabled {
                        // Success
                        successAction()
                    }
                }
            }
        }
    }
    
    private func setOptionEnabled(section: Int, option: Int, enabled: Bool) {
        let indexPath = IndexPath(row: option, section: section)
        if let cell = settingsTableView.cellForRow(at: indexPath) as? SettingsTableCell {
            cell.setEnabled(enabled: enabled)
        }
    }
            
    
    private func setOptionFirstResponder(section: Int, option: Int) {
        let indexPath = IndexPath(row: option, section: section)
        if let cell = settingsTableView.cellForRow(at: indexPath) as? SettingsTableCell {
            cell.textField.becomeFirstResponder()
        }
    }
    
    private func setOptionValue(section: Int, option: Int, value: Bool) {
        let indexPath = IndexPath(row: option, section: section)
        if let cell = settingsTableView.cellForRow(at: indexPath) as? SettingsTableCell {
            self.setOptionValue(cell: cell, value: value)
        }
    }
    
    private func setOptionValue(cell: SettingsTableCell, value: Bool) {
        cell.toggleSwitch?.isOn = value
        cell.segmentedControl?.selectedSegmentIndex = (value ? 1 : 0)
    }
      
    private func setOptionValue(section: Int, option: Int, value: String) {
        let indexPath = IndexPath(row: option, section: section)
        if let cell = settingsTableView.cellForRow(at: indexPath) as? SettingsTableCell {
            cell.textField?.text = value
        }
    }

    private func setOptionValue(section: Int, option: Int, value: Int) {
        let indexPath = IndexPath(row: option, section: section)
        if let cell = settingsTableView.cellForRow(at: indexPath) as? SettingsTableCell {
            cell.slider?.value = Float(value)
            cell.sliderValue?.text = "\(value)"
        }
    }
    
    private func setSectionValue(section: Int, value: Bool) {
        if let view = self.settingsTableView.headerView(forSection: section) as! SettingsHeaderFooterView? {
            view.cell.toggleSwitch?.isOn = value
        }
    }
    
    private func setSectionEnabled(section: Int, enabled: Bool) {
        if let view = self.settingsTableView.headerView(forSection: section) as? SettingsHeaderFooterView {
            view.cell.label?.alpha = (enabled ? 1.0 : 0.3)
            view.cell.toggleSwitch?.isEnabled = enabled
            view.cell.toggleSwitch?.alpha = (enabled ? 1.0 : 0.3)
        }
    }
    
    private func getTrumpSuitCollectionView() -> UICollectionView? {
        var collection: UICollectionView?
        let indexPath = IndexPath(row: InGameOptions.trumpSequenceSuits.rawValue, section: Sections.inGame.rawValue)
        if let cell = settingsTableView.cellForRow(at: indexPath) as? SettingsTableCell {
            collection = cell.trumpSequenceCollectionView
        }
        return collection
    }

    private func getCardsInHandBounceSegmentedControl() -> UISegmentedControl? {
        var segmentedControl: UISegmentedControl?
        let indexPath = IndexPath(row: InGameOptions.cardsInHandBounce.rawValue, section: Sections.inGame.rawValue)
        if let cell = settingsTableView.cellForRow(at: indexPath) as? SettingsTableCell {
            segmentedControl = cell.segmentedControl
        }
        return segmentedControl
    }
    
    private func clearReceiveNotifications() {
        self.setOptionValue(section: Sections.sync.rawValue, option: SyncOptions.receiveNotifications.rawValue, value: false)
        Scorecard.shared.settings.receiveNotifications = false
        // Save 'receive notifications'
        UserDefaults.standard.set(false, forKey: "receiveNotifications")
        // Delete subscriptions
        Notifications.updateHighScoreSubscriptions()
    }
    
    func clearAlerts() {
        // Reset Alert Vibrate
        self.setOptionValue(section: Sections.sync.rawValue, option: SyncOptions.vibrateAlert.rawValue, value: false)
        Scorecard.shared.settings.alertVibrate = false
        UserDefaults.standard.set(Scorecard.shared.settings.alertVibrate, forKey: "alertVibrate")
    }
    
    func enableOnline() {
        // Enable online player details
        self.setSectionEnabled(section: Sections.sync.rawValue, enabled: true)
        // Enable Facetime calls switch
        self.setOptionEnabled(section: Sections.sync.rawValue, option: SyncOptions.facetimeCalls.rawValue, enabled: true)
        // Enable (and default on alerts
        self.enableAlerts(switchOn: true)
    }
    
    func clearOnline() {
        if Scorecard.shared.settings.onlinePlayerEmail != nil {
            Scorecard.shared.settings.onlinePlayerEmail = nil
            self.onlineEnabled = false
            UserDefaults.standard.set(nil, forKey: "onlinePlayerEmail")
            self.refreshOnlinePlayer()
            // Delete Facetime address
            self.facetimeEnabled = false
            Scorecard.shared.settings.faceTimeAddress = ""
            UserDefaults.standard.set(nil, forKey: "facetimeAddress")
            self.setOptionValue(section: Sections.sync.rawValue, option: SyncOptions.facetimeCalls.rawValue, value: false)
            self.setOptionEnabled(section: Sections.sync.rawValue, option: SyncOptions.facetimeCalls.rawValue, enabled: false)
            self.setOptionValue(section: Sections.sync.rawValue, option: SyncOptions.facetimeAddress.rawValue, value: "")
            self.refreshFaceTimeAddress()
            // Update cell
            self.displayOnlineCell(inProgress: "Disabling")
            // Delete subscriptions
            self.updateOnlineGameSubscriptions()
            // Disable alerts
            self.clearAlerts()
        }
        self.setSectionValue(section: Sections.sync.rawValue, value: false)
    }
    
    func clearSharing() {
        if Scorecard.shared.settings.allowBroadcast {
            self.setOptionValue(section: Sections.sync.rawValue, option: SyncOptions.shareScorecard.rawValue, value: false)
            Scorecard.shared.settings.allowBroadcast = false
            UserDefaults.standard.set(false, forKey: "allowBroadcast")
            Scorecard.shared.stopSharing()
        }
    }
    
    func setHistory() {
        if !Scorecard.shared.settings.saveHistory {
            self.setSectionValue(section: Sections.saveHistory.rawValue, value: false)
            self.setSectionEnabled(section: Sections.saveHistory.rawValue, enabled: false)
            Scorecard.shared.settings.saveHistory = true
            UserDefaults.standard.set(false, forKey: "saveHistory")
            self.setOptionValue(section: Sections.saveHistory.rawValue, option: SaveHistoryOptions.saveGameLocation.rawValue, value: false)
            self.setOptionEnabled(section: Sections.saveHistory.rawValue, option: SaveHistoryOptions.saveGameLocation.rawValue, enabled: false)
            UserDefaults.standard.set(false, forKey: "saveLocation")
        }
    }
    
    func setSharing() {
        if !Scorecard.shared.settings.allowBroadcast {
            self.setOptionValue(section: Sections.sync.rawValue, option: SyncOptions.shareScorecard.rawValue, value: true)
            Scorecard.shared.settings.allowBroadcast = true
            UserDefaults.standard.set(true, forKey: "allowBroadcast")
            Scorecard.shared.resetSharing()
        }
    }
    
    // MARK: - Online game methods ========================================================== -
    
    func displayOnlineCell(cell: SettingsTableCell? = nil, inProgress: String? = nil, reload: Bool = true) {
        let previousOnlineEnabled = self.onlineEnabled
        self.onlineEnabled = false
        
            if let onlinePlayerEmail = Scorecard.shared.settings.onlinePlayerEmail {
                self.onlineEnabled = true
                if let cell = cell ?? (settingsTableView.headerView(forSection: Sections.sync.rawValue) as? SettingsHeaderFooterView)?.cell {
                    if inProgress != nil {
                        // Still enabling - just put up message
                        cell.onlinePlayerThumbnail.isHidden = true
                        cell.onlinePlayerButton.isHidden = true
                        cell.onlinePlayerNameLabel.text = inProgress!
                    } else {
                        // Player enabled
                        if let playerMO = Scorecard.shared.findPlayerByEmail(onlinePlayerEmail) {
                            cell.onlinePlayerNameLabel?.text = "as \(playerMO.name!)"
                            cell.onlinePlayerButton.isHidden = false
                            cell.onlinePlayerThumbnail.isHidden = false
                            cell.onlinePlayerThumbnail.set(data: playerMO.thumbnail, initials: playerMO.name, nameHeight: 0.0, diameter: self.rowHeight - 8.0)
                            self.enableOnline()
                        } else {
                            self.clearOnline()
                        }
                    }
                }
            }
        if self.onlineEnabled != previousOnlineEnabled {
            // Refresh TODO
        }
    }
            
    private func identifyOnlinePlayer() {
        let thisPlayer = Scorecard.shared.settings.onlinePlayerEmail
        _ = SelectionViewController.show(from: self, mode: .single, thisPlayer: thisPlayer, showThisPlayerName: true, formTitle: "Select Player", backText: "", backImage: "back", bannerColor: Palette.banner, completion: self.identifyPlayerCompletion)
    }
    
    private func saveOnlineEmailLocally(playerEmail: String!) {
        // Save the setting and update screen
        Scorecard.shared.settings.onlinePlayerEmail = playerEmail
        Utility.mainThread {
            UserDefaults.standard.set(playerEmail, forKey: "onlinePlayerEmail")
            self.displayOnlineCell()
            self.updateOnlineGameSubscriptions()
        }
    }
    
    private func updateOnlineGameSubscriptions() {
        if self.onlineEnabled {
            Notifications.addOnlineGameSubscription(Scorecard.shared.settings.onlinePlayerEmail, completion: {
                Utility.mainThread { [unowned self] in
                    self.displayOnlineCell()
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
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: ScorecardViewController, backText: String = "Back", backImage: String = "back", completion: (()->())?){
        
        let storyboard = UIStoryboard(name: "SettingsViewController", bundle: nil)
        let settingsViewController: SettingsViewController = storyboard.instantiateViewController(withIdentifier: "SettingsViewController") as! SettingsViewController
        
        settingsViewController.preferredContentSize = CGSize(width: 400, height: 700)
        settingsViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        settingsViewController.backText = backText
        settingsViewController.backImage = backImage
        settingsViewController.completion = completion
        
        viewController.present(settingsViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: {
            self.didDismiss()
        })
    }
    
    override internal func didDismiss() {
        self.completion?()
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class SettingsTableCell: UITableViewCell {
      
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setEnabled(enabled: true)
    }
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ collectionView: UICollectionView, _ dataSourceDelegate: D, forRow row: Int) {
        
        collectionView.delegate = dataSourceDelegate
        collectionView.dataSource = dataSourceDelegate
        collectionView.reloadData()
    }
    
    @IBOutlet fileprivate weak var separator: UIView!
    @IBOutlet fileprivate weak var label: UILabel!
    @IBOutlet fileprivate weak var toggleSwitch: UISwitch!
    @IBOutlet fileprivate weak var labelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var subHeadingLabel: UILabel!
    @IBOutlet fileprivate weak var editLabel: UILabel!
    @IBOutlet fileprivate weak var editButton: AngledButton!
    @IBOutlet fileprivate weak var segmentedControl: UISegmentedControl!
    @IBOutlet fileprivate weak var slider: UISlider!
    @IBOutlet fileprivate weak var sliderLabel: UILabel!
    @IBOutlet fileprivate weak var sliderValue: UITextField!
    @IBOutlet fileprivate weak var textField: UITextField!
    @IBOutlet fileprivate weak var collapseButton: UIButton!
    @IBOutlet fileprivate weak var colorThemeCollectionView: UICollectionView!
    @IBOutlet fileprivate weak var onlinePlayerThumbnail: ThumbnailView!
    @IBOutlet fileprivate weak var onlinePlayerNameLabel: UILabel!
    @IBOutlet fileprivate weak var onlinePlayerButton: AngledButton!
    @IBOutlet fileprivate weak var trumpSequenceCollectionView: UICollectionView!
    @IBOutlet fileprivate weak var infoLabel: UILabel!
    @IBOutlet fileprivate weak var infoValue1: UILabel!
    @IBOutlet fileprivate weak var infoValue2: UILabel!
    @IBOutlet fileprivate weak var infoValue3: UILabel!
    
    public func resizeSwitch(_ factor: CGFloat) {
        self.toggleSwitch.transform = CGAffineTransform(scaleX: factor, y: factor)
    }
    
    public func setEnabled(enabled: Bool) {
        if self.reuseIdentifier?.prefix(6) == "Header" {
            self.label?.alpha = 1.0
        } else {
            self.label?.alpha = (enabled ? 1.0 : 0.3)
        }
        self.toggleSwitch?.isEnabled = enabled
        self.toggleSwitch?.alpha = (enabled ? 1.0 : 0.3)
        self.editLabel?.alpha = (enabled ? 1.0 : 0.3)
        self.setEnabled(button: self.editButton, enabled: enabled)
        self.onlinePlayerNameLabel?.alpha = (enabled ? 1.0 : 0.3)
        self.onlinePlayerThumbnail?.alpha = (enabled ? 1.0 : 0.3)
        self.setEnabled(button: self.onlinePlayerButton, enabled: enabled)
        self.segmentedControl?.isEnabled = enabled
        self.segmentedControl?.alpha = (enabled ? 1.0 : 0.3)
        self.slider?.isEnabled = enabled
        self.slider?.alpha = (enabled ? 1.0 : 0.3)
        self.setEnabled(textField: self.textField, enabled: enabled)
        self.trumpSequenceCollectionView?.isUserInteractionEnabled = enabled
        self.trumpSequenceCollectionView?.alpha = (enabled ? 1.0 : 0.5)
    }
    
    private func setEnabled(button: UIButton?, enabled: Bool) {
        button?.isEnabled = enabled
        button?.alpha = (enabled ? 1.0 : 0.3)
    }
    
    private func setEnabled(textField: UITextField?, enabled: Bool) {
        textField?.isEnabled = enabled
        textField?.layer.borderWidth = (enabled ? 1.0 : 0.3)
        textField?.layer.cornerRadius = (enabled ? 5.0 : 0.0)
    }
    
    override func prepareForReuse() {
        self.setEnabled(enabled: true)
        self.toggleSwitch?.removeTarget(nil, action: nil, for: .allEvents)
        self.editButton?.removeTarget(nil, action: nil, for: .allEvents)
        self.onlinePlayerButton?.removeTarget(nil, action: nil, for: .allEvents)
        self.segmentedControl?.removeTarget(nil, action: nil, for: .allEvents)
        self.slider?.removeTarget(nil, action: nil, for: .allEvents)
        self.textField?.removeTarget(nil, action: nil, for: .allEvents)
    }
}

class SettingsHeaderFooterView: UITableViewHeaderFooterView {
   
    fileprivate var cell: SettingsTableCell!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    convenience init?(_ cell: SettingsTableCell, reuseIdentifier: String? = nil) {
        let frame = CGRect(origin: CGPoint(), size: cell.frame.size)
        self.init(reuseIdentifier: reuseIdentifier)
        cell.frame = frame
        self.cell = cell
        self.addSubview(cell)
    }
    
    override func layoutSubviews() {
        let frame = CGRect(origin: CGPoint(), size: self.frame.size)
        cell.frame = frame
    }
    
}

class TrumpCollectionCell : UICollectionViewCell {
    @IBOutlet fileprivate weak var trumpSuitLabel: UILabel!
}

class ColorThemeCollectionCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var nameLabel: UILabel!
    @IBOutlet fileprivate weak var sample: SampleTheme!
}

extension SettingsViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.bannerPaddingView.backgroundColor = Palette.banner
        self.navigationBar.backgroundColor = Palette.banner
        self.navigationBar.textColor = Palette.bannerText
        self.view.backgroundColor = Palette.background
    }

    private func defaultCellColors(cell: SettingsTableCell) {
        switch cell.reuseIdentifier {
        case "Edit Button":
            cell.editButton.setTitleColor(Palette.textEmphasised, for: .normal)
            cell.editButton.fillColor = Palette.background
            cell.editButton.strokeColor = Palette.emphasis
            cell.editLabel.textColor = Palette.text
        case "Header Collapse":
            cell.collapseButton.tintColor = Palette.emphasis
            cell.collapseButton.setTitleColor(Palette.textEmphasised, for: .normal)
            cell.label.textColor = Palette.textEmphasised
            cell.separator.backgroundColor = Palette.disabled
        case "Header Switch":
            cell.label.textColor = Palette.textEmphasised
            cell.separator.backgroundColor = Palette.disabled
            cell.toggleSwitch.tintColor = Palette.emphasis
            cell.toggleSwitch.onTintColor = Palette.emphasis
        case "Info Single":
            cell.infoLabel.textColor = Palette.text
            cell.infoValue1.textColor = Palette.text
        case "Info Three":
            cell.infoLabel.textColor = Palette.text
            cell.infoValue1.textColor = Palette.text
            cell.infoValue2.textColor = Palette.text
            cell.infoValue3.textColor = Palette.text
        case "Info Three Heading":
            cell.infoLabel.textColor = Palette.text
            cell.infoValue1.textColor = Palette.text
            cell.infoValue2.textColor = Palette.text
            cell.infoValue3.textColor = Palette.text
        case "Online Player":
            cell.onlinePlayerButton.setTitleColor(Palette.textEmphasised, for: .normal)
            cell.onlinePlayerButton.fillColor = Palette.background
            cell.onlinePlayerButton.strokeColor = Palette.emphasis
            cell.onlinePlayerNameLabel.textColor = Palette.text
        case "Slider":
            cell.slider.minimumTrackTintColor = Palette.segmentedControls
            cell.slider.thumbTintColor = Palette.segmentedControls
            cell.sliderLabel.textColor = Palette.text
            cell.sliderValue.textColor = Palette.inputControlText
        case "Segmented":
            cell.segmentedControl.draw(cell.segmentedControl.frame)
        case "Sub Heading":
            cell.subHeadingLabel.textColor = Palette.text
        case "Switch":
            cell.label.textColor = Palette.text
            cell.toggleSwitch.tintColor = Palette.emphasis
            cell.toggleSwitch.onTintColor = Palette.emphasis
        case "Text Field":
            cell.textField.backgroundColor = Palette.background
            cell.textField.textColor = Palette.text
        default:
            break
        }
    }

    private func defaultCellColors(cell: UICollectionViewCell) {
        switch cell.reuseIdentifier {
        case "Header Collapse":
            cell.backgroundColor = Palette.background
        case "Header Switch":
            cell.backgroundColor = Palette.background
        default:
            break
        }
    }

}
