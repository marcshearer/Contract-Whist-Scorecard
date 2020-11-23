//
//  ClientViewControllerLastGame.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/11/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit
    
extension ClientViewController: UITableViewDataSource, UITableViewDelegate {
    
    internal func rightPanelViewDidLoad() {
        if self.containers {
            GameDetailCell.register(self.rightPanelPlayerTableView)
        }
    }
    
    internal func rightPanelLayoutSubviews() {
        if self.containers {
            self.rightPanelLocationContainerView.layoutIfNeeded()
            self.rightPanelLocationContainerView.roundCorners(cornerRadius: 20)
            self.rightPanelLocationLabel.textColor = UIColor.white
        }
    }
    
    internal func showLastGame() {
        if self.containers {
            self.rightPanelTitleLabel.text = "Last Game\nPlayed"
            
            // Load last game for this player
            let history = History(playerUUID: Scorecard.settings.thisPlayerUUID, limit: 1)
            
            if history.games.isEmpty {
                // No history found
                self.rightPanelCaptionLabel.text = "No games found"
                self.rightPanelLocationContainerView.isHidden = true
                self.lastGame = nil
                
            } else {
                // Check if changed
                if self.lastGame?.gameUUID != history.games.first?.gameUUID {
                    
                    // Load all participants and setup game
                    history.loadAllParticipants()
                    self.lastGame = history.games.first!
                    
                    // Setup date caption
                    if let datePlayed = self.lastGame.gameMO.datePlayed {
                        var format: String
                        if Date.startOfYear(from: datePlayed) != Date.startOfYear() {
                            format = "dd MMM YYYY"
                        } else {
                            format = "dd MMM"
                        }
                        self.rightPanelCaptionLabel.text = Utility.dateString(datePlayed, format: format, localized: false)
                    } else {
                        self.rightPanelCaptionLabel.text = ""
                    }
                    
                    // Setup table of scores
                    self.rightPanelPlayerTableViewHeightConstraint.constant = CGFloat(self.lastGame.participant.count) * GameDetailCell.heightForRow()
                    self.rightPanelPlayerTableView.reloadData()
                    
                    // Setup location
                    if self.lastGame.gameLocation.locationSet && self.lastGame.gameLocation.description ?? "" != "" && (self.lastGame.gameLocation.latitude != 0 || self.lastGame.gameLocation.longitude != 0) {
                        self.rightPanelLocationContainerView.isHidden = false
                        self.rightPanelLocationLabel.text = self.lastGame.gameLocation.description
                        GameLocation.dropPin(rightPanelMapView, location: self.lastGame.gameLocation)
                    } else {
                        self.rightPanelLocationContainerView.isHidden = true
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.lastGame?.participant?.count ?? 0
    }
    
    internal func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return GameDetailCell.heightForRow()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = GameDetailCell.dequeue(tableView, for: indexPath)
        let participant = self.lastGame!.participant[indexPath.row]
        var name: String
        var thumbnail: Data?
        if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(participant.participantMO.playerUUID!) {
            name = playerMO.name!
            thumbnail = playerMO.thumbnail
        } else {
            name = participant.name
        }
        cell.set(playerName: name, playerThumbnail: thumbnail, score: Int(participant.totalScore), textColor: Palette.banner.text)
        return cell
    }
}
