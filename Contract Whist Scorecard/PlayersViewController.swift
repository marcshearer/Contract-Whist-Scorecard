//
//  PlayersViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

protocol PlayersViewDelegate : class {
    func playerRemoved(playerUUID: String)
    func refresh()
    func set(isEnabled: Bool)
}

class PlayersViewController: ScorecardViewController, PlayersViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, BannerDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Properties to get state
    private var completion: (()->())?
    
    // Other properties
    private var playerObserver: NSObjectProtocol?
    private var imageObserver: NSObjectProtocol?
    
    private var playerDetailList: [PlayerDetail]!
    
    internal var playerDetailView: PlayerDetailViewDelegate?
    
    private var removing: Bool = false
    private var isEnabled: Bool = true
    private var rotated: Bool = false
    private var firstTime: Bool = true
    
    // UI properties
    private var horizontalInset: CGFloat = 16.0
    private let verticalInset: CGFloat = 16.0
    private var minAcross = 3
    private let idealWidth: CGFloat = 210.0
    private var spacing: CGFloat = 16.0
    private let thumbnailInset: CGFloat = 16.0
    private let aspectRatio: CGFloat = 4.0/3.0
    private var cellWidth: CGFloat = 0.0

    private var sync: Sync!
    internal let syncDelegateDescription = "PlayerDetail"

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var collectionView: UICollectionView!
    
    // MARK: - IB Actions ============================================================================== -
    
    internal func addPlayerPressed() {
        self.showSelectPlayers()
    }
    
    internal func removePlayerPressed() {
        self.removing = true
        self.startWiggle()
        self.enableButtons()
    }

    internal func removePlayerCancelPressed() {
        self.removing = false
        self.stopWiggle()
        self.enableButtons()
    }

    internal func finishPressed() { // ButtonDelegate
        
        self.dismissAction()
        self.dismiss()
    }
    
    @IBAction func downSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            self.finishPressed()
        }
    }
    
    // MARK: - View Overrides ========================================================================== -
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()
        
        // Set nofifications for player image download
        playerObserver = setPlayerDownloadNotification(name: .playerDownloaded)
        imageObserver = setPlayerDownloadNotification(name: .playerImageDownloaded)
        
        // Set up player list
        self.playerDetailList = Scorecard.shared.playerDetailList()
        
        // Update from cloud
        self.updatePlayersFromCloud()
        
        // Setup help
        self.setupHelpView()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.collectionView.setNeedsLayout()
        self.collectionView.layoutIfNeeded()
        
        self.setupSize()
        let collectionViewLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        collectionViewLayout!.invalidateLayout()
        self.collectionView.reloadData()
        
        if self.firstTime || self.rotated {
            self.setupButtons()
            self.firstTime = false
            self.rotated = false
        }
        self.enableButtons()
    }
    
    override func rightPanelDidDisappear() {
        self.playerDetailView = nil
    }
    
    // MARK: - Players View Delegate ================================================================= -
    
    internal func playerRemoved(playerUUID: String) {
        if let index = self.playerDetailList.firstIndex(where: {$0.playerUUID == playerUUID}) {
            self.playerDetailList.remove(at: index)
            self.collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
        }
    }
    
    internal func refresh() {
        self.collectionView.reloadData()
    }
    
    internal func set(isEnabled: Bool) {
        self.isEnabled = isEnabled
        self.collectionView.reloadData()
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    private func setupSize() {
        self.minAcross = (ScorecardUI.landscapePhone() ? 5 : 3)
        self.horizontalInset = ((self.menuController?.isVisible ?? false) ? 20 : 16)
        self.spacing = min(16.0, self.collectionView.frame.width / 25)
        self.collectionView.contentInset = UIEdgeInsets(top: self.verticalInset, left: self.horizontalInset, bottom: self.verticalInset, right: self.horizontalInset)
        let availableWidth = self.collectionView.frame.width + self.spacing - (2 * self.horizontalInset)
        let idealAcross = max(self.minAcross, Int(availableWidth / idealWidth))
        let cellSpacedWidth = availableWidth / CGFloat(idealAcross)
        self.cellWidth = cellSpacedWidth - self.spacing
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.playerDetailList.count
    }
    
   func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.cellWidth, height: self.cellWidth * self.aspectRatio)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return self.spacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return self.spacing
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Player Cell", for: indexPath) as! PlayerCell
        
        cell.tile.backgroundColor = (self.isEnabled ? Palette.buttonFace.background : Palette.disabled.background)
        cell.thumbnail.set(textColor: self.isEnabled ? Palette.buttonFace.text : Palette.disabled.faintText)
        cell.isUserInteractionEnabled = self.isEnabled
        cell.thumbnail.set(playerMO: self.playerDetailList[indexPath.item].playerMO, nameHeight: 20, diameter: self.cellWidth - (thumbnailInset * 2))
        cell.set(thumbnailInset: self.thumbnailInset)
        if self.removing {
            cell.thumbnail.startWiggle()
        } else {
            cell.thumbnail.stopWiggle()
        }
        cell.addShadow()
        
        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if self.removing {
            self.removePlayer(at: indexPath)
        } else {
            self.amendPlayer(at: indexPath)
        }
    }
    
    func amendPlayer(at indexPath: IndexPath) {
        let playerDetail = self.playerDetailList[indexPath.row]
        if let playerDetailView = self.playerDetailView {
            self.rootViewController.rightPanelDefaultScreenColors(rightInsetColor: Palette.normal.background)
            self.setRightPanel(title: playerDetail.name, caption: "")
            playerDetailView.refresh(playerDetail: playerDetail, mode: .amend)
        } else {
            PlayerDetailViewController.show(from: self, playerDetail: playerDetail, mode: .amend, sourceView: self.view, playersViewDelegate: self, returnTo: "Return to Profiles")
        }
    }
    
    func removePlayer(at indexPath: IndexPath) {
            
        if let playerMO = self.playerDetailList[indexPath.item].playerMO {
            if playerMO.playerUUID == Scorecard.settings.thisPlayerUUID {
                self.alertMessage("This player is set up as yourself and therefore cannot be removed.\n\nIf you want to remove this player, select another player as yourself in Settings first.")
            } else {
                self.alertDecision("This will remove the player \n'\(playerMO.name!)'\nfrom this device.\n\nIf you have synchronised with iCloud the player will still be available to download in future.\n Otherwise this will remove their details permanently.\n\n Are you sure you want to do this?", title: "Warning", okButtonText: "Remove", okHandler: {
                    self.collectionView.performBatchUpdates({
                        // Remove from core data, the player list and the collection view etc
                        
                        // Remove from email cache
                        Scorecard.shared.playerEmails[playerMO.playerUUID!] = nil
                        
                        // Remove from player list
                        if let index = Scorecard.shared.playerList.firstIndex(where: {$0.playerUUID == playerMO.playerUUID}) {
                            Scorecard.shared.playerList.remove(at: index)
                        }
                        
                        // Remove from collection view and player detail list
                        self.collectionView.deleteItems(at: [indexPath])
                        self.playerDetailList.remove(at: indexPath.item)
                        
                        // Stop wiggling
                        if let cell = self.collectionView.cellForItem(at: indexPath) as? PlayerCell {
                            cell.thumbnail?.stopWiggle()
                        }
                        
                        if CoreData.update(updateLogic: {
                            CoreData.delete(record: playerMO)
                        }) {
                            // Save to iCloud
                            Scorecard.settings.saveToICloud()
                        }
                    })
                })
            }
        }
    }
    
    // MARK: Sync handlers =============================================================== -
    
    private func updatePlayersFromCloud(players: [String]? = nil) {
        
        if Scorecard.activeSettings.syncEnabled && Scorecard.shared.isNetworkAvailable && Scorecard.shared.isLoggedIn {
            
            let players = players ?? Scorecard.shared.playerUUIDList()
            
            // Synchronise players
            if players.count > 0 {
                if self.sync == nil {
                    self.sync = Sync()
                }
                _ = self.sync.synchronise(syncMode: .syncUpdatePlayers, specificPlayerUUIDs: players, waitFinish: true, okToSyncWithTemporaryPlayerUUIDs: true)
            }
        }
    }
    
    // MARK: - Image download handlers =================================================== -
    
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
            // Update the player from the managed object
            if let index = self.playerDetailList.firstIndex(where: {($0.objectID == objectID)}) {
                // Found it - reload the cell
                self.playerDetailList[index].restoreMO()
                self.collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
            } else {
                // New player - shouldn't happen but refresh view just in case
                self.collectionView.reloadData()
            }
        }
    }
    
    // MARK: - UI setup routines ======================================================================== -
    
    private func setupButtons() {
        let font = UIFont.systemFont(ofSize: 16)
        self.banner.set(
            rightButtons: [
                BannerButton(action: self.helpPressed, type: .help)],
            lowerButtons: [
                BannerButton(title: "Add", width: 140, action: self.addPlayerPressed, type: .shadow, menuHide: true, menuText: "Add Players", font: font, id: "add"),
                BannerButton(title: "Remove", width: 140, action: self.removePlayerPressed, type: .shadow, menuHide: true, menuText: "Remove Players", font: font, id: "remove"),
                BannerButton(title: "Finish", width: 140, action: self.removePlayerCancelPressed, type: .shadow, menuHide: true, menuText: "End Removing Players", font: font, id: "cancel")],
            menuOption: .profiles,
            normalOverrideHeight: 120)
    }
    
    private func enableButtons() {
        self.banner.setButton("cancel", isHidden: !removing, disableOptions: removing)
        self.banner.setButton("add", isHidden: removing)
        self.banner.setButton("remove", isHidden: removing)
    }
        
    // MARK: - Utility routines ============================================================================== -
    
    private func showSelectPlayers() {
        self.hideDetail()
        _ = SelectPlayersViewController.show(from: self, playerDetailView: self.playerDetailView) { (playerList) in
            if playerList != nil {
                self.playerDetailList = Scorecard.shared.playerDetailList()
                self.collectionView.reloadData()
            }
        }
    }
    
    private func hideDetail() {
        self.playerDetailView?.hide()
        self.setRightPanel(title: "", caption: "")
        self.rootViewController.rightPanelDefaultScreenColors(rightInsetColor: Palette.banner.background)
    }
    
    private func forEachCell(_ action: (String, PlayerCell)->()) {
        for (item, playerDetail) in self.playerDetailList.enumerated() {
            if let cell = self.collectionView.cellForItem(at: IndexPath(item: item, section: 0)) as? PlayerCell {
                action(playerDetail.playerUUID, cell)
            }
        }
    }
    
    private func startWiggle() {
        self.forEachCell { (playerUUID, cell) in
            cell.thumbnail?.startWiggle()
        }
    }

    private func stopWiggle() {
        self.forEachCell { (_, cell) in
            cell.thumbnail?.stopWiggle()
        }
    }

    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func create(completion: (()->())?) -> PlayersViewController {
    
        let storyboard = UIStoryboard(name: "PlayersViewController", bundle: nil)
        let playersViewController: PlayersViewController = storyboard.instantiateViewController(withIdentifier: "PlayersViewController") as! PlayersViewController
        
        playersViewController.completion = completion
        
        return playersViewController
    }
    
    @discardableResult class public func show(from viewController: ScorecardViewController, completion: (()->())?) -> PlayersViewController {
        
        let playersViewController = PlayersViewController.create(completion: completion)
        
        viewController.present(playersViewController, animated: true, container: .mainRight, completion: nil)
        
        return playersViewController
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: {
            self.completion?()
        })
    }
    
    override internal func didDismiss() {
        self.dismissAction()
        self.completion?()
    }
    
    private func dismissAction() {
        NotificationCenter.default.removeObserver(playerObserver!)
        NotificationCenter.default.removeObserver(imageObserver!)
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class PlayerCell: UICollectionViewCell {
    private var thumbnailInset: CGFloat!
    
    @IBOutlet fileprivate weak var thumbnail: ThumbnailView!
    @IBOutlet fileprivate weak var tile: UIView!
    @IBOutlet fileprivate var thumbnailInsets: [NSLayoutConstraint]!

    public func set(thumbnailInset: CGFloat) {
        self.thumbnailInset = thumbnailInset
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.thumbnailInsets.forEach { (inset) in
            inset.constant = self.thumbnailInset
        }
        self.tile.layoutIfNeeded()
        self.tile.roundCorners(cornerRadius: 8.0)
    }
}

extension PlayersViewController {

    private func defaultViewColors() {
        self.view.backgroundColor = Palette.normal.background
    }
}

extension PlayersViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
                
        self.helpView.add("This screen allows you to add, remove or change the players on this device.")
        
        self.helpView.add("This area shows the photo and name of all the players on this device. Tap on a player to see their details.", views: [self.collectionView], item: 0, itemTo: 999, border: 8, shrink: true)
        
        self.helpView.add("The {} allows you to add new players. These can either be completely new players, or existing players created on another device, but not yet downloaded from iCloud to this device.", bannerId: "add")
        
        self.helpView.add("The {} allows you to remove players from this device. Note that if they have been synced to iCloud they will still exist there and can be downloaded again in future.", bannerId: "remove")
        
        self.helpView.add("The {} takes you out of remove mode.", bannerId: "cancel")
        
        self.helpView.add("The {} exits the @*/Profiles@*/ screen and returns you to the @*/Home@*/ screen.", bannerId: Banner.finishButton)
    }
}
