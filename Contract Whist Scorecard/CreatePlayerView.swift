//
//  CreatePlayerView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 29/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

@objc protocol CreatePlayerViewDelegate : class {
    
    func didCreatePlayer(playerDetail: PlayerDetail)

}

class CreatePlayerView : UIView, UITextFieldDelegate, PlayerViewImagePickerDelegate {

    public var requiredHeight: CGFloat!
    
    private var createNameFieldTag = 1
    private var createIDFieldTag = 2
    
    private var playerDetail = PlayerDetail()
    
    private var createPlayerImagePickerPlayerView: PlayerView!

    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var parent: ScorecardViewController!
    @IBOutlet public weak var delegate: CreatePlayerViewDelegate?
    @IBOutlet private weak var createPlayerNameTextField: UITextField!
    @IBOutlet private weak var createPlayerNameErrorLabel: UILabel!
    @IBOutlet private weak var createPlayerIDErrorLabel: UILabel!
    @IBOutlet private weak var createPlayerIDTextField: UITextField!
    @IBOutlet private weak var createPlayerImageContainerView: UIView!
    @IBOutlet private weak var createPlayerButton: ShadowButton!
    @IBOutlet private weak var smallFormatCreatePlayerButton: ShadowButton!
    @IBOutlet private var actionButton: [ShadowButton]!
    @IBOutlet private var inputField: [UITextField]!
    @IBOutlet private var titleLabel: [UILabel]!
    @IBOutlet private var duplicateLabel: [UILabel]!
    
    @IBAction func createPlayerButtonPressed(_ sender: UIButton) {
        self.createNewPlayer()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadCreatePlayerView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadCreatePlayerView()
    }
    
    internal override func awakeFromNib() {
        self.setupImagePickerPlayerView()
        self.setupDefaultColors()
        self.updatePlayerControls()
        self.enableControls()
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        self.requiredHeight = (ScorecardUI.smallPhoneSize() ? self.smallFormatCreatePlayerButton.frame.maxY : self.createPlayerButton.frame.maxY) + 20.0
    }

    private func loadCreatePlayerView() {
        Bundle.main.loadNibNamed("CreatePlayerView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.setupControls()
        
        self.layoutSubviews()
        self.setNeedsLayout()
    }
    
    // MARK: - Routines called by calling view when becomes active / inactive =============================== -
    
    public func didBecomeActive() {
        self.createPlayerNameTextField.becomeFirstResponder()
    }
    
    public func willBecomeInactive(action: @escaping ()->()) {
        self.parent?.alertDecision(if: (self.playerDetail.name != "" || self.playerDetail.name != "" || self.playerDetail.thumbnail != nil), "You have not created this player yet.\nIf you continue you may lose the details you have entered.\nUse the 'Create New Player' button to create this player.\n\nAre you sure you want to leave this option?", title: "Warning", okButtonText: "Confirm", okHandler: action, cancelButtonText: "Cancel")
    }
            
    private func playerNameValid(allowBlank: Bool = false) -> Bool {
        (allowBlank || self.playerDetail.name != "") && !Scorecard.shared.isDuplicateName(self.playerDetail)
    }
    
    private func playerIDValid(allowBlank: Bool = false) -> Bool {
        return (allowBlank || (self.playerDetail.tempEmail ?? "") != "") && !Scorecard.shared.isDuplicatePlayerUUID(self.playerDetail)

    }
    
    // MARK: - UI setup routines ================================================= -
    
    public func updatePlayerControls() {
        self.createPlayerNameTextField.text = self.playerDetail.name
        self.createPlayerIDTextField.text = self.playerDetail.tempEmail
        if let playerMO = self.playerDetail.playerMO {
            self.createPlayerImagePickerPlayerView.set(playerMO: playerMO)
        } else {
            self.createPlayerImagePickerPlayerView.set(data: nil)
        }
    }

    private func setupControls() {
        if ScorecardUI.smallPhoneSize() {
            self.createPlayerButton.isHidden = true
        } else {
            self.smallFormatCreatePlayerButton.isHidden = true
        }
        self.addTargets(self.createPlayerNameTextField)
        self.addTargets(self.createPlayerIDTextField)
    }

    private func enableControls() {
        let createEnabled = self.playerNameValid() && self.playerIDValid()
        self.actionButton.forEach{(button) in button.isEnabled = createEnabled}
        self.smallFormatCreatePlayerButton.isEnabled = createEnabled
        self.createPlayerNameErrorLabel.isHidden = self.playerNameValid(allowBlank: true)
        self.createPlayerIDErrorLabel.isHidden = self.playerIDValid(allowBlank: true)
    }
    
    private func setupImagePickerPlayerView() {
        self.createPlayerImagePickerPlayerView = PlayerView(type: .imagePicker, parentViewController: self.parent, parentView: self.createPlayerImageContainerView, width: self.createPlayerImageContainerView.frame.width, height: self.createPlayerImageContainerView.frame.height, cameraTintColor: Palette.thumbnailDisc.text)
        self.createPlayerImagePickerPlayerView.imagePickerDelegate = self
        self.createPlayerImagePickerPlayerView.set(data: nil)
    }
    
    // MARK: - Create player ========================================================================== -

    private func createNewPlayer() {
        if playerDetail.createMO(saveToICloud: false) != nil {
            self.delegate?.didCreatePlayer(playerDetail: self.playerDetail)
            Scorecard.settings.save()
            self.playerDetail = PlayerDetail()
            self.playerDetail.dateCreated = Date()
            self.playerDetail.visibleLocally = true
            self.playerDetail.localDateCreated = Date()
            self.updatePlayerControls()
            self.enableControls()
            self.createPlayerNameTextField.resignFirstResponder()
            self.createPlayerIDTextField.resignFirstResponder()
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
            playerDetail.tempEmail = textField.text!.lowercased()
        default:
            break
        }
        self.enableControls()
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.text == "" {
            // Don't allow blank name
            return false
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
    
    // MARK: - View defaults ============================================================================ -
    
    private func setupDefaultColors() {
        
        self.duplicateLabel.forEach{$0.textColor = Palette.errorCondition}
        self.titleLabel.forEach{$0.textColor = Palette.buttonFace.text}
        
        self.createPlayerImagePickerPlayerView.set(backgroundColor: Palette.thumbnailDisc.background)
        self.createPlayerImagePickerPlayerView.set(textColor: Palette.thumbnailDisc.text)

        self.actionButton.forEach{$0.setBackgroundColor(Palette.banner.background)}
        self.actionButton.forEach{$0.setTitleColor(Palette.banner.text, for: .normal)}

    }
}

extension CreatePlayerView {
    
    public func addHelp(to helpView: HelpView, condition: (()->Bool)?) {
        
        helpView.add("To create a new player give them a name.\n\nIt should be unique on this device, but can be quite simple. E.g. just their forename.", views: [self.createPlayerNameTextField], condition: condition)
        
        helpView.add("Each player requires a unique ID.\n\nIt needs to be unique across all devices and they will need to remember it to access their history from another device.\n\nAn email address or mobile phone number for example. The unique ID is **not** case sensitive.", views: [self.createPlayerIDTextField], condition: condition)
        
        helpView.add("You can add a photo (or other image) for the player by tapping the camera button.", views: [self.createPlayerImagePickerPlayerView.thumbnailView], condition: condition, radius: self.createPlayerImagePickerPlayerView.thumbnailView.frame.height / 2)
        
        helpView.add("Tap the @*/Create New Player@*/ button when you are ready to create the player.\n\nIf you create a player you can modify or remove them later through the @*/Profiles@*/ screen.", views: [self.createPlayerButton], condition: condition)
    }
}
