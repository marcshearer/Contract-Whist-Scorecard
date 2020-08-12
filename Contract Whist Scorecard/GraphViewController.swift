//
//  GraphViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class GraphViewController: ScorecardViewController, GraphDetailDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Properties to determine how view is displayed
    private var playerDetail: PlayerDetail!
    
    // UI component pointers
    @IBOutlet weak var graphView: GraphView!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: Any) {
        self.dismiss()
    }
    
    // MARK: - method to show and dismiss this view controller ========================================= -
    
    static public func show(from sourceViewController: UIViewController, playerDetail: PlayerDetail) {
        let storyboard = UIStoryboard(name: "GraphViewController", bundle: nil)
        let graphViewController = storyboard.instantiateViewController(withIdentifier: "GraphViewController") as! GraphViewController
        graphViewController.modalPresentationStyle = .fullScreen
        
        graphViewController.playerDetail = playerDetail
        sourceViewController.present(graphViewController, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()

        drawGraph()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Scorecard.shared.reCenterPopup(self)
        view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        drawGraph(frame: graphView.frame)
        graphView.setNeedsDisplay()
    }
    
    func drawGraph(frame: CGRect = UIScreen.main.bounds) {
        var values: [CGFloat] = []
        var drillRef: [String] = []
        var xAxisLabels: [String] = []
        let phoneSize = ScorecardUI.phoneSize()
        let portraitPhoneSize = ScorecardUI.portraitPhone()
        let showLimit = (portraitPhoneSize ? 12 : (phoneSize ? 25 : 50))
        let participantList = History.getParticipantRecordsForPlayer(playerUUID: playerDetail.playerUUID)
        
        // Initialise the view
        graphView.reset()
        graphView.backgroundColor = Palette.normal.background
        graphView.setColors(axis: Palette.normal.text, gradient: [Palette.normal.background, Palette.emphasis.background])
        graphView.setXAxis(hidden: true, fractionMin: 1.0)
        
        if participantList.count == 0 {
            self.alertMessage("No games played since game history has been saved", okHandler: {
                self.dismiss()
            })
        } else {
        
            // Build data
            for participant in participantList {
                values.append(CGFloat(participant.totalScore))
                drillRef.append(participant.gameUUID!)
                xAxisLabels.append(Utility.dateString(participant.datePlayed! as Date))
            }
            
            let maximum = values.max()!
            let minimum = values.min()!
            var average = CGFloat(playerDetail.totalScore) / CGFloat(playerDetail.gamesPlayed)
            average.round()
            
            if values.count > showLimit {
                values = values.suffix(showLimit)
                drillRef = drillRef.suffix(showLimit)
                xAxisLabels = xAxisLabels.suffix(showLimit)
            }
            
            // Add maximum score line
            if maximum >= average + 10 {
                graphView.addDataset(values: [maximum, maximum], weight: 2.0, color: Palette.normal.text.withAlphaComponent(0.4))
                graphView.addYaxisLabel(text: "\(Int(maximum))", value: maximum, position: .right, color: Palette.normal.text)
                if !portraitPhoneSize {
                    graphView.addYaxisLabel(text: "Highest", value: maximum, position: .left, color: Palette.normal.text)
                }
            }
            
            // Add minimum score line
            if minimum <= average - 6 {
                graphView.addDataset(values: [minimum, minimum], weight: 2.0, color: Palette.normal.text.withAlphaComponent(0.4))
                graphView.addYaxisLabel(text: "\(Int(minimum))", value: minimum, position: .right, color: Palette.normal.text)
                if !portraitPhoneSize {
                    graphView.addYaxisLabel(text: "Lowest", value: minimum, position: .left, color: Palette.normal.text)
                }
            }
            
            // Add average score line
            graphView.addDataset(values: [average, average], weight: 3.0, color: Palette.emphasis.background.withAlphaComponent(0.4))
            graphView.addYaxisLabel(text: "\(Int(average))", value: average, position: .right, color: Palette.normal.strongText)
            if !portraitPhoneSize {
                graphView.addYaxisLabel(text: "Average", value: average, position: .left, color: Palette.normal.strongText)
            }
            
            // Add 100 line
            if abs(average-100) > 2 && abs(minimum-100) > 2 && abs(maximum-100) > 2 {
                graphView.addDataset(values: [100, 100], weight: 1.0, color: UIColor.white)
                if abs(average-100) > 6 && abs(minimum-100) > 6 && abs(maximum-100) > 6 {
                    graphView.addYaxisLabel(text: "100", value: 100, position: .right, color: UIColor.white)
                }
            }
            
            // Add main dataset - score per game
            graphView.addDataset(values: values, weight: 3.0, color: Palette.emphasis.background, gradient: false, pointSize: 12.0, tag: 1, drillRef: drillRef)
            graphView.detailDelegate = self
            
            // Set title
            let attributedTitle = NSMutableAttributedString()
            var attributes: [NSAttributedString.Key : Any] = [:]
            attributes[NSAttributedString.Key.foregroundColor] = Palette.normal.strongText
            attributes[NSAttributedString.Key.font] = UIFont.systemFont(ofSize: 28.0, weight: .light)
            attributedTitle.append(NSAttributedString(string: "Game Score History for ", attributes: attributes))
            attributes[NSAttributedString.Key.font] = UIFont.systemFont(ofSize: 28.0, weight: .bold)
            attributedTitle.append(NSAttributedString(string: self.playerDetail.name, attributes: attributes))
            
            graphView.add(attributedTitle: attributedTitle)
        }
    }
    
    func graphDetail(drillRef: Any) {
        let gameUUID = drillRef as! String
        let history = History(gameUUID: gameUUID, getParticipants: true)
        if history.games.count != 0 {
            HistoryDetailViewController.show(from: self, gameDetail: history.games.first!, sourceView: self.view)
        }
    }
}

extension GraphViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.graphView.backgroundColor = Palette.normal.background
        self.view.backgroundColor = Palette.normal.background
    }

}
