//
//  CreatePlayerView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 29/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

@objc protocol CreatePlayerViewDelegate : class {
    
    func playerCreated(playerDetail: PlayerDetail)

}

class CreatePlayerView : UIView, UITextFieldDelegate, PlayerViewImagePickerDelegate {

    private var createNameFieldTag = 1
    private var createIDFieldTag = 2
    
    private var playerDetail = PlayerDetail()
    
    private var createPlayerImagePickerPlayerView: PlayerView!

    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var parent: UIViewController!
    @IBOutlet public weak var delegate: CreatePlayerViewDelegate?
    @IBOutlet private weak var createPlayerNameTextField: UITextField!
    @IBOutlet private weak var createPlayerNameErrorLabel: UILabel!
    @IBOutlet private weak var createPlayerIDErrorLabel: UILabel!
    @IBOutlet private weak var createPlayerIDTextField: UITextField!
    @IBOutlet private weak var createPlayerImageContainerView: UIView!
    @IBOutlet private weak var smallFormatCreatePlayerButton: RoundedButton!
    @IBOutlet private var actionButton: [RoundedButton]!
    
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
        self.updatePlayerControls()
        self.enableControls()
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
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
        return (allowBlank || self.playerDetail.tempEmail != "") && !Scorecard.shared.isDuplicatePlayerUUID(self.playerDetail)

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
            self.actionButton.forEach{(button) in button.isHidden = true}
        } else {
            self.smallFormatCreatePlayerButton.isHidden = true
        }
        self.addTargets(self.createPlayerNameTextField)
        self.addTargets(self.createPlayerIDTextField)
        
        self.smallFormatCreatePlayerButton.toRounded(cornerRadius: self.smallFormatCreatePlayerButton.frame.height/2.0)
    }

    private func enableControls() {
        let createEnabled = self.playerNameValid() && self.playerIDValid()
        self.actionButton.forEach{(button) in button.isEnabled(createEnabled)}
        self.smallFormatCreatePlayerButton.isEnabled(createEnabled)
        self.createPlayerNameErrorLabel.isHidden = self.playerNameValid(allowBlank: true)
        self.createPlayerIDErrorLabel.isHidden = self.playerIDValid(allowBlank: true)
    }
    
    private func setupImagePickerPlayerView() {
        self.createPlayerImagePickerPlayerView = PlayerView(type: .imagePicker, parentViewController: self.parent, parentView: self.createPlayerImageContainerView, width: self.createPlayerImageContainerView.frame.width, height: self.createPlayerImageContainerView.frame.height)
        self.createPlayerImagePickerPlayerView.imagePickerDelegate = self
        self.createPlayerImagePickerPlayerView.set(data: nil)
    }
    
    // MARK: - Create player ========================================================================== -

    private func createNewPlayer() {
        if playerDetail.createMO(saveToICloud: false) != nil {
            self.delegate?.playerCreated(playerDetail: self.playerDetail)
            Scorecard.settings.save()
            self.playerDetail = PlayerDetail()
            self.updatePlayerControls()
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
        self.createPlayerNameTextField.attributedPlaceholder = NSAttributedString(string: "Enter name", attributes:[NSAttributedString.Key.foregroundColor: Palette.inputControlPlaceholder])
        self.createPlayerIDTextField.attributedPlaceholder = NSAttributedString(string: "Enter identifier", attributes:[NSAttributedString.Key.foregroundColor: Palette.inputControlPlaceholder])
        self.createPlayerIDErrorLabel.textColor = Palette.textError
        self.createPlayerNameErrorLabel.textColor = Palette.textError
        
        self.createPlayerImagePickerPlayerView.set(backgroundColor: Palette.thumbnailDisc)
        self.createPlayerImagePickerPlayerView.set(textColor: Palette.thumbnailDiscText)

        self.smallFormatCreatePlayerButton.normalBackgroundColor = Palette.banner
        self.smallFormatCreatePlayerButton.disabledBackgroundColor = Palette.disabled
        self.smallFormatCreatePlayerButton.normalTextColor =  Palette.bannerText
        self.smallFormatCreatePlayerButton.disabledTextColor =  Palette.disabledText
        self.smallFormatCreatePlayerButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)

    }
}
