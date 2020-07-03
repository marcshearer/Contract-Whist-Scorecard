//
//  GetStartedViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/03/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class GetStartedViewController: ScorecardViewController, ButtonDelegate, PlayerSelectionViewDelegate, CreatePlayerViewDelegate, RelatedPlayersDelegate {

    private enum Section: CGFloat {
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
    @IBOutlet private weak var infoButtonContainer: UIView!
    @IBOutlet private weak var infoButton: RoundedButton!
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
    @IBOutlet private var settingsSaveLocationSwitch: [UISwitch]!

    // MARK: - IB Actions ============================================================================== -
        
    @IBAction func dowloadButtonPressed(_ sender: UIButton) {
        self.showRelatedPlayers()
    }
    
    @IBAction func homeButtonPressed(_ sender: UIButton) {
        self.dismiss()
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

        if self.firstTime || self.rotated {
            self.contentViewHeightConstraint.constant =
                (ScorecardUI.landscapePhone() ? ScorecardUI.screenWidth
                    : self.view.frame.height - self.view.safeAreaInsets.top)
            self.contentView.layoutIfNeeded()
            self.setupSizes()
            self.setupControls()
            if self.firstTime {
                self.change(section: .downloadPlayers)
            }
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
                self.downloadPlayersContainerTopConstraint.constant = -(min(1,section.rawValue) * self.containerHeight)
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
                self.createPlayerContainerTopConstraint.constant = -(min(1,section.rawValue - 1) * (self.containerHeight))
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
        textField.addTarget(self, action: #selector(PlayerDetailViewController.textFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        textField.addTarget(self, action: #selector(PlayerDetailViewController.textFieldShouldReturn(_:)), for: UIControl.Event.editingDidEndOnExit)
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        self.enableControls()
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.text == "" {
            // Don't allow blank field
            return false
        } else if textField.tag == downloadFieldTag {
            self.showRelatedPlayers()
        }
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
        self.thisPlayerChangeButton.setTitle("Cancel")
        Utility.animate(view: self.view, duration: 0.5) {
            self.playerSelectionViewTopConstraint.constant = 0
            self.playerSelectionViewBottomConstraint.constant = 0
        }
        
        let playerList = Scorecard.shared.playerList.filter { $0.playerUUID != Scorecard.settings.thisPlayerUUID }
        self.playerSelectionView.set(players: playerList, addButton: false, updateBeforeSelect: false, scrollEnabled: true, collectionViewInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10), contentInset: UIEdgeInsets(top: 10, left: 10, bottom: 0, right: 10))
    }
    
    private func hidePlayerSelection() {
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
        _ = RelatedPlayersViewController.show(from: self, email: self.downloadIdentifierTextField.text!, descriptionMode: .lastPlayed)
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
        self.downloadIdentifierTextField.text = ""
        self.enableControls()
    }
    
    // MARK: - View defaults ============================================================================ -
    
    private func setupDefaultColors() {
        self.view.backgroundColor = Palette.background
        
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
        
        self.downloadButton.setBackgroundColor(Palette.banner)
        self.downloadButton.setTitleColor(Palette.bannerText, for: .normal)
        
        self.createPlayerSettingsTitleLabel.textColor = Palette.text
                
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in control.tintColor = Palette.emphasis}
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in control.onTintColor = Palette.emphasis}
        self.settingsSaveLocationSwitch.forEach{(control) in control.tintColor = Palette.emphasis}
        self.settingsSaveLocationSwitch.forEach{(control) in control.onTintColor = Palette.emphasis}
        
        self.formLabel.forEach{(label) in label.textColor = Palette.text}
        
        self.actionButton.forEach{(button) in button.setBackgroundColor(Palette.banner)}
        self.actionButton.forEach{(button) in button.setTitleColor(Palette.bannerText, for: .normal)}
                
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
        self.createPlayerView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
        self.createPlayerSettingsView.roundCorners(cornerRadius: 8.0, topRounded: true, bottomRounded: true)
        self.playerSelectionView.roundCorners(cornerRadius: 8.0)
    }
    
    private func setupControls() {
       
        if ScorecardUI.smallPhoneSize() {
            self.actionButton.forEach{(button) in button.isHidden = true}
        } else {
            self.smallFormatHomeButton.isHidden = true
        }
       
        self.infoButtonContainer.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.infoButton.toCircle()

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
