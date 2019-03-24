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
    var scorecard: Scorecard!
    
    // Properties to pass state to / from segues
    var playerDetail: PlayerDetail!
    var gameDetail: HistoryGame!
    var returnSegue: String!
    
    // UI component pointers
    @IBOutlet weak var graphView: GraphView!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "hideStatisticsGraph", sender: self)
    }
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -

    @IBAction func hideGraphHistoryDetail(segue:UIStoryboardSegue) {
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
        graphView.backgroundColor = ScorecardUI.totalColor
        
        if participantList.count == 0 {
            self.alertMessage("No games played since game history has been saved", okHandler: {
                self.performSegue(withIdentifier: "hideStatisticsGraph", sender: self)
            })
        } else {
        
            // Build data
            for participant in max(0, participantList.count - showLimit)...participantList.count - 1 {
                values.append(CGFloat(participantList[participant].totalScore))
                drillRef.append(participantList[participant].gameUUID!)
                xAxisLabels.append(Utility.dateString(participantList[participant].datePlayed! as Date))
            }
            
            // Add main dataset - score per game
            graphView.addDataset(values: values, weight: 3.0, color: UIColor.white, gradient: true, pointSize: 6.0, tag: 1, drillRef: drillRef)
            graphView.detailDelegate = self
            
            // Add average score line
            var average = CGFloat(playerDetail.totalScore) / CGFloat(playerDetail.gamesPlayed)
            average.round()
            graphView.addDataset(values: [average, average], weight: 1.0, color: UIColor.white.withAlphaComponent(0.5))
            graphView.addYaxisLabel(text: "\(Int(average))", value: average, position: .right)
            if !portraitPhoneSize {
                graphView.addYaxisLabel(text: "Average", value: average, position: .left)
            }
            
            // Add maximum score line
            let maximum = values.max()!
            if maximum >= average + 6 {
                graphView.addDataset(values: [maximum, maximum], weight: 1.0, color: UIColor.white.withAlphaComponent(0.5))
                graphView.addYaxisLabel(text: "\(Int(maximum))", value: maximum, position: .right)
                if !portraitPhoneSize {
                    graphView.addYaxisLabel(text: "Max", value: maximum, position: .left)
                }
            }
            
            // Add minimum score line
            let minimum = values.min()!
            if minimum <= average - 6 {
                graphView.addDataset(values: [minimum, minimum], weight: 1.0, color: UIColor.white.withAlphaComponent(0.5))
                graphView.addYaxisLabel(text: "\(Int(minimum))", value: minimum, position: .right)
                if !portraitPhoneSize {
                    graphView.addYaxisLabel(text: "Min", value: minimum, position: .left)
                }
            }
            
            // Add 100 line
            if abs(average-100) > 2 && abs(minimum-100) > 2 && abs(maximum-100) > 2 {
                graphView.addDataset(values: [100, 100], weight: 0.5, color: UIColor.black.withAlphaComponent(0.5))
                if abs(average-100) > 6 && abs(minimum-100) > 6 && abs(maximum-100) > 6 {
                    graphView.addYaxisLabel(text: "100", value: 100, position: .right, color: UIColor.black)
                }
            }
            
            graphView.addTitle(title: "Game Score History for \(playerDetail.name)")
        }
    }
    
    func graphDetail(drillRef: Any) {
        let gameUUID = drillRef as! String
        let history = History(gameUUID: gameUUID, getParticipants: true)
        if history.games.count != 0 {
            self.gameDetail = history.games[0]
            self.performSegue(withIdentifier: "showGraphHistoryDetail", sender: self)
        }
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showGraphHistoryDetail":
            let destination = segue.destination as! HistoryDetailViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.popoverPresentationController?.sourceView
            destination.preferredContentSize = CGSize(width: 400, height: (scorecard.settingSaveLocation ? 530 :
                262) - (44 * (scorecard.numberPlayers - gameDetail.participant.count)))
            destination.gameDetail = gameDetail
            destination.scorecard = self.scorecard
            destination.returnSegue = "hideGraphHistoryDetail"
            
            
        default:
            break
        }
    }
}
