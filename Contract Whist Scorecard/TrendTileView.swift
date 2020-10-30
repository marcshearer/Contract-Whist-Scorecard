//
//  TrendTile.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class TrendTileView: DashboardTileView {
    
    internal override var helpId: String { "trend" }
    
    @IBInspectable var maxPoints = 5

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
        self.dashboardDelegate?.action(view: detailType, personal: false)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.tileView.backgroundColor = Palette.buttonFace.background
        self.titleLabel.textColor = Palette.normal.strongText
        self.typeButton.tintColor = Dashboard.color(detailView: detailType)
        Dashboard.formatTypeButton(detailView: detailType, button: self.typeButton)

        self.titleLabel.text = self.title
        
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        
        self.tileView.layoutIfNeeded()

        self.drawGraph()

        self.contentView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.tileView.roundCorners(cornerRadius: 8.0)
        
    }
    
    // MARK: - Dashboard Tile delegates ================================================= -

    internal func addHelp(to helpView: HelpView) {
        
        helpView.add("The @*/\(self.title)@*/ tile shows the trend for your total score in the last \(self.maxPoints) games.\n\nClick on the tile to show Stats for all players on this device.", views: [self], shrink: true)
    }

    internal func reloadData() {
        Utility.mainThread {
            self.drawGraph()
            self.graphView.setNeedsDisplay()
        }
    }
    
      // MARK: - Graph draw routine ===================================================== -
    
    func drawGraph() {
        var values: [CGFloat] = []
        let showLimit = 6
        let participantList = History.getParticipantRecordsForPlayer(playerUUID: Scorecard.settings.thisPlayerUUID, sortDirection: .descending, limit: showLimit)
        let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID)!
        
        // Initialise the view
        graphView.reset()
        
        if participantList.count > 0 {
            // Build data
            for participant in participantList.reversed() {
                values.append(CGFloat(participant.totalScore))
            }
            
            let average = CGFloat(playerMO.totalScore) / CGFloat(playerMO.gamesPlayed)
            
            // Set x axis
            graphView.setXAxis(hidden: true, fractionMin: 1.0)
            
            // Add average score line
            graphView.addDataset(values: [average, average], weight: 0.5, color: Palette.stats)
            
            // Add 100 line
            graphView.addDataset(values: [100, 100], weight: 0.5, color: Palette.normal.text)
            
            // Add main dataset - score per game
            graphView.addDataset(values: values, weight: 2.0, color: Palette.stats, pointFillColor: Palette.buttonFace.background, gradient: false, pointSize: 8.0, tag: 1)
        }
    }
}
