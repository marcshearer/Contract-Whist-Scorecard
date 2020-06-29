//
//  GetStartedViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/03/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class GetStartedViewController: ScorecardViewController, ButtonDelegate, PlayerViewImagePickerDelegate, PlayerSelectionViewDelegate {

    private enum Section: CGFloat {
        case downloadPlayers = 0
        case createPlayer = 1
        case createPlayerSettings = 2
    }
    
    private var location = Location()
    private var completion: (()->())?
    private var section: Section = .downloadPlayers
    private var playerDetail = PlayerDetail()
    private var createPlayerImagePickerPlayerView: PlayerView!
    private var rotated = false
    private var firstTime = true
    private var imageObserver: NSObjectProtocol?
    
    private let separatorHeight: CGFloat = 20.0
    private var containerHeight: CGFloat = 0.0
    private var playerSelectionViewHeight: CGFloat = 0.0

    private let downloadPlayers = 1
    private let createPlayer = 2

    private var createNameFieldTag = 1
    private var createIDFieldTag = 2
    private var downloadFieldTag = 3
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var topSection: UIView!
    @IBOutlet private weak var bottomSection: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var getStartedLabel: UILabel!
    @IBOutlet private weak var thisPlayerThumbnailView: ThumbnailView!
    @IBOutlet private weak var thisPlayerChangeContainerView: UIView!
    @IBOutlet private weak var thisPlayerChangeButton: RoundedButton!
    @IBOutlet private weak var tapGestureRecognizer: UITapGestureRecognizer!
    @IBOutlet private weak var infoButtonContainer: UIView!
    @IBOutlet private weak var infoButton: RoundedButton!
    @IBOutlet private weak var playerSelectionView: PlayerSelectionView!
    @IBOutlet private weak var playerSelectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var playerSelectionViewTopConstraint: NSLayoutConstraint!
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
    @IBOutlet private weak var createPlayerView: UIView!
    @IBOutlet private weak var createPlayerContainerView: UIView!
    @IBOutlet private weak var createPlayerContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerSettingsView: UIView!
    @IBOutlet private weak var createPlayerSettingsContainerView: UIView!
    @IBOutlet private weak var createPlayerSettingsContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerSettingsContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var downloadIdentifierTextField: UITextField!
    @IBOutlet private weak var downloadButton: RoundedButton!
    @IBOutlet private weak var createPlayerNameTextField: UITextField!
    @IBOutlet private weak var createPlayerNameErrorLabel: UILabel!
    @IBOutlet private weak var createPlayerIDErrorLabel: UILabel!
    @IBOutlet private weak var createPlayerIDTextField: UITextField!
    @IBOutlet private weak var createPlayerImageContainerView: UIView!
    @IBOutlet private weak var createPlayerSettingsTitleLabel: UILabel!
    @IBOutlet private weak var smallFormatHomeButton: ClearButton!
    @IBOutlet private weak var smallFormatCreatePlayerButton: RoundedButton!
    @IBOutlet private var actionButton: [RoundedButton]!
    @IBOutlet private var formLabel: [UILabel]!
    @IBOutlet private var settingsOnLineGamesEnabledSwitch: [UISwitch]!
    @IBOutlet private var settingsSaveLocationSwitch: [UISwitch]!

    // MARK: - IB Actions ============================================================================== -
        
    @IBAction func dowloadButtonPressed(_ sender: UIButton) {
        self.showSelectPlayers()
    }
    
    @IBAction func homeButtonPressed(_ sender: UIButton) {
        self.dismiss()
    }

    @IBAction func createPlayerButtonPressed(_ sender: UIButton) {
        self.createNewPlayer()
    }

    @IBAction func thisPlayerChangeButtonPressed(_ sender: UIButton) {
        if self.playerSelectionViewTopConstraint.constant != 0 {
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
        self.setupImagePickerPlayerView() // needs to be before colors are set
        self.setupDefaultColors()
        self.showThisPlayer()
        
        // Look out for images arriving
        imageObserver = setPlayerDownloadNotification(name: .playerImageDownloaded)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        Scorecard.shared.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        
        if self.firstTime {
            self.setupSizes()
            self.setupControls()
            self.change(section: .downloadPlayers)
            self.roundCorners()
        }
        
        if self.rotated && self.playerSelectionViewTopConstraint.constant == 0 {
            // Resize player selection
            self.showPlayerSelection()
        }
        
        self.rotated = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.firstTime = false
    }
    
    // MARK: - Form handling ===================================================================== -
    
    private func initialise() {
        self.setOnlineGamesEnabled(Scorecard.settings.onlineGamesEnabled)
        self.setSaveLocation(Scorecard.settings.saveLocation)
    }
    
    private func setOnlineGamesEnabled(_ enabled: Bool) {
        Scorecard.settings.onlineGamesEnabled = enabled
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
        let createEnabled = self.playerNameValid() && self.playerIDValid()
        switch self.section {
        case .downloadPlayers:
            self.downloadButton.isEnabled(self.downloadIdentifierTextField.text != "")
            self.actionButton.forEach{(button) in button.isEnabled(homeEnabled)}
        case .createPlayer:
            self.actionButton.forEach{(button) in button.isEnabled(createEnabled)}
            self.smallFormatCreatePlayerButton.isEnabled(createEnabled)
            self.createPlayerNameErrorLabel.isHidden = self.playerNameValid(allowBlank: true)
            self.createPlayerIDErrorLabel.isHidden = self.playerIDValid(allowBlank: true)
        case .createPlayerSettings:
            self.actionButton.forEach{(button) in button.isEnabled(homeEnabled)}
        }
        self.smallFormatHomeButton.isEnabled(homeEnabled)
    }
    
    private func playerNameValid(allowBlank: Bool = false) -> Bool {
        (allowBlank || self.playerDetail.name != "") && !Scorecard.shared.isDuplicateName(self.playerDetail)
    }
    
    private func playerIDValid(allowBlank: Bool = false) -> Bool {
        return (allowBlank || self.playerDetail.playerUUID != "") && !Scorecard.shared.isDuplicatePlayerUUID(self.playerDetail)

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
            self.titleLabel.isHidden = false
            self.thisPlayerThumbnailView.isHidden = true
        }
    }
    
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
                // Add in shadow (which might have been removed in previous animation)
                self.downloadPlayersContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
            default:
                // Add in shadow (which might have been removed in previous animation)
                self.createPlayerContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
                // Pull the create player input view back up to touch the title bar
                self.createPlayerClippingContainerTopConstraint.constant = 0
            }
            Utility.animate(duration: 0.5,completion: {
                switch section {
                case .downloadPlayers:
                    // Push the create player input view down so that it is hidden (as the clipping window is slightly too big to allow for shadow)
                    self.createPlayerClippingContainerTopConstraint.constant = 20
                default:
                    // Remove the shadow from the now hidden view as you get a line otherwise
                    self.downloadPlayersContainerView.removeShadow()
                }
                // Slide (invisibly) back to the create player view if necessary (from create player settings)
                self.createPlayerContainerTopConstraint.constant = 0
            }, animations: {
                // Slide up/down to the right view
                self.downloadPlayersContainerTopConstraint.constant = -(min(1,section.rawValue) * self.containerHeight)
                // Sort out rounding of title bar corners
                self.downloadPlayersTitleBar.set(topRounded: true, bottomRounded: section != .downloadPlayers)
                self.createPlayerTitleBar.set(topRounded: true, bottomRounded: section != .createPlayer)
            })
            
        } else {
            // Moving from create to/from settings - slide bottom clipping section
            if section == .createPlayer {
                // Add in shadow (which might have been removed in previous animation)
                self.createPlayerContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
            }
            Utility.animate(view: self.inputClippingContainerView, duration: 0.5, completion: {
                if section != .createPlayer {
                    // Remove the shadow from the now hidden view as you get a line otherwise
                    self.createPlayerContainerView.removeShadow()
                }
            }, animations: {
                // Slide up/down to the right view
                self.createPlayerContainerTopConstraint.constant = -(min(1,section.rawValue - 1) * (self.containerHeight))
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
        textField.addTarget(self, action: #selector(PlayerDetailViewController.textFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        textField.addTarget(self, action: #selector(PlayerDetailViewController.textFieldShouldReturn(_:)), for: UIControl.Event.editingDidEndOnExit)
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        switch textField.tag {
        case self.createNameFieldTag:
            // Name
            playerDetail.name = textField.text!
        case self.createIDFieldTag:
            // PlayerUUID
            playerDetail.tempEmail = textField.text!
        default:
            break
        }
        self.enableControls()
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.text == "" {
            // Don't allow blank name
            return false
        } else if textField.tag == downloadFieldTag {
            self.showSelectPlayers()
        } else {
            // Update field - to get any shortcut expansion
            self.textFieldDidChange(textField)
            // Try to move to next text field - resign if none found
            if textField.tag == self.createNameFieldTag {
                self.createPlayerIDTextField.becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }
        return true
    }

    // MARK: - Button delegate ==================================================================== -
    
    internal func buttonPressed(_ button: UIView) {
        switch button.tag {
        case downloadPlayers:
            self.alertDecision(if: (self.playerDetail.name != "" || self.playerDetail.name != "" || self.playerDetail.thumbnail != nil), "You have not created this player yet.\nIf you continue you may lose the details you have entered.\nUse the 'Create New Player' button to create this player.\n\nAre you sure you want to leave this option?", title: "Warning", okButtonText: "Confirm", okHandler: {self.change(section: .downloadPlayers)}, cancelButtonText: "Cancel")
            self.downloadIdentifierTextField.becomeFirstResponder()
        
        case createPlayer:
            self.change(section: .createPlayer)
            self.createPlayerNameTextField.becomeFirstResponder()
            
        default:
            break
        }
    }
    
    // MARK: - Image picker delegates ================================================================= -
    
    internal func playerViewImageChanged(to thumbnail: Data?) {
        playerDetail.thumbnail = thumbnail
        if thumbnail != nil {
            playerDetail.thumbnailDate = Date()
        } else {
            playerDetail.thumbnailDate = nil
        }
        self.enableControls()
    }
    
    // MARK: - Create player ========================================================================== -

    private func createNewPlayer() {
        if playerDetail.createMO(saveToICloud: false) != nil {
            if Scorecard.settings.thisPlayerUUID == "" {
                self.setThisPlayer(playerUUID: playerDetail.playerUUID)
            } else {
                Scorecard.settings.save()
            }
            self.playerDetail = PlayerDetail()
            self.updatePlayerControls()
            self.change(section: .createPlayerSettings)
        }
    }
    
    private func updatePlayerControls() {
        self.createPlayerNameTextField.text = self.playerDetail.name
        self.createPlayerIDTextField.text = self.playerDetail.tempEmail
        if let playerMO = self.playerDetail.playerMO {
            self.createPlayerImagePickerPlayerView.set(playerMO: playerMO)
        } else {
            self.createPlayerImagePickerPlayerView.set(data: nil)
        }
    }
    
    // MARK: - Player Selection View Delegate Handlers ======================================================= -
    
    private func showPlayerSelection() {
        if self.playerSelectionViewTopConstraint.constant != 0 {
            self.playerSelectionView.set(parent: self)
            self.playerSelectionView.delegate = self
        }
        self.thisPlayerChangeButton.setTitle("Cancel")
        Utility.animate(view: self.view, duration: 0.5) {
            self.playerSelectionViewTopConstraint.constant = 0
        }
        
        let playerList = Scorecard.shared.playerList.filter { $0.playerUUID != Scorecard.settings.thisPlayerUUID }
        self.playerSelectionView.set(players: playerList, addButton: false, updateBeforeSelect: false, scrollEnabled: true, collectionViewInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10), contentInset: UIEdgeInsets(top: 22.5, left: 10, bottom: 0, right: 10))
    }
    
    private func hidePlayerSelection() {
        self.thisPlayerChangeButton.setTitle("Change")
        Utility.animate(view: self.view, duration: 0.5, completion: {
        }, animations: {
            self.playerSelectionViewTopConstraint.constant = -self.playerSelectionViewHeight
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
    
    // MARK: - Show select players view ================================================================= -
    
    private func showSelectPlayers() {
        let noExistingPlayers = Scorecard.shared.playerList.isEmpty
        
        _ = SelectPlayersViewController.show(from: self, specificEmail: self.downloadIdentifierTextField.text!, descriptionMode: .lastPlayed, allowOtherPlayer: false, allowNewPlayer: false, saveToICloud: false, completion: { (selected, playerList, selection, thisPlayerUUID) in
            
            if !(playerList?.isEmpty ?? true) && noExistingPlayers && thisPlayerUUID != nil {
                // TODO Need to do review this to match UUIDs instead
                if let playerMO = playerList?.first(where: { $0.playerUUID == thisPlayerUUID}) {
                    // Found the player whose email we entered (should usually be the case)
                    self.setThisPlayer(playerUUID: playerMO.playerUUID)
                } else {
                    self.setThisPlayer(playerUUID: playerList!.first!.playerUUID)
                }
            }
            self.downloadIdentifierTextField.text = ""
            self.enableControls()
        })
    }
    
    // MARK: - View defaults ============================================================================ -
    
    private func setupImagePickerPlayerView() {
        self.createPlayerImagePickerPlayerView = PlayerView(type: .imagePicker, parentViewController: self, parentView: self.createPlayerImageContainerView, width: self.createPlayerImageContainerView.frame.width, height: self.createPlayerImageContainerView.frame.height)
        self.createPlayerImagePickerPlayerView.imagePickerDelegate = self
        self.createPlayerImagePickerPlayerView.set(data: nil)
    }
    
    private func setupDefaultColors() {
        self.bannerPaddingView.bannerColor = Palette.banner
        self.topSection.backgroundColor = Palette.banner
        self.titleLabel.textColor = Palette.bannerEmbossed
        self.getStartedLabel.textColor = Palette.bannerText
        
        self.infoButton.backgroundColor = Palette.bannerShadow
        self.infoButton.setTitleColor(Palette.bannerText, for: .normal)
        
        self.thisPlayerThumbnailView.set(textColor: Palette.bannerText)
        self.thisPlayerThumbnailView.set(font: UIFont.systemFont(ofSize: 15, weight: .bold))
        self.thisPlayerChangeButton.backgroundColor = Palette.bannerShadow
        self.thisPlayerChangeButton.setTitleColor(Palette.bannerText, for: .normal)
        
        self.playerSelectionView.backgroundColor = Palette.buttonFace
        
        self.downloadPlayersTitleBar.set(faceColor: Palette.buttonFace)
        self.downloadPlayersTitleBar.set(textColor: Palette.buttonFaceText)
        
        self.createPlayerTitleBar.set(faceColor: Palette.buttonFace)
        self.createPlayerTitleBar.set(textColor: Palette.buttonFaceText)
        
        self.downloadPlayersView.backgroundColor = Palette.buttonFace
        self.createPlayerView.backgroundColor = Palette.buttonFace
        self.createPlayerSettingsView.backgroundColor = Palette.buttonFace
        
        self.downloadIdentifierTextField.attributedPlaceholder = NSAttributedString(string: "Enter identifier", attributes:[NSAttributedString.Key.foregroundColor: Palette.inputControlPlaceholder])
        self.downloadButton.normalBackgroundColor = Palette.banner
        self.downloadButton.disabledTextColor = Palette.disabled
        self.downloadButton.normalTextColor = Palette.bannerText
        self.downloadButton.disabledTextColor = Palette.disabledText
        
        self.createPlayerSettingsTitleLabel.textColor = Palette.text
        self.createPlayerNameTextField.attributedPlaceholder = NSAttributedString(string: "Enter name", attributes:[NSAttributedString.Key.foregroundColor: Palette.inputControlPlaceholder])
        self.createPlayerIDTextField.attributedPlaceholder = NSAttributedString(string: "Enter identifier", attributes:[NSAttributedString.Key.foregroundColor: Palette.inputControlPlaceholder])
        self.createPlayerIDErrorLabel.textColor = Palette.textError
        self.createPlayerNameErrorLabel.textColor = Palette.textError
        
        self.createPlayerImagePickerPlayerView.set(backgroundColor: Palette.thumbnailDisc)
        self.createPlayerImagePickerPlayerView.set(textColor: Palette.thumbnailDiscText)
        
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in control.tintColor = Palette.emphasis}
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in control.onTintColor = Palette.emphasis}
        self.settingsSaveLocationSwitch.forEach{(control) in control.tintColor = Palette.emphasis}
        self.settingsSaveLocationSwitch.forEach{(control) in control.onTintColor = Palette.emphasis}
        
        self.formLabel.forEach{(label) in label.textColor = Palette.text}
        
        self.actionButton.forEach{(button) in button.normalBackgroundColor = Palette.banner}
        self.actionButton.forEach{(button) in button.disabledBackgroundColor = Palette.disabled}
        self.actionButton.forEach{(button) in button.normalTextColor =  Palette.bannerText}
        self.actionButton.forEach{(button) in button.disabledTextColor =  Palette.disabledText}
        
        self.smallFormatCreatePlayerButton.normalBackgroundColor = Palette.banner
        self.smallFormatCreatePlayerButton.disabledBackgroundColor = Palette.disabled
        self.smallFormatCreatePlayerButton.normalTextColor =  Palette.bannerText
        self.smallFormatCreatePlayerButton.disabledTextColor =  Palette.disabledText
        self.smallFormatCreatePlayerButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        
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
            self.playerSelectionViewHeight = self.view.frame.height - self.bottomSection.frame.minY + self.view.safeAreaInsets.bottom
            self.playerSelectionView.set(size: CGSize(width: UIScreen.main.bounds.width, height: self.playerSelectionViewHeight))
            self.playerSelectionViewTopConstraint.constant = -self.playerSelectionViewHeight
            self.playerSelectionViewHeightConstraint.constant = self.playerSelectionViewHeight

        }
    }
    
    private func roundCorners() {
        self.downloadPlayersView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
        self.createPlayerView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
        self.createPlayerSettingsView.roundCorners(cornerRadius: 8.0, topRounded: true, bottomRounded: true)
        self.playerSelectionView.roundCorners(cornerRadius: 8.0)
    }
    
    private func setupControls() {
       
        if ScorecardUI.smallPhoneSize() {
            self.actionButton.forEach{(button) in button.isHidden = true}
        } else {
            self.smallFormatHomeButton.isHidden = true
            self.smallFormatCreatePlayerButton.isHidden = true
        }
        
        self.infoButtonContainer.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.infoButton.toCircle()

        self.thisPlayerChangeContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.thisPlayerChangeButton.roundCorners(cornerRadius: self.thisPlayerChangeButton.frame.height / 2.0)
        
        self.downloadPlayersTitleBar.set(font: UIFont.systemFont(ofSize: 17, weight: .bold))
            
        self.createPlayerTitleBar.set(font: UIFont.systemFont(ofSize: 17, weight: .bold))
        self.createPlayerTitleBar.set(topRounded: true, bottomRounded: true)

        self.createPlayerSettingsContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        
        self.downloadButton.toRounded(cornerRadius: 8.0)
        
        self.addTargets(self.downloadIdentifierTextField)
        self.addTargets(self.createPlayerNameTextField)
        self.addTargets(self.createPlayerIDTextField)
        
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in control.addTarget(self, action: #selector(GetStartedViewController.onlineGamesChanged(_:)), for: .valueChanged) }
        
        self.settingsSaveLocationSwitch.forEach{(control) in control.addTarget(self, action: #selector(GetStartedViewController.saveGameLocationChanged(_:)), for: .valueChanged) }
        
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in self.resizeSwitch(control, factor: 0.75)}

        self.settingsSaveLocationSwitch.forEach{(control) in self.resizeSwitch(control, factor: 0.75)}
        
        self.actionButton.forEach{(button) in button.toRounded(cornerRadius: button.frame.height/2.0)}
        self.smallFormatCreatePlayerButton.toRounded(cornerRadius: self.smallFormatCreatePlayerButton.frame.height/2.0)
    }
    
    public func resizeSwitch(_ control: UISwitch, factor: CGFloat) {
        control.transform = CGAffineTransform(scaleX: factor, y: factor)
    }

    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: ScorecardViewController, completion: (()->())? = nil) {
        
        let storyboard = UIStoryboard(name: "GetStartedViewController", bundle: nil)
        let getStartedViewController: GetStartedViewController = storyboard.instantiateViewController(withIdentifier: "GetStartedViewController") as! GetStartedViewController
        
        getStartedViewController.preferredContentSize = CGSize(width: 400, height: 700)
        getStartedViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        getStartedViewController.completion = completion
        
        viewController.present(getStartedViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.imageObserver = nil
        Scorecard.settings.syncEnabled = true
        Scorecard.settings.save()
        
        // Save to iCloud
        Scorecard.settings.saveToICloud()
        
        self.dismiss(animated: true, completion: self.completion)
    }
    
}
