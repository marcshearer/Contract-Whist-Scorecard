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
    
    // Local class variables
    var totalScoreParticipants: [ParticipantMO]!
    var handsMadeParticipants: [ParticipantMO]!
    var twosMadeParticipants: [ParticipantMO]!
    var longestWinStreak: [(streak: Int, participantMO: ParticipantMO?)]!
    
    // MARK: - IB Outlets ============================================================================== -

    @IBOutlet weak var finishButton: RoundedButton!
    @IBOutlet weak var tableView: UITableView!
    
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
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        positionPopup()
        self.tableView.reloadData()
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        tableView.isScrollEnabled = self.tableView.frame.size.height <= ((self.scorecard.settingBonus2 ? 4 : 3) * 160)
    }
    
    // MARK: - TableView Overrides ===================================================================== -

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if tableView.tag == 1 {
            // Section table view
            return 0
        } else {
            // Scores table view
            return 30
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        if tableView.tag == 1 {
            // Section table view - no sections
            return nil
        } else {
            let view = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: tableView.frame.width, height: 30.0))
            view.backgroundColor = UIColor.clear
            view.font = UIFont.systemFont(ofSize: 20.0, weight: .thin)
            view.textColor = ScorecardUI.textColor
            switch tableView.tag % 1000000 {
            case 0:
                view.text = "High Scores"
            case 1:
                view.text = "Most Bids Made"
            case 2:
                view.text = "Longest win streak"
            case 3:
                view.text = "Most Twos Made"
            default:
                view.text = ""
            }
            return view
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView.tag == 1 {
            // Section table view
            return (self.scorecard.settingBonus2 ? 4 : 3)
        } else {
            // Section score table view
            switch tableView.tag % 1000000 {
            case 0:
                return totalScoreParticipants.count
            case 1:
                return handsMadeParticipants.count
            case 2:
                return longestWinStreak.count
            case 3:
                return twosMadeParticipants.count
            default:
                return 0
            }
        }
    }
    
    internal func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath){
        if tableView.tag == 1 {
            // Main section table view
            let tableViewCell = cell as! HighScoresSectionCell
            tableViewCell.setTableViewDataSourceDelegate(self, forRow: indexPath.row + 1000000)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if tableView.tag == 1 {
            // Section table view
            var cell: HighScoresSectionCell
            
            cell = tableView.dequeueReusableCell(withIdentifier: "High Scores Section Cell", for: indexPath) as! HighScoresSectionCell
            let rightJustify = (indexPath.row % 2 == 0)
            let height = cell.leftFiller.frame.height
            let width = height / 3.0
            
            if rightJustify {
                cell.leftFillerWidthConstraint.constant = width
                cell.rightFillerWidthConstraint.constant = 0.0
                Polygon.roundedMask(to: cell.leftFiller, definedBy: [PolygonPoint(x: 0.0, y: 0.0),
                                                                     PolygonPoint(x: 0.0, y: height),
                                                                     PolygonPoint(x: width, y: height / 2.0)])
            } else {
                cell.rightFillerWidthConstraint.constant = width
                cell.leftFillerWidthConstraint.constant = 0.0
                Polygon.roundedMask(to: cell.rightFiller, definedBy: [PolygonPoint(x: width, y: 0.0),
                                                                      PolygonPoint(x: width, y: height),
                                                                      PolygonPoint(x: 0.0, y: height / 2.0)])
            }
            
            return cell
            
        } else {
            // Scores table view
            var cell: HighScoresScoreCell
            var participantMO: ParticipantMO!
            var playerMO: PlayerMO!
            var thumbnail: Data?
            var value: Int16!
            var name: String
            
            cell = tableView.dequeueReusableCell(withIdentifier: "High Scores Score Cell", for: indexPath) as! HighScoresScoreCell
            
            switch tableView.tag % 1000000 {
            case 0:
                // High scores
                participantMO = totalScoreParticipants[indexPath.row]
                value = participantMO.totalScore
            
            case 1:
                // Tricks made
                participantMO = handsMadeParticipants[indexPath.row]
                value = participantMO.handsMade
                
            case 2:
                // Longest win streak
                let winStreak = longestWinStreak[indexPath.row]
                participantMO = winStreak.participantMO
                value = Int16(winStreak.streak)
                
            case 3:
                // Twos made
                participantMO = twosMadeParticipants[indexPath.row]
                value = participantMO.twosMade
                
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
            let game = History(gameUUID: participantMO.gameUUID).games.first!
            
            cell.name.text = name
            Utility.setThumbnail(data: thumbnail,
                                 imageView: cell.thumbnail,
                                 initials: name,
                                 label: cell.disc)

            cell.date?.text = DateFormatter.localizedString(from: participantMO.datePlayed!, dateStyle: .medium, timeStyle: .none)
            cell.location?.text = game.gameLocation.description
            cell.locationWidthConstraint.constant = (view.frame.width > 600 ? 150 : 0)
            cell.value.text = "\(value!)"
            cell.selectionStyle = .none
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        var detailParticipantMO: ParticipantMO!
        
        if tableView.tag != 1 {
            // Scores table view
            switch tableView.tag % 1000000 {
            case 0:
                detailParticipantMO = totalScoreParticipants[indexPath.row]
            case 1:
                detailParticipantMO = handsMadeParticipants[indexPath.row]
            case 2:
                detailParticipantMO = longestWinStreak[indexPath.row].participantMO
            case 3:
                detailParticipantMO = twosMadeParticipants[indexPath.row]
            default:
                break
            }
            
            let history = History(gameUUID: detailParticipantMO.gameUUID)
            
            if history.games.count > 0 {
                HistoryDetailViewController.show(from: self, gameDetail: history.games[0], sourceView: self.popoverPresentationController?.sourceView, scorecard: scorecard)
            }
        }
        return nil
    }

    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func setupScores() {
        let playerEmailList = self.scorecard.playerEmailList(getPlayerMode: .getAll)
        totalScoreParticipants = History.getHighScores(type: .totalScore, playerEmailList: playerEmailList)
        handsMadeParticipants = History.getHighScores(type: .handsMade, playerEmailList: playerEmailList)
        twosMadeParticipants = History.getHighScores(type: .twosMade, playerEmailList: playerEmailList)
        longestWinStreak = History.getWinStreaks(playerEmailList: playerEmailList)
    }
    
    func positionPopup() {
        scorecard.reCenterPopup(self)
    }
    
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class HighScoresSectionCell: UITableViewCell {
    @IBOutlet weak var leftFiller: UIView!
    @IBOutlet weak var rightFiller: UIView!
    @IBOutlet weak var leftFillerWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightFillerWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var scoreTableView: UITableView!
    
    func setTableViewDataSourceDelegate
        <D: UITableViewDataSource & UITableViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        scoreTableView.delegate = dataSourceDelegate
        scoreTableView.dataSource = dataSourceDelegate
        scoreTableView.tag = row
        scoreTableView.reloadData()
    }
}

class HighScoresScoreCell: UITableViewCell {
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var disc: UILabel!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var location: UILabel!
    @IBOutlet weak var locationWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var value: UILabel!
    @IBOutlet weak var separator: UIView!
}

