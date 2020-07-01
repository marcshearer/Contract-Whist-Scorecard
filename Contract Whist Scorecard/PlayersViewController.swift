//
//  PlayersViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class PlayersViewController: ScorecardViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Properties to get state
    private var completion: (()->())?
    private var backText = ""
    private var backImage = "home"
    
    // Other properties
    private var playerObserver: NSObjectProtocol?
    private var imageObserver: NSObjectProtocol?
    
    private var playerDetailList: [PlayerDetail]!
    
    private var removing: Bool = false
    
    // UI properties
    private let minAcross: CGFloat = 3.0
    private let minDown: CGFloat = 2.0
    private let spacing: CGFloat = 16.0
    private let thumbnailInset: CGFloat = 16.0
    private let aspectRatio: CGFloat = 4.0/3.0
    private var cellWidth: CGFloat = 0.0

    private var sync: Sync!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var finishButton: ClearButton!
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var topSection: UIView!
    @IBOutlet private weak var titleBar: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var addPlayerButton: ShadowButton!
    @IBOutlet private weak var removePlayerButton: ShadowButton!
    @IBOutlet private weak var removePlayerCancelButton: ShadowButton!
    @IBOutlet private weak var collectionView: UICollectionView!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func addPlayerPressed(_ sender: UIButton) {
        self.showSelectPlayers()
    }
    
    @IBAction func removePlayerPressed(_ sender: UIButton) {
        self.removing = true
        self.startWiggle()
        self.enableButtons()
    }

    @IBAction func removePlayerCancelPressed(_ sender: UIButton) {
        self.removing = false
        self.stopWiggle()
        self.enableButtons()
    }

    @IBAction func finishPressed(sender: UIButton) {
        
        self.dismissAction()
        self.dismiss()
    }
    
    @IBAction func downSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            self.finishPressed(sender: finishButton)
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
        
        self.collectionView.contentInset = UIEdgeInsets(top: self.spacing, left: self.spacing, bottom: self.spacing, right: self.spacing)
        
        // Update from cloud
        self.updatePlayersFromCloud()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        Scorecard.shared.reCenterPopup(self)
        
        self.setupSize()
        
        self.collectionView.setNeedsLayout()
        self.collectionView.layoutIfNeeded()
        
        self.formatButtons()
        self.enableButtons()
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    private func setupSize() {
        let availableWidth = self.collectionView.frame.width - spacing
        let availableHeight = self.collectionView.frame.height - spacing
        var cellSpacedWidth = min(140, availableWidth / minAcross)
        let cellSpacedHeight = min(210, availableHeight / minDown)
        cellSpacedWidth = min(cellSpacedWidth, cellSpacedHeight / aspectRatio)
        self.cellWidth = cellSpacedWidth - spacing
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.playerDetailList.count
    }
    
   func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.cellWidth, height: self.cellWidth * self.aspectRatio)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Player Cell", for: indexPath) as! PlayerCell
        self.defaultCellColors(cell: cell)
        
        cell.thumbnail.set(playerMO: self.playerDetailList[indexPath.item].playerMO, nameHeight: 20, diameter: self.cellWidth - (thumbnailInset * 2))
        cell.set(thumbnailInset: self.thumbnailInset)
        if self.removing {
            cell.thumbnail.startWiggle()
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
        PlayerDetailViewController.show(from: self, playerDetail: playerDetail, mode: .amend, sourceView: self.view)
        { (playerDetail, deletePlayer) in
            if playerDetail != nil {
                if deletePlayer {
                    // Remove it
                    self.collectionView.performBatchUpdates({
                        self.playerDetailList.remove(at: indexPath.item)
                        self.collectionView.deleteItems(at: [indexPath])
                    })
                } else {
                    // Refresh updated player
                    self.collectionView.reloadItems(at: [indexPath])
                }
            }
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

    func formatButtons() {
        
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText)
    }
    
    func enableButtons() {
        self.addPlayerButton.isHidden = removing
        self.removePlayerButton.isHidden = removing
        self.removePlayerCancelButton.isHidden = !removing
    }
        
    // MARK: - Utility routines ============================================================================== -
    
    private func showSelectPlayers() {
        _ = SelectPlayersViewController.show(from: self, completion: { (playerList) in
            if playerList != nil {
                self.playerDetailList = Scorecard.shared.playerDetailList()
                self.collectionView.reloadData()
            }
        })
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
    
    class public func show(from viewController: ScorecardViewController, backText: String = "", backImage: String = "home", completion: (()->())?){
        
        let storyboard = UIStoryboard(name: "PlayersViewController", bundle: nil)
        let playersViewController: PlayersViewController = storyboard.instantiateViewController(withIdentifier: "PlayersViewController") as! PlayersViewController
        
        playersViewController.preferredContentSize = CGSize(width: 400, height: 700)
        playersViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        playersViewController.backText = backText
        playersViewController.backImage = backImage
        playersViewController.completion = completion
        
        viewController.present(playersViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
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
        self.view.backgroundColor = Palette.background
        self.bannerPaddingView.backgroundColor = Palette.banner
        self.topSection.backgroundColor = Palette.banner
        self.titleLabel.textColor = Palette.bannerText
        self.addPlayerButton.setBackgroundColor(Palette.bannerShadow)
        self.addPlayerButton.setTitleColor(Palette.bannerText, for: .normal)
        self.removePlayerButton.setBackgroundColor(Palette.bannerShadow)
        self.removePlayerButton.setTitleColor(Palette.bannerText, for: .normal)
        self.removePlayerCancelButton.setBackgroundColor(Palette.bannerShadow)
        self.removePlayerCancelButton.setTitleColor(Palette.bannerText, for: .normal)
    }
    
    private func defaultCellColors(cell: PlayerCell) {
        cell.tile.backgroundColor = Palette.buttonFace
        cell.thumbnail.set(textColor: Palette.buttonFaceText)
    }
}
