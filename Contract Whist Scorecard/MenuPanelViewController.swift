//
//  MenuPanelViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 16/08/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

enum MenuOption {
    case playGame
    case personalResults
    case everyoneResults
    case highScores
    case awards
    case profiles
    case settings
    case changePlayer
    case cancelChangePlayer
}

struct Option {
    let title: String
    let menuOption: MenuOption?
    let action: (()->())?
    
    init(title: String, menuOption: MenuOption? = nil, action: (()->())? = nil) {
        self.title = title
        self.menuOption = menuOption
        self.action = action
    }
}

protocol MenuController {
    
    var currentOption: MenuOption {get}
    
    func isVisible() -> Bool
    
    func add(suboptions: [Option], to option: MenuOption, on container: Container, highlight: Int?, disableOptions: Bool)
    
    func setAll(isEnabled: Bool)
    
    func removeSuboptions(for container: Container?)
    
    func refresh()
    
    func setNotification(message: String?, deviceName: String?)
    
    func set(playingGame: Bool)
    
    func set(gamePlayingTitle: String?)
}

class MenuPanelViewController : ScorecardViewController, MenuController, UITableViewDelegate, UITableViewDataSource {
    
    struct OptionMap {
        let mainOption: Bool
        let index: Int
    }
    
    enum TableView: Int {
        case options = 1
        case settings = 2
    }
    
    private var options: [Option] = []
    private var suboptions: [Option] = []
    private var suboptionMenuOption: MenuOption!
    private var suboptionContainer: Container!
    private var suboptionHighlight: Int? = nil
    private var optionMap: [OptionMap] = []
    internal var currentOption: MenuOption = .playGame
    private var screenshotImageView = UIImageView()
    private var changingPlayer = false
    private var disableOptions: Bool = false
    private var disableAll: Bool = false
    private var currentContainerItems: [PanelContainerItem]?
    private var imageObserver: NSObjectProtocol?
    private var notificationDeviceName: String?
    private var playingGame: Bool = false
    private var gamePlayingTitle: String? = nil

    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var thisPlayerThumbnail: ThumbnailView!
    @IBOutlet private weak var infoButton: ShadowButton!
    @IBOutlet private weak var optionsTableView: UITableView!
    @IBOutlet private weak var settingsTableView: UITableView!
    @IBOutlet private weak var notificationsView: UIView!
    @IBOutlet private weak var notificationsHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var notificationsHeadingTitleBar: TitleBar!
    @IBOutlet private weak var notificationsBodyView: UIView!
    @IBOutlet private weak var notificationsBodyLabel: UILabel!
    @IBOutlet private weak var rightBorderView: UIView!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction private func playerTapGesture(recognizer: UITapGestureRecognizer) {
        self.playerPressed()
    }
    
    @IBAction private func notificationTapGesture(recognizer: UITapGestureRecognizer) {
        if let deviceName = self.notificationDeviceName {
            self.dismissAndSelectOption(option: .playGame)
            self.rootViewController.selectAvailableDevice(deviceName: deviceName)
        }
    }
        
    // MARK: - View Overrides ========================================================================== -

    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupOptions()
        self.defaultScreenColors()
        
        // Look out for images arriving
        self.imageObserver = setPlayerDownloadNotification(name: .playerImageDownloaded)
        
        // Configure notifications panel
        self.setupNotifications()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override internal func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    
        // Layout notifications
        self.layoutNotifications()
        
        // Layout thumbnail
        self.thisPlayerThumbnail.layoutIfNeeded()
        self.showThisPlayer()
    }
    
    // MARK: - Menu Delegates ===================================================================== -
    
    internal func isVisible() -> Bool {
        return self.view.frame.width > 0
    }
    
    internal func setAll(isEnabled: Bool) {
        self.disableAll = !isEnabled
        self.reloadData()
    }
    
    func removeSuboptions(for container: Container?) {
        if container == self.suboptionContainer || container == nil {
            self.suboptions = []
            self.suboptionMenuOption = nil
            self.suboptionContainer = nil
            self.suboptionHighlight = nil
            self.disableOptions = false
            self.setupOptionMap()
            self.reloadData()
        }
    }
    
    func add(suboptions: [Option], to option: MenuOption, on container: Container, highlight: Int?, disableOptions: Bool = false) {
        if !suboptions.isEmpty || option != self.suboptionMenuOption {
            self.suboptions = suboptions
            self.suboptionHighlight = highlight
        }
        self.suboptionMenuOption = option
        self.suboptionContainer = container
        self.disableOptions = disableOptions
        self.setupOptionMap()
        self.reloadData()
    }
    
    internal func refresh() {
        self.defaultScreenColors()
        self.showThisPlayer()
        self.changingPlayer = false
        self.reloadData()
    }
    
    internal func setNotification(message: String?, deviceName: String?) {
        if let message = message {
            self.notificationsBodyLabel.text = message
            self.notificationDeviceName = deviceName
        } else {
            self.notificationDeviceName = nil
        }
        self.showNotification()
    }
    
    private func showNotification() {
        var height: CGFloat = 0
        if self.notificationDeviceName != nil && self.currentOption != .playGame {
            height = 150
        }
        
        self.notificationsHeightConstraint.constant = height
    }
    
    internal func reloadData() {
        self.optionsTableView.reloadData()
        self.settingsTableView.reloadData()
    }
    
    internal func set(playingGame: Bool) {
        self.playingGame = playingGame
        self.setupOptionMap()
        self.reloadData()
    }
    
    internal func set(gamePlayingTitle: String?) {
        self.gamePlayingTitle = gamePlayingTitle
        self.reloadData()
    }
    
    // MARK: - Option actions ===================================================================== -
    
    private func setupOptions() {
        self.options = [
            Option(title: "Play Game", menuOption: .playGame),
            Option(title: "Results", menuOption: .personalResults),
            Option(title: "Awards", menuOption: .awards),
            Option(title: "Profiles", menuOption: .profiles),
        ]
        self.setupOptionMap()
    }
    
    private func setupOptionMap() {
        self.optionMap = []
        for (index, option) in self.options.enumerated() {
            if !self.playingGame || option.menuOption == .playGame {
                self.optionMap.append(OptionMap(mainOption: true, index: index))
                if suboptionMenuOption == option.menuOption {
                    for (index, _) in self.suboptions.enumerated() {
                        self.optionMap.append(OptionMap(mainOption: false, index: index))
                    }
                }
            }
        }
    }

    // MARK: - TableView Overrides ===================================================================== -

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch TableView(rawValue: tableView.tag)! {
        case .options:
            return self.optionMap.count
        case .settings:
            return (self.playingGame ? 0 : 1)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch TableView(rawValue: tableView.tag)! {
        case .options:
            return (self.optionMap[indexPath.row].mainOption ? 40 : 35)
        case .settings:
            return 40
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Option") as! MenuPanelTableCell
        
        let (option, mainOption, index) = self.getOption(tag: tableView.tag, row: indexPath.row)
        if mainOption {
            let disabled = self.disableOptions || self.disableAll
            cell.titleLabel.text = (self.playingGame && self.gamePlayingTitle != nil ? self.gamePlayingTitle! : option.title)
            cell.titleLabel.textColor = (option.menuOption == self.currentOption ? Palette.splitSidePanel.themeText : (disabled ? Palette.normal.faintText : Palette.splitSidePanel.text))
            cell.isUserInteractionEnabled = !disabled
            cell.titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
            if option.menuOption == .playGame {
                self.setOther(isEnabled: !disabled)
            }
        } else {
            let disabled = self.disableAll
            cell.titleLabel.text = "      \(option.title)"
            cell.titleLabel.textColor = (self.suboptionHighlight == index ? Palette.splitSidePanel.themeText : (disabled ? Palette.normal.faintText : Palette.splitSidePanel.text))
            cell.titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            cell.isUserInteractionEnabled = !disabled
        }
        cell.titleLabel.setNeedsDisplay()
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = UIColor.clear
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let (option, mainOption, index) = self.getOption(tag: tableView.tag, row: indexPath.row)
        
        var changed = false
        if mainOption {
            changed = (option.menuOption != self.currentOption)
        } else {
            changed = (self.suboptionHighlight == nil || self.suboptionHighlight != index)
        }
        
        if changed {
            // Update menu
            if mainOption {
                self.addSuboptions(option: option.menuOption)
                self.setupOptionMap()
            } else if self.suboptionHighlight != nil {
                self.suboptionHighlight = index
            }
            self.reloadData()
            
            // Execute option/action
            if let action = option.action {
                action()
            } else if let menuOption = option.menuOption {
                self.dismissAndSelectOption(option: menuOption, changeOption: mainOption)
            }
        }
        return nil
    }
    
    private func getOption(tag: Int, row: Int) -> (option: Option, mainOption: Bool, index: Int) {
        var option: Option
        var mainOption: Bool
        var index: Int
        switch TableView(rawValue: tag)! {
        case .options:
            mainOption = self.optionMap[row].mainOption
            index = optionMap[row].index
            if mainOption {
                option = self.options[index]
            } else {
                option = self.suboptions[index]
            }
        case .settings:
            index = 0
            mainOption = true
            option = Option(title: "Settings", menuOption: .settings)
        }
        return (option: option, mainOption: mainOption, index: index)
    }
    
    // MARK: - Utility routines ================================================================= -
    
    private func setupNotifications() {
        self.notificationsHeadingTitleBar.set(title: "Notifications")
        self.notificationsHeadingTitleBar.set(faceColor: Palette.buttonFace.background)
        self.notificationsHeadingTitleBar.set(textColor: Palette.buttonFace.text)
        self.notificationsHeadingTitleBar.set(font: UIFont.systemFont(ofSize: 28, weight: .thin))
        self.notificationsBodyView.backgroundColor = Palette.banner.background
        self.notificationsBodyLabel.textColor = Palette.banner.text
    }
    
    private func layoutNotifications() {
        self.notificationsBodyView.layoutIfNeeded()
        self.notificationsBodyView.roundCorners(cornerRadius: 16, topRounded: false, bottomRounded: true)
    }
    
    private func setOther(isEnabled: Bool) {
        // Enable/disable other controls when enable/disable Play Game
        self.thisPlayerThumbnail.isUserInteractionEnabled = isEnabled
        self.thisPlayerThumbnail.alpha = (isEnabled ? 1.0 : 0.8)
        self.infoButton.isEnabled = isEnabled
    }
    
    private func addSuboptions(option: MenuOption?) {
        if let option = option {
            switch option {
            case .personalResults:
                self.add(suboptions: [
                    Option(title: "Personal", action: { self.dismissAndSelectOption(option: .personalResults, changeOption: false)}),
                    Option(title: "Everyone", action: { self.dismissAndSelectOption(option: .everyoneResults, changeOption: false)})],
                         to: option, on: self.container!, highlight: 0)
            default:
                self.suboptions = []
            }
        }
    }
    
    private func defaultScreenColors() {
        Palette.ignoringGameBanners {
            self.view.backgroundColor = Palette.splitSidePanel.background
            self.rightBorderView.backgroundColor = Palette.splitSideBorder.background
            self.titleLabel.textColor = Palette.splitSidePanel.contrastText
            self.titleLabel.setNeedsDisplay()
            self.thisPlayerThumbnail.set(textColor: Palette.splitSidePanel.text)
            self.thisPlayerThumbnail.setNeedsDisplay()
            self.infoButton.setBackgroundColor(Palette.splitSidePanel.faintText)
            self.infoButton.setTitleColor(Palette.splitSidePanel.text, for: .normal)
            self.infoButton.setNeedsDisplay()
        }
    }
    
    // MARK: - Image download notification ======================================================= -
    
    func setPlayerDownloadNotification(name: Notification.Name) -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) {
            (notification) in
            self.updatePlayer(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }
    
    func updatePlayer(objectID: NSManagedObjectID) {
        // Find any cells containing an image/player which has just been downloaded asynchronously
        Utility.mainThread {
            if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID) {
                if playerMO.objectID == objectID {
                    // This is this player - update player
                    self.showThisPlayer()
                }
            }
        }
    }
    
    // MARK: - Dismiss / select option =========================================================== -
    
    private func dismissAndSelectOption(option: MenuOption, changeOption: Bool = true, completion: (()->())? = nil) {
        self.rootViewController.view.isUserInteractionEnabled = false
        if option == .changePlayer || option == .playGame || option == .settings {
            self.showLastGame()
        }
        let lastOption = self.currentOption
        if changeOption {
            self.setCurrentOption(option: option)
        }
        if lastOption != .playGame {
            // Show a screenshot and dismiss current view to leave the screenshot showing before showing new screens on top of it
            self.createDismissImageView()
            if let items = self.currentContainerItems {
                self.dismissItems(items, removeSuboptions: changeOption) {
                    self.dismissAndSelectCompletion(option: option, completion: completion)
                }
            } else {
                self.dismissAndSelectCompletion(option: option, completion: completion)
            }
        } else {
            if self.changingPlayer {
                self.playerPressed()
            }
            self.dismissAndSelectCompletion(option: option, completion: completion)
        }
    }
    
    private func dismissItems(_ items: [PanelContainerItem], sequence: Int = 0, removeSuboptions: Bool = true, completion: (()->())?) {
        let viewController = items[sequence].viewController
        viewController.willDismiss()
        viewController.dismiss(animated: false, hideDismissImageView: false, removeSuboptions: removeSuboptions, completion: viewController.didDismiss)
        if sequence < items.count - 1 {
            self.dismissItems(items, sequence: sequence + 1, removeSuboptions: removeSuboptions, completion: completion)
        } else {
            completion?()
        }
    }
    
    private func setCurrentOption(option: MenuOption) {
        if option == .changePlayer || option == .playGame {
            self.currentOption = .playGame
        } else {
            self.currentOption = option
        }
        self.showNotification()
    }
    
    private func dismissAndSelectCompletion(option: MenuOption, completion: (()->())? = nil) {
        self.invokeOption(option) {
            self.rootViewController.view.isUserInteractionEnabled = true
        }
        if option == .playGame || option == .changePlayer {
            // Returning home - hide the disimiss view
            self.hideDismissImageView()
            self.rootViewController.view.isUserInteractionEnabled = true
        }
        completion?()
    }
    
    public func invokeOption(_ option: MenuOption, completion: (()->())?) {
        switch option {
        case .playGame:
            break

        case .personalResults, .everyoneResults:
            let title = (option == .personalResults ? "Personal" : "Everyone")
            let filename = "\(title)Dashboard"
            let viewController = DashboardViewController.create(
                dashboardNames: [(title: title, fileName: filename, imageName: nil)])
            self.presentInContainers([PanelContainerItem(viewController: viewController, container: .mainRight)], animated: true, completion: completion)
            
        case .highScores:
            let viewController = DashboardViewController.create(
                dashboardNames: [(title: "High Scores",  fileName: "HighScoresDashboard",  imageName: nil)])
            self.presentInContainers([PanelContainerItem(viewController: viewController, container: .mainRight)], animated: true, completion: completion)
            
        case .awards:
            let viewController = DashboardViewController.create( title: "Awards",
                 dashboardNames: [(title: "Awards",  fileName: "AwardsDashboard",  imageName: nil)],
                 allowSync: false, backgroundColor: Palette.normal, bottomInset: 0)
            let detailViewController = AwardDetailViewController.create()
            viewController.awardDetail = detailViewController
            self.presentInContainers([PanelContainerItem(viewController: viewController, container: .main),
                                      PanelContainerItem(viewController: detailViewController, container: .right)],
                                     rightPanelTitle: "", animated: true, completion: completion)
            
        case .profiles:
            let viewController = PlayersViewController.create(completion: nil)
            let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID)!
            let playerDetail = PlayerDetail()
            playerDetail.fromManagedObject(playerMO: playerMO)
            let detailViewController = PlayerDetailViewController.create(playerDetail: playerDetail, mode: .amend, playersViewDelegate: viewController, dismissOnSave: false)
            viewController.playerDetailView = detailViewController
            self.presentInContainers([PanelContainerItem(viewController: viewController, container: .main),
                                      PanelContainerItem(viewController: detailViewController, container: .right)],
                                     rightPanelTitle: playerDetail.name, animated: true, completion: completion)
            
        case .settings:
            // Need to invoke settings from root view controller
            if let settingsViewController = self.rootViewController.invokeOption(option, completion: completion) {
                self.currentContainerItems = [PanelContainerItem(viewController: settingsViewController, container: .main)]
            }
            
        default:
            // Not a genuine new option - execute via root view controller
            self.rootViewController.invokeOption(option, completion: completion)
        }
    }
    
    private func presentInContainers(_ items: [PanelContainerItem], rightPanelTitle: String? = nil, animated: Bool, completion: (() -> ())?) {
        self.currentContainerItems = items
        self.rootViewController.presentInContainers(items, rightPanelTitle: rightPanelTitle, animated: animated, completion: completion)
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func create() -> MenuPanelViewController {
        
        let storyboard = UIStoryboard(name: "MenuPanelViewController", bundle: nil)
        let menuPanelViewController = storyboard.instantiateViewController(withIdentifier: "MenuPanelViewController") as! MenuPanelViewController
        
        return menuPanelViewController
    }
    
    // MARK: - Player button ===================================================================== -
    
    private func showThisPlayer() {
        if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID) {
            self.thisPlayerThumbnail.set(data: playerMO.thumbnail, name: playerMO.name!, nameHeight: 20.0, diameter: self.thisPlayerThumbnail.frame.width)
        }
    }
    
    private func playerPressed() {
        self.rootViewController.view.isUserInteractionEnabled = false
        if !changingPlayer {
            self.dismissAndSelectOption(option: .changePlayer)
            self.thisPlayerThumbnail.name.text = "Cancel"
            self.removeSuboptions(for: nil)
        } else {
            self.rootViewController.invokeOption(.cancelChangePlayer) {
                self.rootViewController.view.isUserInteractionEnabled = true
            }
            self.showThisPlayer()
        }
        changingPlayer.toggle()
    }
}

class MenuPanelTableCell: UITableViewCell {
    @IBOutlet fileprivate weak var titleLabel: UILabel!
}
