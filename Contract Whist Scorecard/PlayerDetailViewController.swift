//
//  PlayerDetailViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 13/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

enum DetailMode {
    case amend
    case amending
    case display
    case none
}

protocol PlayerDetailViewDelegate : class {
    func hide()
    func refresh(playerDetail: PlayerDetail, mode: DetailMode)
}

class PlayerDetailViewController: ScorecardViewController, PlayerDetailViewDelegate, UITableViewDataSource, UITableViewDelegate, SyncDelegate, PlayerViewImagePickerDelegate, BannerDelegate, DetailDelegate {
    
    
    // MARK: - Class Properties ======================================================================== -
    
    internal var isVisible: Bool { return true }
    
    var detailView: UIView { return self.view }
    
    private enum NameOptions: Int, CaseIterable {
        case name = 0
    }
        
    private enum ThumbnailOptions: Int, CaseIterable {
        case thumbnail = 0
    }
    
    private enum EditOptions: Int, CaseIterable {
        case editPlayer = 0
    }
    
    private enum DeleteOptions: Int, CaseIterable {
        case deletePlayer = 0
    }
    
    private enum LastPlayedOptions: Int, CaseIterable {
        case lastPlayed = 0
    }
    
    private enum RecordsOptions: Int, CaseIterable {
        case totalScore = 0
        case handsMade = 1
        case winStreak = 2
        case twosMade = 3
    }
    
    private enum StatsOptions: Int, CaseIterable {
        case played = 0
        case win = 1
        case winPercent = 2
        case total = 3
        case average = 4
    }
    
    // Main state properties
    private var reconcile: Reconcile!
    private let settings = Scorecard.game.settings ?? Scorecard.settings
    private let sync = Sync()
    internal let syncDelegateDescription = "Players"
    
    private var sections = 0
    private var nameSection = -1
    private var thumbnailSection = -1
    private var editSection = -1
    private var lastPlayedSection = -1
    private var recordsSection = -1
    private var statsSection = -1
    private var deleteSection = -1

    // Text field tags
    private let nameFieldTag = 0
    private let editButtonTag = 2
    private let cancelButtonTag = 3
    private let confirmButtonTag = 4
    private let deleteButtonTag = 5

    // Properties to control how view works
    private var playerDetail: PlayerDetail!
    private var originalPlayer: PlayerDetail!
    private var mode: DetailMode!
    private var sourceView: UIView!
    private var dismissOnSave = true
    private var returnTo: String = ""
    
    // Local class variables
    private var actionSheet: ActionSheet!
    private var changed = false
    private var imageObserver: NSObjectProtocol!
 
    private var nameCell: PlayerDetailCell!
    private var playerView: PlayerView!
    private var labelFontSize: CGFloat?
    private var textFieldFontSize: CGFloat?
    private var heightFactor: CGFloat = 1.0
    
    // Players view delegate
    internal weak var playersViewDelegate: PlayersViewDelegate?

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var playerNameLabel: UILabel!
    @IBOutlet private weak var tableViewContainer: UIView!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var tableViewContainerLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableViewContainerTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableViewContainerRightPanelTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableViewContainerBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var tableViewInsets: [NSLayoutConstraint]!
    
    // MARK: - IB Actions ============================================================================== -
        
    internal func finishPressed() {
        Notifications.removeObserver(self.imageObserver)
        self.imageObserver = nil
        self.dismiss(animated: true)
    }

    @IBAction func allSwipe(recognizer:UISwipeGestureRecognizer) {
        if self.menuController?.isVisible ?? false {
            self.menuController?.swipeGesture(direction: recognizer.direction)
        } else {
            finishPressed()
        }
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()

        // Setup player header fields and sections
        self.setupSections()
        self.setupBanner()
               
        // Setup observer for image download changes
        self.imageObserver = setPlayerDownloadNotification(name: .playerImageDownloaded)
        
        // Save copy to a managed object
        self.originalPlayer = playerDetail.copy()
        
        // Set player title
        self.playerNameLabel.text = self.playerDetail.name
        
        // Hide banner if in a right-hand container
        if self.container == .right {
            self.banner.set(normalOverrideHeight: 0)
            self.banner.isHidden = true
            self.tableViewContainerLeadingConstraint.constant = 30
            self.tableViewContainerTrailingConstraint.constant = 30
            self.tableViewContainerBottomConstraint.constant = 50
            Constraint.setActive([self.tableViewTopConstraint], to: false)
            Constraint.setActive([self.tableViewContainerRightPanelTopConstraint], to: true)
            self.tableViewInsets.forEach{ (inset) in inset.constant = 10}
            self.labelFontSize = 10
            self.textFieldFontSize = 12
            self.heightFactor = 0.8
        } else {
            self.tableViewContainerLeadingConstraint.constant = ScorecardUI.smallPhoneSize() ? 16 : 30
            self.tableViewInsets.forEach{ (inset) in inset.constant = 0}
            self.tableView.contentInset = UIEdgeInsets(top: (ScorecardUI.landscapePhone() ? 0 : 10.0), left: 0.0, bottom: 0.0, right: 0.0)
            self.tableView.contentInsetAdjustmentBehavior = .never
            self.playerNameLabel.isHidden = true
        }
        
        // Enable buttons
        self.enableButtons()
        
        // Setup help
        self.setupHelpView()
    }
    
    internal override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if self.container == .right {
            self.tableViewContainer.layoutIfNeeded()
            self.tableViewContainer.roundCorners(cornerRadius: 20)
        }
    }
    
    // MARK: - Player Detail View Delegate ============================================================= -
    
    internal func hide() {
        self.playerNameLabel.isHidden = true
        self.tableViewContainer.isHidden = true
        self.tableView.isHidden = true
    }
    
    internal func refresh(playerDetail: PlayerDetail, mode: DetailMode) {
        self.playerDetail = playerDetail
        self.playerNameLabel.isHidden = true
        self.playerNameLabel.text = self.playerDetail.name
        self.mode = mode
        self.tableViewContainer.isHidden = false
        self.tableView.isHidden = false
        self.setupBanner()
        self.tableView.reloadData()
    }

    // MARK: - TableView Overrides ===================================================================== -

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows: Int
        
        switch section {
        case nameSection:
            rows = NameOptions.allCases.count
        case thumbnailSection:
            rows = ThumbnailOptions.allCases.count
        case editSection:
            rows = EditOptions.allCases.count
        case deleteSection:
            rows = DeleteOptions.allCases.count
        case lastPlayedSection:
            rows = LastPlayedOptions.allCases.count
        case recordsSection:
            rows = RecordsOptions.allCases.count - (self.settings.bonus2 ? 0 : 1)
        case statsSection:
            rows = StatsOptions.allCases.count
        default:
            rows = 0
        }
        return rows
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        var height: CGFloat
        
        switch section {
        case nameSection, thumbnailSection:
            height = 40.0
        case editSection, deleteSection:
            height = 0.0
        default:
            height = (ScorecardUI.landscapePhone() ? 30.0 : 50.0)
        }
        return height * self.heightFactor
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var header: PlayerDetailHeaderFooterView?        
        var text = ""
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Header") as! PlayerDetailCell
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultCellColors(cell: cell)
        
        switch section {
        case nameSection:
            text = "Player Name"
        case thumbnailSection:
            text = "Photo"
        case lastPlayedSection:
            text = "Last played:"
        case recordsSection:
            text = "Personal records:"
        case statsSection:
            text = "Personal statistics:"
        default:
            break
        }
        
        cell.headerLabel.text = text
        
        header = PlayerDetailHeaderFooterView(cell)
        
        return header
    }
    
    internal func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = Palette.normal.background
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat
        let landscape = ScorecardUI.landscapePhone()
        
        switch indexPath.section {
        case editSection, deleteSection:
            height = (landscape ? 40.0 : 50.0)
        case thumbnailSection:
            height = 60.0
        case statsSection:
            switch StatsOptions(rawValue: indexPath.row)! {
            case .total:
                height = 40.0
            default:
                height = 20.0
            }
        default:
            height = 20.0
        }
        
        return height * self.heightFactor
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: PlayerDetailCell!
        
        switch indexPath.section {
        case nameSection:
            switch NameOptions(rawValue: indexPath.row)! {
            case .name:
                cell = tableView.dequeueReusableCell(withIdentifier: "Input Field", for: indexPath) as? PlayerDetailCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                cell.inputField.text = playerDetail.name
                cell.inputField.tag = self.nameFieldTag
                cell.inputField.isSecureTextEntry = false
                cell.inputField.isEnabled = (self.mode == .amending)
                self.addTargets(cell.inputField)
                self.nameCell = cell
                if mode == .amending {
                    cell.inputField.becomeFirstResponder()
                }
            }
            
        case thumbnailSection:
            switch ThumbnailOptions(rawValue: indexPath.row)! {
            case .thumbnail:
                cell = tableView.dequeueReusableCell(withIdentifier: "Thumbnail", for: indexPath) as? PlayerDetailCell
                // Setup default colors (previously done in StoryBoard)
                cell.imagePlayerView.layoutIfNeeded()
                
                self.setupImagePickerPlayerView(cell: cell)
                self.defaultCellColors(cell: cell)
                
                cell.playerView.set(data: self.playerDetail.thumbnail)
                cell.playerView.isEnabled = (self.mode == .amending)
                if cell.playerView.isEnabled {
                    cell.thumbnailMessageLabel.text = (self.playerDetail.thumbnail == nil ? "Tap the camera to add a photo" : "Tap photo to remove or change it")
                } else {
                   cell.thumbnailMessageLabel.text = ""
                }
            }
            
            
        case deleteSection:
            switch DeleteOptions(rawValue: indexPath.row)! {
            case .deletePlayer:
                cell = tableView.dequeueReusableCell(withIdentifier: "Action Button", for: indexPath) as? PlayerDetailCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                if mode == .amend {
                    cell.actionButton.setTitle("Remove Player", for: .normal)
                    cell.actionButton.setBackgroundColor(Palette.error.background)
                    cell.actionButton.setTitleColor(Palette.error.text, for: .normal)
                    cell.actionButton.tag = self.deleteButtonTag
                    cell.actionButton.addTarget(self, action: #selector(PlayerDetailViewController.actionButtonPressed(_:)), for: .touchUpInside)
                    cell.actionButton.isHidden = false
                } else {
                    cell.actionButton.isHidden = true
                }
                cell.separator.isHidden = true
            }
            
        case editSection:
            switch EditOptions(rawValue: indexPath.row)! {
            case .editPlayer:
                cell = tableView.dequeueReusableCell(withIdentifier: "Action Button", for: indexPath) as? PlayerDetailCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                if self.mode != .display {
                    cell.actionButton.tag = self.editButtonTag
                    cell.cancelButton.tag = self.cancelButtonTag
                    cell.confirmButton.tag = self.confirmButtonTag
                    cell.buttons.forEach { $0.addTarget(self, action: #selector(PlayerDetailViewController.actionButtonPressed(_:)), for: .touchUpInside) }
                    self.enableButtons(editButtonCell: cell)
                } else {
                    cell.actionButton.isHidden = true
                }
            }
            
        case lastPlayedSection:
            switch LastPlayedOptions(rawValue: indexPath.row)! {
            case .lastPlayed:
                cell = tableView.dequeueReusableCell(withIdentifier: "Single", for: indexPath) as? PlayerDetailCell
                // Setup default colors (previously done in StoryBoard)
                self.defaultCellColors(cell: cell)
                
                if playerDetail.datePlayed != nil {
                    let formatter = DateFormatter()
                    formatter.dateStyle = DateFormatter.Style.full
                    cell.singleLabel.text = formatter.string(from: playerDetail.datePlayed)
                } else {
                    cell.singleLabel.text="Not played"
                }
            }
            
        case recordsSection:
            cell = tableView.dequeueReusableCell(withIdentifier: "Record", for: indexPath) as? PlayerDetailCell
            // Setup default colors (previously done in StoryBoard)
            self.defaultCellColors(cell: cell)
            
            switch RecordsOptions(rawValue: indexPath.row)! {
            case .totalScore:
                cell.recordDescLabel.text = "High score"
                cell!.recordValueLabel.text = "\(playerDetail.maxScore)"
                if playerDetail.maxScoreDate != nil {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd MMM yyyy"
                    cell!.recordDateLabel.text = formatter.string(from: playerDetail.maxScoreDate)
                } else {
                    cell!.recordDateLabel.text=""
                }
                
            case .handsMade:
                cell.recordDescLabel.text = "Bids made"
                cell!.recordValueLabel.text = "\(playerDetail.maxMade)"
                if playerDetail.maxMadeDate != nil {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd MMM yyyy"
                    cell!.recordDateLabel.text = formatter.string(from: playerDetail.maxMadeDate)
                } else {
                    cell!.recordDateLabel.text=""
                }
                
            case .winStreak:
                cell.recordDescLabel.text = "Win streak"
                cell!.recordValueLabel.text = "\(playerDetail.maxWinStreak)"
                if playerDetail.maxWinStreakDate != nil {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd MMM yyyy"
                    cell!.recordDateLabel.text = formatter.string(from: playerDetail.maxWinStreakDate)
                } else {
                    cell!.recordDateLabel.text=""
                }
                
            case .twosMade:
                cell.recordDescLabel.text = "Twos made"
                cell!.recordValueLabel.text = "\(playerDetail.maxTwos)"
                if playerDetail.maxTwosDate != nil {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd MMM yyyy"
                    cell!.recordDateLabel.text = formatter.string(from: playerDetail.maxTwosDate)
                } else {
                    cell!.recordDateLabel.text=""
                }
            }
            
        case statsSection:
            cell = tableView.dequeueReusableCell(withIdentifier: "Stat", for: indexPath) as? PlayerDetailCell
            // Setup default colors (previously done in StoryBoard)
            self.defaultCellColors(cell: cell)
            
            switch StatsOptions(rawValue: indexPath.row)! {
            case .played:
                cell.statDescLabel1.text = "Games played"
                cell.statValueLabel1.text = "\(playerDetail.gamesPlayed)"

                cell.statDescLabel2.text = "Hands played"
                cell.statValueLabel2.text = "\(playerDetail.handsPlayed)"

            case .win:
                cell.statDescLabel1.text = "Games won"
                cell.statValueLabel1.text = "\(playerDetail.gamesWon)"

                cell.statDescLabel2.text = "Hands made"
                cell.statValueLabel2.text = "\(playerDetail.handsMade)"

            case .winPercent:
                cell.statDescLabel1.text = "Win %"
                if CGFloat(playerDetail.gamesPlayed) == 0 {
                    cell.statValueLabel1.text = "0.0 %"
                } else {
                    let percent = (CGFloat(playerDetail.gamesWon) / CGFloat(playerDetail.gamesPlayed)) * 100
                    cell.statValueLabel1.text = "\(String(format: "%0.1f", percent)) %"
                }
                
                cell.statDescLabel2.text = "Made %"
                if playerDetail.handsPlayed == 0 {
                    cell.statValueLabel2.text = "0.0 %"
                } else {
                    let percent = (CGFloat(playerDetail.handsMade) / CGFloat(playerDetail.handsPlayed)) * 100
                    cell.statValueLabel2.text = "\(String(format: "%0.1f", percent)) %"
                }
                
            case .total:
                cell.statDescLabel1.text = "Total score"
                cell.statValueLabel1.text = "\(playerDetail.totalScore)"

                if self.settings.bonus2 {
                    cell.statDescLabel2.text = "Twos made"
                    cell.statValueLabel2.text = "\(playerDetail.twosMade)"
                } else {
                    cell.statDescLabel2.text = ""
                    cell.statValueLabel2.text = ""
                }
                
            case .average:
                cell.statDescLabel1.text = "Average score"
                if playerDetail.gamesPlayed == 0 {
                    cell.statValueLabel1.text = "0.0"
                } else {
                    let average = (CGFloat(playerDetail.totalScore) / CGFloat(playerDetail.gamesPlayed))
                    cell.statValueLabel1.text = "\(String(format: "%0.1f", average))"
                }

                if self.settings.bonus2 {
                    cell.statDescLabel2.text = "Twos made %"
                    if playerDetail.handsPlayed == 0 {
                        cell.statValueLabel2.text = "0.0 %"
                    } else {
                        let percent = (CGFloat(playerDetail.twosMade) / CGFloat(playerDetail.handsPlayed)) * 100
                        cell.statValueLabel2.text = "\(String(format: "%0.1f", percent)) %"
                    }
                } else {
                    cell.statDescLabel2.text = ""
                    cell.statValueLabel2.text = ""
                }
            }
        default:
            break
        }
             
        if let labelFontSize = self.labelFontSize, let textFieldFontSize = self.textFieldFontSize {
            cell.setFontSize(labelFontSize, textFieldFontSize)
        }
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.clear
        cell!.selectedBackgroundView = backgroundView
            
        return cell!
    }
    
    internal func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch indexPath.section {
        case recordsSection:
            let record = RecordsOptions(rawValue: indexPath.row)!
            if record == .winStreak {
            // Win streak - special case
                _ = HistoryViewer(from: self, playerUUID: self.playerDetail.playerUUID, winStreak: true)
            } else {
                var highScoreType: HighScoreType?
                switch record {
                case .totalScore:
                    highScoreType = .totalScore
                case .handsMade:
                    highScoreType = .handsMade
                case .twosMade:
                    highScoreType = .twosMade
                default:
                    break
                }
                if let highScoreType = highScoreType {
                    let participantMO = History.getHighScores(type: highScoreType, limit: 1, playerUUIDList: [playerDetail.playerUUID])
                
                    if participantMO.count > 0 {
                        let history = History(gameUUID: participantMO[0].gameUUID, getParticipants: true)
                        if history.games.count >= 1 {
                            HistoryDetailViewController.show(from: self, gameDetail: history.games[0])
                        }
                    }
                }
            }
        default:
            break
        }
        return nil
    }
       
    // MARK: - TextField and Button Control Overrides ======================================================== -
    
    private func addTargets(_ textField: UITextField) {
        textField.addTarget(self, action: #selector(PlayerDetailViewController.textFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        textField.addTarget(self, action: #selector(PlayerDetailViewController.textFieldShouldReturn(_:)), for: UIControl.Event.editingDidEndOnExit)
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        self.changed = true
        switch textField.tag {
        case self.nameFieldTag:
            // Name
            playerDetail.name = textField.text!
            playerDetail.nameDate = Date()
        default:
            break
        }
        self.enableButtons()
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == self.nameFieldTag && textField.text == "" {
            // Don't allow blank name
            return false
        } else {
            textField.resignFirstResponder()
        }
        return true
    }

    @objc func actionButtonPressed(_ button: UIButton) {
        if self.mode != .display {
            switch button.tag {
            case self.deleteButtonTag:
                // Delete the player
                self.checkDeletePlayer()
            case self.editButtonTag, cancelButtonTag:
                // Toggle amend mode
                if mode == .amend {
                    self.mode = .amending
                    self.setOtherPanes(isEnabled: false)
                } else {
                    self.playerDetail = originalPlayer.copy()
                    self.mode = .amend
                    self.changed = false
                    self.setOtherPanes(isEnabled: true)
                }
                self.tableView.reloadData()
                self.enableButtons()
            case self.confirmButtonTag:
                // Update core data with any changes
                if !CoreData.update(updateLogic: {
                    if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(self.playerDetail.playerUUID) {
                        self.playerDetail.toManagedObject(playerMO: playerMO)
                        self.playersViewDelegate?.refresh()
                        self.playerNameLabel.text = self.playerDetail.name
                        if self.dismissOnSave {
                            self.dismiss(animated: true)
                        }
                    }
                }) {
                    self.alertMessage("Error saving player")
                }
                self.originalPlayer = self.playerDetail.copy()
                self.mode = .amend
                self.setOtherPanes(isEnabled: true)
                self.changed = false
                self.tableView.reloadData()
                self.enableButtons()
            default:
                break
            }
        }
    }
    
    private func setOtherPanes(isEnabled: Bool) {
        self.menuController?.setAll(isEnabled: isEnabled)
        self.playersViewDelegate?.set(isEnabled: isEnabled)
    }
    
    private func removeImage() {
        playerDetail.thumbnail = nil
        playerDetail.thumbnailDate = nil
        self.changed = true
        self.enableButtons()
    }
    
    internal func playerViewImageChanged(to thumbnail: Data?) {
        playerDetail.thumbnail = thumbnail
        self.changed = true
        if thumbnail != nil {
            playerDetail.thumbnailDate = Date()
            self.enableButtons()
        } else {
            self.removeImage()
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func enableButtons(editButtonCell: PlayerDetailCell? = nil) {
        var invalid: Bool
        
        let duplicateName = self.playerDetail.name != self.originalPlayer.name && Scorecard.shared.isDuplicateName(playerDetail)
        
        switch mode! {
        case .amending:
            invalid = duplicateName || playerDetail.name == ""
        default:
            invalid = false
        }
                
        if mode == .amending || mode == .amend {
            var cell = editButtonCell
            if cell == nil {
                cell = self.tableView.cellForRow(at: IndexPath(row: EditOptions.editPlayer.rawValue, section: editSection)) as? PlayerDetailCell
            }
            if let cell = cell {
                let canSave = (changed && !invalid)
                cell.actionButton.isHidden = canSave
                cell.actionButton.setTitle(self.mode == .amend ? "Edit" : (canSave ? "Done" : "Cancel"), for: .normal)
                cell.cancelButton.isHidden = !canSave
                cell.confirmButton.isHidden = !canSave
            }
        }
         
        self.banner.setButton(Banner.finishButton, isHidden: (self.mode == .amending || self.container == .right))
        
        if let view = tableView.headerView(forSection: nameSection) as? PlayerDetailHeaderFooterView {
            if let cell = view.cell {
                cell.duplicateLabel.isHidden = !duplicateName
            }
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -

    private func setupSections() {
        self.sections = 0
        nameSection = self.sections
        self.sections += 1
        thumbnailSection = self.sections
        self.sections += 1
        editSection = self.sections
        self.sections += 1
        lastPlayedSection = self.sections
        self.sections += 1
        recordsSection = self.sections
        self.sections += 1
        statsSection = self.sections
        self.sections += 1
        if self.mode == .amend || self.mode == .amending {
            deleteSection = self.sections
            self.sections += 1
        }
    }
    
    func setupBanner() {
        if self.container == .right {
            self.banner.set(leftButtons: [])
        } else {
            self.banner.set(title: playerDetail.name,
                leftButtons:
                    [BannerButton(image: UIImage(named: "back"), action: {[weak self] in self?.finishPressed()}, menuHide: true, menuText: self.returnTo, id: Banner.finishButton)],
                rightButtons:
                    [BannerButton(action: {[weak self] in self?.helpPressed()}, type: .help)])
        }
    }
    
    func setupImagePickerPlayerView(cell: PlayerDetailCell) {
        cell.playerView = PlayerView(type: .imagePicker, parentViewController: self, parentView: cell.imagePlayerView, width: cell.imagePlayerView.frame.width - 10, height: cell.imagePlayerView.frame.height - 10, cameraTintColor: Palette.thumbnailDisc.text)
        cell.playerView.imagePickerDelegate = self
    }
    
    func checkDeletePlayer() {
        if self.playerDetail.playerUUID == Scorecard.settings.thisPlayerUUID {
            self.alertMessage("This player is set up as yourself and therefore cannot be removed.\n\nIf you want to remove this player, select another player as yourself in Settings first.")
        } else {
            self.alertDecision("This will remove the player \n'\(playerDetail.name)'\nfrom this device.\n\nIf you have synchronised with iCloud the player will still be available to download in future.\n Otherwise this will remove their details permanently.\n\n Are you sure you want to do this?", title: "Warning", okButtonText: "Remove", okHandler: {
                
                // Update core data with any changes
                self.playerDetail.deleteMO()
                
                // Save to iCloud
                Scorecard.settings.saveToICloud()
                
                // Remove from email cache
                Scorecard.shared.playerEmails[self.playerDetail.playerUUID] = nil
                
                // Delete any detached games
                History.deleteDetachedGames()
                
                // Refresh caller
                self.playersViewDelegate?.playerRemoved(playerUUID: self.playerDetail.playerUUID)
                
                // Return to caller
                if self.dismissOnSave {
                    self.dismiss(animated: true)
                } else {
                    self.playerNameLabel.text = ""
                    self.hide()
                }
                
            })
        }
    }
    
    // MARK: - Image download handlers =================================================== -
    
    func setPlayerDownloadNotification(name: Notification.Name) -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = Notifications.addObserver(forName: name) {
            [weak self] (notification) in
            self?.updatePlayer(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }
    
    func updatePlayer(objectID: NSManagedObjectID) {
        // Find any cells containing an image/player which has just been downloaded asynchronously
        Utility.mainThread {
            if objectID == self.playerDetail.objectID {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: ThumbnailOptions.thumbnail.rawValue, section: self.thumbnailSection)) as? PlayerDetailCell {
                    cell.playerView.set(data: self.playerDetail.thumbnail)
                }
            }
        }
    }
    
    
    // MARK: - method to show this view controller ============================================================================== -
    
    static public func create(playerDetail: PlayerDetail, mode: DetailMode, playersViewDelegate: PlayersViewDelegate? = nil, dismissOnSave: Bool = true, returnTo: String = "Results") -> PlayerDetailViewController {
        
        let storyboard = UIStoryboard(name: "PlayerDetailViewController", bundle: nil)
        let playerDetailViewController = storyboard.instantiateViewController(withIdentifier: "PlayerDetailViewController") as! PlayerDetailViewController

        
        playerDetailViewController.playerDetail = playerDetail
        playerDetailViewController.mode = mode
        playerDetailViewController.playersViewDelegate = playersViewDelegate
        playerDetailViewController.dismissOnSave = dismissOnSave
        playerDetailViewController.returnTo = returnTo
        
        return playerDetailViewController
    }
        
    static public func show(from sourceViewController: ScorecardViewController, playerDetail: PlayerDetail, mode: DetailMode, sourceView: UIView, playersViewDelegate: PlayersViewDelegate? = nil, dismissOnSave: Bool = true, returnTo: String = "Results", container: Container? = nil) {
        
        let playerDetailViewController = PlayerDetailViewController.create(playerDetail: playerDetail, mode: mode, playersViewDelegate: playersViewDelegate, dismissOnSave: dismissOnSave, returnTo: returnTo)
                
        var container = container
        if container == nil {
            container = sourceViewController.container
        }
        
        let popoverSize = (ScorecardUI.phoneSize() || container != nil ? nil : ScorecardUI.defaultSize)
                        
        sourceViewController.present(playerDetailViewController, popoverSize: popoverSize, animated: true, container: container, completion: nil)
    }
    
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class PlayerDetailCell: UITableViewCell {
    @IBOutlet fileprivate weak var headerLabel: UILabel!
    @IBOutlet fileprivate weak var inputField: UITextField!
    @IBOutlet fileprivate weak var duplicateLabel: UILabel!
    @IBOutlet fileprivate var buttons: [ShadowButton]!
    @IBOutlet fileprivate weak var actionButton: ShadowButton!
    @IBOutlet fileprivate weak var cancelButton: ShadowButton!
    @IBOutlet fileprivate weak var confirmButton: ShadowButton!
    @IBOutlet fileprivate weak var singleLabel: UILabel!
    @IBOutlet fileprivate weak var recordDescLabel: UILabel!
    @IBOutlet fileprivate weak var recordValueLabel: UILabel!
    @IBOutlet fileprivate weak var recordDateLabel: UILabel!
    @IBOutlet fileprivate weak var statDescLabel1: UILabel!
    @IBOutlet fileprivate weak var statValueLabel1: UILabel!
    @IBOutlet fileprivate weak var statDescLabel2: UILabel!
    @IBOutlet fileprivate weak var statValueLabel2: UILabel!
    @IBOutlet fileprivate weak var separator: UIView!
    @IBOutlet fileprivate weak var imagePlayerView: UIView!
    @IBOutlet fileprivate weak var thumbnailMessageLabel: UILabel!
    @IBOutlet fileprivate var labels: [UILabel]!
    @IBOutlet fileprivate var textFields: [UITextField]!
    fileprivate var playerView: PlayerView!
    
    fileprivate func setFontSize(_ labelFontSize: CGFloat, _ textFieldFontSize: CGFloat) {
        self.labels?.forEach { (label) in label.font = UIFont.systemFont(ofSize: labelFontSize) }
        self.textFields?.forEach { (textField) in textField.font = UIFont.systemFont(ofSize: textFieldFontSize) }
    }
}

class PlayerDetailHeaderFooterView: UITableViewHeaderFooterView {
   
    public var cell: PlayerDetailCell!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    convenience init?(_ cell: PlayerDetailCell, reuseIdentifier: String? = nil) {
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

extension PlayerDetailViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.view.backgroundColor = (self.container == .right ? Palette.banner.background :  Palette.normal.background)
        self.tableViewContainer.backgroundColor = (self.container == .right ? Palette.normal.background : UIColor.clear)
        self.playerNameLabel.textColor = Palette.banner.text
    }

    private func defaultCellColors(cell: PlayerDetailCell) {
        switch cell.reuseIdentifier {
        case "Action Button":
            cell.actionButton.setTitleColor(Palette.buttonFace.text, for: .normal)
            cell.actionButton.setBackgroundColor(Palette.buttonFace.background)
            cell.cancelButton.setTitleColor(Palette.buttonFace.text, for: .normal)
            cell.cancelButton.setBackgroundColor(Palette.buttonFace.background)
            cell.confirmButton.setTitleColor(Palette.error.text, for: .normal)
            cell.confirmButton.setBackgroundColor(Palette.error.background)
            cell.separator.backgroundColor = Palette.separator.background
        case "Header":
            cell.headerLabel.textColor = Palette.normal.strongText
            cell.duplicateLabel.textColor = Palette.errorCondition
        case "Record":
            cell.recordDateLabel.textColor = Palette.normal.text
            cell.recordDescLabel.textColor = Palette.normal.text
            cell.recordValueLabel.textColor = Palette.normal.text
        case "Single":
            cell.singleLabel.textColor = Palette.normal.text
        case "Stat":
            cell.statDescLabel1.textColor = Palette.normal.text
            cell.statDescLabel2.textColor = Palette.normal.text
            cell.statValueLabel1.textColor = Palette.normal.text
            cell.statValueLabel2.textColor = Palette.normal.text
        case "Thumbnail":
            cell.playerView.set(backgroundColor: Palette.thumbnailDisc.background)
            cell.playerView.set(textColor: Palette.thumbnailDisc.text)
            cell.thumbnailMessageLabel.textColor = Palette.normal.text
        default:
            break
        }
    }

    private func defaultCellColors(cell: UICollectionViewCell) {
        switch cell.reuseIdentifier {
        case "Header":
            cell.backgroundColor = Palette.normal.background
        default:
            break
        }
    }

}

extension PlayerDetailViewController {
    
    internal func setupHelpView() {
        weak var weakSelf = self
        
        self.helpView.reset()
                
        self.helpView.add("This is the player's name on this device. \(weakSelf?.mode == .display ? "" : "You can change the name for this player on your device\(weakSelf?.mode == .amend ? " when in edit mode" : "").")", views: [self.tableView], section: self.nameSection, item: -1, itemTo: 0, horizontalBorder: 8)
        
        self.helpView.add("This is the player's photo. \(weakSelf?.mode == .display ? "" : weakSelf?.playerDetail.thumbnail == nil ? "You can add a photo by tapping the camera button\(weakSelf?.mode == .amend ? " when in edit mode" : "")." : "You can change or remove the photo by tapping it\(weakSelf?.mode == .amend ? " when in edit mode" : "").")", views: [self.tableView], section: self.thumbnailSection, item: -1, itemTo: 0, horizontalBorder: 8)
        
        self.helpView.add("\(weakSelf?.mode != .amending ? "Tap the edit button to edit the name and/or photo. " : ((weakSelf?.changed ?? true) ? "Tap the @*/Save@*/ button to save changes or the @*/Cancel@*/ button to cancel any changes." : "Tap the @*/Cancel@*/ button to leave edit mode."))", views: [self.tableView], condition: { weakSelf?.mode != .display }, section: editSection, item: 0, horizontalBorder: 8)
        
        self.helpView.add("This section shows the date when the player last played a game of Whist.", views: [self.tableView], section: self.lastPlayedSection, item: -1, itemTo: 999, horizontalBorder: 8)

        self.helpView.add("This section shows the player's high score, most bids made //etc//.", views: [self.tableView], section: self.recordsSection, item: -1, itemTo: 999, horizontalBorder: 8)

        self.helpView.add("This section shows the players statistics including games played, percentage of games won //etc//.", views: [self.tableView], section: self.statsSection, item: -1, itemTo: 999, horizontalBorder: 8)
        
        self.helpView.add("Tap the @*/Remove Player@*/ button to remove the player from this device. Note that if this player has been synced to the cloud they will still exist there and can be downloaded again in future.", views: [self.tableView], condition: { weakSelf?.mode == .amend }, section: self.deleteSection, item: 0, horizontalBorder: 8)

        self.helpView.add("Tap the {} to close @*/Player Details@*/.", bannerId: Banner.finishButton)
    }
}
