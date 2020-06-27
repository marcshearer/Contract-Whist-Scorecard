//
//  TrendTile.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class TrendTileView: UIView, DashboardTileDelegate {
    
    private var detailType: DashboardDetailType = .history
    
    @IBInspectable private var detail: Int {
        get {
            return self.detailType.rawValue
        }
        set(detail) {
            self.detailType = DashboardDetailType(rawValue: detail) ?? .history
        }
    }
    @IBInspectable var maxPoints = 5

    @IBInspectable private var title: String = ""
       
    @IBOutlet private weak var dashboardDelegate: DashboardActionDelegate?
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var tileView: UIView!
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var typeButton: ClearButton!
    @IBOutlet private weak var graphView: GraphView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadTrendTileView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadTrendTileView()
    }
            
    private func loadTrendTileView() {
        Bundle.main.loadNibNamed("TrendTileView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(TrendTileView.tapSelector(_:)))
        self.contentView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func tapSelector(_ sender: UIView) {
        self.dashboardDelegate?.action(view: detailType)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.tileView.backgroundColor = Palette.buttonFace
        self.titleLabel.textColor = Palette.textTitle
        self.typeButton.tintColor = Dashboard.color(detailView: detailType)
        self.typeButton.setImage(Dashboard.image(detailView: detailType), for: .normal)
        
        self.titleLabel.text = self.title
        
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        
        self.tileView.layoutIfNeeded()

        self.drawGraph()

        self.contentView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.tileView.roundCorners(cornerRadius: 8.0)
        
    }
    
    internal func reloadData() {
        Utility.mainThread {
            self.drawGraph()
            self.graphView.setNeedsDisplay()
        }
    }
    
    func drawGraph() {
        var values: [CGFloat] = []
        let showLimit = 6
        let participantList = History.getParticipantRecordsForPlayer(playerUUID: Scorecard.settings.thisPlayerUUID, limit: showLimit)
        let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID)!
        
        // Initialise the view
        graphView.reset()
        
        if participantList.count > 0 {
            // Build data
            for participant in participantList {
                values.append(CGFloat(participant.totalScore))
            }
            
            let average = CGFloat(playerMO.totalScore) / CGFloat(playerMO.gamesPlayed)
            
            // Set x axis
            graphView.setXAxis(hidden: true, fractionMin: 1.0)
            
            // Add average score line
            graphView.addDataset(values: [average, average], weight: 0.5, color: Palette.stats)
            
            // Add 100 line
            graphView.addDataset(values: [100, 100], weight: 0.5, color: Palette.text)
            
            // Add main dataset - score per game
            graphView.addDataset(values: values, weight: 2.0, color: Palette.stats, pointFillColor: Palette.buttonFace, gradient: false, pointSize: 8.0, tag: 1)
        }
    }
}
