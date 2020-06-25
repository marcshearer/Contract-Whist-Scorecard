//
//  HighScoreTileView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class HighScoreTileView: UIView, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
        
    private var detailType: DashboardDetailType = .highScores
    private var rows = 0
    private var totalScoreRow = -1
    private var handsMadeRow = -1
    private var winStreakRow = -1
    private var twosMadeRow = -1
    private var heightFactors: [CGFloat] = []
    private var collectionViewNib: UINib!
    private var winnerImageWidth: CGFloat = 30
    private var scores: [Int : (value: Int, name: String?)] = [:]
    
    @IBInspectable private var detail: Int {
        get {
            return self.detailType.rawValue
        }
        set(detail) {
            self.detailType = DashboardDetailType(rawValue: detail) ?? .history
        }
    }
    @IBInspectable private var personal: Bool = true
    @IBInspectable private var totalScore: Bool = true
    @IBInspectable private var handsMade: Bool = true
    @IBInspectable private var winStreak: Bool = true
    @IBInspectable private var twosMade: Bool = false

    @IBInspectable private var title: String = ""
       
    @IBOutlet private weak var dashboardDelegate: DashboardActionDelegate?
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var tileView: UIView!
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var typeButton: ClearButton!
    @IBOutlet private weak var tableView: UITableView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadTitleBarView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadTitleBarView()
    }
            
    private func loadTitleBarView() {
        Bundle.main.loadNibNamed("HighScoreTileView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Register table view cell
        let nib = UINib(nibName: "HighScoreTileTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "Table Cell")
        
        // Load collection view cell
        self.collectionViewNib = UINib(nibName: "HighScoreTileCollectionViewCell", bundle: nil)
        
        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(HighScoreTileView.tapSelector(_:)))
        self.contentView.addGestureRecognizer(tapGesture)
        
     }
    
    @objc private func tapSelector(_ sender: UIView) {
        self.dashboardDelegate?.action(view: detailType)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()

        // Setup table view rows
        self.setupRows()
 
        // Setup scores
        self.getValues()
        
        self.tileView.backgroundColor = Palette.buttonFace
        self.titleLabel.textColor = Palette.textTitle
        self.typeButton.tintColor = Dashboard.color(detailView: detailType)
        self.typeButton.setImage(Dashboard.image(detailView: detailType), for: .normal)
        
        self.titleLabel.text = self.title
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        
        self.tileView.layoutIfNeeded()
        
        self.tableView.reloadData()
                
        self.contentView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.tileView.roundCorners(cornerRadius: 8.0)
    }
    
    private func setupRows() {
        self.rows = 0
        if self.totalScore {
            self.totalScoreRow = rows
            self.rows += 1
            self.heightFactors.append(2.5)
        }
        if self.handsMade {
            self.handsMadeRow = rows
            self.rows += 1
            self.heightFactors.append(2)
        }
        if self.winStreak {
            self.winStreakRow = rows
            self.rows += 1
            self.heightFactors.append(1.4)
        }
        if self.twosMade && Scorecard.settings.bonus2 {
            self.twosMadeRow = rows
            self.rows += 1
            self.heightFactors.append(2)
        }
        let totalFactors = self.heightFactors.reduce(0,+)
        for index in 0..<heightFactors.count {
            self.heightFactors[index] /= totalFactors
        }
    }
    
    // MARK: - Table view delegates ========================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.rows
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.frame.height * heightFactors[indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Table Cell", for: indexPath) as! HighScoreTileTableViewCell

        cell.titleLabel.textColor = Palette.textTitle
        cell.valueLabel.textColor = Palette.highScores
        cell.valueLabel.isHidden = (indexPath.row == self.winStreakRow)
        cell.valueImageView.isHidden = (indexPath.row != self.totalScoreRow)
        cell.collectionView.isHidden = (indexPath.row != self.winStreakRow)
        cell.valueLabelBottomConstraint.constant = 0
        let score = self.scores[indexPath.row]!
        let name = score.name
        
        switch indexPath.row {
        case totalScoreRow:
            cell.titleLabel.text = "High Score \(name == nil ? "" : " - \(name!)")"
            cell.valueImageView.image = UIImage(systemName: "rosette")?.asTemplate()
            cell.valueImageView.tintColor = Palette.highScores
            cell.valueLabel.text = "\(score.value)"
            cell.valueLabelBottomConstraint.constant = cell.valueImageView.frame.height * 0.28
            cell.valueImageViewBottomConstraint.constant = max(0, min(16, cell.frame.height - 75), min(32, cell.frame.height - 86))
            
        case handsMadeRow:
            cell.titleLabel.text = "Bids Made \(name == nil ? "" : " - \(name!)")"
            cell.valueLabel.text = "\(score.value)"
            let dial = Dial(view: cell.valueLabel)
            dial.draw(dialColor: Palette.highScores.withAlphaComponent(0.5), valueColor: Palette.highScores, fraction: CGFloat(score.value) / CGFloat(Scorecard.game.rounds))
            cell.valueImageViewBottomConstraint.constant = max(0, min(16, cell.frame.height - 60), min(32, cell.frame.height - 69))

        case winStreakRow:
            cell.titleLabel.text = "Win Streak \(name == nil ? "" : " - \(name!)")"
            cell.setCollectionViewDataSourceDelegate(self, nib: self.collectionViewNib, forRow: indexPath.row)
            if score.value > 0 {
                let imageWidth = min(winnerImageWidth, (tableView.frame.width - 32) / CGFloat(score.value))
                cell.collectionViewWidthConstraint.constant = min(tableView.frame.width - 32.0, CGFloat(score.value) * imageWidth)
            } else {
                cell.collectionViewWidthConstraint.constant = 0
            }
            
        case twosMadeRow:
            cell.titleLabel.text = "Twos Made \(name == nil ? "" : " - \(name!)")"
            cell.valueLabel.text = "\(score.value)"
            let dial = Dial(view: cell.valueLabel)
            dial.draw(dialColor: Palette.highScores.withAlphaComponent(0.5), valueColor: Palette.highScores, fraction: CGFloat(score.value) / CGFloat(Scorecard.game.rounds))
        default:
            break
        }
        return cell
    }
    
    // MARK: - Collection view delegates ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.scores[winStreakRow]!.value
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let value = scores[winStreakRow]!.value
        return CGSize(width: collectionView.frame.width / CGFloat(value), height: collectionView.frame.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Collection Cell", for: indexPath) as! HighScoreTileCollectionViewCell
        cell.winImageView.image = UIImage(named: "high score 1")?.asTemplate()
        cell.winImageView.tintColor = Palette.highScores
        return cell
    }
    
    // MARK: - Data sources =============================================================== -
    
    private func getValues() {
        if personal {
            if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID) {
                if self.totalScore {
                    self.scores[self.totalScoreRow] = (Int(playerMO.maxScore), nil)
                }
                if self.handsMade {
                    self.scores[self.handsMadeRow] = (Int(playerMO.maxMade), nil)
                }
                if self.winStreak {
                    let streaks = History.getWinStreaks(playerUUIDList: [playerMO.playerUUID!])
                    self.scores[self.winStreakRow] = (streaks.first?.streak ?? 0, nil)
                }
                if self.twosMade {
                    self.scores[self.totalScoreRow] = (Int(playerMO.twosMade), nil)
                }

            }
        } else {
            let playerUUIDList = Scorecard.shared.playerUUIDList()
            if self.totalScore {
                let participants = History.getHighScores(type: .totalScore, limit: 1, playerUUIDList: playerUUIDList)
                self.scores[self.totalScoreRow] = (Int(participants.first?.totalScore ?? 0), participants.first?.name ?? "Unknown")
            }
            if self.handsMade {
                let participants = History.getHighScores(type: .handsMade, limit: 1, playerUUIDList: playerUUIDList)
                self.scores[self.handsMadeRow] = (Int(participants.first?.handsMade ?? 0), participants.first?.name ?? "Unknown")
            }
            if self.winStreak {
                let longestWinStreak = History.getWinStreaks(playerUUIDList: playerUUIDList, limit: 1)
                self.scores[self.winStreakRow] = (Int(longestWinStreak.first?.streak ?? 0), longestWinStreak.first?.participantMO?.name ?? "Unknown")
            }
            if self.twosMade {
                let participants = History.getHighScores(type: .twosMade, limit: 1, playerUUIDList: playerUUIDList)
                self.scores[self.twosMadeRow] = (Int(participants.first?.twosMade ?? 0), participants.first?.name ?? "Unknown")
            }
        }
    }
}

class HighScoreTileTableViewCell: UITableViewCell {
    @IBOutlet fileprivate weak var titleLabel: UILabel!
    @IBOutlet fileprivate weak var valueImageView: UIImageView!
    @IBOutlet fileprivate weak var valueImageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var valueLabel: UILabel!
    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    @IBOutlet fileprivate weak var collectionViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var valueLabelBottomConstraint: NSLayoutConstraint!

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
    
    public func draw(dialColor: UIColor, valueColor: UIColor, fraction: CGFloat) {
        self.view.layer.sublayers?.forEach {
            if let layer = $0 as? CAShapeLayer {
                layer.removeFromSuperlayer()
            }
        }
        let radius = (min(self.view.frame.width, self.view.frame.height) / 2.0) * 0.9
        self.drawArc(color: dialColor, fraction: 1.0, radius: radius, lineWidth: 2.0)
        self.drawArc(color: valueColor, fraction: fraction, radius: radius, lineWidth: 4.0)
    }
    
    private func drawArc(color: UIColor, fraction: CGFloat, radius: CGFloat, lineWidth: CGFloat = 1.0) {
        
        let path = UIBezierPath()
        path.addArc(withCenter: CGPoint(x: self.view.frame.width / 2, y: self.view.frame.height / 2),
                    radius: radius, startAngle: .pi/2, endAngle: (.pi * (0.5 + (2 * fraction))), clockwise: true)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.lineWidth = lineWidth
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = color.cgColor
        
        self.view.layer.insertSublayer(shapeLayer, at: 0)
        
    }
    
}
