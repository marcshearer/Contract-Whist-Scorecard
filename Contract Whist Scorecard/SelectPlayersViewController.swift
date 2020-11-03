//
//  SelectPlayersController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 19/03/2019.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class SelectPlayersViewController: ScorecardViewController, SyncDelegate, ButtonDelegate, CreatePlayerViewDelegate, RelatedPlayersDelegate, BannerDelegate {
    
    private enum Section: Int {
        case downloadPlayers = 0
        case createPlayer = 1
     }
    
    // Main state properties
    private var sync: Sync!
    internal let syncDelegateDescription = "SelectPlayers"
    private var playerDetailView: PlayerDetailViewDelegate!

    // Properties to pass state to action controller
    private var selection: [Bool] = []
    private var playerList: [PlayerDetail] = []
    private var selected = 0
    private var completion: (([PlayerDetail]?)->())?
    
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
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var bottomSection: UIView!
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
    @IBOutlet private weak var downloadIdentifierView: UIView!
    @IBOutlet private weak var downloadDownloadButton: ShadowButton!
    @IBOutlet private weak var downloadSeparatorView: UIView!
    @IBOutlet private weak var downloadSeparatorLabel: UILabel!
    @IBOutlet private weak var downloadRelatedPlayersCaption: UILabel!
    @IBOutlet private weak var downloadRelatedPlayersView: RelatedPlayersView!
    @IBOutlet private var formLabels: [UILabel]!
     
    // MARK: - IB Actions ============================================================================== -
    
    internal func finishPressed() {
        self.dismiss()
    }
    
    @IBAction func downloadDownloadButtonPressed(_ sender: UIButton) {
        self.downloadCloudPlayer(email: self.downloadIdentifierTextField.text!)
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup banner
        self.setupBanner()
        
        // Setup help
        self.setupHelpView()
                
        self.setupDefaultColors()
        self.downloadRelatedPlayersView.set(email: nil, playerDetailView: playerDetailView)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        self.view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if self.firstTime || self.rotated {
            self.contentViewHeightConstraint.constant =
                (ScorecardUI.landscapePhone() ? ScorecardUI.screenWidth
                    : self.view.frame.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom - self.banner.height)
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
    
    private func setupBanner() {
        self.banner.set(
            rightButtons: [
                BannerButton(action: self.helpPressed, type: .help)])
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
        textField.addTarget(self, action: #selector(SelectPlayersViewController.textFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        textField.addTarget(self, action: #selector(SelectPlayersViewController.textFieldShouldReturn(_:)), for: UIControl.Event.editingDidEndOnExit)
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
            self.playerCreated(playerDetail: playerDetail, reloadRelatedPlayers: false)
        }
        // Reload the list to include players related to the new players
        self.downloadRelatedPlayersView.set(email: nil, playerDetailView: self.playerDetailView)
        
        let count = playerDetailList.count
        self.bubbleView.show(from: self.view, message: "\(count) player\(count == 1 ? "" : "s")\ncreated")
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
                if let playerDetailView = self.playerDetailView, let playerDetail = returnedList.first {
                    self.setRightPanel(title: playerDetail.name, caption: "")
                    playerDetailView.refresh(playerDetail: playerDetail, mode: .display)
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
            self.downloadRelatedPlayersView.set(email: nil, playerDetailView: self.playerDetailView)
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
        self.view.backgroundColor = self.defaultBannerColor.background
        
        self.downloadPlayersTitleBar.set(faceColor: Palette.buttonFace.background)
        self.downloadPlayersTitleBar.set(textColor: Palette.buttonFace.text)
        
        self.createPlayerTitleBar.set(faceColor: Palette.buttonFace.background)
        self.createPlayerTitleBar.set(textColor: Palette.buttonFace.text)
        
        self.downloadPlayersView.backgroundColor = Palette.buttonFace.background
                
        self.downloadDownloadButton.setBackgroundColor(Palette.confirmButton.background)
        self.downloadDownloadButton.setTitleColor(Palette.confirmButton.text, for: .normal)
        
        self.downloadSeparatorView.backgroundColor = Palette.separator.background
        self.downloadSeparatorLabel.backgroundColor = Palette.buttonFace.background
        self.downloadSeparatorLabel.textColor = Palette.buttonFace.text
                        
        self.formLabels.forEach { $0.textColor = Palette.normal.text }
    }
    
    private func setupSizes() {
        
        if !Utility.animating || self.firstTime {
            
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
        self.downloadIdentifierView.roundCorners(cornerRadius: 5.0)
        self.downloadIdentifierView.backgroundColor = Palette.inputControl.background
    }
        
    // MARK: - Function to show and dismiss this view  ============================================================================== -
    
    public class func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, playerDetailView: PlayerDetailViewDelegate? = nil, completion: (([PlayerDetail]?)->())? = nil) -> SelectPlayersViewController? {
        
        let storyboard = UIStoryboard(name: "SelectPlayersViewController", bundle: nil)
        let selectPlayersViewController = storyboard.instantiateViewController(withIdentifier: "SelectPlayersViewController") as! SelectPlayersViewController
        
        selectPlayersViewController.appController = appController
        selectPlayersViewController.playerDetailView = playerDetailView
        selectPlayersViewController.completion = completion
    
        viewController.present(selectPlayersViewController, appController: appController, animated: true, container: .mainRight, completion: nil)
        
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

extension SelectPlayersViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
                
        self.helpView.add("The @*/\(self.banner.title ?? "Select Players")@*/ screen allows you to add players to your device.\n\nYou can either download existing players from iCloud or create new players.\n\n\(self.section == .downloadPlayers ? "To create new players tap the @*/Create New Player@*/ button.\n\nYou can download players in two way\n- either by entering the player's **Unique ID**\n- or by selecting from a list of players who have **played a game with a player on this device**." : "To download players from iCloud tap the @*/Download Players@*/ button.")")
        
        self.helpView.add("To download a player using their **Unique ID**, enter it in the identifier box and then tap the @*/Download@*/ button.", views: [self.downloadIdentifierView, self.downloadDownloadButton], condition: {self.section == .downloadPlayers }, border: 4)
        
        self.downloadRelatedPlayersView.addHelp(to: self.helpView, condition: { self.section == .downloadPlayers })
        
        self.helpView.add("Tap the @*/Create Player@*/ button to create a new player who has not already been created on another device.", views: [self.createPlayerTitleBar], condition: { self.section == .downloadPlayers })
        
        self.helpView.add("Tap the @*/Download Players@*/ button to download existing players from iCloud", views: [self.downloadPlayersTitleBar], condition: {self.section == .createPlayer })
        
        self.createPlayerView.addHelp(to: self.helpView, condition: { self.section == .createPlayer })
        
    }
    

}
