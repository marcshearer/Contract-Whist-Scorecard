//
//  SelectPlayersController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 19/03/2019.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class SelectPlayersViewController: ScorecardViewController, SyncDelegate, ButtonDelegate, CreatePlayerViewDelegate, RelatedPlayersDelegate {
    
    private enum Section: Int {
        case downloadPlayers = 0
        case createPlayer = 1
     }
    
    // Main state properties
    private var sync: Sync!
    
    // Properties to pass state to action controller
    private var selection: [Bool] = []
    private var playerList: [PlayerDetail] = []
    private var selected = 0
    private var completion: (([PlayerDetail]?)->())?
    private var backText = "Back"
    private var backImage = "back"
    
    // Properties to manage sliding views
    private var section: Section = .downloadPlayers
    private let separatorHeight: CGFloat = 20.0
    private let titleOverlap: CGFloat = 25.0
    private var containerHeight: CGFloat = 0.0
    private var playerSelectionViewHeight: CGFloat = 0.0

    // Other properties
    private var rotated = false
    private var firstTime = true
    private var downloadFieldTag = 1
    private var downloadList: [PlayerDetail] = []
    private let bubbleView = BubbleView()

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var topSection: UIView!
    @IBOutlet private weak var bottomSection: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var inputClippingContainerView: UIView!
    @IBOutlet private weak var inputClippingContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var inputClippingContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var downloadPlayersTitleBar: TitleBar!
    @IBOutlet private weak var createPlayerTitleBar: TitleBar!
    @IBOutlet private weak var downloadPlayersContainerView: UIView!
    @IBOutlet private weak var downloadPlayersView: UIView!
    @IBOutlet private weak var downloadPlayersContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var downloadPlayersContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerView: CreatePlayerView!
    @IBOutlet private weak var createPlayerContainerView: UIView!
    @IBOutlet private weak var createPlayerContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var createPlayerContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var downloadIdentifierTextField: UITextField!
    @IBOutlet private weak var downloadDownloadButton: ShadowButton!
    @IBOutlet private weak var downloadSeparatorView: UIView!
    @IBOutlet private weak var downloadSeparatorLabel: UILabel!
    @IBOutlet private weak var downloadRelatedPlayersCaption: UILabel!
    @IBOutlet private weak var downloadRelatedPlayersView: RelatedPlayersView!
    @IBOutlet private weak var backButton: ClearButton!
    @IBOutlet private var formLabels: [UILabel]!
     
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func backButtonPressed(_ sender: UIButton) {
        self.dismiss()
    }
    
    @IBAction func downloadDownloadButtonPressed(_ sender: UIButton) {
        self.downloadCloudPlayer(email: self.downloadIdentifierTextField.text!)
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.backButton.setTitle(self.backText)
        self.backButton.setImage(UIImage(named: self.backImage), for: .normal)
        
        self.setupDefaultColors()
        self.downloadRelatedPlayersView.set(email: nil)
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
                    : self.view.frame.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom)
            self.contentView.layoutIfNeeded()
            self.setupSizes()
            self.setupControls()
            if self.firstTime {
                self.change(section: .downloadPlayers)
            }
            self.roundCorners()
        }
        self.rotated = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.firstTime = false
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    private func enableControls() {
        self.downloadDownloadButton.isEnabled = (self.downloadIdentifierTextField.text != "")
    }
    
    // MARK: - Change section ==================================================================== -
    
    private func change(section: Section) {
        self.section = section

        switch section {
        case .downloadPlayers:
            // Change rounding of download title bar
            self.downloadPlayersTitleBar.set(topRounded: true, bottomRounded: false)
        case .createPlayer:
            // Move create players up to fill gap between title bar and panel
            self.createPlayerContainerTopConstraint.constant = -self.titleOverlap
            // Change rounding of download title bar
            self.downloadPlayersTitleBar.set(topRounded: true, bottomRounded: true)
        }
        Utility.animate(duration: 0.5,completion: {
            switch section {
            case .downloadPlayers:
                // Move create players down to have a gap between the title bar and panel
                self.createPlayerContainerTopConstraint.constant = self.separatorHeight
            case .createPlayer:
                // Activate the create players window (set first responder)
                self.createPlayerView.didBecomeActive()
            }
            // Change rounding of create player title bar
            self.createPlayerTitleBar.set(topRounded: true, bottomRounded: section != .createPlayer)
        }, animations: {
            // Slide up/down to the right view
            self.inputClippingContainerTopConstraint.constant = (section == .downloadPlayers ? -self.titleOverlap : 0)
            self.downloadPlayersContainerTopConstraint.constant = -(min(1,CGFloat(section.rawValue)) * self.containerHeight)
        })
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
            self.textFieldDidChange(textField)
            if let email = textField.text {
                self.downloadCloudPlayer(email: email)
            }
        }
        return true
    }
    
    // MARK: - Create Player Delegate ============================================================= -
    
    internal func didCreatePlayer(playerDetail: PlayerDetail) {
        self.bubbleView.show(from: self.view, message: "\(playerDetail.name)\ncreated")
        self.playerCreated(playerDetail: playerDetail, reloadRelatedPlayers: true)
    }
    
    // MARK: - Related Players Delegate ============================================================ -
    
    internal func didDownloadPlayers(playerDetailList: [PlayerDetail], emailPlayerUUID: String?) {
        for playerDetail in playerDetailList {
            self.playerCreated(playerDetail: playerDetail, reloadRelatedPlayers: true)
        }
    }

    // MARK: - Sync routines including the delegate methods ======================================== -
    
    // Used to download a single player
    
    private func downloadCloudPlayer(email: String) {
      
        sync = Sync()
        self.sync?.delegate = self
        
        self.lockDuringDownload()
        
        // Get related players from cloud
        if !(self.sync?.synchronise(syncMode: .syncGetPlayerDetails, specificEmail: email, waitFinish: true, okToSyncWithTemporaryPlayerUUIDs: true) ?? false) {
            self.syncCompletion(-1)
        }

    }
    
    private func getImages(_ imageFromCloud: [PlayerMO]) {
        self.sync.fetchPlayerImagesFromCloud(imageFromCloud)
    }
    
    internal func syncMessage(_ message: String) {
    }
    
    internal func syncAlert(_ message: String, completion: @escaping ()->()) {
        self.alertMessage(message) {
            completion()
            self.unlockAfterDownload()
        }
    }
    
    internal func syncCompletion(_ errors: Int) {
        Utility.mainThread {
            self.unlockAfterDownload()
        }
    }
    
    internal func syncReturnPlayers(_ returnedList: [PlayerDetail]!, _ thisPlayerUUID: String?) {
        Utility.mainThread {
            if returnedList?.count ?? 0 == 0 {
                self.alertMessage("Player not found", okHandler: self.unlockAfterDownload)
            } else {
                for playerDetail in returnedList {
                    // Note should only be one
                    if Scorecard.shared.isDuplicatePlayerUUID(playerDetail) {
                        self.alertMessage("A player with this Unique ID already exists on this device", okHandler: self.unlockAfterDownload)
                    } else {
                        self.addNewPlayer(playerDetail: playerDetail)
                        self.bubbleView.show(from: self.view, message: "\(playerDetail.name)\ndownloaded", completion: self.unlockAfterDownload)
                    }
                }
            }
        }
    }
    
    func addNewPlayer(playerDetail: PlayerDetail) {
        // Add new player to local database
        
        if let playerMO = playerDetail.createMO() {
            if playerDetail.thumbnailDate != nil && playerDetail.syncRecordID != nil {
                self.getImages([playerMO])
            }
            self.playerCreated(playerDetail: playerDetail, reloadRelatedPlayers: true)
        }
    }
    
    private func lockDuringDownload() {
        self.downloadIdentifierTextField.text = ""
        self.downloadIdentifierTextField.placeholder = "Downloading ..."
        self.bottomSection.isUserInteractionEnabled = false
    }
    
    private func unlockAfterDownload() {
        self.downloadIdentifierTextField.placeholder = "Enter identifier"
        self.bottomSection.isUserInteractionEnabled = true
    }
    // MARK: - Button delegate ==================================================================== -
    
    internal func buttonPressed(_ button: UIView) {
        switch button.tag {
        case Section.downloadPlayers.rawValue:
            self.createPlayerView.willBecomeInactive {
                self.change(section: .downloadPlayers)
                self.downloadIdentifierTextField.becomeFirstResponder()
            }
        
        case Section.createPlayer.rawValue:
            self.change(section: .createPlayer)
            
        default:
            break
        }
    }

    // MARK: - Utility routines ========================================================================= -
    
    internal func playerCreated(playerDetail: PlayerDetail, reloadRelatedPlayers: Bool) {
        // Remove from the downloaded list if it is there
        if reloadRelatedPlayers {
            // Reload the list to include players related to the new players
            self.downloadRelatedPlayersView.set(email: nil)
        } else {
            // Just remove this player from the list
            if let email = playerDetail.tempEmail {
                self.downloadRelatedPlayersView.remove(email: email)
            } else {
                self.downloadRelatedPlayersView.remove(playerUUID: playerDetail.playerUUID)
            }
        }
        // Add to downloaded list
        self.downloadList.append(playerDetail)
    }
    
    // MARK: - View defaults ============================================================================ -
    
    private func setupDefaultColors() {
        self.view.backgroundColor = Palette.banner
        
        self.titleLabel.textColor = Palette.bannerText
        
        self.downloadPlayersTitleBar.set(faceColor: Palette.buttonFace)
        self.downloadPlayersTitleBar.set(textColor: Palette.buttonFaceText)
        
        self.createPlayerTitleBar.set(faceColor: Palette.buttonFace)
        self.createPlayerTitleBar.set(textColor: Palette.buttonFaceText)
        
        self.downloadPlayersView.backgroundColor = Palette.buttonFace
                
        self.downloadDownloadButton.setBackgroundColor(Palette.confirmButton)
        self.downloadDownloadButton.setTitleColor(Palette.confirmButtonText, for: .normal)
        
        self.downloadSeparatorView.backgroundColor = Palette.separator
        self.downloadSeparatorLabel.backgroundColor = Palette.buttonFace
        self.downloadSeparatorLabel.textColor = Palette.buttonFaceText
                        
        self.formLabels.forEach { $0.textColor = Palette.text }
    }
    
    private func setupSizes() {
        
        if !Utility.animating {
            
            // Setup heights for the input containers and clipping views
            let titleBarHeight: CGFloat = self.downloadPlayersTitleBar.frame.height
            
            let clippingHeight = self.bottomSection.frame.height - titleBarHeight - (self.view.safeAreaInsets.bottom == 0.0 ? 5.0 : 0.0) - self.separatorHeight + self.titleOverlap
            
            self.containerHeight = clippingHeight - titleBarHeight - self.separatorHeight - 10.0 // to allow for shadow
            self.downloadPlayersContainerHeightConstraint.constant = self.containerHeight
            self.createPlayerContainerHeightConstraint.constant = self.createPlayerView.requiredHeight
            self.inputClippingContainerHeightConstraint.constant = clippingHeight
        }
    }
    
    private func roundCorners() {
        self.downloadPlayersView.layoutIfNeeded()
        self.createPlayerView.layoutIfNeeded()
        self.downloadPlayersView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
        self.createPlayerView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
    }
    
    private func setupControls() {
       
        self.bottomSection.addShadow()

        self.downloadPlayersTitleBar.set(font: UIFont.systemFont(ofSize: 17, weight: .bold))
            
        self.createPlayerTitleBar.set(font: UIFont.systemFont(ofSize: 17, weight: .bold))
        self.createPlayerTitleBar.set(topRounded: true, bottomRounded: true)

        self.addTargets(self.downloadIdentifierTextField)
    }
        
    // MARK: - Function to show and dismiss this view  ============================================================================== -
    
    public class func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, backText: String = "", backImage: String = "back", completion: (([PlayerDetail]?)->())? = nil) -> SelectPlayersViewController? {
        
        let storyboard = UIStoryboard(name: "SelectPlayersViewController", bundle: nil)
        let selectPlayersViewController = storyboard.instantiateViewController(withIdentifier: "SelectPlayersViewController") as! SelectPlayersViewController
        
        selectPlayersViewController.preferredContentSize = CGSize(width: 400, height: 700)
        selectPlayersViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        selectPlayersViewController.backImage = backImage
        selectPlayersViewController.backText = backText
        selectPlayersViewController.completion = completion
    
        viewController.present(selectPlayersViewController, appController: appController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
        return selectPlayersViewController
    }
    
    private func dismiss()->() {
        self.dismiss(animated: true, completion: {
            self.completion?(self.downloadList)
        })
    }
    
    override internal func didDismiss() {
        self.cancelAction()
        self.dismiss()
    }
    
    private func cancelAction() {
        // Abandon any sync in progress
        self.sync?.stop()
    }
}

class BubbleView: UIView {
    
    private var shadowView: UIView?
    private var label: UILabel?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.isHidden = true
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.isHidden = true
    }
    
    func show(from view: UIView, message: String, size: CGFloat = 150, completion: (()->())? = nil) {
        self.frame = CGRect(x: 0, y: 0, width: size, height: size)
        self.alpha = 1
        if self.label == nil {
            self.shadowView = UIView(frame: CGRect(origin: CGPoint(), size: self.frame.size))
            self.toCircle(self.shadowView)
            self.shadowView?.backgroundColor = Palette.banner
            self.addSubview(self.shadowView!)
            self.label = UILabel(frame: CGRect(x: 5, y: 5, width: size - 10, height: size - 10))
            self.label?.backgroundColor = UIColor.clear
            self.label?.textColor = Palette.bannerText
            self.label?.numberOfLines = 0
            self.label?.adjustsFontSizeToFitWidth = true
            self.label?.textAlignment = .center
            self.shadowView?.addSubview(self.label!)
            self.addShadow(shadowOpacity: 0.5)
        }
        self.label?.text = message
        self.removeFromSuperview()
        view.addSubview(self)
        view.bringSubviewToFront(self)
        self.isHidden = false
        self.transform = CGAffineTransform(scaleX: 0, y: 0)
        Utility.animate(duration: 0.25,
            completion: {
                Utility.animate(duration: 0.2, afterDelay: 2.0,
                    completion: {
                        self.transform = CGAffineTransform(scaleX: 1, y: 1)
                        completion?()
                    },
                    animations: {
                        Utility.getActiveViewController()?.alertSound(sound: .lock)
                        self.frame = CGRect(x: view.frame.maxX, y: view.frame.maxY / 8, width: size, height: size)
                        self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                        self.alpha = 0
                    })
            },
            animations: {
                self.transform = CGAffineTransform(scaleX: 1, y: 1)
                self.frame = CGRect(x: view.frame.midX - (size / 2), y: max(50, view.frame.midY - size), width: size, height: size)
            })
    }
    
    func toCircle(_ view: UIView?) {
        view?.layer.cornerRadius = self.layer.bounds.height / 2
        view?.layer.masksToBounds = true
    }
    
}
