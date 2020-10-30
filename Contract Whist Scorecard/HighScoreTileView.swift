//
//  HighScoreTileView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class HighScoreTileView: DashboardTileView, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
        
    internal override var helpId: String { "highScore" }
    
    struct RowInfo {
        var type: HighScoreType
        var occurrence: Int
        var height: CGFloat = 0.0
        var score: Int?
        var name: String?
        var playerUUID: String?
        var participantMO: ParticipantMO?
    }
    
    private var collectionViewNib: UINib!
    private var titleHeight: CGFloat = 26.5
    private var captionHeight: CGFloat = 0.0
    private var spacing: CGFloat = 0.0
    private var totalScoreImageHeight: CGFloat = 60.0
    private var madeDialHeight: CGFloat = 50.0
    private var winnerImageAspectRatio: CGFloat = 100/77
    private var winnerMinValue: Int = 7
    private var winnerImageInsets: CGFloat = 32.0
    private var rowInfo: [RowInfo] = []
    private var captionAbove: Bool = false
    
    @IBInspectable private var totalScore: Bool = true
    @IBInspectable private var handsMade: Bool = true
    @IBInspectable private var winStreak: Bool = true
    @IBInspectable private var twosMade: Bool = false
    @IBInspectable private var count: Int = 1
    @IBInspectable private var titleRows: Int = 1
    @IBInspectable private var showTypeButton: Bool = true
    @IBInspectable private var detailDrill: Bool = false

    @IBOutlet private weak var titleLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var typeButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableView: UITableView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadHighScoreTileView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadHighScoreTileView()
    }
            
    private func loadHighScoreTileView() {
        Bundle.main.loadNibNamed("HighScoreTileView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Register table view cell
        let nib = UINib(nibName: "HighScoreTileTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "Table Cell")
        
        // Load collection view cell
        self.collectionViewNib = UINib(nibName: "HighScoreTileCollectionViewCell", bundle: nil)
     }
    
    @objc private func tapSelector(_ sender: UIView) {
        self.dashboardDelegate?.action(view: detailType, personal: personal)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()

        // Setup tap gesture
        if !detailDrill {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(HighScoreTileView.tapSelector(_:)))
            self.contentView.addGestureRecognizer(tapGesture)
        }
        
        // Setup table view rows
        self.setupRows()
 
        // Setup scores
        self.getValues()
        
        // Setup default colors
        self.defaultViewColors()
        
        // Set title
        self.titleLabel.text = self.title
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        
        // Adjust heights
        self.tableView.layoutIfNeeded()
        self.adjustHeights()
        
        if !self.showTypeButton {
            self.typeButtonWidthConstraint.constant = 0
            self.typeButton.isHidden = true
        }
        self.titleLabelHeightConstraint.constant = (CGFloat(self.titleRows) * self.titleHeight)
        self.titleLabel.numberOfLines = self.titleRows
        
        self.tileView.layoutIfNeeded()
        
        self.tableView.reloadData()
                
        self.contentView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.tileView.roundCorners(cornerRadius: 8.0)
    }
    
    // MARK: - Dashboard Tile delegates ================================================= -

    internal func addHelp(to helpView: HelpView) {
        
        helpView.add("The @*/\(self.title)@*/ tile shows \(self.personal ? "your" : "the") highest scores\(self.personal ? "" : " for the players on this device").\n\nClick on the tile to show more high score details.", views: [self], shrink: true)
    }

    internal func reloadData() {
        self.getValues()
        self.tableView.reloadData()
    }
    
    internal func didRotate() {
        self.layoutSubviews()
    }
    
    // MARK: - Table view delegates ========================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.rowInfo.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return rowInfo[indexPath.row].height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Table Cell", for: indexPath) as! HighScoreTileTableViewCell
        
        let row = rowInfo[indexPath.row]
        cell.captionAboveLabel.textColor = Palette.normal.strongText
        cell.valueLabel.textColor = Palette.highScores
        cell.valueLabel.isHidden = (row.type == .winStreak)
        cell.valueImageView.isHidden = (row.type == .winStreak)
        cell.collectionView.isHidden = (row.type != .winStreak)
        
        
        var imageHeight = cell.frame.height - self.captionHeight - self.spacing
        var scale: CGFloat = 1.0
        switch row.type {
        case .totalScore:
            imageHeight = min(60, imageHeight)
            scale = 0.72
        case .handsMade, .twosMade:
            imageHeight = imageHeight * 0.9
        case .winStreak:
            break
        }
        cell.valueImageViewHeightConstraint.constant = imageHeight
        cell.valueLabelHeightConstraint.constant = imageHeight * scale
        cell.layoutIfNeeded()
        
        let score = row.score ?? 0
        let name = row.name
        var title = ""
        
        switch row.type {
        case .totalScore:
            title = "High Score"
            cell.valueImageView.image = UIImage(named: "rosette")?.asTemplate()
            cell.valueImageView.tintColor = Palette.highScores
            cell.valueLabel.text = "\(score)"
            cell.valueLabel.font = UIFont.systemFont(ofSize: max(6, cell.valueImageView.frame.width / 4))

        case .handsMade, .twosMade:
            title = (row.type == .handsMade ? "Bids Made" : "Twos Made")
            cell.valueLabel.text = "\(score)"
            let dial = Dial(view: cell.valueImageView)
            dial.draw(dialColor: Palette.highScores.withAlphaComponent(0.5), valueColor: Palette.highScores, radius: imageHeight * 0.5, fraction: CGFloat(score) / CGFloat(Scorecard.game.rounds))
            cell.valueLabel.font = UIFont.systemFont(ofSize: max(6, imageHeight / 3))
    
        case .winStreak:
            title = "Win Streak"
            cell.setCollectionViewDataSourceDelegate(self, nib: self.collectionViewNib, forRow: indexPath.row)
            if score > 0 {
                let imageSize = self.winnerImageSize(availableWidth: cell.frame.width, count: score)
                cell.collectionViewWidthConstraint.constant = imageSize.width * CGFloat(score)
                cell.collectionViewHeightConstraint.constant = imageSize.height
            } else {
                cell.collectionViewWidthConstraint.constant = 0
            }
        }
        
        if self.captionAbove {
            cell.captionAboveLabel.text = "\(title) \(name == nil ? "" : " - \(name!)")"
        } else {
            cell.captionBelowLabel.text = (personal ? title : name)
        }
        cell.captionAboveLabelHeightConstraint.constant = (self.captionAbove ? self.captionHeight : 0)
        cell.captionBelowLabelHeightConstraint.constant = (self.captionAbove ? 0 : self.captionHeight)
        
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = UIColor.clear
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        
        if detailDrill {
            let row = self.rowInfo[indexPath.row]
            self.parentDashboardView?.drillHighScore(from: self.parentDashboardView!.parentViewController!, sourceView: self.parentDashboardView!, type: row.type, occurrence: row.occurrence, detailParticipantMO: row.participantMO, playerUUID: row.playerUUID!)
        }
        
        return nil
    }
    
    // MARK: - Collection view delegates ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let row = collectionView.tag
        return self.rowInfo[row].score ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let row = collectionView.tag
        let score = rowInfo[row].score ?? 0
        return CGSize(width: (collectionView.frame.width / CGFloat(score)) - 0.01, height: collectionView.frame.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Collection Cell", for: indexPath) as! HighScoreTileCollectionViewCell
        cell.winImageView.image = UIImage(named: "cup")?.asTemplate()
        cell.winImageView.tintColor = Palette.highScores
        return cell
    }
    
    // MARK: - Data sources =============================================================== -
    
    private func getValues() {
        var scores: [HighScoreType : [(name: String, score: Int, playerUUID: String, participantMO: ParticipantMO?)]] = [:]
        var playerMO: PlayerMO?
        
        if personal {
            playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID)
        } else {
            // Accumulate high scores in advance
            if self.totalScore {
                scores[.totalScore] = self.parentDashboardView?.getHighScores(type: .totalScore, count: count)
            }
            if self.handsMade {
                scores[.handsMade] = self.parentDashboardView?.getHighScores(type: .handsMade, count: count)
            }
            if self.winStreak {
                scores[.winStreak] = self.parentDashboardView?.getHighScores(type: .winStreak, count: count)
            }
            if self.twosMade {
                scores[.twosMade] = self.parentDashboardView?.getHighScores(type: .twosMade, count: count)
            }
        }
        
        for (index, row) in self.rowInfo.enumerated() {
            if personal {
                if let playerMO = playerMO {
                    switch row.type {
                    case .totalScore:
                        self.rowInfo[index].score = Int(playerMO.maxScore)
                    case .handsMade:
                        self.rowInfo[index].score = Int(playerMO.maxMade)
                    case .winStreak:
                        self.rowInfo[index].score = Int(playerMO.maxWinStreak)
                    case .twosMade:
                        self.rowInfo[index].score = Int(playerMO.maxTwos)
                    }
                    self.rowInfo[index].playerUUID = playerMO.playerUUID
                }
            } else {
                if let highScores = scores[row.type] {
                    if row.occurrence < highScores.count {
                        let highScore = highScores[row.occurrence]
                        self.rowInfo[index].score = highScore.score
                        self.rowInfo[index].name = highScore.name
                        self.rowInfo[index].participantMO = highScore.participantMO
                        self.rowInfo[index].playerUUID = highScore.participantMO?.playerUUID
                    }
                }
            }
        }
    }
    
    // MARK: - Setup form  ============================================================================= -
    
    private func setupRows() {
        var types = 0
        
        if self.totalScore {
            types += 1
            for occurrence in 0..<self.count {
                self.rowInfo.append(RowInfo(type: .totalScore, occurrence: occurrence))
            }
        }
        if self.handsMade {
            types += 1
            for occurrence in 0..<self.count {
                self.rowInfo.append(RowInfo(type: .handsMade, occurrence: occurrence))
            }
        }
        if self.winStreak {
            types += 1
            for occurrence in 0..<self.count {
                self.rowInfo.append(RowInfo(type: .winStreak, occurrence: occurrence))
            }
        }
        if self.twosMade && Scorecard.settings.bonus2 {
           types += 1
           for occurrence in 0..<self.count {
                self.rowInfo.append(RowInfo(type: .twosMade, occurrence: occurrence))
            }
        }
        self.captionAbove = (types > 1)
    }
    
    private func adjustHeights() {
        // Allocate idealised heights
        self.captionHeight = 21.0
        self.spacing = 20.0
        
        for (index, row) in self.rowInfo.enumerated() {
            switch row.type {
            case .totalScore:
                self.rowInfo[index].height = self.totalScoreImageHeight
            case .handsMade, .twosMade:
                self.rowInfo[index].height = madeDialHeight
            case .winStreak:
                let imageSize = winnerImageSize(availableWidth: self.tableView.frame.width, count: row.score ?? 0)
                self.rowInfo[index].height = imageSize.height
            }
        }
            
        // Adjust heights to available height and add in spacing and caption heights
        // Only have half spacing in bottom row
        let availableHeight = self.tableView.frame.height
        let totalHeights = self.rowInfo.reduce(0,{$0 + $1.height + self.captionHeight + self.spacing})
        let factor = availableHeight / totalHeights
        for index in 0..<self.rowInfo.count {
            self.rowInfo[index].height = (self.rowInfo[index].height + self.captionHeight + self.spacing) * factor
        }
        self.captionHeight *= factor
        self.spacing *= factor
    }
    
    private func winnerImageSize(availableWidth: CGFloat, count: Int) -> CGSize {
        let imageWidth = (availableWidth - self.winnerImageInsets) / CGFloat(max(self.winnerMinValue, count))
        let imageHeight = imageWidth * winnerImageAspectRatio
        return CGSize(width: imageWidth, height: imageHeight)
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func defaultViewColors() {
        self.tileView.backgroundColor = Palette.buttonFace.background
        self.titleLabel.textColor = Palette.normal.strongText
        Dashboard.formatTypeButton(detailView: detailType, button: self.typeButton)
    }
}

class HighScoreTileTableViewCell: UITableViewCell {
    @IBOutlet fileprivate weak var captionAboveLabel: UILabel!
    @IBOutlet fileprivate weak var captionAboveLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var valueImageView: UIImageView!
    @IBOutlet fileprivate weak var valueImageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var valueLabel: UILabel!
    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    @IBOutlet fileprivate weak var collectionViewFlowLayout: UICollectionViewFlowLayout!
    @IBOutlet fileprivate weak var collectionViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var collectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var valueLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var captionBelowLabel: UILabel!
    @IBOutlet fileprivate weak var captionBelowLabelHeightConstraint: NSLayoutConstraint!
    
    func setCollectionViewDataSourceDelegate
         <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, nib: UINib, forRow row: Int) {
         
         collectionView.delegate = dataSourceDelegate
         collectionView.dataSource = dataSourceDelegate
         collectionView.register(nib, forCellWithReuseIdentifier: "Collection Cell")
         collectionView.tag = row
         collectionView.reloadData()
     }
}

class HighScoreTileCollectionViewCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var winImageView: UIImageView!
}

class Dial {
    private let view: UIView
    
    init(view: UIView) {
        self.view = view
    }
    
    public func draw(dialColor: UIColor, valueColor: UIColor, radius: CGFloat, fraction: CGFloat) {
        if radius > 0 {
            self.view.layer.sublayers?.forEach {
                if let layer = $0 as? CAShapeLayer {
                    layer.removeFromSuperlayer()
                }
            }
            self.view.layoutIfNeeded()
            self.drawArc(color: dialColor, fraction: 1.0, radius: radius - 3.0, lineWidth: 2.0)
            self.drawArc(color: valueColor, fraction: fraction, radius: radius - 3.0, lineWidth: 4.0)
        }
    }
    
    private func drawArc(color: UIColor, fraction: CGFloat, radius: CGFloat, lineWidth: CGFloat = 1.0) {
        
        let path = UIBezierPath()
        path.addArc(withCenter: CGPoint(x: self.view.frame.width / 2, y: radius + 3.0),
                    radius: radius, startAngle: .pi/2, endAngle: (.pi * (0.5 + (2 * fraction))), clockwise: true)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.lineWidth = lineWidth
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = color.cgColor
        
        self.view.layer.insertSublayer(shapeLayer, at: 0)
        
    }
    
}
