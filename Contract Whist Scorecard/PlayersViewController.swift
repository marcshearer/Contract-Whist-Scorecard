//
//  PlayersViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class PlayersViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    public var scorecard: Scorecard!
    
    // Properties to get state from calling segue
    public var detailMode: DetailMode = .amend // Also passed on to detail segue
    public var returnSegue = ""
    public var backText = "Back"
    public var backImage = "back"
    public var actionText = "Compare"
    public var actionSegue = "showStatistics"
    public var allowSync = true
    public var layoutComplete = false

    // Local class variables
    private var playerList: [PlayerDetail]!
    private var selectedPlayer = 0
    private var playerDetail: PlayerDetail!
    private var labelFontSize: CGFloat = 14.0
    private var labelWidth: CGFloat = 120.0
    private var labelHeight: CGFloat = 17.0
    private var width: CGFloat = 0
    private var observer: NSObjectProtocol?

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var playersCollectionView: UICollectionView!
    @IBOutlet weak var syncButton: RoundedButton!
    @IBOutlet weak var finishButton: RoundedButton!
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var toolbarViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var footerPaddingTopConstraint: NSLayoutConstraint!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
  
    @IBAction func hidePlayersPlayerDetail(segue:UIStoryboardSegue) {
        
        let source = segue.source as! PlayerDetailViewController
        if detailMode != .display && source.playerDetail.name != "" {
            // Restore list to core data and refresh
            self.refreshView()
        }
    }

    @IBAction func hidePlayersSelectPlayers(segue:UIStoryboardSegue) {
        // Restore list to core data and refresh
        let source = segue.source as! SelectPlayersViewController
        if source.playerList.count != 0 {
            self.refreshView()
        }
    }
    
    @IBAction func hidePlayersSync(segue:UIStoryboardSegue) {
        // Refresh screen
        refreshView()
    }

    // MARK: - IB Actions ============================================================================== -
    @IBAction func syncPressed(sender: UIButton) {
        self.performSegue(withIdentifier: "showSync", sender: self)
    }
    
    @IBAction func newPlayerPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "showSelectPlayers", sender: self)
    }

    @IBAction func finishPressed(sender: UIButton) {
        
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
        
        // Get player list
        self.playerList = self.scorecard.playerDetailList()
        
        formatButtons()
        
        if allowSync {
            // Check for network / iCloud login
            scorecard.checkNetworkConnection(button: syncButton, label: nil)
        } else {
            syncButton.isHidden = true
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
  
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let playerNumber = indexPath.row+1
        selectedPlayer = playerNumber
        self.performSegue(withIdentifier: "showPlayerDetail", sender: self)
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
        
        if !allowSync {
            syncButton.isHidden = true
        }
        toolbarHeight = 30
        
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText)
        
        let newToolbarTop = (toolbarHeight == 0 ? 44 : 44 + view.safeAreaInsets.bottom + toolbarHeight)
        if newToolbarTop != self.toolbarViewHeightConstraint.constant {
            self.toolbarViewHeightConstraint.constant = newToolbarTop
        }
    }
    
    func refreshView() {
        // Reset everything
        self.playerList = scorecard.playerDetailList()
        self.playersCollectionView.reloadData()
        formatButtons()
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showPlayerDetail":
            let destination = segue.destination as! PlayerDetailViewController
          
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view
            destination.preferredContentSize = CGSize(width: 400, height: 540)
            
            destination.playerDetail = self.playerList[selectedPlayer - 1]
            destination.returnSegue = "hidePlayersPlayerDetail"
            destination.mode = detailMode
            destination.scorecard = self.scorecard
            
        case "showSelectPlayers":
            let destination = segue.destination as! SelectPlayersViewController
            
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view
            destination.preferredContentSize = CGSize(width: 400, height: 600)
            
            destination.scorecard = self.scorecard
            destination.descriptionMode = .opponents
            destination.returnSegue = "hidePlayersSelectPlayers"
            destination.backText = "Cancel"
            destination.actionText = "Download"
            destination.allowOtherPlayer = true
            destination.allowNewPlayer = true
            
        case "showSync":
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
}
