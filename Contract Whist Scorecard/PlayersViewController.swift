//
//  PlayersViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class PlayersViewController: CustomViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    public var scorecard: Scorecard!
    
    // Properties to pass state to action segue
    public var selection = [Bool]()
    
    // Properties to pass state to detail segue
    public var multiSelectMode = false
    
    // Properties to get state from calling segue
    public var playerList: [PlayerDetail]!
    public var detailMode: DetailMode = .amend // Also passed on to detail segue
    public var returnSegue = ""
    public var backText = "Back"
    public var backImage = "back"
    public var actionText = "Compare"
    public var actionSegue = "showStatistics"
    public var allowSync = true
    public var layoutComplete = false
    public var selected = 0

    // Local class variables
    private var selectedPlayer = 0
    private var playerDetail: PlayerDetail!
    private var labelFontSize: CGFloat = 14.0
    private var labelWidth: CGFloat = 120.0
    private var labelHeight: CGFloat = 17.0
    private var width: CGFloat = 0
    private var observer: NSObjectProtocol?

    // UI component pointers
    var collectionCell = [PlayerCell?]()
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var playersCollectionView: UICollectionView!
    @IBOutlet weak var selectButton: RoundedButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var finishButton: RoundedButton!
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var toolbarViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var footerPaddingTopConstraint: NSLayoutConstraint!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    @IBAction func hidePlayersPlayerDetail(segue:UIStoryboardSegue) {
        
        if detailMode != .display {
            let source = segue.source as! PlayerDetailViewController
            playerDetail = source.playerDetail
            
            if source.playerDetail.name == "" {
                // Cancelled need to restore from Managed Object
                source.playerDetail.restoreMO()
                
            } else {
                // Confirmed - need to delete or update
                if source.deletePlayer {
                    // Update core data with any changes
                    playerDetail.deleteMO()
                    self.playerList.remove(at: selectedPlayer - 1)
                    playersCollectionView.deleteItems(at: [IndexPath(row: selectedPlayer-1, section: 0)])
                    // Remove this player from list of subscriptions
                    Notifications.updateHighScoreSubscriptions(scorecard: self.scorecard)
                    // Delete any detached games
                    History.deleteDetachedGames(scorecard: self.scorecard)
                } else {
                    // Update core data with any changes
                    if !CoreData.update(updateLogic: {
                        let playerMO = playerDetail.playerMO!
                        if playerMO.email != playerDetail.email {
                            // Need to rebuild as email changed
                            playerDetail.toManagedObject(playerMO: playerMO)
                            if Reconcile.rebuildLocalPlayer(playerMO: playerDetail.playerMO) {
                                playerDetail.fromManagedObject(playerMO: playerMO)
                            }
                        } else {
                            playerDetail.toManagedObject(playerMO: playerMO)
                        }
                    }) {
                        self.alertMessage("Error saving player")
                    }
                    
                    playersCollectionView.reloadItems(at: [IndexPath(row: selectedPlayer-1, section: 0)])
                }
            }
        }
    }
    
    @IBAction func hidePlayersSync(segue:UIStoryboardSegue) {
        // Refresh screen
        refreshView()
    }

    // MARK: - IB Actions ============================================================================== -
    @IBAction func selectPressed(sender: UIButton) {
        
        if multiSelectMode {
            if selected > 0 {
                // Go compare
                 NotificationCenter.default.removeObserver(observer!)
                self.performSegue(withIdentifier: actionSegue, sender: self)
            } else {
                // Select all
                selectAll(true)
            }
        } else {
            // Select button is overloaded and is sync in this case
            self.performSegue(withIdentifier: "showPlayersSync", sender: self)
        }
        
        formatButtons()
    }
    
    @IBAction func cancelPressed(sender: UIButton) {
        for playerNumber in 1...selection.count {
            setSelection(playerNumber, false)
        }
        selected = 0
        selectAll(false)
        formatButtons()
    }

    @IBAction func finishPressed(sender: UIButton) {
        
         // Undo any selection
        for playerNumber in 1...selection.count {
            setSelection(playerNumber, false)
        }
        selected = 0
        NotificationCenter.default.removeObserver(observer!)
        self.performSegue(withIdentifier: returnSegue, sender: self)
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            self.finishPressed(sender: finishButton)
        }
    }
    
    // MARK: - View Overrides ========================================================================== -
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for _ in 1...self.playerList.count {
            selection.append(false)
            collectionCell.append(nil)
        }
        
        formatButtons()
        
        if !multiSelectMode {
            if allowSync {
                // Check for network / iCloud login
                scorecard.checkNetworkConnection(button: selectButton, label: nil)
                selectButton.backgroundColor = .clear
                selectButton.setTitle("Sync...")
                selectButton.setTitleColor(UIColor.white, for: .normal)
                selectButton.contentHorizontalAlignment = .right
            } else {
                selectButton.isHidden = true
            }
        }
        
        // Set nofification for image download
        observer = setImageDownloadNotification()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.setNeedsLayout()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutComplete = true
        setWidth(frame: self.view.safeAreaLayoutGuide.layoutFrame)
        self.formatButtons()
        self.playersCollectionView.reloadData()
    }
    
    // MARK: - CollectionView Overrides ================================================================ -

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return (self.layoutComplete ? self.playerList.count : 0)
    }

    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: width, height: width + (ScorecardUI.phoneSize() ? 30 : 60))
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: PlayerCell
        let playerNumber = indexPath.row + 1
        var dateLastPlayed = ""
        
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Player Cell", for: indexPath) as! PlayerCell
        
        collectionCell[playerNumber-1] = cell
        
        // Create new thumbnail
        Utility.setThumbnail(data: self.playerList[playerNumber-1].thumbnail,
                             imageView: cell.playerThumbnail,
                             initials: self.playerList[playerNumber-1].name,
                             label: cell.playerDisc)
        
        cell.playerName.text = self.playerList[playerNumber-1].name
        
        cell.playerPlayed.text = "\(self.playerList[playerNumber-1].gamesPlayed)"
        cell.playerWon.text = "\(Utility.roundPercent(self.playerList[playerNumber-1].gamesWon, self.playerList[playerNumber-1].gamesPlayed)) %"
        cell.playerAverageScore.text = "\(Utility.roundQuotient(self.playerList[playerNumber-1].totalScore, self.playerList[playerNumber-1].gamesPlayed))"
        cell.playerMade.text = "\(Utility.roundPercent(self.playerList[playerNumber-1].handsMade, self.playerList[playerNumber-1].handsPlayed)) %"
        cell.playerTwos.text = "\(Utility.roundPercent(self.playerList[playerNumber-1].twosMade, self.playerList[playerNumber-1].handsPlayed)) %"
        if self.playerList[playerNumber-1].datePlayed != nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM YY"
            dateLastPlayed = formatter.string(from: self.playerList[playerNumber-1].datePlayed)
        } else {
            dateLastPlayed = ""
        }
        cell.playerLastPlayed.text = "\(dateLastPlayed)"
        
        setFont(size: self.labelFontSize, label: cell.playerPlayedLabel, cell.playerPlayed, cell.playerWonLabel, cell.playerWon, cell.playerAverageScoreLabel, cell.playerAverageScore, cell.playerMadeLabel, cell.playerMade, cell.playerTwosLabel, cell.playerTwos, cell.playerLastPlayedLabel, cell.playerLastPlayed)
        setContraints(constant: self.labelWidth, constraint: cell.playerPlayedLabelWidth, cell.playerWonLabelWidth, cell.playerAverageScoreLabelWidth, cell.playerMadeLabelWidth, cell.playerTwosLabelWidth, cell.playerLastPlayedLabelWidth)
        setContraints(constant: self.labelHeight, constraint: cell.playerPlayedLabelHeight, cell.playerWonLabelHeight,cell.playerAverageScoreLabelHeight, cell.playerMadeLabelHeight, cell.playerTwosLabelHeight, cell.playerLastPlayedLabelHeight)
        if !self.scorecard.settingBonus2 {
            // Hide twos if not switched on
            cell.playerTwosLabelHeight.constant = 0
        }
        setHidden(available: cell.playerValuesView.frame.height - 6, label: cell.playerPlayedLabel, cell.playerPlayed, cell.playerWonLabel, cell.playerWon, cell.playerAverageScoreLabel,cell.playerAverageScore, cell.playerMadeLabel, cell.playerMade, cell.playerTwosLabel, cell.playerTwos, cell.playerLastPlayedLabel, cell.playerLastPlayed)
        ScorecardUI.veryRoundCorners(cell.playerThumbnail)
        ScorecardUI.roundCorners(cell.playerDetailsView)
        
        formatCell(cell, to: selection[playerNumber-1])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let playerNumber = indexPath.row+1
        if multiSelectMode {
            let newValue = !selection[playerNumber-1]
            setSelection(playerNumber, newValue)
            if newValue {
                selected += 1
            } else {
                selected -= 1
            }
            formatButtons()
        } else {
            selectedPlayer = playerNumber
            self.performSegue(withIdentifier: "showPlayerDetail", sender: self)
        }
    }
    
    // MARK: - Image download handlers =================================================== -
    
    func setImageDownloadNotification() -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = NotificationCenter.default.addObserver(forName: .playerImageDownloaded, object: nil, queue: nil) {
            (notification) in
            self.updateImage(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }
    
    func updateImage(objectID: NSManagedObjectID) {
        // Find any cells containing an image which has just been downloaded asynchronously
        Utility.mainThread {
            let index = self.playerList.index(where: {($0.objectID == objectID)})
            if index != nil {   
                // Found it - update from managed object and reload the cell
                self.playerList[index!].fromManagedObject(playerMO: self.playerList[index!].playerMO)
                self.playersCollectionView.reloadItems(at: [IndexPath(row: index!, section: 0)])
            }
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -

    func setWidth(frame: CGRect) {
        let totalHeight: CGFloat = frame.height
        let totalWidth: CGFloat = frame.width
        let numberThatFit = (totalWidth > 510 ? Int(totalWidth / 170) : 2)
        width = min(((totalWidth / CGFloat(numberThatFit)) - 1) - 1, totalHeight-30)
        if width <= 200 {
            labelFontSize = 12
            labelWidth = 80
            labelHeight = 15
        } else {
            labelFontSize = 14
            labelWidth = 120
            labelHeight = 17
        }
    }
    
    func setFont(size: CGFloat, label: UILabel...) {
        for each in label {
            each.font = UIFont.systemFont(ofSize: size)
        }
    }
    
    func setContraints(constant: CGFloat, constraint: NSLayoutConstraint...) {
        for each in constraint {
            each.constant = constant
        }
    }
    
    func setHidden(available: CGFloat, label: UILabel...) {
        for each in label {
            each.isHidden = each.frame.maxY > available
        }
    }

    func formatButtons() {
        var toolbarHeight:CGFloat
        
        if multiSelectMode {
            // In multi-select mode
            if selected == 0 {
                selectButton.setTitle("All", for: .normal)
                toolbarHeight = 0
            } else {
                selectButton.setTitle(actionText, for: .normal)
                toolbarHeight = 44
            }
        } else {
            if !allowSync {
                selectButton.isHidden = true
            }
            toolbarHeight = 0
        }
        
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText)
        
        let newToolbarTop = (toolbarHeight == 0 ? 44 : 44 + view.safeAreaInsets.bottom + toolbarHeight)
        if newToolbarTop != self.toolbarViewHeightConstraint.constant {
            Utility.animate {
                self.toolbarViewHeightConstraint.constant = newToolbarTop
            }
        }
    }
    
    func setSelection(_ playerNumber: Int, _ to: Bool) {
        selection[playerNumber-1] = to
        if collectionCell[playerNumber-1] != nil {
            formatCell(collectionCell[playerNumber-1]!, to: to)
        }
    }
    
    func formatCell(_ cell: PlayerCell, to: Bool) {
        cell.playerTick.isHidden = !to
        cell.playerTick.superview!.bringSubviewToFront(cell.playerTick)
        let alpha: CGFloat = (to || !multiSelectMode ? 1.0 : 0.5)
        cell.playerDetailsView.alpha = alpha
        cell.playerValuesView.alpha = alpha
        cell.playerDisc.alpha = alpha
        cell.playerThumbnail.alpha = alpha
        cell.playerTick.alpha = 1.0
    }
    
    func refreshView() {
        // Reset everything
        scorecard.refreshPlayerDetailList(playerList)
        playersCollectionView.reloadData()
        selection.removeAll()
        collectionCell.removeAll()
        selected = 0
        for _ in 1...self.playerList.count {
            selection.append(false)
            collectionCell.append(nil)
        }
        formatButtons()
    }
    
    func selectAll(_ to: Bool) {
        // Select all
        for playerNumber in 1...selection.count {
            setSelection(playerNumber, to)
        }
        selected = (to ? selection.count : 0)
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showPlayerDetail":
            let destination = segue.destination as! PlayerDetailViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view as UIView
            destination.preferredContentSize = CGSize(width: 400, height: 540)
            destination.playerDetail = self.playerList[selectedPlayer - 1]
            destination.returnSegue = "hidePlayersPlayerDetail"
            destination.mode = detailMode
            destination.scorecard = self.scorecard
            destination.sourceView = view
            
        case "showPlayersSync":
            let destination = segue.destination as! SyncViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view
            destination.preferredContentSize = CGSize(width: 400, height: 523)
            destination.returnSegue = "hidePlayersSync"
            destination.scorecard = self.scorecard
        default:
            break
        }
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class PlayerCell: UICollectionViewCell {
    @IBOutlet weak var playerDetailsView: UIView!
    @IBOutlet weak var playerValuesView: UIView!
    @IBOutlet weak var playerThumbnail: UIImageView!
    @IBOutlet weak var playerDisc: UILabel!
    @IBOutlet weak var playerName: UILabel!
    @IBOutlet weak var playerPlayed: UILabel!
    @IBOutlet weak var playerWon: UILabel!
    @IBOutlet weak var playerAverageScore: UILabel!
    @IBOutlet weak var playerMade: UILabel!
    @IBOutlet weak var playerTwos: UILabel!
    @IBOutlet weak var playerLastPlayed: UILabel!
    @IBOutlet weak var playerPlayedLabel: UILabel!
    @IBOutlet weak var playerWonLabel: UILabel!
    @IBOutlet weak var playerAverageScoreLabel: UILabel!
    @IBOutlet weak var playerMadeLabel: UILabel!
    @IBOutlet weak var playerTwosLabel: UILabel!
    @IBOutlet weak var playerLastPlayedLabel: UILabel!
    @IBOutlet weak var playerPlayedLabelWidth: NSLayoutConstraint!
    @IBOutlet weak var playerWonLabelWidth: NSLayoutConstraint!
    @IBOutlet weak var playerAverageScoreLabelWidth: NSLayoutConstraint!
    @IBOutlet weak var playerMadeLabelWidth: NSLayoutConstraint!
    @IBOutlet weak var playerTwosLabelWidth: NSLayoutConstraint!
    @IBOutlet weak var playerLastPlayedLabelWidth: NSLayoutConstraint!
    @IBOutlet weak var playerPlayedLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var playerWonLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var playerAverageScoreLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var playerMadeLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var playerTwosLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var playerLastPlayedLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var playerTick: UIImageView!
}
