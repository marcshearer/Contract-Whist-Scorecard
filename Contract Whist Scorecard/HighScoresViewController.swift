//
//  HighScoresViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

enum HighScoreType {
    case totalScore
    case handsMade
    case twosMade
}

class HighScoresViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate, UIPopoverPresentationControllerDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    var scorecard: Scorecard!
    
    // Properties to pass state to / from segues
    var returnSegue = ""
    var backText = "Back"
    var backImage = "back"
    var detailGame: HistoryGame!
    
    // Local class variables
    var totalScoreParticipants: [ParticipantMO]!
    var handsMadeParticipants: [ParticipantMO]!
    var twosMadeParticipants: [ParticipantMO]!
    
    // MARK: - IB Outlets ============================================================================== -

    @IBOutlet weak var finishButton: RoundedButton!
    @IBOutlet weak var highScoresView: UIView!
    @IBOutlet weak var tableView: UITableView!
 
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideHighScoresHistoryDetail(segue:UIStoryboardSegue) {
    }
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: self.returnSegue, sender: self)
    }
    
    @IBAction func allSwipe(recognizer:UISwipeGestureRecognizer) {
        finishPressed(finishButton)
    }
  
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScores()
        
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText)
        tableView.isScrollEnabled = highScoresView.frame.size.height <= 500
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        positionPopup()
        tableView.isScrollEnabled = size.height <= 500
        
    }
    
    // MARK: - TableView Overrides ===================================================================== -

    func numberOfSections(in tableView: UITableView) -> Int {
        return (self.scorecard.settingBonus2 ? 3 : 2)
    }

    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "High Scores"
        case 1:
            return "Most Bids Made"
        case 2:
            return "Most Twos Made"
        default:
            return ""
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        ScorecardUI.sectionHeaderStyleView(header.backgroundView!)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let view = UITableViewHeaderFooterView()
        ScorecardUI.sectionHeaderStyleView(view)
        
        return view
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return totalScoreParticipants.count
        case 1:
            return handsMadeParticipants.count
        case 2:
            return twosMadeParticipants.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: HighScoresTableCell
        var participantMO: ParticipantMO!
        var playerMO: PlayerMO!
        var thumbnail: Data?
        var value: Int16!
        var name: String
        var last = false
        
        cell = tableView.dequeueReusableCell(withIdentifier: "High Scores Cell", for: indexPath) as! HighScoresTableCell
        
        switch indexPath.section {
        case 0:
            // High scores
            participantMO = totalScoreParticipants[indexPath.row]
            value = participantMO.totalScore
            last = (indexPath.row == totalScoreParticipants.count-1)
        
        case 1:
            // Tricks made
            participantMO = handsMadeParticipants[indexPath.row]
            value = participantMO.handsMade
            last = (indexPath.row == totalScoreParticipants.count-1)
            
        case 2:
            // High scores
            participantMO = twosMadeParticipants[indexPath.row]
            value = participantMO.twosMade
            last = (indexPath.row == totalScoreParticipants.count-1)
            
        default:
            break
        }
        // Find the matching player
        playerMO = scorecard.findPlayerByEmail(participantMO.email!)
        if playerMO != nil {
            thumbnail = playerMO.thumbnail
            name = playerMO.name!
        } else {
            name = participantMO.name!
        }
        
        cell.name.text = name
        Utility.setThumbnail(data: thumbnail,
                             imageView: cell.thumbnail,
                             initials: name,
                             label: cell.disc)

        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy")
        cell.date.text = formatter.string(from: participantMO.datePlayed! as Date)
        cell.value.text = "\(value!)"
        
        if last {
             cell.separator.isHidden = true
        } else {
            cell.separator.isHidden = false
        }
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.clear
        cell.selectedBackgroundView = backgroundView
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var detailParticipantMO: ParticipantMO!
        
        switch indexPath.section {
        case 0:
            detailParticipantMO = totalScoreParticipants[indexPath.row]
        case 1:
            detailParticipantMO = handsMadeParticipants[indexPath.row]
        case 2:
            detailParticipantMO = twosMadeParticipants[indexPath.row]
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: false)
        
        let history = History(gameUUID: detailParticipantMO.gameUUID)
        
        if history.games.count > 0 {
            detailGame = history.games[0]
            self.performSegue(withIdentifier: "showHighScoresHistoryDetail", sender: self)
        }
    }

    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func setupScores() {
        let playerEmailList = self.scorecard.playerEmailList(getPlayerMode: .getAll)
        totalScoreParticipants = History.getHighScores(type: .totalScore, playerEmailList: playerEmailList)
        handsMadeParticipants = History.getHighScores(type: .handsMade, playerEmailList: playerEmailList)
        twosMadeParticipants = History.getHighScores(type: .twosMade, playerEmailList: playerEmailList)
    }
    
    func positionPopup() {
        scorecard.reCenterPopup(self)
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showHighScoresHistoryDetail":
            let destination = segue.destination as! HistoryDetailViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.popoverPresentationController?.sourceView
            destination.preferredContentSize = CGSize(width: 400, height: 554)
            destination.gameDetail = detailGame
            destination.locationLabel = nil
            destination.scorecard = self.scorecard
            destination.returnSegue = "hideHighScoresHistoryDetail"
            
        default:
            break
        }
    }


}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class HighScoresTableCell: UITableViewCell {
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var disc: UILabel!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var value: UILabel!
    @IBOutlet weak var separator: UIView!
}
