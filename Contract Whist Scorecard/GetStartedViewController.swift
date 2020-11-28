//
//  GetStartedViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/03/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class GetStartedViewController: ScorecardViewController, ButtonDelegate, PlayerSelectionViewDelegate, CreatePlayerViewDelegate, RelatedPlayersDelegate, UIGestureRecognizerDelegate {

    private enum Section: Int {
        case downloadPlayers = 0
        case createPlayer = 1
        case createPlayerSettings = 2
    }
    
    private var location = Location()
    private var completion: (()->())?
    private var section: Section = .downloadPlayers
    private var rotated = false
    private var firstTime = true
    private var imageObserver: NSObjectProtocol?
    private var bubbleView = BubbleView()
    private var entryHelpView: HelpView!
    private var entryHelpShown = false
    private var selectingPlayer = false
    
    private let separatorHeight: CGFloat = 20.0
    private let titleOverlap: CGFloat = 25.0
    private var containerHeight: CGFloat = 0.0
    private var playerSelectionViewHeight: CGFloat = 0.0
    private var overlap: CGFloat = 0.0

    // Title bar and text field tags
    private let downloadPlayersTag = 1
    private let createPlayerTag = 2
    private var downloadFieldTag = 1
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var topSection: UIView!
    @IBOutlet private weak var bottomSection: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var getStartedLabel: UILabel!
    @IBOutlet private weak var thisPlayerThumbnailView: ThumbnailView!
    @IBOutlet private weak var thisPlayerChangeContainerView: UIView!
    @IBOutlet private weak var thisPlayerChangeButton: RoundedButton!
    @IBOutlet private weak var tapGestureRecognizer: UITapGestureRecognizer!
    @IBOutlet private weak var playerSelectionView: PlayerSelectionView!
    @IBOutlet private weak var playerSelectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var playerSelectionViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var playerSelectionViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var inputClippingContainerView: UIView!
    @IBOutlet private weak var inputClippingContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var downloadPlayersTitleBar: TitleBar!
    @IBOutlet private weak var createPlayerTitleBar: TitleBar!
    @IBOutlet private weak var downloadPlayersContainerView: UIView!
    @IBOutlet private weak var downloadPlayersView: UIView!
    @IBOutlet private weak var downloadPlayersContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var downloadPlayersContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerClippingContainerView: UIView!
    @IBOutlet private weak var createPlayerClippingContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerClippingContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerView: CreatePlayerView!
    @IBOutlet private weak var createPlayerContainerView: UIView!
    @IBOutlet private weak var createPlayerContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerSettingsView: UIView!
    @IBOutlet private weak var createPlayerSettingsContainerView: UIView!
    @IBOutlet private weak var createPlayerSettingsContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerSettingsContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var downloadIdentifierTextField: UITextField!
    @IBOutlet private weak var downloadButton: ShadowButton!
    @IBOutlet private weak var createPlayerSettingsTitleLabel: UILabel!
    @IBOutlet private weak var smallFormatHomeButton: ClearButton!
    @IBOutlet private var actionButton: [ShadowButton]!
    @IBOutlet private var formLabel: [UILabel]!
    @IBOutlet private var settingsOnLineGamesEnabledSwitch: [UISwitch]!
    @IBOutlet private var settingsOnlineGamesEnabledLabel: [UILabel]!
    @IBOutlet private var settingsSaveLocationSwitch: [UISwitch]!
    @IBOutlet private var settingsSaveLocationLabel: [UILabel]!

    // MARK: - IB Actions ============================================================================== -
        
    @IBAction func dowloadButtonPressed(_ sender: UIButton) {
        self.showRelatedPlayers()
    }
    
    @IBAction func homeButtonPressed(_ sender: UIButton) {
        self.dismiss()
    }
    
    @IBAction func helpPressed(_ sender: UIButton) {
        self.helpPressed()
    }

    @IBAction func thisPlayerChangeButtonPressed(_ sender: UIButton) {
        if !self.selectingPlayer {
            self.showPlayerSelection()
        } else {
            self.hidePlayerSelection()
        }
    }
    
    @IBAction private func tapGesture(recognizer: UITapGestureRecognizer) {
        self.thisPlayerChangeButtonPressed(self.thisPlayerChangeButton)
    }
    
    // MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initialise()
        self.setupDefaultColors()
        self.showThisPlayer()
        
        // Setup help
        self.setupHelpView()
        
        // Look out for images arriving
        imageObserver = setPlayerDownloadNotification(name: .playerImageDownloaded)
                
        // Dismiss keyboard on tapping elsewhere
        let tapGesture = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        self.view.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
        self.rotated = true
   }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let firstTime = self.firstTime
        let rotated = self.rotated
        self.firstTime = false
        self.rotated = false
        
        if firstTime || rotated {
            self.contentViewHeightConstraint.constant =
                (ScorecardUI.landscapePhone() ? ScorecardUI.screenWidth
                    : self.view.frame.height - self.view.safeAreaInsets.top)
            self.contentView.layoutIfNeeded()
            self.setupSizes()
            self.setupControls()
            if firstTime {
                self.change(section: .downloadPlayers)
            }
            self.roundCorners()
        }
        
        if rotated && self.playerSelectionViewTopConstraint.constant == 0 {
            // Resize player selection
            self.showPlayerSelection()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !self.entryHelpShown {
            self.entryHelpView.show(finishTitle: "Continue", focusBackgroundColor: UIColor.black.withAlphaComponent(0.7))
            self.entryHelpShown = true
        }
    }
        
    // MARK: - Form handling ===================================================================== -
    
    private func initialise() {
        self.setOnlineGamesEnabled(Scorecard.settings.onlineGamesEnabled)
        self.setSaveLocation(Scorecard.settings.saveLocation)
    }
    
    private func setOnlineGamesEnabled(_ enabled: Bool) {
        Scorecard.settings.onlineGamesEnabled = enabled
        Scorecard.settings.onlineGamesEnabledSettingState = (enabled ? .available : .availableNotify)
        Scorecard.settings.save()
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in control.isOn = enabled}
    }

    private func setSaveLocation(_ enabled: Bool) {
        Scorecard.settings.saveLocation = enabled
        Scorecard.settings.save()
        self.settingsSaveLocationSwitch.forEach{(control) in control.isOn = enabled}
    }
    
    private func enableControls() {
        self.thisPlayerChangeButton.isHidden = (Scorecard.shared.playerList.count <= 1)
        let homeEnabled = !Scorecard.shared.playerList.isEmpty && Scorecard.settings.thisPlayerUUID != ""
        switch self.section {
        case .downloadPlayers:
            self.downloadButton.isEnabled = (self.downloadIdentifierTextField.text != "")
            self.actionButton.forEach{(button) in button.isEnabled = homeEnabled}
        case .createPlayer:
            // Handled in CreatePlayerView
            break
        case .createPlayerSettings:
            self.actionButton.forEach{(button) in button.isEnabled = homeEnabled}
        }
        self.smallFormatHomeButton.isEnabled(homeEnabled)
    }
    
    private func showThisPlayer() {
        if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID) {
            self.thisPlayerThumbnailView.set(playerMO: playerMO, nameHeight: 15.0, diameter: self.thisPlayerThumbnailView.frame.width)
            if ScorecardUI.mediumPhoneSize() {
                self.titleLabel.isHidden = true
            }
            self.getStartedLabel.isHidden = true
            self.thisPlayerThumbnailView.isHidden = false
        } else {
            self.titleLabel.isHidden = false
            self.getStartedLabel.isHidden = ScorecardUI.smallPhoneSize()

            self.thisPlayerThumbnailView.isHidden = true
        }
    }
    
    func setPlayerDownloadNotification(name: Notification.Name) -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = Notifications.addObserver(forName: name) { [weak self] (notification) in
            self?.updatePlayer(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
            self?.playerSelectionView?.updatePlayer(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }

    func updatePlayer(objectID: NSManagedObjectID) {
        // Find any cells containing an image/player which has just been downloaded asynchronously
        Utility.mainThread {
            if Scorecard.settings.thisPlayerUUID != "" {
                if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID) {
                    if playerMO.objectID == objectID {
                        // This is this player - update player (managed object will have been updated in background
                        self.showThisPlayer()
                    }
                }
            }
        }
    }
    
    // MARK: - Change section ==================================================================== -
    
    private func change(section: Section) {
        let oldSection = self.section
        self.section = section
        self.enableControls()
        
        // Animate the change
        // Note that there are effectively two sliders here. A top-level one which slides up/down between the 'download' view and the create players views
        // And then within that there is another which slides up/down between the 'create players' and the 'create players settings' views
        
        if section == .downloadPlayers || oldSection == .downloadPlayers {
            // Moving to / from download slide top clipping section
            switch section {
            case .downloadPlayers:
                // Sort out rounding of title bar corners
                self.downloadPlayersTitleBar.set(topRounded: true, bottomRounded: false)
            default:
                // Pull the create player input view back up to touch the title bar
                self.createPlayerClippingContainerTopConstraint.constant = -self.titleOverlap
            }
            Utility.animate(duration: 0.5,completion: {
                switch section {
                case .downloadPlayers:
                    // Push the create player input view down so that it is hidden (as the clipping window is slightly too big to allow for shadow)
                    self.createPlayerClippingContainerTopConstraint.constant = self.separatorHeight
                case .createPlayer:
                    // Activate the create players window (set first responder)
                    self.createPlayerView.didBecomeActive()
                default:
                    break
                }
                // Change the rounding of the create player title bar
                self.createPlayerTitleBar.set(topRounded: true, bottomRounded: section != .createPlayer)
                // Sort out rounding of title bar corners
                self.downloadPlayersTitleBar.set(topRounded: true, bottomRounded: section != .downloadPlayers)
                // Slide (invisibly) back to the create player view if necessary (from create player settings)
                self.createPlayerContainerTopConstraint.constant = 0
            }, animations: {
                // Slide up/down to the right view
                self.downloadPlayersContainerTopConstraint.constant = -(min(1, CGFloat(section.rawValue)) * self.containerHeight)
            })
            
        } else {
            // Moving from create to/from settings - slide bottom clipping section
            Utility.animate(view: self.inputClippingContainerView, duration: 0.5, completion: {
                if section != .createPlayer {
                    // Active the create player view (set first responder)
                    self.createPlayerView.didBecomeActive()
                }
            }, animations: {
                // Slide up/down to the right view
                self.createPlayerContainerTopConstraint.constant = -(min(1, CGFloat(section.rawValue) - 1) * (self.containerHeight))
                self.createPlayerSettingsContainerTopConstraint.constant = (section == .createPlayerSettings ? -self.titleOverlap : self.separatorHeight)
                // Sort out rounding of title bar corners
                self.createPlayerTitleBar.set(topRounded: true, bottomRounded: section != .createPlayer)
            })
        }
        
    }
    
    // MARK: - Switch targets =========================================================== -

    @objc internal func onlineGamesChanged(_ onlineGamesSwitch: UISwitch) {
        if onlineGamesSwitch.isOn {
            Notifications.checkNotifications(
                refused: { (requested) in
                    if !requested {
                        self.alertMessage("You have previously refused permission for this app to send you notifications. \nThis will mean that you will not receive game invitation notifications.\nTo change this, please authorise notifications in the Whist section of the main Settings App")
                    }
                },
                request: true)
            self.setOnlineGamesEnabled(true)
        } else {
            self.setOnlineGamesEnabled(false)
        }
        self.enableControls()
    }
    
    @objc internal func saveGameLocationChanged(_ saveGameLocationSwitch: UISwitch) {
        if saveGameLocationSwitch.isOn {
            self.location.checkUseLocation(
                refused: { (requested) in
                    if !requested {
                        self.alertMessage("You have previously refused permission for this app to use your location. To change this, please allow location access 'While Using the App' in the Whist section of the main Settings App")
                    }
                    self.setSaveLocation(false)
                },
                accepted: {
                    self.setSaveLocation(true)
                },
                request: true)
            
        } else {
            self.setSaveLocation(false)
        }
        self.enableControls()
    }
    
    // MARK: - TextField Targets ======================================================== -
    
    private func addTargets(_ textField: UITextField) {
        textField.addTarget(self, action: #selector(GetStartedViewController.textFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        textField.addTarget(self, action: #selector(GetStartedViewController.textFieldShouldReturn(_:)), for: UIControl.Event.editingDidEndOnExit)
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        self.enableControls()
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.text == "" {
            // Don't do anything if blank
        } else if textField.tag == downloadFieldTag {
            self.showRelatedPlayers()
        }
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: - Create Player Delegate ============================================================= -
    
    internal func didCreatePlayer(playerDetail: PlayerDetail) {
        if Scorecard.settings.thisPlayerUUID == "" {
            self.setThisPlayer(playerUUID: playerDetail.playerUUID)
        }
        self.change(section: .createPlayerSettings)
    }



    // MARK: - Button delegate ==================================================================== -
    
    internal func buttonPressed(_ button: UIView) {
        switch button.tag {
        case downloadPlayersTag:
            self.createPlayerView.willBecomeInactive {
                self.change(section: .downloadPlayers)
                self.downloadIdentifierTextField.becomeFirstResponder()
            }
        
        case createPlayerTag:
            self.change(section: .createPlayer)
            
        default:
            break
        }
    }
    
    // MARK: - Player Selection View Delegate Handlers ======================================================= -
    
    private func showPlayerSelection() {
        self.selectingPlayer = true
        self.thisPlayerChangeButton.setTitle("Cancel")
        Utility.animate(view: self.view, duration: 0.5) {
            self.playerSelectionViewTopConstraint.constant = 0
            self.playerSelectionViewBottomConstraint.constant = 0
        }
        
        let playerList = Scorecard.shared.playerList.filter { $0.playerUUID != Scorecard.settings.thisPlayerUUID }
        self.playerSelectionView.set(players: playerList, addButton: false, updateBeforeSelect: false, scrollEnabled: true, collectionViewInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10), contentInset: UIEdgeInsets(top: 10, left: 10, bottom: 0, right: 10))
    }
    
    private func hidePlayerSelection() {
        self.selectingPlayer = false
        self.thisPlayerChangeButton.setTitle("Change")
        Utility.animate(view: self.view, duration: 0.5, completion: {
        }, animations: {
            self.playerSelectionViewTopConstraint.constant = -self.playerSelectionViewHeight
            self.playerSelectionViewBottomConstraint.constant = self.overlap
        })
    }
    
    internal func didSelect(playerMO: PlayerMO) {
        // Save player as default for device
        self.setThisPlayer(playerUUID: playerMO.playerUUID!)
        self.hidePlayerSelection()
    }
    
    private func setThisPlayer(playerUUID: String) {
        Scorecard.settings.thisPlayerUUID = playerUUID
        Scorecard.settings.save()
        self.showThisPlayer()
        self.enableControls()
    }
    
    internal func resizeView() {
        // Additional players added - resize the view
        self.showPlayerSelection()
    }

    // MARK: - Show select players view and delegate view ================================================ -
    
    private func showRelatedPlayers() {
        RelatedPlayersViewController.show(from: self, email: self.downloadIdentifierTextField.text!, descriptionMode: .lastPlayed, previousScreen: "@*/Get Started@*/ screen")
    }
    
    internal func didDownloadPlayers(playerDetailList: [PlayerDetail], emailPlayerUUID: String?) {
         if Scorecard.settings.thisPlayerUUID == "" && emailPlayerUUID != nil {
            
            if let playerDetail = playerDetailList.first(where: { $0.playerUUID == emailPlayerUUID}) {
                // Found the player whose email we entered (should usually be the case)
                self.setThisPlayer(playerUUID: playerDetail.playerUUID)
            } else {
                self.setThisPlayer(playerUUID: playerDetailList.first!.playerUUID)
            }
        }
        let downloaded = playerDetailList.count
        if downloaded > 0 {
            bubbleView.show(from: self.view, message: "\(downloaded) player\(downloaded == 1 ? "" : "s")\ndownloaded")
        }
        self.downloadIdentifierTextField.text = ""
        self.enableControls()
    }
    
    // MARK: - Tap gesture delegates ========================================================= -
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return self.helpView.isHidden
    }
    
    // MARK: - View defaults ============================================================================ -
    
    private func setupDefaultColors() {
        self.view.backgroundColor = Palette.normal.background
        
        self.bannerPaddingView.bannerColor = Palette.banner.background
        self.topSection.backgroundColor = Palette.banner.background
        self.titleLabel.textColor = Palette.banner.themeText
        self.getStartedLabel.textColor = Palette.banner.text
        
        self.thisPlayerThumbnailView.set(textColor: Palette.banner.text)
        self.thisPlayerThumbnailView.set(font: UIFont.systemFont(ofSize: 15, weight: .bold))
        self.thisPlayerChangeButton.backgroundColor = Palette.bannerShadow.background
        self.thisPlayerChangeButton.setTitleColor(Palette.banner.text, for: .normal)
        
        self.playerSelectionView.backgroundColor = Palette.buttonFace.background
        
        self.downloadPlayersTitleBar.set(faceColor: Palette.buttonFace.background)
        self.downloadPlayersTitleBar.set(textColor: Palette.buttonFace.text)
        
        self.createPlayerTitleBar.set(faceColor: Palette.buttonFace.background)
        self.createPlayerTitleBar.set(textColor: Palette.buttonFace.text)
        
        self.downloadPlayersView.backgroundColor = Palette.buttonFace.background
        self.createPlayerContainerView.backgroundColor = Palette.buttonFace.background
        self.createPlayerSettingsView.backgroundColor = Palette.buttonFace.background
        
        self.downloadButton.setBackgroundColor(Palette.banner.background)
        self.downloadButton.setTitleColor(Palette.banner.text, for: .normal)
        
        self.createPlayerSettingsTitleLabel.textColor = Palette.normal.text
                
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in control.tintColor = Palette.emphasis.background}
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in control.onTintColor = Palette.emphasis.background}
        self.settingsSaveLocationSwitch.forEach{(control) in control.tintColor = Palette.emphasis.background}
        self.settingsSaveLocationSwitch.forEach{(control) in control.onTintColor = Palette.emphasis.background}
        
        self.formLabel.forEach{(label) in label.textColor = Palette.normal.text}
        
        self.actionButton.forEach{(button) in button.setBackgroundColor(Palette.banner.background)}
        self.actionButton.forEach{(button) in button.setTitleColor(Palette.banner.text, for: .normal)}
                
    }
    
    private func setupSizes() {
        
        if !Utility.animating {
            
            // Setup heights for the input containers and clipping views
            let titleBarHeight: CGFloat = self.downloadPlayersTitleBar.frame.height
            
            let clippingHeight = self.bottomSection.frame.height - titleBarHeight - (self.view.safeAreaInsets.bottom == 0.0 ? 5.0 : self.view.safeAreaInsets.bottom)
            
            self.containerHeight = clippingHeight - titleBarHeight - self.separatorHeight - 10.0 // to allow for shadow
            self.downloadPlayersContainerHeightConstraint.constant = self.containerHeight
            self.createPlayerContainerHeightConstraint.constant = self.containerHeight
            self.createPlayerSettingsContainerHeightConstraint.constant = self.containerHeight - separatorHeight
            
            self.inputClippingContainerHeightConstraint.constant = clippingHeight
            self.createPlayerClippingContainerHeightConstraint.constant = self.containerHeight + 10.0 // to allow for shadow
            
            
            // Setup the player selection view
            self.playerSelectionViewHeight = self.view.frame.height - self.bottomSection.frame.minY + self.view.safeAreaInsets.bottom - overlap
            self.playerSelectionView.set(size: CGSize(width: UIScreen.main.bounds.width, height: self.playerSelectionViewHeight))
            self.playerSelectionViewTopConstraint.constant = -self.playerSelectionViewHeight
            self.playerSelectionViewHeightConstraint.constant = self.playerSelectionViewHeight
            self.overlap = self.playerSelectionViewBottomConstraint.constant
        }
    }
    
    private func roundCorners() {
        self.downloadPlayersView.layoutIfNeeded()
        self.createPlayerView.layoutIfNeeded()
        self.createPlayerSettingsView.layoutIfNeeded()
        self.playerSelectionView.layoutIfNeeded()
        self.downloadPlayersView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
        self.createPlayerContainerView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
        self.createPlayerSettingsView.roundCorners(cornerRadius: 8.0, topRounded: true, bottomRounded: true)
        self.playerSelectionView.roundCorners(cornerRadius: 8.0)
    }
    
    private func setupControls() {
       
        if ScorecardUI.smallPhoneSize() {
            self.actionButton.forEach{(button) in button.isHidden = true}
        } else {
            self.smallFormatHomeButton.isHidden = true
        }
       
        self.thisPlayerChangeContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.thisPlayerChangeButton.roundCorners(cornerRadius: self.thisPlayerChangeButton.frame.height / 2.0)
       
        self.bottomSection.addShadow()
        
        self.downloadPlayersTitleBar.set(font: UIFont.systemFont(ofSize: 17, weight: .bold))
            
        self.createPlayerTitleBar.set(font: UIFont.systemFont(ofSize: 17, weight: .bold))
        self.createPlayerTitleBar.set(topRounded: true, bottomRounded: true)

        self.addTargets(self.downloadIdentifierTextField)
        
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in control.addTarget(self, action: #selector(GetStartedViewController.onlineGamesChanged(_:)), for: .valueChanged) }
        
        self.settingsSaveLocationSwitch.forEach{(control) in control.addTarget(self, action: #selector(GetStartedViewController.saveGameLocationChanged(_:)), for: .valueChanged) }
        
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in self.resizeSwitch(control, factor: 0.75)}

        self.settingsSaveLocationSwitch.forEach{(control) in self.resizeSwitch(control, factor: 0.75)}
        
        self.actionButton.forEach{(button) in button.toCircle()}
    }
    
    public func resizeSwitch(_ control: UISwitch, factor: CGFloat) {
        control.transform = CGAffineTransform(scaleX: factor, y: factor)
    }

    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: ScorecardViewController, completion: (()->())? = nil) {
        
        let storyboard = UIStoryboard(name: "GetStartedViewController", bundle: nil)
        let getStartedViewController: GetStartedViewController = storyboard.instantiateViewController(withIdentifier: "GetStartedViewController") as! GetStartedViewController
        
        getStartedViewController.completion = completion
        
        viewController.present(getStartedViewController, animated: true, container: .none, completion: nil)
    }
    
    private func dismiss() {
        Notifications.removeObserver(self.imageObserver)
        self.imageObserver = nil
        Scorecard.settings.syncEnabled = true
        Scorecard.settings.save()
        
        // Save to iCloud
        Scorecard.settings.saveToICloud()
        
        // Update subscriptions
        Notifications.addOnlineGameSubscription(Scorecard.settings.thisPlayerUUID)
        Notifications.updateHighScoreSubscriptions()
        
        self.dismiss(animated: true, completion: self.completion)
    }
}

extension GetStartedViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
                
        self.addIntroduction(helpView: self.helpView)
        
        self.helpView.add("Once you have created some players the @*/Home@*/ button will become enabled.\n\nTap it to start playing Whist.", views: [self.smallFormatHomeButton], horizontalBorder: 8, verticalBorder: 4)
        
        self.helpView.add("The first player you create becomes the default player for this device and is displayed here. This will normally be the owner of the device.", views: [self.thisPlayerThumbnailView], border: 4)
        
        self.helpView.add("You have chosen to change the default player for this device. Tap on a player to select them.", views: [self.playerSelectionView], condition: { self.selectingPlayer }, border: 4)
        
        self.helpView.add("\(!self.selectingPlayer ? "When you have created 2 or more players you are able to change the default player. Tap the @*/Change@*/ button to change the default player for this device to another player." : "Tap the @*/Cancel@*/ button to keep the current default player.")", views: [self.thisPlayerChangeButton], radius: self.thisPlayerChangeButton.frame.height / 2)
        
        self.helpView.add("To download players who have played before on another device enter one of their Unique Ids here.", views: [self.downloadIdentifierTextField], condition: { self.section == .downloadPlayers && !self.selectingPlayer })
        
        self.helpView.add("Once you have entered a player's Unique Id tap the @*/Download Players from iCloud@*/ to choose the players to download.", views: [self.downloadButton], condition: { self.section == .downloadPlayers && !self.selectingPlayer })
        
        self.addOnlineGamesSwitchHelp(section: .downloadPlayers)
        
        self.addSaveLocationHelp(section: .downloadPlayers)
        
        self.addHomeButtonHelp(section: .downloadPlayers)
        
        self.helpView.add("Tap the @*/Download Players@*/ button to download existing players from iCloud", views: [self.downloadPlayersTitleBar], condition: {self.section != .downloadPlayers && !self.selectingPlayer})
        
        self.helpView.add("Tap the @*/Create New Player@*/ button to create a new player who has not already been created on another device.", views: [self.createPlayerTitleBar], condition: { self.section != .createPlayer && !self.selectingPlayer})
        
        self.createPlayerView.addHelp(to: self.helpView, condition: { self.section == .createPlayer  && !self.selectingPlayer})
        
        self.addOnlineGamesSwitchHelp(section: .createPlayerSettings)
        
        self.addSaveLocationHelp(section: .createPlayerSettings)

        self.addHomeButtonHelp(section: .createPlayerSettings)
        
        self.entryHelpView = HelpView(in: self)

        self.addIntroduction(helpView: self.entryHelpView)

    }
    
    private func addIntroduction(helpView: HelpView) {
        helpView.add("^^Welcome to Whist!^^\n\nTo get started you need to create some players.\n\nIf you have played before on another device, you can download players from iCloud by entering your Unique Id.\n\nIf you have not played before tap the @*/Create New Player@*/ button to create a new player from scratch.\n\nOn nearly every screen in the @*/Whist app@*/ you will find a " + NSAttributedString(imageName: "system.questionmark.circle.fill", color: Palette.bannerShadow.background) + " button. Tapping it will display help for the screen.")
    }
    
    private func addOnlineGamesSwitchHelp(section: Section) {
        var helpLabel: UILabel?
        var helpSwitch: UISwitch?
        
        self.settingsOnlineGamesEnabledLabel.forEach { (label) in
            if label.tag == section.rawValue {
                helpLabel = label
            }
        }
        self.settingsOnLineGamesEnabledSwitch.forEach { (switchControl) in
            if switchControl.tag == section.rawValue {
                helpSwitch = switchControl
            }
        }
        
        self.helpView.add("If you want to play Whist with players on other devices (as opposed to simply scoring a game played with cards) you need to enable online games.\n\nFor this to work the App needs to send notifications between the devices so you will be asked to confirm that you are happy with this if you switch this option on.", views: [helpLabel, helpSwitch], condition: { self.section == section && !self.selectingPlayer }, horizontalBorder: 8)
        
    }
    
    private func addSaveLocationHelp(section: Section) {
        var helpLabel: UILabel?
        var helpSwitch: UISwitch?
        
        self.settingsSaveLocationLabel.forEach { (label) in
            if label.tag == section.rawValue {
                helpLabel = label
            }
        }
        self.settingsSaveLocationSwitch.forEach { (switchControl) in
            if switchControl.tag == section.rawValue {
                helpSwitch = switchControl
            }
        }
        
        self.helpView.add("It is great to save the location of each game you play so that you can look back and see all the amazing places you've played @*/Whist@*/.\n\nFor this to work the App needs access to your current location when the app is running and you will be asked to confirm that you are happy with this if you switch this option on.", views: [helpLabel, helpSwitch], condition: { self.section == section && !self.selectingPlayer }, horizontalBorder: 8)
        
    }
    
    private func addHomeButtonHelp(section: Section) {
        var helpButton: UIButton?
        
        self.actionButton.forEach { (button) in
            if button.tag == section.rawValue {
                helpButton = button
            }
        }
        
        if let helpButton = helpButton {
            self.helpView.add("Once you have created some players the @*/Home@*/ button will become enabled.\n\nTap it to start playing Whist.", views: [helpButton], condition: { self.section == section && !self.selectingPlayer }, radius: helpButton.frame.height / 2)
        }
    }
    
}
