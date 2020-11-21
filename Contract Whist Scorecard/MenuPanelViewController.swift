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

class Option {
    fileprivate let title: String
    fileprivate let releaseTitle: String?
    fileprivate let titleColor: UIColor?
    fileprivate var menuOption: MenuOption?
    fileprivate let action: (()->())?
    fileprivate let releaseAction: (()->())?
    fileprivate let spaceBefore: CGFloat
    fileprivate var pressed: Bool
    fileprivate var id: AnyHashable?
    
    init(title: String, releaseTitle: String? = nil, titleColor: UIColor? = nil, menuOption: MenuOption? = nil, spaceBefore:CGFloat = 0.0, id: AnyHashable? = nil, action: (()->())? = nil, releaseAction: (()->())? = nil) {
        self.title = title
        self.releaseTitle = releaseTitle
        self.titleColor = titleColor
        self.menuOption = menuOption
        self.spaceBefore = spaceBefore
        self.id = id
        self.action = action
        self.releaseAction = releaseAction
        self.pressed = false
    }
}



protocol MenuSwipeDelegate : class {
    func swipeGesture(direction: UISwipeGestureRecognizer.Direction) -> Bool
}

protocol MenuController {
    
    var currentOption: MenuOption {get}
    
    var isVisible: Bool {get}
    
    var swipeDelegate: MenuSwipeDelegate? {get set}
    
    func highlightSuboption(id: AnyHashable)
    
    func menuDidDisappear()
    
    func rightPanelDidDisappear(completion: (()->())?)
    
    func add(suboptions: [Option], to option: MenuOption, on container: Container, highlight: Int?, disableOptions: Bool)
    
    func setAll(isEnabled: Bool)
    
    func removeSuboptions(for container: Container?)
    
    func refresh()
    
    func reset()
    
    func setNotification(message: String?, deviceName: String?)
    
    func set(playingGame: Bool)
    
    func set(gamePlayingTitle: String?)
    
    func getSuboptionView(id: AnyHashable?) -> (view: UITableView, item: Int, title: NSAttributedString, positionSort: CGFloat)?
    
    func showHelp(helpElement: HelpViewElement, showNext: Bool, completion: @escaping (Bool)->())
    
    func swipeGesture(direction: UISwipeGestureRecognizer.Direction)
}

class MenuPanelViewController : ScorecardViewController, MenuController, UITableViewDelegate, UITableViewDataSource {
    
    struct OptionMap {
        let mainOption: Bool
        let index: Int
        let id: AnyHashable?
        var highlight: Bool
        
        init(mainOption: Bool, index: Int, id: AnyHashable? = nil, highlight: Bool = false) {
            self.mainOption = mainOption
            self.index = index
            self.id = id
            self.highlight = highlight
        }
    }
    
    enum TableView: Int {
        case options = 1
        case settings = 2
    }
    
    internal weak var swipeDelegate: MenuSwipeDelegate?
    private var options: [Option] = []
    private var suboptions: [Option] = []
    private var suboptionMenuOption: MenuOption!
    private var suboptionContainer: Container!
    private var optionMap: [OptionMap] = []
    internal var currentOption: MenuOption = .playGame
    internal var lastOption: MenuOption?
    private var screenshotImageView = UIImageView()
    private var changingPlayer = false
    private var disableOptions: Bool = false
    private var disableAll: Bool = false
    private var currentContainerItems: [PanelContainerItem]?
    private var imageObserver: NSObjectProtocol?
    private var notificationDeviceName: String?
    private var playingGame: Bool = false
    private var gamePlayingTitle: String? = nil
    private var helpViewAfterPlayGame: HelpView!
    private var helpViewAfterOther: HelpView!

    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var thisPlayerContainer: UIView!
    @IBOutlet private weak var thisPlayerThumbnail: ThumbnailView!
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
            if self.currentOption == .settings {
                // Need to avoid restart of comms on exit from settings
                self.rootViewController.setNoSettingsRestart()
            }
            self.dismissAndSelectOption(option: .playGame) {
                self.rootViewController.selectAvailableDevice(deviceName: deviceName)
            }
        }
    }
    
    @objc internal func menuPanelHelpPressed(_ sender: UIButton) {
        
        func rootHelpView(isHidden: Bool) {
            self.rootViewController.helpView.isHidden = isHidden
            if !isHidden {
                self.rootViewController.view.bringSubviewToFront(self.rootViewController.helpView)
            }
        }
        
        func completion() {
            self.view.superview?.insertSubview(self.view, at: 1)
            rootHelpView(isHidden: true)
        }
        
        rootHelpView(isHidden: false) // Show the root help view to mask out any tap gestures below
        
        if currentOption == .playGame && self.rootViewController.viewControllerStack.isEmpty {
            // Show menu initial menu panel help followed by option help followed by final menu panel help
            self.view.superview?.bringSubviewToFront(self.view)
            self.helpView.show(alwaysNext: true) { (finishPressed) in
                self.view.superview?.insertSubview(self.view, at: 1)
                if !finishPressed {
                    self.rootViewController.panelhelpPressed(alwaysNext: false) { (finishPressed) in
                        if !finishPressed {
                            self.view.superview?.bringSubviewToFront(self.view)
                            rootHelpView(isHidden: false)
                            self.helpViewAfterPlayGame.show(alwaysNext: false) { (finishPressed) in
                                completion()
                            }
                        } else {
                            completion()
                        }
                    }
                } else {
                    completion()
                }
            }
        } else {
            self.rootViewController.panelhelpPressed(alwaysNext: false) { (finishPressed) in
                if !finishPressed {
                    self.view.superview?.bringSubviewToFront(self.view)
                    rootHelpView(isHidden: false)
                    self.helpViewAfterOther.show(alwaysNext: false) { (finishPressed) in
                        completion()
                    }
                } else {
                    completion()
                }
            }
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
        
        // Show this player
        self.showThisPlayer()
        
        // Set up help
        self.helpViewAfterPlayGame = HelpView(in: self)
        self.helpViewAfterOther = HelpView(in: self)
        self.setupHelpViews()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
    }
    
    override internal func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    
        // Layout notifications
        self.layoutNotifications()
    }
    
    // MARK: - Menu Delegates ===================================================================== -
    
    internal var isVisible: Bool {
        return self.rootViewController.isVisible(container: .left)
    }
    
    internal func menuDidDisappear() {
        // Release any pressed press and hold buttons
        for option in self.suboptions {
            if option.pressed {
                option.releaseAction?()
            }
        }
    }
    
    internal func rightPanelDidDisappear(completion: (()->())?) {
        var dismissItems: [PanelContainerItem] = []
        if let items = self.currentContainerItems {
            for (index, item) in items.reversed().enumerated() {
                if item.container == .right {
                    dismissItems.append(item)
                    self.currentContainerItems?.remove(at: index)
                } else {
                    item.viewController.rightPanelDidDisappear()
                }
            }
        }
        if !dismissItems.isEmpty {
            self.dismissItems(dismissItems, completion: completion)
            self.rootViewController.showLastGame()
        } else {
            completion?()
        }
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
            self.disableOptions = false
            self.setupOptionMap()
            self.reloadData()
        }
    }
    
    func swipeGesture(direction: UISwipeGestureRecognizer.Direction) {
        
        if self.gameMode == .none {
            // First check if delegate wants to handle a left swipe
            if direction == .right || !(self.swipeDelegate?.swipeGesture(direction: direction) ?? false) {
                
                if !disableAll && !disableOptions {
                    
                    if let currentRow = self.optionMap.firstIndex(where: { optionFromMap($0).menuOption == self.currentOption }) {
                        
                        if direction == .right && currentRow != 0 {
                            self.selectRow(tableView: .options, row: 0, animation: .uncoverToRight)
                        } else {
                            
                            let offset = (direction == .left ? 1 : -1)
                            var nextRow = currentRow + offset
                            while nextRow >= 0 && nextRow < self.optionMap.count {
                                let optionMap = self.optionMap[nextRow]
                                let option = self.optionFromMap(optionMap)
                                if (self.currentOption != option.menuOption && optionMap.mainOption) {
                                    // Select this option
                                    self.selectRow(tableView: .options, row: nextRow, animation: direction == .right ? .uncoverToRight : .coverFromRight)
                                    break
                                }
                                nextRow = nextRow + offset
                            }
                        }
                    }
                }
            }
        }
    }
    
    func highlightSuboption(id: AnyHashable) {
        for index in 0..<self.optionMap.count {
            self.optionMap[index].highlight = false
        }
        if let index = self.optionMap.firstIndex(where: {$0.id == id}) {
            self.optionMap[index].highlight = true
        }
        self.reloadData()
    }
    
    func optionFromMap(_ optionMap: OptionMap) -> Option {
        if optionMap.mainOption {
            return options[optionMap.index]
        } else {
            return suboptions[optionMap.index]
        }
    }
    
    private func optionRow(_ menuOption: MenuOption?) -> Int? {
        return self.optionMap.firstIndex(where: {self.optionFromMap($0).menuOption == menuOption})
    }
    
    func add(suboptions: [Option], to option: MenuOption, on container: Container, highlight: Int?, disableOptions: Bool = false) {
        if !suboptions.isEmpty || option != self.suboptionMenuOption {
            self.suboptions = suboptions
            self.suboptions.forEach{(suboption) in suboption.menuOption = option}
        }
        self.suboptionMenuOption = option
        self.suboptionContainer = container
        self.disableOptions = disableOptions
        self.setupOptionMap()
        self.reloadData()
    }
    
    func getSuboptionView(id: AnyHashable?) -> (view: UITableView, item: Int, title: NSAttributedString, positionSort: CGFloat)? {
        if let item = self.optionMap.firstIndex(where: {$0.mainOption == false && self.suboptions[$0.index].id == id}) {
            return (self.optionsTableView, item, NSAttributedString(markdown: "@*/\(self.suboptions[self.optionMap[item].index].title)@*/ menu option"), CGFloat(item))
        } else {
            return nil
        }
    }
        
    func showHelp(helpElement: HelpViewElement, showNext: Bool, completion: @escaping (Bool)->()) {
        self.view.superview?.bringSubviewToFront(self.view)
        self.helpView.showMenuElement(element: helpElement, showNext: showNext, completion: { (finishPressed) in
            self.view.superview?.insertSubview(self.view, at: 1)
            completion(finishPressed)
        })
    }
    
    internal func reset() {
        self.setCurrentOption(option: .playGame)
        self.refresh()
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
        if self.playingGame != playingGame {
            self.playingGame = playingGame
            self.setupOptionMap()
            self.reloadData()
        }
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
                    for (index, suboption) in self.suboptions.enumerated() {
                        self.optionMap.append(OptionMap(mainOption: false, index: index, id: suboption.id))
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
            if let (option, mainOption, _) = self.getOption(tableView: .options, row: indexPath.row) {
                return (mainOption ? 40 : 35) + option.spaceBefore
            } else {
                return 40
            }
        case .settings:
            return 40
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Option") as! MenuPanelTableCell
        
        if let (option, mainOption, _) = self.getOption(tableView: TableView(rawValue: tableView.tag)!, row: indexPath.row) {
            if mainOption {
                let disabled = self.disableOptions || self.disableAll
                cell.titleLabel.text = (self.playingGame && self.gamePlayingTitle != nil ? self.gamePlayingTitle! : option.title)
                cell.titleLabel.textColor = (option.menuOption == self.currentOption ? Palette.leftSidePanel.themeText : (disabled ? Palette.normal.faintText : Palette.leftSidePanel.text))
                cell.titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
                cell.helpButton.isHidden = (option.menuOption != self.currentOption)
                cell.helpButton.addTarget(self, action: #selector(MenuPanelViewController.menuPanelHelpPressed), for: .touchUpInside)
                cell.settingsBadgeButton?.isHidden = true
                if option.menuOption == .playGame {
                    self.setOther(isEnabled: !disabled)
                } else if option.menuOption == .settings {
                    let count = Scorecard.settings.notifyCount()
                    if count > 0 {
                        cell.settingsBadgeButton.setTitle("\(count)", for: .normal)
                        cell.settingsBadgeButton.setBackgroundColor(Palette.alwaysTheme.background)
                        cell.settingsBadgeButton.setTitleColor(Palette.alwaysTheme.text, for: .normal)
                        cell.settingsBadgeButton.isHidden = false
                    }
                }
            } else {
                let disabled = self.disableAll
                cell.titleLabel.text = "      \((option.pressed ? option.releaseTitle! : option.title))"
                cell.titleLabel.textColor = option.titleColor ?? (self.optionMap[indexPath.row].highlight ? Palette.leftSidePanel.themeText : (disabled ? Palette.normal.faintText : Palette.leftSidePanel.text))
                cell.titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
                cell.helpButton.isHidden = true
            }
            cell.titleLabelTopConstraint.constant = option.spaceBefore
            cell.titleLabel.setNeedsDisplay()
            cell.selectedBackgroundView = UIView()
            cell.selectedBackgroundView?.backgroundColor = UIColor.clear
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        self.selectRow(tableView: TableView(rawValue: tableView.tag)!, row: indexPath.row)
        return nil
    }

    func selectRow(tableView: TableView, row: Int, animation: ViewAnimation? = nil) {
        if let (option, mainOption, _) = self.getOption(tableView: tableView, row: row) {
            var changed = false
            var action = option.action
            if !self.disableAll {
                if mainOption {
                    if !self.disableOptions {
                        changed = (option.menuOption != self.currentOption)
                    }
                } else {
                    if !self.disableAll {
                        if let releaseAction = option.releaseAction, let _ = option.releaseTitle {
                            if option.pressed {
                                action = releaseAction
                            }
                            option.pressed.toggle()
                            changed = true
                        } else {
                            changed = true
                        }
                    }
                }
            }
            
            if changed {
                // Execute option/action
                if action != nil {
                    action?()
                } else if let menuOption = option.menuOption {
                    self.dismissAndSelectOption(option: menuOption, changeOption: mainOption, animation: animation)
                }
                // Update menu
                self.reloadData()
            }
        }
    }
    
    private func getOption(tableView: TableView, row: Int) -> (option: Option, mainOption: Bool, index: Int)? {
        var option: Option
        var mainOption: Bool
        var index: Int
        switch tableView {
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
        self.thisPlayerThumbnail.alpha = (isEnabled ? 1.0 : 0.6)
    }
    
    private func defaultScreenColors() {
        Palette.ignoringGameBanners {
            self.view.backgroundColor = Palette.leftSidePanel.background
            self.rightBorderView.backgroundColor = Palette.leftSidePanelBorder.background
            self.titleLabel.textColor = Palette.leftSidePanel.contrastText
            self.titleLabel.setNeedsDisplay()
            self.thisPlayerThumbnail.set(textColor: Palette.leftSidePanel.text)
            self.thisPlayerThumbnail.setNeedsDisplay()
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
    
    private func dismissAndSelectOption(option: MenuOption, changeOption: Bool = true, animation: ViewAnimation? = nil, completion: (()->())? = nil) {
        
        if changeOption {
            self.setCurrentOption(option: option)
        }
        
        var animation: ViewAnimation! = animation
        if animation == nil {
            if option == .settings {
                animation = .coverFromBottom
            } else if self.lastOption == .settings {
                animation = .uncoverToBottom
            } else {
                if let currentRow = self.optionRow(self.currentOption), let lastRow = self.optionRow(self.lastOption) {
                    if currentRow > lastRow {
                        animation = .coverFromRight
                    } else {
                        animation = .uncoverToRight
                    }
                } else {
                    animation = .coverFromRight
                }
            }
        }
      
        self.rootViewController.view.isUserInteractionEnabled = false
        let returningHome = (option == .changePlayer || option == .playGame)
        let dismissAnimation: ViewAnimation = (returningHome ? (self.lastOption == .settings ? .uncoverToBottom : .uncoverToRight) : .none)
        
        if returningHome {
            self.showLastGame()
        }

        if !returningHome {
            self.createDismissSnapshot(container: .mainRight)
        }
        
        if self.lastOption != .playGame {
            // Show a screenshot and dismiss current view to leave the screenshot showing before showing new screens on top of it
            if let items = self.currentContainerItems {
                self.dismissItems(items, animation: dismissAnimation, removeSuboptions: changeOption) {
                    self.dismissAndSelectCompletion(option: option, animation: animation, completion: completion)
                }
            } else {
                self.dismissAndSelectCompletion(option: option, animation: animation, completion: completion)
            }
        } else {
            if self.changingPlayer {
                self.playerPressed()
            }
            self.dismissAndSelectCompletion(option: option, animation: animation, completion: completion)
        }
    }
    
    private func dismissItems(_ items: [PanelContainerItem], animation: ViewAnimation = .none, sequence: Int = 0, removeSuboptions: Bool = true, completion: (()->())? = nil) {
        let viewController = items[sequence].viewController
        viewController.willDismiss()
        // Animate views before dismissing view controller
        ViewAnimator.animate(rootView: self.rootViewController.view,
            clippingView: self.rootViewController.view(container: .mainRight),
            oldViews: items.map{$0.viewController.view}, animation: animation, layout: true,
             completion: {
                viewController.dismiss(animated: false, hideDismissSnapshot: false, removeSuboptions: removeSuboptions, completion: viewController.didDismiss)
                if sequence < items.count - 1 {
                    self.dismissItems(items, sequence: sequence + 1, removeSuboptions: removeSuboptions, completion: completion)
                } else {
                    completion?()
                }
             }
        )
    }

    
    private func setCurrentOption(option: MenuOption) {
        self.lastOption = self.currentOption
        if option == .changePlayer || option == .playGame {
            self.currentOption = .playGame
        } else {
            self.currentOption = option
        }
        self.showNotification()
    }
    
    private func dismissAndSelectCompletion(option: MenuOption, animation: ViewAnimation, completion: (()->())? = nil) {
        self.currentContainerItems = []
        self.invokeOption(option, animation: animation) {
            self.rootViewController.view.isUserInteractionEnabled = true
            completion?()
        }
    }
    
    private func invokeOption(_ option: MenuOption, animation: ViewAnimation, completion: (()->())?) {
        
        self.swipeDelegate = nil
        
        switch option {
        case .playGame:
            completion?()

        case .personalResults, .everyoneResults:
            let viewController = DashboardViewController.create(
                dashboardNames: [
                    DashboardName(title: "Personal", returnTo: "Personal", fileName: "PersonalDashboard", helpId: "ersonalResults"),
                    DashboardName(title: "Everyone", returnTo: "Everyone", fileName: "EveryoneDashboard", helpId: "everyoneResults")],
                showCarousel: false, initialPage: (animation.leftMovement ? 0 : 1),
                completion: self.optionCompletion)
            self.presentInContainers([PanelContainerItem(viewController: viewController, container: .mainRight)], animation: animation, completion: completion)
            
        case .highScores:
            let viewController = DashboardViewController.create(
                dashboardNames: [DashboardName(title: "High Scores", fileName: "HighScoresDashboard", helpId: "highScores")], showCarousel: false, completion: self.optionCompletion)
            self.presentInContainers([PanelContainerItem(viewController: viewController, container: .mainRight)], animation: animation, completion: completion)
            
        case .awards:
            let viewController = DashboardViewController.create( title: "Awards",
                 dashboardNames: [DashboardName(title: "Awards",  fileName: "AwardsDashboard",  helpId: "awards")],
                 allowSync: false, backgroundColor: Palette.normal, bottomInset: 0,
                 showCarousel: false, completion: self.optionCompletion)
            var items = [PanelContainerItem(viewController: viewController, container: .main)]
            
            if self.rootViewController.isVisible(container: .right) {
                let detailViewController = AwardDetailViewController.create()
                detailViewController.rootViewController = self.rootViewController
                detailViewController.rootViewController.detailDelegate = detailViewController
                viewController.awardDetail = detailViewController
                items.append(PanelContainerItem(viewController: detailViewController, container: .right))
            }
            
            self.presentInContainers(items, rightPanelTitle: "", animation: animation, completion: completion)
            
        case .profiles:
            let viewController = PlayersViewController.create(completion: self.optionCompletion)
            var items = [PanelContainerItem(viewController: viewController, container: .main)]
            var title = ""
            
            if self.rootViewController.isVisible(container: .right) {
                let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID)!
                let playerDetail = PlayerDetail()
                playerDetail.fromManagedObject(playerMO: playerMO)
                let detailViewController = PlayerDetailViewController.create(playerDetail: playerDetail, mode: .amend, playersViewDelegate: viewController, dismissOnSave: false)
                detailViewController.rootViewController = self.rootViewController
                detailViewController.rootViewController.detailDelegate = detailViewController
                viewController.playerDetailView = detailViewController
                items.append(PanelContainerItem(viewController: detailViewController, container: .right))
                title = playerDetail.name
            }
            
            self.presentInContainers(items, rightPanelTitle: title, animation: animation, completion: completion)
            
        case .settings:
            // Need to invoke settings from root view controller
            if let settingsViewController = self.rootViewController.invokeOption(option, animation: animation, completion: completion) {
                self.currentContainerItems = [PanelContainerItem(viewController: settingsViewController, container: .mainRight)]
            }
            
        default:
            // Not a genuine new option - execute via root view controller
            self.rootViewController.invokeOption(option, animation: animation, completion: completion)
        }
    }
    
    private func optionCompletion() {
        if !self.isVisible {
            // Completing option but menu no longer visible - reset and re-allocate screen space
            self.reset()
            self.rootViewController.allocateContainerSizes()
        }
    }
    
    private func presentInContainers(_ items: [PanelContainerItem], rightPanelTitle: String? = nil, animation: ViewAnimation, completion: (() -> ())?) {
        self.currentContainerItems = items
        self.rootViewController.presentInContainers(items, rightPanelTitle: rightPanelTitle, animation: animation, completion: completion)
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
        if !self.playingGame {
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
}

class MenuPanelTableCell: UITableViewCell {
    @IBOutlet fileprivate weak var titleLabel: UILabel!
    @IBOutlet fileprivate weak var titleLabelTopConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var helpButton: HelpButton!
    @IBOutlet fileprivate weak var settingsBadgeButton: ShadowButton!
}

extension MenuPanelViewController {
    
    internal func setupHelpViews() {
        
        self.helpView.reset()
        
        self.helpView.add("This shows you who the default player for this device is. You can change the default player by tapping the image", views: [self.thisPlayerThumbnail], border: 8)
        
        self.helpViewAfterPlayGame.reset()
        
        for (item, element) in self.optionMap.enumerated() {
            if element.mainOption {
                let option = self.options[element.index]
                switch option.menuOption {
                case .playGame:
                    self.helpViewAfterPlayGame.add("This @*/Play Game@*/ menu option displays the main home page which allows you to start or join a game.", views: [self.optionsTableView], item: item, horizontalBorder: 16)
                case .personalResults:
                    self.helpViewAfterPlayGame.add("The @*/Results@*/ menu option allows you to view dashboards showing your own history and statistics and history and statistics for all players on this device. You can drill into each tile in the dashboard to see supporting data.", views: [self.optionsTableView], item: item, horizontalBorder: 16)
                case .awards:
                    self.helpViewAfterPlayGame.add("The @*/Awards@*/ menu option displays the awards achieved so far by this player and other awards which are available to be achieved in the future", views: [self.optionsTableView], item: item, horizontalBorder: 16)
                case .profiles:
                    self.helpViewAfterPlayGame.add("The @*/Profiles@*/ menu option allows you to add/remove players from this device or to view/modify the details of an existing player", views: [self.optionsTableView], item: item, horizontalBorder: 16)
                default:
                    break
                }
            }
        }
            
        let notify = Scorecard.settings.notifyCount() > 0
        self.helpViewAfterPlayGame.add("The @*/Settings@*/ menu option allows you to customise the Whist app to meet your individual requirements. Options include choosing a colour theme for your device.\(notify ? "\n\nThe badge indicates that your settings might not be optimal or new settings are available. Go into @*/Settings@*/ to get more details." : "")", views: [self.settingsTableView], item: 0, horizontalBorder: 16)
    
        self.helpViewAfterOther.reset()
        
        self.helpViewAfterOther.add("The @*/Notifications@*/ pane will show you if someone has invited you to a game while you are not in the @*/Play Game@*/ screen.\n\nTap the notification to join the game.\n\nIf there is more than one game available you will just be taken to the @*/Play Game@*/ screen where you can choose which game to join.", views: [notificationsView], radius: 16)
        
    }
}

