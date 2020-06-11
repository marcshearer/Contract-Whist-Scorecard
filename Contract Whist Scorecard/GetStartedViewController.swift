//
//  GetStartedViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/03/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

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

    private let downloadPlayers = 1
    private let createPlayer = 2

    private var createNameFieldTag = 1
    private var createIDFieldTag = 2
    private var downloadFieldTag = 3
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var topSection: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var thisPlayerThumbnailView: ThumbnailView!
    @IBOutlet private weak var thisPlayerChangeContainerView: UIView!
    @IBOutlet private weak var thisPlayerChangeButton: RoundedButton!
    @IBOutlet private weak var tapGestureRecognizer: UITapGestureRecognizer!
    @IBOutlet private weak var infoButtonContainer: UIView!
    @IBOutlet private weak var infoButton: RoundedButton!
    @IBOutlet private weak var playerSelectionView: PlayerSelectionView!
    @IBOutlet private weak var playerSelectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var downloadPlayersTitleBar: TitleBar!
    @IBOutlet private weak var createPlayerTitleBar: TitleBar!
    @IBOutlet private weak var inputContainerView: UIView!
    @IBOutlet private weak var inputContainerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var downloadPlayersContainerView: UIView!
    @IBOutlet private weak var downloadPlayersView: UIView!
    @IBOutlet private weak var createPlayerView: UIView!
    @IBOutlet private weak var createPlayerContainerView: UIView!
    @IBOutlet private weak var createPlayerSettingsView: UIView!
    @IBOutlet private weak var createPlayerSettingsContainerView: UIView!
    @IBOutlet private weak var downloadPlayersViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var downloadIdentifierTextField: UITextField!
    @IBOutlet private weak var downloadButton: RoundedButton!
    @IBOutlet private weak var createPlayerNameTextField: UITextField!
    @IBOutlet private weak var createPlayerNameErrorLabel: UILabel!
    @IBOutlet private weak var createPlayerIDErrorLabel: UILabel!
    @IBOutlet private weak var createPlayerIDTextField: UITextField!
    @IBOutlet private weak var createPlayerImageContainerView: UIView!
    @IBOutlet private weak var createPlayerSettingsTitleLabel: UILabel!
    @IBOutlet private weak var bannerHomeButton: ClearButton!
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
        if self.playerSelectionViewHeightConstraint.constant != 0 {
            self.hidePlayerSelection()
        } else {
            self.showPlayerSelection()
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
        self.change(section: .downloadPlayers)
        
        self.displayThisPlayer()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        Scorecard.shared.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.setupControls()
        
        if firstTime {
            self.setupSizes()
        }
        
        if self.rotated && self.playerSelectionViewHeightConstraint.constant != 0 {
            // Resize player selection
            self.showPlayerSelection()
        }

        self.firstTime = false
        self.rotated = false
    }
    
    // MARK: - Form handling ===================================================================== -
    
    private func initialise() {
        self.setOnlineGamesEnabled(false)
        self.setSaveLocation(false)
    }
    
    private func setOnlineGamesEnabled(_ enabled: Bool) {
        Scorecard.shared.settings.onlineGamesEnabled = enabled
        self.settingsOnLineGamesEnabledSwitch.forEach{(control) in control.isOn = enabled}
    }

    private func setSaveLocation(_ enabled: Bool) {
        Scorecard.shared.settings.saveLocation = enabled
        self.settingsSaveLocationSwitch.forEach{(control) in control.isOn = enabled}
    }
    
    private func enableControls() {
        self.thisPlayerChangeButton.isHidden = (Scorecard.shared.playerList.count <= 1)
        switch self.section {
        case .downloadPlayers:
            self.downloadButton.isEnabled(self.downloadIdentifierTextField.text != "")
            self.actionButton.forEach{(button) in button.isEnabled(!Scorecard.shared.playerList.isEmpty)}
        case .createPlayer:
            self.actionButton.forEach{(button) in button.isEnabled(self.playerNameValid() && self.playerIDValid())}
            self.createPlayerNameErrorLabel.isHidden = self.playerNameValid(allowBlank: true)
            self.createPlayerIDErrorLabel.isHidden = self.playerIDValid(allowBlank: true)
        case .createPlayerSettings:
            self.actionButton.forEach{(button) in button.isEnabled(!Scorecard.shared.playerList.isEmpty)}
        }
    }
    
    private func playerNameValid(allowBlank: Bool = false) -> Bool {
        return (allowBlank || self.playerDetail.name != "") && !Scorecard.shared.isDuplicateName(self.playerDetail)
    }
    
    private func playerIDValid(allowBlank: Bool = false) -> Bool {
        return (allowBlank || self.playerDetail.email != "") && !Scorecard.shared.isDuplicateEmail(self.playerDetail)

    }
    
    private func displayThisPlayer() {
        if let playerMO = Scorecard.shared.findPlayerByEmail(Scorecard.shared.settings.thisPlayerEmail) {
            self.thisPlayerThumbnailView.set(playerMO: playerMO, nameHeight: 15.0, diameter: self.thisPlayerThumbnailView.frame.width)
        }
    }
    
    // MARK: - Change section ==================================================================== -
    
    private func change(section: Section) {
        self.section = section
        if section == .downloadPlayers {
            self.downloadPlayersContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        }
        self.enableControls()
        
        Utility.animate(duration: 0.5, completion: {
            self.downloadPlayersContainerView.removeShadow()
        }, animations: {
            self.downloadPlayersViewTopConstraint.constant = -(self.downloadPlayersView.frame.height) * section.rawValue - (section == .createPlayerSettings ? 20 : 0)
            self.downloadPlayersTitleBar.set(topRounded: true, bottomRounded: section != .downloadPlayers)
            self.createPlayerTitleBar.set(topRounded: section == .downloadPlayers, bottomRounded: true)
        })
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
            // Email
            playerDetail.email = textField.text!
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
        if let playerMO = playerDetail.createMO() {
            if Scorecard.shared.settings.thisPlayerEmail == "" {
                Scorecard.shared.settings.thisPlayerEmail = self.playerDetail.email
                self.thisPlayerThumbnailView.set(playerMO: playerMO, nameHeight: 15.0, diameter: self.thisPlayerThumbnailView.frame.width)
            }
            self.playerDetail = PlayerDetail()
            self.updatePlayerControls()
            self.change(section: .createPlayerSettings)
        }
    }
    
    private func updatePlayerControls() {
        self.createPlayerNameTextField.text = self.playerDetail.name
        self.createPlayerIDTextField.text = self.playerDetail.email
        if let playerMO = self.playerDetail.playerMO {
            self.createPlayerImagePickerPlayerView.set(playerMO: playerMO)
        } else {
            self.createPlayerImagePickerPlayerView.set(data: nil)
        }
    }
    
    // MARK: - Player Selection View Delegate Handlers ======================================================= -
    
    private func showPlayerSelection() {
        if self.playerSelectionViewHeightConstraint.constant == 0 {
            self.playerSelectionView.set(parent: self)
            self.playerSelectionView.delegate = self
        }
        Utility.animate(view: self.view, duration: 0.5) {
            let selectionHeight = self.view.frame.height - self.playerSelectionView.frame.minY + self.view.safeAreaInsets.bottom
            self.playerSelectionView.set(size: CGSize(width: UIScreen.main.bounds.width, height: selectionHeight))
            self.playerSelectionViewHeightConstraint.constant = selectionHeight
            self.thisPlayerChangeButton.setTitle("Cancel")
        }
        
        let playerList = Scorecard.shared.playerList.filter { $0.email != Scorecard.shared.settings.thisPlayerEmail }
        self.playerSelectionView.set(players: playerList, addButton: false, updateBeforeSelect: false, scrollEnabled: true, collectionViewInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10), contentInset: UIEdgeInsets(top: 22.5, left: 10, bottom: 0, right: 10))
    }
    
    private func hidePlayerSelection() {
        Utility.animate(view: self.view, duration: 0.5, completion: {
        }, animations: {
            self.playerSelectionViewHeightConstraint.constant = 0.0
            self.thisPlayerChangeButton.setTitle("Change")
        })
    }
    
    internal func didSelect(playerMO: PlayerMO) {
        // Save player as default for device
        Scorecard.shared.settings.thisPlayerEmail = playerMO.email!
        self.displayThisPlayer()
        self.hidePlayerSelection()
    }
    
    internal func resizeView() {
        // Additional players added - resize the view
        self.showPlayerSelection()
    }
    
    // MARK: - Show select players view ================================================================= -
    
    private func showSelectPlayers() {
        
        _ = SelectPlayersViewController.show(from: self, specificEmail: self.downloadIdentifierTextField.text!, descriptionMode: .lastPlayed, allowOtherPlayer: false, allowNewPlayer: false, completion: { (selected, playerList, selection) in
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
        self.titleLabel.textColor = Palette.bannerText
        
        self.infoButton.backgroundColor = Palette.bannerShadow
        self.infoButton.setTitleColor(Palette.bannerText, for: .normal)
        
        self.thisPlayerThumbnailView.set(textColor: Palette.bannerText)
        self.thisPlayerThumbnailView.set(font: UIFont.systemFont(ofSize: 15, weight: .bold))
        self.thisPlayerChangeButton.backgroundColor = Palette.bannerShadow
        self.thisPlayerChangeButton.setTitleColor(Palette.bannerText, for: .normal)
        
        self.playerSelectionView.backgroundColor = Palette.background
        
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
    }
    
    private func setupSizes() {
        self.inputContainerViewHeightConstraint.constant = self.view.safeAreaLayoutGuide.layoutFrame.maxY - self.createPlayerTitleBar.frame.height - 20.0 + 4.0 - self.downloadPlayersTitleBar.frame.maxY
    }
    
    private func setupControls() {
       
        if ScorecardUI.screenHeight >= 650 {
            self.bannerHomeButton.isHidden = true
        } else {
            self.actionButton.forEach{(button) in button.isHidden = true}
        }
        
        self.infoButtonContainer.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.infoButton.toCircle()

        self.thisPlayerChangeContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.thisPlayerChangeButton.roundCorners(cornerRadius: self.thisPlayerChangeButton.frame.height / 2.0)

        self.playerSelectionView.roundCorners(cornerRadius: 8.0)
        
        self.downloadPlayersTitleBar.set(font: UIFont.systemFont(ofSize: 17, weight: .bold))
            
        self.createPlayerTitleBar.set(font: UIFont.systemFont(ofSize: 17, weight: .bold))
        self.createPlayerTitleBar.set(topRounded: true, bottomRounded: true)

        self.downloadPlayersView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
        self.downloadPlayersContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        
        self.createPlayerView.roundCorners(cornerRadius: 8.0, topRounded: true, bottomRounded: false)
        self.createPlayerContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        
        self.createPlayerSettingsView.roundCorners(cornerRadius: 8.0, topRounded: true, bottomRounded: false)
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
        Scorecard.shared.settings.syncEnabled = true
        Scorecard.shared.settings.save()
        Scorecard.shared.settings.saveToICloud()
        self.dismiss(animated: true, completion: self.completion)
    }
    
}
