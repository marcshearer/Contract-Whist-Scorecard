//
//  PlayersViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

enum ShapeType {
    case arrowRight
    case hexagon
    case arrowLeft
}

class PlayersViewController: CustomViewController, ScrollViewDataSource, ScrollViewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    private let scorecard = Scorecard.shared
    
    // Properties to get state from calling segue
    public var detailMode: DetailMode = .amend // Also passed on to detail segue
    public var returnSegue = ""
    public var backText = "Back"
    public var backImage = "back"
    public var actionText = "Compare"
    public var actionSegue = "showStatistics"
    public var layoutComplete = false
    public var refresh = true

    // Local class variables
    private var playerList: [PlayerDetail]!
    private var selectedPlayer = 0
    private var playerDetail: PlayerDetail!
    private var playerObserver: NSObjectProtocol?
    private var imageObserver: NSObjectProtocol?
    private var scrollView: ScrollView!
    private var lastSize: CGSize!
    private var sync: Sync!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var playersScrollView: UIScrollView!
    @IBOutlet private weak var finishButton: RoundedButton!
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var leftPadView: UIView!
    @IBOutlet private weak var rightPadView: UIView!
    @IBOutlet private weak var leftPadWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var leftPadHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var leftPadTextLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var leftPadTextTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var rightPadTextLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var rightPadTextTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var rightPadWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var rightPadHeightConstraint: NSLayoutConstraint!

    // MARK: - IB Unwind Segue Handlers ================================================================ -
  
    @IBAction func hidePlayersSelectPlayers(segue:UIStoryboardSegue) {
        // Restore list to core data and refresh
        let source = segue.source as! SelectPlayersViewController
        if source.playerList.count != 0 {
            self.refreshView()
        }
    }
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func newPlayerPressed(_ sender: UIButton) {
        if self.scorecard.settingSyncEnabled {
            self.performSegue(withIdentifier: "showSelectPlayers", sender: self)
        } else {
            PlayerDetailViewController.show(from: self, playerDetail: PlayerDetail(visibleLocally: true), mode: .create, sourceView: view, completion: { (playerDetail, deletePlayer) in
                    if playerDetail != nil {
                        let _ = playerDetail!.createMO()
                        self.refreshView()
                    }
            })
        }
    }

    @IBAction func finishPressed(sender: UIButton) {
        
        NotificationCenter.default.removeObserver(playerObserver!)
        NotificationCenter.default.removeObserver(imageObserver!)
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
        
        // Set nofifications for player image download
        playerObserver = setPlayerDownloadNotification(name: .playerDownloaded)
        imageObserver = setPlayerDownloadNotification(name: .playerImageDownloaded)
        
        // Setup scroll view
        self.scrollView = ScrollView(self.playersScrollView)
        self.scrollView.dataSource = self
        self.scrollView.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Get player list
        self.playerList = self.scorecard.playerDetailList()
        
        // Update from cloud
        self.updatePlayersFromCloud()
        
        if self.refresh {
            // Only set when enter from menu - not just re-appearing
            self.view.setNeedsLayout()
            self.refresh = false
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if self.view.safeAreaLayoutGuide.layoutFrame.size != self.lastSize {
        
            // Setup width / height
            let cellFrame = self.cellFrame(1)
            
            // Mask top border
            let fillerWidth = cellFrame.width
            let fillerHeight = (cellFrame.height / 2.0)
            let shapeWidth = fillerWidth + view.safeAreaInsets.left
            let arrowWidth = (fillerWidth - 5.0) / 4.0
            if ScorecardUI.screenWidth < 500 {
                self.leftPadWidthConstraint.constant = fillerWidth + view.safeAreaInsets.left + 20.0
                self.leftPadHeightConstraint.constant = fillerHeight
                self.arrowFillerMask(view: leftPadView, frame: CGRect(x: 0, y: 0, width: shapeWidth, height: fillerHeight), type: .arrowRight, arrowWidth: arrowWidth)
                self.leftPadTextLeadingConstraint.constant = view.safeAreaInsets.left + 18.0
                self.leftPadTextTrailingConstraint.constant = 50.0
                self.leftPadView.isHidden = false
                self.rightPadView.isHidden = true
            } else {
                self.rightPadWidthConstraint.constant = (fillerWidth * 2.0) - arrowWidth + view.safeAreaInsets.right + 20.0 + 5.0
                self.rightPadHeightConstraint.constant = fillerHeight
                self.arrowFillerMask(view: rightPadView, frame: CGRect(x: 20.0, y: 0, width: fillerWidth, height: fillerHeight), type: .hexagon, arrowWidth: arrowWidth)
                self.rightPadTextLeadingConstraint.constant = 80.0
                self.rightPadTextTrailingConstraint.constant = fillerWidth - arrowWidth + view.safeAreaInsets.right + 60.0
                self.leftPadView.isHidden = true
                self.rightPadView.isHidden = false
            }
            
            self.lastSize = self.view.safeAreaLayoutGuide.layoutFrame.size
        }
        self.scrollView.reloadData()
        
        self.layoutComplete = true
        self.formatButtons()
    }
    
    // MARK: - ScrollView Overrides ================================================================ -

    func scrollView(_ scrollView: ScrollView,
                    numberofItemsInSection section: Int) -> Int {
        let players = self.playerList?.count ?? 0
        return players
    }

    
    func scrollView(_ scrollView: ScrollView,
                        frameForItemAt indexPath: IndexPath) -> CGRect {
        
        return cellFrame(indexPath.item)
    }
    
    func scrollView(_ scrollView: ScrollView, cellForItemAt indexPath: IndexPath) -> ScrollViewCell {
        let item = indexPath.item
        let type = cellType(item)
        let cellFrame = self.cellFrame(item)
        let cell = PlayerCell(width: cellFrame.width, height: cellFrame.height, type: type)

        let (shapeLayer, path) = self.arrowMask(frame: cell.playerThumbnail.frame, type: type)
        if self.playerList[item].thumbnail != nil {
            cell.playerTile.isHidden = true
            cell.playerThumbnail.isHidden = false
            cell.playerThumbnail.image = UIImage(data: self.playerList[item].thumbnail!)
            cell.playerThumbnail.contentMode = .scaleAspectFill
            cell.playerThumbnail.clipsToBounds = true
            cell.playerThumbnail.alpha = 1.0
            cell.playerThumbnail.superview!.bringSubviewToFront(cell.playerThumbnail)
            let gradient = CAGradientLayer()
            gradient.frame = cell.frame
            gradient.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor(white: 0.0, alpha: 0.1).cgColor ,UIColor(white: 0.0, alpha: 0.3).cgColor]
            gradient.locations = [0.0, 0.8, 0.9, 1.0]
            cell.playerThumbnail.layer.insertSublayer(gradient, at: 0)
            cell.playerThumbnailName.text = self.playerList[item].name
            cell.playerThumbnail.layer.mask = shapeLayer
        } else {
            cell.playerThumbnail.isHidden = true
            cell.playerTile.isHidden = false
            cell.playerTile.superview!.bringSubviewToFront(cell.playerTile)
            cell.playerTile.layer.mask = shapeLayer
            cell.playerTileName.text = self.playerList[item].name
        }
        cell.path = path

        return cell
    }
    
    func scrollView(_ scrollView: ScrollView, didSelectCellAt cell: ScrollViewCell, tapPosition: CGPoint) {
        let cell = cell as! PlayerCell
        let relativeTapPosition = CGPoint(x: tapPosition.x - cell.frame.minX, y: tapPosition.y - cell.frame.minY)
        if let path = cell.path {
            if path.contains(relativeTapPosition) {
                PlayerDetailViewController.show(from: self, playerDetail: self.playerList[cell.indexPath.item], mode: detailMode, sourceView: self.view, completion: { (playerDetail, deletePlayer) in
                                                    if self.detailMode != .display && playerDetail != nil {
                                                        if deletePlayer {
                                                            // Refresh all
                                                            self.refreshView()
                                                        } else {
                                                            // Refresh updated player
                                                            playerDetail!.fromManagedObject(playerMO: playerDetail!.playerMO!)
                                                            self.scrollView.reloadItems(at: [cell.indexPath!])
                                                        }
                                                    }
                })
            }
        }
    }
    
    private func cellType(_ item: Int) -> ShapeType {
        var type: ShapeType
        if ScorecardUI.screenWidth > 500.0 {
            switch item % 3 {
            case 0:
                type = .arrowRight
            case 1:
                type = .arrowLeft
            default:
                type = .hexagon
            }
        } else {
            type = (item % 2 == 0 ? .arrowLeft : .arrowRight)
        }
        return type
    }
    
    private func cellFrame(_ item: Int) -> CGRect {
        var cellX: CGFloat
        var cellWidth: CGFloat
        var cellY: CGFloat
        var cellHeight: CGFloat
        
        let viewWidth = self.view.safeAreaLayoutGuide.layoutFrame.width
        
        if ScorecardUI.screenWidth > 500 {
            cellWidth = ((8.0 / 20.0) * viewWidth) - 5.0
            cellHeight = ((21.0 / 80.0) * viewWidth)
            switch item % 3 {
            case 0:
                cellX = 0.0
                cellY = ((cellHeight + 10.0) * CGFloat(item / 3)) + 5.0
            case 1:
                cellX = viewWidth - cellWidth
                cellY = ((cellHeight + 10.0) * CGFloat(item / 3)) + 5.0
            default:
                cellX = (6.0 / 20.0) * viewWidth + 2.5
                cellY = ((cellHeight + 10.0) * (CGFloat(item / 3) + 0.5)) + 5.0
            }
        } else {
            cellWidth = ((4.0 / 7.0) * viewWidth) - 5.0
            cellHeight = ((3.0 / 7.0) * viewWidth) - 10.0
            cellX = (item % 2 == 0 ? viewWidth - cellWidth : 0.0)
            cellY = (((cellHeight / 2.0) + 5.0) * CGFloat(item)) + 5.0
        }
        
        return CGRect(x: cellX, y: cellY, width: cellWidth, height: cellHeight)
    }
    
    // MARK: Sync handlers =============================================================== -
    
    private func updatePlayersFromCloud(players: [String]? = nil) {
        
        if self.scorecard.settingSyncEnabled && self.scorecard.isNetworkAvailable && self.scorecard.isLoggedIn {
            
            let players = players ?? self.scorecard.playerEmailList()
            
            // Synchronise players
            if players.count > 0 {
                if self.sync == nil {
                    self.sync = Sync()
                    self.sync.initialise()
                }
                if self.sync.connect() {
                    self.sync.synchronise(syncMode: .syncUpdatePlayers, specificEmail: players)
                }
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
            let index = self.playerList.firstIndex(where: {($0.objectID == objectID)})
            if index != nil {   
                // Found it - update from managed object and reload the cell
                self.playerList[index!].fromManagedObject(playerMO: self.playerList[index!].playerMO)
                self.scrollView.reloadItems(at: [IndexPath(row: index!, section: 0)])
            }
        }
    }

    func formatButtons() {
        
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText)
    }
    
    func refreshView() {
        // Reset everything
        self.playerList = scorecard.playerDetailList()
        self.scrollView.reloadData()
        formatButtons()
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
            
        case "showSelectPlayers":
            let destination = segue.destination as! SelectPlayersViewController
            
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view
            destination.preferredContentSize = CGSize(width: 400, height: 600)
            
            destination.descriptionMode = .opponents
            destination.returnSegue = "hidePlayersSelectPlayers"
            destination.backText = "Cancel"
            destination.actionText = "Download"
            destination.allowOtherPlayer = true
            destination.allowNewPlayer = true
            
        default:
            break
        }
    }
    
    // MARK: - Arrow masks ============================================================================== -

    private func arrowMask(frame: CGRect, type: ShapeType) -> (CAShapeLayer, UIBezierPath) {
        
        let width = frame.width
        let height = frame.height
        let minX: CGFloat = 0.0
        let minY: CGFloat = 0.0
        let arrowWidth = width / 4.0
        
        var points: [PolygonPoint] = []
        switch type {
        case .arrowRight:
            points.append(PolygonPoint(x: minX, y: minY))
            points.append(PolygonPoint(x: minX + width - arrowWidth, y: minY))
            points.append(PolygonPoint(x: minX + width, y: minY + (height / 2.0)))
            points.append(PolygonPoint(x: minX + width - arrowWidth, y: minY + height))
            points.append(PolygonPoint(x: minX, y: minY + height))
            points.append(PolygonPoint(x: arrowWidth, y: minY + (height / 2.0)))
        case .arrowLeft:
            points.append(PolygonPoint(x: minX + width, y: minY))
            points.append(PolygonPoint(x: minX + arrowWidth, y: minY))
            points.append(PolygonPoint(x: minX, y: minY + (height / 2.0)))
            points.append(PolygonPoint(x: minX + arrowWidth, y: minY + height))
            points.append(PolygonPoint(x: minX + width, y: minY + height))
            points.append(PolygonPoint(x: minX + width - arrowWidth, y: minY + (height / 2.0)))
        case .hexagon:
            points.append(PolygonPoint(x: minX, y: minY + (height / 2.0)))
            points.append(PolygonPoint(x: minX + arrowWidth, y: minY))
            points.append(PolygonPoint(x: minX + width - arrowWidth, y: minY))
            points.append(PolygonPoint(x: minX + width, y: minY + (height / 2.0)))
            points.append(PolygonPoint(x: minX + width - arrowWidth, y: minY + height))
            points.append(PolygonPoint(x: minX + arrowWidth, y: minY + height))
        }
        
        let path = Polygon.roundedBezierPath(definedBy: points)
        let shapeLayer = Polygon.shapeLayer(from: path)
        
        return (shapeLayer, path)
    }
    
    private func arrowFillerMask(view: UIView, frame: CGRect, type: ShapeType, arrowWidth: CGFloat) {
        
        let width = frame.width
        let height = frame.height
        let minX = frame.minX
        let minY = frame.minY

        var points: [CGPoint] = []
        switch type {
        case .arrowLeft:
            points.append(CGPoint(x: minX + width, y: minY))
            points.append(CGPoint(x: minX + width, y: minY + height))
            points.append(CGPoint(x: minX + arrowWidth, y: minY + height))
            points.append(CGPoint(x: minX, y: minY))
        case .arrowRight:
            points.append(CGPoint(x: minX, y: minY))
            points.append(CGPoint(x: minX, y: minY + height))
            points.append(CGPoint(x: minX + width - arrowWidth, y: minY + height))
            points.append(CGPoint(x: minX + width, y: minY))
        case .hexagon:
            points.append(CGPoint(x: minX, y: minY))
            points.append(CGPoint(x: minX + arrowWidth, y: minY + height))
            points.append(CGPoint(x: minX + width - arrowWidth, y: minY + height))
            points.append(CGPoint(x: minX + width, y: minY))
        }
        
        var lines: [(start: CGPoint, end: CGPoint)] = []
        for index in 0...points.count-1 {
            lines.append(Polygon.partialLine(from: points[index], to: points[(index == points.count-1 ? 0 : index+1)], fraction: 0.1))
        }
        
        let path = UIBezierPath()
        if ScorecardUI.screenWidth <= 500 {
            path.move(to: points[0])
        } else {
            path.move(to: CGPoint(x: points[0].x - (lines[2].end.x - lines[2].start.x) * 0.1, y: points[3].y))
            path.addQuadCurve(to: lines[0].start, controlPoint: points[0])
        }
        if type == . hexagon {
            path.addLine(to: lines[0].end)
            path.addQuadCurve(to: lines[1].start, controlPoint: points[1])
        } else {
            path.addLine(to: points[1])
        }
        path.addLine(to: lines[1].end)
        path.addQuadCurve(to: lines[2].start, controlPoint: points[2])
        path.addLine(to: lines[2].end)
        path.addQuadCurve(to: CGPoint(x: points[3].x + (lines[2].end.x - lines[2].start.x) * 0.1, y: points[3].y), controlPoint: points[3])
        path.addLine(to: points[0])
        path.close()
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.strokeColor = UIColor.black.cgColor
        
        view.layer.mask = shapeLayer
    }

}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class PlayerCell: ScrollViewCell {
    public var playerThumbnail: UIImageView!
    public var playerThumbnailName: UILabel!
    public var playerTile: UILabel!
    public var playerTileName: UILabel!
    public var path: UIBezierPath!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(width: CGFloat, height: CGFloat, type: ShapeType) {
        var textX: CGFloat
        var textWidth: CGFloat
        
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        self.init(frame: frame)
        
        self.playerThumbnail = UIImageView(frame: frame)
        self.addSubview(self.playerThumbnail)
        
        switch type {
        case .arrowLeft:
            textX = width * 0.25
            textWidth = width * 0.63
        case .arrowRight:
            textX = width * 0.10
            textWidth = width * 0.63
        case .hexagon:
            textX = width * 0.10
            textWidth = width * 0.80
        }
        let thumbnailNameFrame = CGRect(x: textX, y: height - 25.0, width: textWidth, height: 25.0)
        self.playerThumbnailName = UILabel(frame: thumbnailNameFrame)
        self.playerThumbnail.addSubview(self.playerThumbnailName)
        self.playerThumbnailName.backgroundColor = UIColor.clear
        self.playerThumbnailName.textColor = UIColor.white
        self.playerThumbnailName.textAlignment = .center
        self.playerThumbnailName.font = UIFont.systemFont(ofSize: 18.0)
        self.playerThumbnailName.adjustsFontSizeToFitWidth = true
        
        self.playerTile = UILabel(frame: frame)
        self.playerTile.backgroundColor = ScorecardUI.bannerColor.withAlphaComponent(0.25)
        self.addSubview(self.playerTile)
        
        switch type {
        case .arrowLeft:
            textX = width * 0.10
            textWidth = width * 0.63
        case .arrowRight:
            textX = width * 0.25
            textWidth = width * 0.63
        case .hexagon:
            textX = width * 0.10
            textWidth = width * 0.80
        }
        let tileNameFrame = CGRect(x: textX, y: 0.0, width: textWidth, height: height)
        self.playerTileName = UILabel(frame: tileNameFrame)
        self.playerTile.addSubview(self.playerTileName)
        self.playerTileName.backgroundColor = UIColor.clear
        self.playerTileName.textColor = ScorecardUI.textColor
        self.playerTileName.textAlignment = .center
        self.playerTileName.font = UIFont.systemFont(ofSize: 24.0)
        self.playerTileName.adjustsFontSizeToFitWidth = true
    }
}
