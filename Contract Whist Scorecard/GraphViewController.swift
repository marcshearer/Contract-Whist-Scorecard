//
//  GraphViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class GraphViewController: CustomViewController, GraphDetailDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    private let scorecard = Scorecard.shared
    
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
        graphViewController.playerDetail = playerDetail
        sourceViewController.present(graphViewController, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        drawGraph()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        scorecard.reCenterPopup(self)
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
        let portraitPhoneSize = phoneSize && frame.height > frame.width
        let showLimit = (portraitPhoneSize ? 12 : (phoneSize ? 25 : 50))
        let participantList = History.getParticipantRecordsForPlayer(playerEmail: playerDetail.email, includeBF: false)
        
        // Initialise the view
        graphView.reset()
        graphView.backgroundColor = Palette.darkHighlight
        
        if participantList.count == 0 {
            self.alertMessage("No games played since game history has been saved", okHandler: {
                self.dismiss()
            })
        } else {
        
            // Build data
            for participant in max(0, participantList.count - showLimit)...participantList.count - 1 {
                values.append(CGFloat(participantList[participant].totalScore))
                drillRef.append(participantList[participant].gameUUID!)
                xAxisLabels.append(Utility.dateString(participantList[participant].datePlayed! as Date))
            }
            
            // Add main dataset - score per game
            graphView.addDataset(values: values, weight: 3.0, color: Palette.darkHighlightText, gradient: true, pointSize: 6.0, tag: 1, drillRef: drillRef)
            graphView.detailDelegate = self
            
            // Add average score line
            var average = CGFloat(playerDetail.totalScore) / CGFloat(playerDetail.gamesPlayed)
            average.round()
            graphView.addDataset(values: [average, average], weight: 1.0, color: Palette.darkHighlightTextContrast.withAlphaComponent(0.2))
            graphView.addYaxisLabel(text: "\(Int(average))", value: average, position: .right, color: Palette.darkHighlightTextContrast)
            if !portraitPhoneSize {
                graphView.addYaxisLabel(text: "Average", value: average, position: .left, color: Palette.darkHighlightTextContrast)
            }
            
            // Add maximum score line
            let maximum = values.max()!
            if maximum >= average + 6 {
                graphView.addDataset(values: [maximum, maximum], weight: 1.0, color: Palette.darkHighlightText.withAlphaComponent(0.2))
                graphView.addYaxisLabel(text: "\(Int(maximum))", value: maximum, position: .right)
                if !portraitPhoneSize {
                    graphView.addYaxisLabel(text: "Max", value: maximum, position: .left)
                }
            }
            
            // Add minimum score line
            let minimum = values.min()!
            if minimum <= average - 6 {
                graphView.addDataset(values: [minimum, minimum], weight: 1.0, color: Palette.darkHighlightText.withAlphaComponent(0.2))
                graphView.addYaxisLabel(text: "\(Int(minimum))", value: minimum, position: .right)
                if !portraitPhoneSize {
                    graphView.addYaxisLabel(text: "Min", value: minimum, position: .left)
                }
            }
            
            // Add 100 line
            if abs(average-100) > 2 && abs(minimum-100) > 2 && abs(maximum-100) > 2 {
                graphView.addDataset(values: [100, 100], weight: 0.5, color: Palette.darkHighlightText.withAlphaComponent(0.2))
                if abs(average-100) > 6 && abs(minimum-100) > 6 && abs(maximum-100) > 6 {
                    graphView.addYaxisLabel(text: "100", value: 100, position: .right, color: Palette.darkHighlightText)
                }
            }
            
            graphView.addTitle(title: "Game Score History for \(playerDetail.name)")
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
