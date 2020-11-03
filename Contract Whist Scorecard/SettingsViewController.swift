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


class SettingsViewController: ScorecardViewController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, CustomCollectionViewLayoutDelegate, PlayerSelectionViewDelegate, BannerDelegate {
    
    // MARK: - Class Properties ======================================================================== -
        
    // Properties to pass state
    private var backText = "Back"
    private var backImage = "back"
    private var completion: (()->())?
    
    // Other properties
    private var testMode = false
    private var dataInfoExpanded = false
    private var trumpSequenceEdit = false
    private var onlineEnabled = false
    private var facetimeEnabled = false
    private var rowHeight: CGFloat = 35.0
    private var infoHeight: CGFloat = 20.0
    private var reload = false
    private var notificationsRefused = false
    private var location = Location()
    private var useLocation: Bool?
    private var themeNames: [ThemeName] = ThemeName.allCases
    private var currentThemeIndex = 0
    private var themesDisplayed: CGFloat = 5.0 // Must be odd
    private var themesCount: Int = 0
    private var themesBottomLimit: Int = 0
    private var themesTopLimit: Int = 0
    private var firstTime: Bool = true
    private var playerSelectionHeight: CGFloat = 0.0
    private var thisPlayerHeight: CGFloat = 0.0
    private var lastMenuVisible: Bool?
    
    // Sections
    private enum Sections: Int, CaseIterable {
        case onlineGames = 0
        case theme = 1
        case inGame = 2
        case displayStatus = 3
        case generalInfo = 4
        case dataInfo = 5
    }
    
    // Options
    
     private enum OnlineGameOptions : Int, CaseIterable {
        case vibrateAlert = 0
        case facetimeCalls = 1
        case facetimeAddress = 2
        case shareScorecard = 3
        case receiveNotifications = 4
        case saveGameLocation = 5
    }
    
    private enum ThemeOptions : Int, CaseIterable {
        case colorTheme = 1
        case appearance = 0
    }
    
    private enum InGameOptions : Int, CaseIterable {
        case confettiWin = 0
        case cardsInHandSubheading = 1
        case cardsInHandStart = 2
        case cardsInHandEnd = 3
        case cardsInHandBounce = 4
        case spacer1 = 5
        case bonus2Subheading = 6
        case bonus2 = 7
        case spacer2 = 8
        case includeNoTrump = 9
        case trumpSequenceEdit = 10
        case trumpSequenceSuits = 11
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
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var settingsTableView: UITableView!
    @IBOutlet private weak var thisPlayerContainerView: UIView!
    @IBOutlet private weak var thisPlayerThumbnailView: ThumbnailView!
    @IBOutlet private weak var thisPlayerChangeButton: RoundedButton!
    @IBOutlet private weak var thisPlayerChangeButtonContainer: UIView!
    @IBOutlet private weak var playerSelectionView: PlayerSelectionView!
    @IBOutlet private weak var tapGestureRecognizer: UITapGestureRecognizer!
    @IBOutlet private weak var topSectionView: UIView!
    @IBOutlet private weak var playerSelectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var topSectionHeightConstraint: NSLayoutConstraint!               // Need to be strong as are deactivated
    @IBOutlet private var availableSpaceHeightConstraint: NSLayoutConstraint!           // Need to be strong as are deactivated
    @IBOutlet private var topSectionProportionalHeightConstraint: NSLayoutConstraint!   // Need to be strong as are deactivated
    @IBOutlet private var topSectionLandscapePhoneProportionalHeightConstraint: NSLayoutConstraint!   // Need to be strong as are deactivated


    // MARK: - IB Actions ============================================================================== -
    
    internal func finishPressed() {
        self.dismiss()
    }
    
    @IBAction func helpPressed(_ sender: Any) {
        self.helpPressed()
    }
    
    @IBAction private func tapGesture(recognizer: UITapGestureRecognizer) {
        self.thisPlayerChangePressed(self.thisPlayerChangeButton)
    }
       
    // MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()
        
        if let testModeValue = ProcessInfo.processInfo.environment["TEST_MODE"] {
            if testModeValue.lowercased() == "true" {
                testMode = true
            }
        }
        
        self.onlineEnabled = Scorecard.settings.syncEnabled && Scorecard.settings.onlineGamesEnabled
        self.facetimeEnabled = Scorecard.settings.syncEnabled && Scorecard.settings.onlineGamesEnabled && Scorecard.settings.faceTimeAddress != ""
        
        // Set observer for entering foreground
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            
        // Setup color themes
        self.setupThemes()
        
        // Setup help
        self.setupHelpView()

        // Setup banner
        self.setupBanner()

        self.checkReceiveNotifications()
        
        
        if Scorecard.settings.saveLocation {
            self.checkUseLocation(message: "You have blocked access to the current location for this app. Therefore the save location setting has been reset. To change this please allow location access 'While Using the App' in the Whist section of the main Settings App", prompt: false)
        }
    }
    
    @objc internal func willEnterForeground() {
        // Check if can receive notifications and switch off options dependent on it if not available
        self.checkReceiveNotifications()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.reload = true
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.setupPanelModeBannerSize()
        
        if reload {
            self.settingsTableView.reloadData()
        }
        self.reload = false
        if firstTime {
            self.setupThisPlayerView()
            self.firstTime = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.showSettingsNotifications()
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Sections.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if let section = Sections(rawValue: section) {
            switch section {
            case .onlineGames:
                return (Scorecard.shared.playerList.count == 0 ? 0 : OnlineGameOptions.allCases.count)
                
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
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0.0
        
        if let section = Sections(rawValue: indexPath.section) {
            switch section {
            case .onlineGames:
                if let option = OnlineGameOptions(rawValue: indexPath.row) {
                    switch option {
                    case .facetimeCalls:
                        height = 0 // TODO reinstate
                    case .facetimeAddress:
                        height = 0 // TODO reinstate (facetimeEnabled ? self.rowHeight : 0.0)
                    default:
                        height =  self.rowHeight
                    }
                }
                
            case .inGame:
                if let option = InGameOptions(rawValue: indexPath.row) {
                    switch option {
                    case .confettiWin:
                        height = (Scorecard.settings.confettiWinSettingState != .notAvailable ? self.rowHeight : 0)
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
                        height = 100.0
                    case .appearance:
                        height = 50.0
                    }
                }
                
            case .generalInfo:
                height = self.infoHeight
                
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
        var header: SettingsHeaderFooterView?
        
        if let section = Sections(rawValue: section) {
            switch section {
            case .onlineGames:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Switch") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                header = SettingsHeaderFooterView(cell)
                cell.label.text = "Enable online games"
                cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.onlineGamesChanged(_:)), for: .valueChanged)
                cell.toggleSwitch.isOn = Scorecard.settings.onlineGamesEnabled
                cell.setEnabled(enabled: Scorecard.settings.syncEnabled)
                cell.separator.isHidden = true
                
            case .theme:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Switch") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                header = SettingsHeaderFooterView(cell)
                cell.label.text = "Colour theme"
                cell.toggleSwitch.isHidden = true
                
            case .displayStatus:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Switch") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                header = SettingsHeaderFooterView(cell)
                cell.label.text = "Show Status Bar"
                cell.toggleSwitch.isHidden = false
                cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.displayStatusChanged(_:)), for: .valueChanged)
                cell.toggleSwitch.isOn = !Scorecard.settings.prefersStatusBarHidden
                
            case .inGame:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Switch") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                header = SettingsHeaderFooterView(cell)
                cell.label.text = "In Game"
                cell.toggleSwitch.isHidden = true
                
            case .generalInfo:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Switch") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                header = SettingsHeaderFooterView(cell)
                cell.toggleSwitch.isHidden = true
                cell.label.text = "About Whist"
                
            case .dataInfo:
                let cell = tableView.dequeueReusableCell(withIdentifier: "Header Collapse") as! SettingsTableCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                header = SettingsHeaderFooterView(cell)
                cell.collapseButton.setImage(UIImage(named: (dataInfoExpanded ? "arrow down" : "arrow right"))?.asTemplate(), for: .normal)
                cell.collapseButton.tintColor = Palette.emphasis.background
                
                cell.label.text = "Data"
                cell.collapseButton.addTarget(self, action: #selector(SettingsViewController.dataInfoClicked(_:)), for: .touchUpInside)
                
            }
        }
        
        return header
    }
    
    internal func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = Palette.normal.background
        return view
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: SettingsTableCell!
        
        if let section = Sections(rawValue: indexPath.section) {
            switch section {
            case .onlineGames:
                if let option = OnlineGameOptions(rawValue: indexPath.row) {
                    switch option {
                    case .vibrateAlert:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)

                        cell.resizeSwitch(0.75)
                        cell.label.text = "Vibrate when turn to play"
                        cell.labelLeadingConstraint.constant = 20
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.vibrateAlertChanged(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = Scorecard.settings.alertVibrate
                        self.enableAlerts(cell: cell)
                        
                    case .facetimeCalls:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Facetime calls in online games"
                        cell.labelLeadingConstraint.constant = 20
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.facetimeCallsClicked(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = self.facetimeEnabled
                        cell.setEnabled(enabled: Scorecard.settings.syncEnabled && Scorecard.settings.onlineGamesEnabled)
                        
                    case .facetimeAddress:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Text Field") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.textField.addTarget(self, action: #selector(SettingsViewController.facetimeAddressChanged(_:)), for: UIControl.Event.editingChanged)
                        cell.textField.addTarget(self, action: #selector(SettingsViewController.facetimeAddressEndEdit(_:)), for: UIControl.Event.editingDidEnd)
                        cell.textField.addTarget(self, action: #selector(SettingsViewController.facetimeAddressBeginEdit(_:)), for: UIControl.Event.editingDidBegin)
                        cell.textField.placeholder = "Enter FaceTime address"
                        cell.textField.text = Scorecard.settings.faceTimeAddress
                        cell.setEnabled(enabled: self.facetimeEnabled)
                        
                    case .shareScorecard:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Share scorecard"
                        cell.labelLeadingConstraint.constant = 20.0
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.shareScorecardChanged(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = Scorecard.settings.allowBroadcast
                        
                    case .receiveNotifications:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Receive game notifications"
                        cell.labelLeadingConstraint.constant = 20.0
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.receiveNotificationsChanged(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = Scorecard.settings.receiveNotifications
                        cell.setEnabled(enabled: Scorecard.settings.syncEnabled)
                    case .saveGameLocation:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Save game location"
                        cell.labelLeadingConstraint.constant = 20.0
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.saveGameLocationChanged(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = Scorecard.settings.saveLocation
                    }
                }
                                
            case .theme:
                if let option = ThemeOptions(rawValue: indexPath.row) {
                    switch option {
                    case .colorTheme:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Color Theme") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                    case .appearance:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Appearance") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        cell.appearanceButtons.forEach{(button) in
                            button.addTarget(self, action: #selector(SettingsViewController.appearanceButtonClicked(_:)), for: .touchUpInside)
                        }
                        self.setAppearanceButtons(cell)
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
                        cell.sliderValue.text = "\(Scorecard.settings.cards[index])"
                        cell.slider.value = Float(Scorecard.settings.cards[index])
                        
                    case .cardsInHandBounce:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Segmented") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        self.cardsChanged(bounceSegmentedControl: cell.segmentedControl)
                        cell.segmentedControl.addTarget(self, action: #selector(SettingsViewController.cardsInHandBounceChanged(_:)), for: .valueChanged)
                        cell.segmentedControl.selectedSegmentIndex = (Scorecard.settings.bounceNumberCards ? 1 : 0)
                        
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
                        cell.segmentedControl.selectedSegmentIndex = (Scorecard.settings.bonus2 ? 1 : 0)
                        
                    case .includeNoTrump:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Include No Trump (NT)"
                        cell.labelLeadingConstraint.constant = 20.0
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.includeNoTrumpChanged(_:)), for: .valueChanged)
                        let index = Scorecard.settings.trumpSequence.firstIndex(where: {$0 == "NT"})
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
                        
                    case .confettiWin:
                        cell = tableView.dequeueReusableCell(withIdentifier: "Switch") as? SettingsTableCell
                        
                        // Setup default colors (previously done in StoryBoard)
                        self.defaultCellColors(cell: cell)
                        
                        cell.resizeSwitch(0.75)
                        cell.label.text = "Confetti Storm if Win"
                        cell.labelLeadingConstraint.constant = 20.0
                        cell.toggleSwitch.addTarget(self, action: #selector(SettingsViewController.confettiWinChanged(_:)), for: .valueChanged)
                        cell.toggleSwitch.isOn = Scorecard.settings.confettiWin
                        
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
                    // Become delegate for custom flow layout
                    if let flowLayout = tableViewCell.flowLayout {
                        if flowLayout.delegate == nil {
                            // Configure flow and set initial value
                            flowLayout.delegate = self
                            tableViewCell.colorThemeCollectionView.scrollToItem(at: IndexPath(item: self.currentThemeIndex, section: 0), at: .centeredHorizontally, animated: true)
                            tableViewCell.colorThemeCollectionView.decelerationRate = UIScrollView.DecelerationRate.fast
                        }
                    }
                default:
                    break
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
            case .dataInfo:
                // Expand data info if touch any part of section
                self.dataInfoClicked()
            default:
                break
            }
        }
        return nil
    }
    
    internal func scrollViewDidScroll(_ tableView: UIScrollView) {
        // Configure collapsible header
        if !(self.menuController?.isVisible ?? false) { // Change player will be in menu panel otherwise
            if tableView == self.settingsTableView {
                if tableView.contentOffset.y > 10.0 && self.availableSpaceHeightConstraint.constant != 0.0 {
                    Utility.animate(view: self.view, duration: 0.3) {
                        self.topSectionLandscapePhoneProportionalHeightConstraint.isActive = false
                        self.topSectionProportionalHeightConstraint.isActive = false
                        self.availableSpaceHeightConstraint.constant = 0.0
                        self.thisPlayerThumbnailView.isHidden = true
                        self.thisPlayerChangeButtonContainer.isHidden = true
                        self.topSectionHeightConstraint.isActive = true
                     }
                } else if tableView.contentOffset.y < 10.0 && self.availableSpaceHeightConstraint.constant == 0.0 {
                    Utility.animate(view: self.view, duration: 0.3) {
                        self.topSectionHeightConstraint.isActive = false
                        self.availableSpaceHeightConstraint.constant = 140
                        self.thisPlayerThumbnailView.isHidden = false
                        self.thisPlayerChangeButtonContainer.isHidden = false
                        if ScorecardUI.landscapePhone() {
                            self.topSectionLandscapePhoneProportionalHeightConstraint.isActive = true
                        } else {
                            self.topSectionProportionalHeightConstraint.isActive = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Action functions from TableView Cells =========================================== -
    
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
            self.checkUseLocation(message: "You have previously refused permission for this app to use your location. To change this, please allow location access 'While Using the App' in the Whist section of the main Settings App", prompt: true)
        } else {
            // Switch it off
            self.setSaveGameLocation(value: false)
        }
    }
    
    @objc internal func shareScorecardChanged(_ shareScorecardSwitch: UISwitch) {
        Scorecard.settings.allowBroadcast = shareScorecardSwitch.isOn
    }
    
    @objc internal func thisPlayerChangePressed(_ button: UIButton) {
        if self.playerSelectionHeight == 0 {
            self.showPlayerSelection()
        } else {
            self.hidePlayerSelection()
        }
        Scorecard.settings.save()
    }
    
    
    @objc internal func onlineGamesChanged(_ onlineGamesSwitch: UISwitch) {
        self.onlineEnabled = onlineGamesSwitch.isOn
        if self.onlineEnabled {
            self.authoriseNotifications(message: "You have previously refused permission for this app to send you notifications. \nThis will mean that you will not receive game invitation notifications.\nTo change this, please authorise notifications in the Whist section of the main Settings App",
                successAction: {
                    self.enableOnline()
                    Scorecard.settings.save()
            },
                failureAction: {
                    self.enableOnline()
                    self.clearReceiveNotifications()
                    Scorecard.settings.save()
            })
        } else {
            self.clearOnline()
        }
    }
    
    @objc internal func vibrateAlertChanged(_ vibrateAlertSwitch: UISwitch) {
        Scorecard.settings.alertVibrate = vibrateAlertSwitch.isOn
    }

    @objc internal func facetimeCallsClicked(_ facetimeCallsSwitch: UISwitch) {
        
        self.facetimeEnabled = facetimeCallsSwitch.isOn
        
        if self.facetimeEnabled {
            // Enabled - edit address
            self.setOptionEnabled(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.facetimeAddress.rawValue, enabled: true)
        } else {
            // Disabled blank out address
            Scorecard.settings.faceTimeAddress = ""
            self.setOptionValue(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.facetimeCalls.rawValue, value: false)
            self.setOptionEnabled(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.facetimeAddress.rawValue, enabled: false)
        }
        
        self.refreshFaceTimeAddress()
        if self.facetimeEnabled {
            self.setOptionFirstResponder(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.facetimeAddress.rawValue)
        }
    }
    
    @objc internal func facetimeAddressChanged(_ facetimeAddressTextField: UITextField) {
        
        Scorecard.settings.faceTimeAddress = facetimeAddressTextField.text ?? ""
    }
    
    @objc internal func facetimeAddressBeginEdit(_ facetimeAddressTextField: UITextField) {
        facetimeAddressTextField.layer.borderColor = Palette.normal.text.cgColor
    }
    
    @objc internal func facetimeAddressEndEdit(_ facetimeAddressTextField: UITextField) {
        
        self.facetimeAddressChanged(facetimeAddressTextField)
        
        // If blank then unset facetime calls switch and disable address
        if Scorecard.settings.faceTimeAddress == "" {
            self.facetimeEnabled = false
            self.setOptionValue(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.facetimeCalls.rawValue, value: false)
            self.setOptionEnabled(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.facetimeAddress.rawValue, enabled: false)
            self.refreshFaceTimeAddress()
        }
        self.resignFirstResponder()
        facetimeAddressTextField.layer.borderColor = Palette.emphasis.background.cgColor
    }
     
    @objc internal func receiveNotificationsChanged(_ receiveNotificationsSwitch: UISwitch) {
        if receiveNotificationsSwitch.isOn {
            Scorecard.settings.receiveNotifications = true
            authoriseNotifications(message: "You have previously refused permission for this app to send you notifications. \nThis will mean that you will not receive game completion notifications.\nTo change this, please authorise notifications in the Whist section of the main Settings App",
                successAction: {
                    Notifications.updateHighScoreSubscriptions()
                },
                failureAction: {
                    self.clearReceiveNotifications()
                })
        } else {
            self.clearReceiveNotifications()
        }
        Scorecard.settings.save()
    }
    
    @objc internal func cardsSliderChanged(_ cardsSlider: UISlider) {
        let index = cardsSlider.tag
        let option = (index == 0 ? InGameOptions.cardsInHandStart : InGameOptions.cardsInHandEnd)
        Scorecard.settings.cards[index] = Int(cardsSlider.value)
        self.setOptionValue(section: Sections.inGame.rawValue, option: option.rawValue, value: Scorecard.settings.cards[index])
        self.cardsChanged()
    }
    
    @objc func cardsInHandBounceChanged(_ cardsInHandBounceSegmentedControl: UISegmentedControl) {
        
        Scorecard.settings.bounceNumberCards = (cardsInHandBounceSegmentedControl.selectedSegmentIndex == 1)
        self.cardsChanged()
    }

    @objc internal func bonus2Changed(_ bonus2SegmentedControl: UISegmentedControl) {
        
        Scorecard.settings.bonus2 = (bonus2SegmentedControl.selectedSegmentIndex == 1)
    }
    
    @objc func includeNoTrumpChanged(_ includeNoTrumpSwitch: UISwitch) {
        if includeNoTrumpSwitch.isOn {
            // Add NT
            if Scorecard.settings.trumpSequence.firstIndex(where: {$0 == "NT"}) == nil {
                Scorecard.settings.trumpSequence.append("NT")
            }
        } else {
            // Remove NT
            if let index = Scorecard.settings.trumpSequence.firstIndex(where: {$0 == "NT"}) {
                Scorecard.settings.trumpSequence.remove(at: index)
            }
        }
        self.refreshTrumpSequence()
    }
    
    @objc func trumpSequenceEditClicked(_ trumpSequenceEditButton: UIButton) {
        if trumpSequenceEdit {
            // Leaving edit mode - save it
            self.refreshTrumpSequence()
            
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
        Scorecard.settings.prefersStatusBarHidden = !displayStatusSwitch.isOn

        // Update status bar
        Scorecard.shared.updatePrefersStatusBarHidden(from: self)
    }
    
    @objc internal func appearanceButtonClicked(_ appearanceButton: ClearButton) {
        Scorecard.settings.appearance = ThemeAppearance(rawValue: appearanceButton.tag)!
        self.setAppearanceButtons()
        self.view.window?.overrideUserInterfaceStyle = Scorecard.settings.appearance.userInterfaceStyle
    }
    
    private func setAppearanceButtons(_ cell: SettingsTableCell? = nil) {
        if let cell = cell ?? self.settingsTableView.cellForRow(at: IndexPath(row: ThemeOptions.appearance.rawValue, section: Sections.theme.rawValue)) as? SettingsTableCell {
            cell.appearanceButtons.forEach{(button) in
                if button.tag == Scorecard.settings.appearance.rawValue {
                    button.setImage(UIImage(named: "box tick"), for: .normal)
                    button.tintColor = Palette.segmentedControls.background
                } else {
                    button.setImage(UIImage(named: "box"), for: .normal)
                    button.tintColor = Palette.normal.text
                }
                button.tintColorDidChange()
            }
        }
    }
    
    @objc internal func confettiWinChanged(_ confettiWinSwitch: UISwitch) {
        Scorecard.settings.confettiWin = confettiWinSwitch.isOn
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        switch SettingsCollectionViews(rawValue: collectionView.tag) {
        case .trumpSuit:
            return Scorecard.settings.trumpSequence.count
        case .colorTheme:
            return self.themeNames.count
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
            
            cell.trumpSuitLabel.attributedText = Suit(fromString: Scorecard.settings.trumpSequence[indexPath.row]).toAttributedString(font: UIFont.systemFont(ofSize: 36.0), noTrumpScale: 0.8)
            if self.trumpSequenceEdit {
                self.startCellWiggle(cell: cell)
            }
            
            return cell
            
        case .colorTheme:
            var cell: ColorThemeCollectionCell
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Color Theme Cell", for: indexPath) as! ColorThemeCollectionCell
            
            let theme = Theme(themeName: themeNames[indexPath.item])
            cell.nameLabel.text = themeNames[indexPath.item].description
            cell.nameLabel.textColor = Palette.normal.text  // theme.color(.banner, .current)
            cell.sample.setColors(theme: theme)
            cell.sample.isHidden = false
            
            if indexPath.row == Int(self.themesCount / 2) {
                collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
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
            let selectedSuit = Scorecard.settings.trumpSequence[sourceIndexPath.row]
            Scorecard.settings.trumpSequence.remove(at: sourceIndexPath.row)
            Scorecard.settings.trumpSequence.insert(selectedSuit, at: destinationIndexPath.row)
            
        default:
            break
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch SettingsCollectionViews(rawValue: collectionView.tag) {
        case .colorTheme:
            return true
        default:
            return false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch SettingsCollectionViews(rawValue: collectionView.tag) {
        case .colorTheme:
            self.changed(collectionView, itemAtCenter: indexPath.item, forceScroll: true)
        default:
            break
        }
    }
    
    internal func changed(_ collectionView: UICollectionView, itemAtCenter: Int, forceScroll: Bool) {
        Utility.mainThread {
            if itemAtCenter != self.currentThemeIndex {
                // Rotate cells to give infinite feeling
                if itemAtCenter > self.currentThemeIndex && itemAtCenter >=  self.themesTopLimit {
                    self.currentThemeIndex =  itemAtCenter - (self.themesCount * 2)
                } else if itemAtCenter < self.currentThemeIndex && itemAtCenter <= self.themesBottomLimit {
                    self.currentThemeIndex = itemAtCenter + (self.themesCount * 2)
                } else {
                    self.currentThemeIndex = itemAtCenter
                }
                if forceScroll {
                    collectionView.scrollToItem(at: IndexPath(item: itemAtCenter, section: 0), at: .centeredHorizontally, animated: true)
                }
                Utility.executeAfter(delay: forceScroll ? 0.3 : 0.0) {
                    if self.currentThemeIndex != itemAtCenter {
                        collectionView.scrollToItem(at: IndexPath(item: self.currentThemeIndex, section: 0), at: .centeredHorizontally, animated: false)
                    }
                }
                self.selectColorTheme(item: self.currentThemeIndex)
            }
        }
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
    
    // MARK: - Player Selection View Delegate Handlers ======================================================= -
    
    private func setupThisPlayerView() {
        self.thisPlayerChangeButton.roundCorners(cornerRadius: self.thisPlayerChangeButton.frame.height / 2.0)
        self.thisPlayerChangeButtonContainer.addShadow(shadowSize: CGSize(width: 4,height: 4))
         
        self.setOnlinePlayerUUID(playerUUID: Scorecard.settings.thisPlayerUUID)
         
        self.thisPlayerChangeButton.addTarget(self, action: #selector(SettingsViewController.thisPlayerChangePressed(_:)), for: .touchUpInside)

        self.thisPlayerChangeButton.setTitle("Change")
        
        self.thisPlayerHeight = self.thisPlayerContainerView.frame.height
        
        self.playerSelectionViewHeightConstraint.constant = 0.0
        self.playerSelectionView.set(addButtonColor: Palette.alwaysTheme.background)

    }
    
    private func showPlayerSelection() {
        Utility.animate(view: self.view, duration: 0.5) {
            let selectionHeight = self.playerSelectionView.getHeightFor(items: Scorecard.shared.playerList.count)
            self.playerSelectionHeight = min(selectionHeight, self.view.frame.height - self.playerSelectionView.frame.minY + self.view.safeAreaInsets.bottom)
            self.playerSelectionView.set(size: CGSize(width: UIScreen.main.bounds.width, height: self.playerSelectionHeight))
            self.playerSelectionViewHeightConstraint.constant = self.playerSelectionHeight
            self.thisPlayerChangeButton.setTitle("Cancel")
            self.settingsTableView.isScrollEnabled = false
            self.disableAll()
        }
        
        let playerList = Scorecard.shared.playerList.filter { $0.playerUUID != Scorecard.settings.thisPlayerUUID }
        self.playerSelectionView.set(players: playerList, addButton: true, updateBeforeSelect: false, scrollEnabled: true, collectionViewInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
     }
    
    private func hidePlayerSelection() {
        Utility.animate(view: self.view, duration: 0.5) {
            self.playerSelectionHeight = 0.0
            self.playerSelectionViewHeightConstraint.constant = 0.0
        }
        self.settingsTableView.isScrollEnabled = true
        self.thisPlayerChangeButton.setTitle("Change")
        self.settingsTableView.reloadData()
    }
        
    internal func didSelect(playerMO: PlayerMO) {
        // Save player as default for device
        self.setOnlinePlayerUUID(playerUUID: playerMO.playerUUID)
        self.hidePlayerSelection()
    }
    
    internal func resizeView() {
        // Additional players added - resize the view
        self.showPlayerSelection()
    }
        
    // MARK: - Form Presentation / Handling Routines =================================================== -

    private func enableAlerts(cell: SettingsTableCell? = nil, switchOn: Bool = false) {
        if let cell = cell {
            cell.setEnabled(enabled: self.onlineEnabled)
        } else {
            self.setOptionEnabled(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.vibrateAlert.rawValue, enabled: self.onlineEnabled)
        }
        if switchOn {
            Scorecard.settings.alertVibrate = true
            if let cell = cell {
                self.setOptionValue(cell: cell, value: true)
            } else {
                self.setOptionValue(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.vibrateAlert.rawValue, value: true)
            }
        }
    }
    
    private func cardsChanged(bounceSegmentedControl: UISegmentedControl? = nil) {
        if let bounceSegmentedControl = bounceSegmentedControl ?? self.getCardsInHandBounceSegmentedControl() {
            let cards = Scorecard.settings.cards
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
    
    private func refreshFaceTimeAddress() {
        // Reload row as height might have changed
        let indexPath = IndexPath(row: OnlineGameOptions.facetimeAddress.rawValue, section: Sections.onlineGames.rawValue)
        self.settingsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    private func scrollToBottom() {
        let sections = self.numberOfSections(in: self.settingsTableView)
        let options = self.tableView(self.settingsTableView, numberOfRowsInSection: sections - 1)
        self.settingsTableView.scrollToRow(at: IndexPath(row: options - 1, section: sections - 1), at: .bottom, animated: true)
    }
    
    private func startWiggle() {
        if let collection = self.getTrumpSuitCollectionView() {
            let numberSuits = Scorecard.settings.trumpSequence.count
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
            let numberSuits = Scorecard.settings.trumpSequence.count
            for item in 0..<numberSuits {
                if let cell = collection.cellForItem(at: IndexPath(item: item, section: 0)) {
                    cell.layer.removeAllAnimations()
                }
            }
        }
    }
    
    private func disableAll(exceptSection: Int? = nil, exceptOptions: Int...) {
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
    
    private func forEachOption(exceptSection: Int?, exceptOptions: [Int], action: (Int, Int)->()) {
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
    
    // MARK: - Location permissions============================================================= -
        
    private func checkUseLocation(message: String, prompt: Bool) {
        self.location.checkUseLocation(
            refused: { (requested) in
                self.useLocation = false
                if !requested {
                    self.alertMessage(message, title: "Warning")
                }
                self.setSaveGameLocation(value: false)
            },
            accepted: {
                self.useLocation = true
                self.setSaveGameLocation(value: true)
            },
            unknown: {
                self.useLocation = nil
            },
            request: prompt)
    }
    
    private func setSaveGameLocation(value: Bool) {
        Scorecard.settings.saveLocation = value
        self.setOptionValue(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.saveGameLocation.rawValue, value: value)
    }

    
    // MARK: - Theme routines ========================================================================== -
    
    private func setupThemes() {
                
        // Sort themes
        self.themeNames.sort(by: {$0.description < $1.description})
        
        // Move current value to middle
        self.themesCount = self.themeNames.count
        let currentTheme = self.themeNames.firstIndex(where: {$0 == Scorecard.settings.colorTheme}) ?? 0
        let middleTheme = Int(self.themesCount / 2)
        let shift = middleTheme - currentTheme
        self.themeNames.rotate(by: shift)
        
        // Add extra elements
        self.themeNames = self.themeNames + self.themeNames + self.themeNames + self.themeNames + self.themeNames
        
        // Set limits
        self.themesBottomLimit = 2 * self.themesCount
        self.themesTopLimit = (3 * self.themesCount) - 1
        
        // Set current element
        self.currentThemeIndex = self.themesCount + middleTheme
    }
    
    private func selectColorTheme(item: Int) {
        Scorecard.settings.colorTheme = self.themeNames[item]
        Themes.selectTheme(self.themeNames[item], changeIcon: true)
        self.defaultViewColors()
        self.banner.refresh()
        self.view.setNeedsDisplay()
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        self.settingsTableView.reloadData()
        self.menuController?.refresh()
        self.rootViewController.rightPanelDefaultScreenColors()
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func setupBanner() {
        self.banner.set(rightButtons: [
            BannerButton(action: self.helpPressed, type: .help),
        ])
    }
    
    private func checkReceiveNotifications() {
        Notifications.checkNotifications(refused: { (requested) in
            self.notificationsRefused = true
            self.clearReceiveNotifications()
        }, accepted: {
            self.notificationsRefused = false
        }, unknown: {
            self.notificationsRefused = false
        })
    }
    
    private func authoriseNotifications(message: String, successAction: @escaping ()->(), failureAction: @escaping ()->()) {
        if self.notificationsRefused {
            failureAction()
            self.alertMessage(message, title: "Error")
        } else {
            Notifications.requestNotifications(successAction: successAction, failureAction: failureAction)
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
        self.setOptionValue(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.receiveNotifications.rawValue, value: false)
        Scorecard.settings.receiveNotifications = false
        // Delete subscriptions
        Notifications.updateHighScoreSubscriptions()
    }
    
    func clearAlerts() {
        // Reset Alert Vibrate
        self.setOptionValue(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.vibrateAlert.rawValue, value: false)
        Scorecard.settings.alertVibrate = false
    }
    
    func enableOnline() {
        self.onlineEnabled = true
        Scorecard.settings.onlineGamesEnabled = true
        // Enable online player details
        self.setSectionEnabled(section: Sections.onlineGames.rawValue, enabled: true)
        // Enable Facetime calls switch
        self.setOptionEnabled(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.facetimeCalls.rawValue, enabled: true)
        // Enable (and default on alerts
        self.enableAlerts(switchOn: true)
    }
    
    func clearOnline() {
        self.onlineEnabled = false
        Scorecard.settings.onlineGamesEnabled = false
        // Delete Facetime address
        self.facetimeEnabled = false
        Scorecard.settings.faceTimeAddress = ""
        self.setOptionValue(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.facetimeCalls.rawValue, value: false)
        self.setOptionEnabled(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.facetimeCalls.rawValue, enabled: false)
        self.setOptionValue(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.facetimeAddress.rawValue, value: "")
        self.refreshFaceTimeAddress()
        // Delete subscriptions
        self.updateOnlineGameSubscriptions()
        // Disable alerts
        self.clearAlerts()
        self.setSectionValue(section: Sections.onlineGames.rawValue, value: false)
    }
    
    func clearSharing() {
        if Scorecard.settings.allowBroadcast {
            self.setOptionValue(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.shareScorecard.rawValue, value: false)
            Scorecard.settings.allowBroadcast = false
            Scorecard.shared.stopSharing()
        }
    }
    
    func setSharing() {
        if !Scorecard.settings.allowBroadcast {
            self.setOptionValue(section: Sections.onlineGames.rawValue, option: OnlineGameOptions.shareScorecard.rawValue, value: true)
            Scorecard.settings.allowBroadcast = true
            Scorecard.shared.resetSharing()
        }
    }
    
    private func showSettingsNotifications() {
        if Scorecard.settings.onlineGamesEnabledSettingState == .availableNotify {
            self.alertMessage("You have not enabled online games yet on this device. This setting allows you to play Whist electronically with users of other devices.", okHandler: {
                Scorecard.settings.onlineGamesEnabledSettingState = . available
                self.showSettingsNotifications()
            })
        } else if Scorecard.settings.confettiWinSettingState == .availableNotify {
            self.alertMessage("You have now achieved the loyalty card award. This has enabled a new setting to allow you to have a confetti storm on your device every time you win a game!", okHandler: {
                Scorecard.settings.confettiWinSettingState = .available
                let indexPath = IndexPath(row: InGameOptions.confettiWin.rawValue, section: Sections.inGame.rawValue)
                let cell = self.settingsTableView.cellForRow(at: indexPath) as! SettingsTableCell
                self.settingsTableView.scrollToRow(at: indexPath, at: .top, animated: true)
                self.settingsTableView.layoutIfNeeded()
                UIView.animate(withDuration: 1.0, animations: {
                       cell.label.font = UIFont.systemFont(ofSize: 20.0, weight: .regular)
                    }, completion: { (_) in
                       UIView.animate(withDuration: 1.0, animations: {
                          cell.label.font = UIFont.systemFont(ofSize: 17.0, weight: .regular)
                          self.showSettingsNotifications()
                       })
                })
            })
        }
    }
    
    private func setupPanelModeBannerSize() {
        let menuVisible = self.menuController?.isVisible ?? false
        if menuVisible != self.lastMenuVisible {
            // Change player and info will be in menu panel when menu is visible
            self.topSectionHeightConstraint.isActive = menuVisible
            self.availableSpaceHeightConstraint.isActive = !menuVisible
            self.topSectionProportionalHeightConstraint.isActive = !menuVisible && !ScorecardUI.landscapePhone()
            self.topSectionLandscapePhoneProportionalHeightConstraint.isActive = !menuVisible && ScorecardUI.landscapePhone()
            self.thisPlayerThumbnailView.isHidden = menuVisible
            self.thisPlayerChangeButtonContainer.isHidden = menuVisible
            self.lastMenuVisible = menuVisible
        }
    }
    
    // MARK: - Online game methods ========================================================== -
    
    private func setOnlinePlayerUUID(playerUUID: String!) {
        // Save the setting and update screen
        if let playerUUID = playerUUID {
            Scorecard.settings.thisPlayerUUID = playerUUID
            if let thisPlayerMO = Scorecard.shared.findPlayerByPlayerUUID(playerUUID) {
                self.thisPlayerThumbnailView.set(playerMO: thisPlayerMO, nameHeight: 20.0, diameter: self.thisPlayerThumbnailView.frame.width)
            }
        } else {
            self.thisPlayerThumbnailView.set(nameHeight: 20.0, diameter: self.thisPlayerThumbnailView.frame.width)
        }
    }

    private func updateOnlineGameSubscriptions() {
        Notifications.addOnlineGameSubscription(Scorecard.settings.thisPlayerUUID, completion: nil)
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func create(backText: String = "Back", backImage: String = "back", completion: (()->())?) -> SettingsViewController {
        
        let storyboard = UIStoryboard(name: "SettingsViewController", bundle: nil)
        let settingsViewController: SettingsViewController = storyboard.instantiateViewController(withIdentifier: "SettingsViewController") as! SettingsViewController
        
        settingsViewController.backText = backText
        settingsViewController.backImage = backImage
        settingsViewController.completion = completion
        
        return settingsViewController
    }
    
    class public func show(from viewController: ScorecardViewController, backText: String = "Back", backImage: String = "back", completion: (()->())?){
        
        let settingsViewController = SettingsViewController.create(backText: backText, backImage: backImage, completion: completion)
        
        viewController.present(settingsViewController, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.willDismiss()
        self.dismiss(animated: true, completion: {
            self.didDismiss()
        })
    }
    
    override internal func willDismiss() {
        Scorecard.settings.save()
        
        // Save to iCloud
        Scorecard.settings.saveToICloud()
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
    @IBOutlet fileprivate weak var editButton: ShadowButton!
    @IBOutlet fileprivate weak var segmentedControl: UISegmentedControl!
    @IBOutlet fileprivate weak var slider: UISlider!
    @IBOutlet fileprivate weak var sliderLabel: UILabel!
    @IBOutlet fileprivate weak var sliderValue: UITextField!
    @IBOutlet fileprivate weak var textField: UITextField!
    @IBOutlet fileprivate weak var collapseButton: UIButton!
    @IBOutlet fileprivate weak var colorThemeCollectionView: UICollectionView!
    @IBOutlet fileprivate weak var trumpSequenceCollectionView: UICollectionView!
    @IBOutlet fileprivate weak var infoLabel: UILabel!
    @IBOutlet fileprivate weak var infoValue1: UILabel!
    @IBOutlet fileprivate weak var infoValue2: UILabel!
    @IBOutlet fileprivate weak var infoValue3: UILabel!
    @IBOutlet fileprivate var appearanceLabels: [UILabel]!
    @IBOutlet fileprivate var appearanceButtons: [ClearButton]!

    @IBOutlet fileprivate weak var flowLayout: CustomCollectionViewLayout!
    
    public func resizeSwitch(_ factor: CGFloat) {
        self.toggleSwitch.transform = CGAffineTransform(scaleX: factor, y: factor)
    }
    
    public func setEnabled(enabled: Bool) {
        self.label?.alpha = (enabled ? 1.0 : 0.3)
        self.toggleSwitch?.isEnabled = enabled
        self.toggleSwitch?.alpha = (enabled ? 1.0 : 0.3)
        self.editLabel?.alpha = (enabled ? 1.0 : 0.3)
        self.setEnabled(button: self.editButton, enabled: enabled)
        self.segmentedControl?.isEnabled = enabled
        self.segmentedControl?.alpha = (enabled ? 1.0 : 0.3)
        self.slider?.isEnabled = enabled
        self.slider?.alpha = (enabled ? 1.0 : 0.3)
        self.setEnabled(textField: self.textField, enabled: enabled)
        self.trumpSequenceCollectionView?.isUserInteractionEnabled = enabled
        self.trumpSequenceCollectionView?.alpha = (enabled ? 1.0 : 0.5)
        self.colorThemeCollectionView?.isUserInteractionEnabled = enabled
        self.colorThemeCollectionView?.alpha = (enabled ? 1.0 : 0.5)
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
        self.segmentedControl?.removeTarget(nil, action: nil, for: .allEvents)
        self.slider?.removeTarget(nil, action: nil, for: .allEvents)
        self.slider?.minimumValue = 1
        self.slider?.maximumValue = 13
        self.slider?.setValue(1, animated: false)
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

        self.topSectionView.backgroundColor = Palette.banner.background
        self.view.backgroundColor = Palette.normal.background
        self.settingsTableView.backgroundColor = Palette.normal.background
        self.thisPlayerChangeButton.backgroundColor = Palette.bannerShadow.background
        self.thisPlayerChangeButton.setTitleColor(Palette.banner.text, for: .normal)
        self.thisPlayerThumbnailView.set(textColor: Palette.banner.text)
        self.thisPlayerThumbnailView.backgroundColor = Palette.banner.background
    }

    private func defaultCellColors(cell: SettingsTableCell) {
        if cell.reuseIdentifier != "This Player" {
            cell.backgroundColor = Palette.normal.background
        }
        switch cell.reuseIdentifier {
        case "Edit Button":
            cell.editButton.setTitleColor(Palette.emphasis.text, for: .normal)
            cell.editButton.setBackgroundColor(Palette.emphasis.background)
            cell.editLabel.textColor = Palette.normal.text
        case "Header Collapse":
            cell.collapseButton.tintColor = Palette.emphasis.background
            cell.collapseButton.setTitleColor(Palette.normal.strongText, for: .normal)
            cell.label.textColor = Palette.normal.strongText
            cell.separator.backgroundColor = Palette.disabled.background
        case "Header Switch":
            cell.label.textColor = Palette.normal.strongText
            cell.separator.backgroundColor = Palette.disabled.background
            cell.toggleSwitch.tintColor = Palette.emphasis.background
            cell.toggleSwitch.onTintColor = Palette.emphasis.background
        case "Info Single":
            cell.infoLabel.textColor = Palette.normal.text
            cell.infoValue1.textColor = Palette.normal.text
        case "Info Three":
            cell.infoLabel.textColor = Palette.normal.text
            cell.infoValue1.textColor = Palette.normal.text
            cell.infoValue2.textColor = Palette.normal.text
            cell.infoValue3.textColor = Palette.normal.text
        case "Info Three Heading":
            cell.infoLabel.textColor = Palette.normal.text
            cell.infoValue1.textColor = Palette.normal.text
            cell.infoValue2.textColor = Palette.normal.text
            cell.infoValue3.textColor = Palette.normal.text
        case "Slider":
            cell.slider.minimumTrackTintColor = nil
            cell.slider.thumbTintColor = nil
            cell.slider.thumbTintColor = Palette.segmentedControls.background
            cell.slider.minimumTrackTintColor = Palette.segmentedControls.background
            cell.sliderLabel.textColor = Palette.normal.text
            cell.sliderValue.textColor = Palette.inputControl.text
            cell.slider.tintColorDidChange()
        case "Segmented":
            cell.segmentedControl.draw(cell.segmentedControl.frame)
        case "Sub Heading":
            cell.subHeadingLabel.textColor = Palette.normal.text
        case "Switch":
            cell.label.textColor = Palette.normal.text
            cell.toggleSwitch.tintColor = Palette.emphasis.background
            cell.toggleSwitch.onTintColor = Palette.emphasis.background
        case "Appearance":
            cell.appearanceLabels.forEach{(label) in label.textColor = Palette.normal.text}
        default:
            break
        }
    }

    private func defaultCellColors(cell: UICollectionViewCell) {
        switch cell.reuseIdentifier {
        case "Header Collapse":
            cell.backgroundColor = Palette.normal.background
        case "Header Switch":
            cell.backgroundColor = Palette.normal.background
        default:
            break
        }
    }

}

extension SettingsViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
        
        self.helpView.add("This is the default player for this device (i.e. yourself). You can change the default player by clicking the Change button or tapping the image.", views: [self.thisPlayerThumbnailView, self.thisPlayerChangeButtonContainer], border: 8)
        
        self.helpView.add("This switches the ability to play online/nearby games with other devices on/off.", views: [self.settingsTableView], section: Sections.onlineGames.rawValue, item: -1, horizontalBorder: -16)
        
        self.helpView.add("This switches a vibration on/off when it is your turn to bid or play.", views: [self.settingsTableView], section: Sections.onlineGames.rawValue, item: OnlineGameOptions.vibrateAlert.rawValue, horizontalBorder: -16)
        
        // TODO Reinstate
        // self.helpView.addElement("This allows you to specify a facetime address which will be used to set up a group facetime audio call during online games", views: [self.settingsTableView], section: Sections.onlineGames.rawValue, item: OnlineGameOptions.facetimeCalls.rawValue, horizontalBorder: -16)
        
        self.helpView.add("This switches visibility of games you are scoring on/off to allow/prevent others from viewing the scorecard.", views: [self.settingsTableView], section: Sections.onlineGames.rawValue, item: OnlineGameOptions.shareScorecard.rawValue, horizontalBorder: -16)

        self.helpView.add("This switches game notifications on/off. If switched on, you will receive a notification on your if any player on your device wins a game.", views: [self.settingsTableView], section: Sections.onlineGames.rawValue, item: OnlineGameOptions.receiveNotifications.rawValue, horizontalBorder: -16)
        
        self.helpView.add("This switches location saving on/off. You have to allow the app access to your location while the app is running to enable this option. If location saving is switched on you will be prompted to confirm the location at the start of nearby games.", views: [self.settingsTableView], section: Sections.onlineGames.rawValue, item: OnlineGameOptions.saveGameLocation.rawValue, horizontalBorder: -16)
        
        self.helpView.add("This section allows you to change the colour scheme for your device and also to specify how you want to work with dark mode.\nIf you specify 'light' then you will always operate in light mode even if your device is in dark mode.\nSimilarly if you specify 'dark' then you will always operate in dark mode.\nIf you specify 'device' the app will follow dark mode on your device.", views: [self.settingsTableView], section: Sections.theme.rawValue, item: -1, itemTo: ThemeOptions.colorTheme.rawValue, horizontalBorder: -16)
        
        self.helpView.add("These settings allow you to customise the number of cards in each hand. You can specify a starting point and and end point. You can also choose whether you bounce from the end point back to the starting point. E.g. you can start with 7 cards, progressively reduce to 1 card, and then progressively increase back to 7 cards.", views: [self.settingsTableView], section: Sections.inGame.rawValue, item: InGameOptions.cardsInHandSubheading.rawValue, itemTo: InGameOptions.cardsInHandBounce.rawValue, horizontalBorder: -16)
        
        self.helpView.add("This setting allows you to enable/disable a special ten point bonus every time a player wins a trick with a 2.", views: [self.settingsTableView], section: Sections.inGame.rawValue, item: InGameOptions.bonus2Subheading.rawValue, itemTo: InGameOptions.bonus2.rawValue, horizontalBorder: -16)
        
        self.helpView.add("These settings allow you to choose if you have rounds with no trumps. You can also customise the order of the suits", views: [self.settingsTableView], section: Sections.inGame.rawValue, item: InGameOptions.includeNoTrump.rawValue, itemTo: InGameOptions.trumpSequenceSuits.rawValue, horizontalBorder: -16)
        
        self.helpView.add("This setting allows you to choose if the status bar at the top of the device (showing time, battery, signal etc) is displayed.", views: [self.settingsTableView], section: Sections.displayStatus.rawValue, item: -1, horizontalBorder: -16)
        
        self.helpView.add("This section shows you information about the Whist app installed on your phone.", views: [self.settingsTableView], section: Sections.generalInfo.rawValue, item: -1, itemTo: GeneralInfoOptions.database.rawValue, horizontalBorder: -16)
    }
}
