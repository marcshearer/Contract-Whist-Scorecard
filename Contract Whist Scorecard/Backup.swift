
//
//  Backup.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 08/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation
import MessageUI

class Backup {

    static func sendEmail(from: UIViewController) {
        var bodyText = ""
        
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = from as? MFMailComposeViewControllerDelegate
            mail.setSubject("Whist Backup")
            mail.setToRecipients(["marc@sheareronline.com"])
            
            bodyText = "Players\n\n"
            
            bodyText = bodyText + "\"Name\", \"Email\", \"Visible\", \"Created\", \"Local created\", \"Date played\", \"External Id\", \"Games played\", \"Games won\", \"Hands played\", \"Hands made\", \"Twos made\", \"Total score\", \"Max score\", \"Max score date\", \"Max made\", \"Max made date\", \"Max twos\", \"Max twos date\"\n"
            
            for playerMO in Scorecard.shared.playerList {
                bodyText = bodyText + "\"\(playerMO.name!)\""
                bodyText = bodyText + ", \"\(playerMO.email!)\""
                bodyText = bodyText + ",\((playerMO.visibleLocally ? "true" : "false"))"
                bodyText = bodyText + ", \(Utility.dateString(playerMO.dateCreated! as Date))"
                bodyText = bodyText + ", \(playerMO.localDateCreated == nil ? "\"\"" : Utility.dateString(playerMO.localDateCreated! as Date))"
                bodyText = bodyText + ", \(Utility.dateString(playerMO.datePlayed! as Date))"
                bodyText = bodyText + ", \"\(playerMO.externalId == nil ? "" : playerMO.externalId!)\""
                bodyText = bodyText + ", \(playerMO.gamesPlayed)"
                bodyText = bodyText + ", \(playerMO.gamesWon)"
                bodyText = bodyText + ", \(playerMO.handsPlayed)"
                bodyText = bodyText + ", \(playerMO.handsMade)"
                bodyText = bodyText + ", \(playerMO.twosMade)"
                bodyText = bodyText + ", \(playerMO.totalScore)"
                bodyText = bodyText + ", \(playerMO.maxScore)"
                bodyText = bodyText + ", \(playerMO.maxScoreDate == nil ? "\"\"" : Utility.dateString(playerMO.maxScoreDate! as Date))"
                bodyText = bodyText + ", \(playerMO.maxMade)"
                bodyText = bodyText + ", \(playerMO.maxMadeDate == nil ? "\"\"" : Utility.dateString(playerMO.maxMadeDate! as Date))"
                bodyText = bodyText + ", \(playerMO.maxTwos)"
                bodyText = bodyText + ", \(playerMO.maxTwosDate == nil ? "\"\"" : Utility.dateString(playerMO.maxTwosDate! as Date))"
                bodyText = bodyText + "\n"
            }
            
            bodyText = bodyText + "\nGames\n\n"
            
            bodyText = bodyText + "\"Game UUID\", \"Date played\", \"Device UUID\", \"Location\", \"Latitude\", \"Longitude\", \"Device name\", \"Local created\", \"Exclude History\", \"Player no\", \"Name\", \"Email\", \"Played\", \"Won\", \"Score\", \"Hands played\", \"Hands made\", \"Twos made\", \"Local created\", \"Player no\", \"Name\", \"Email\", \"Played\", \"Won\", \"Score\", \"Hands played\", \"Hands made\", \"Twos made\", \"Local created\", \"Player no\", \"Name\", \"Email\", \"Played\", \"Won\", \"Score\", \"Hands played\", \"Hands made\", \"Twos made\", \"Local created\", \"Player no\", \"Name\", \"Email\", \"Played\", \"Won\", \"Score\", \"Hands played\", \"Hands made\", \"Twos made\", \"Local created\"\n"
            
            let history=History(getParticipants: true, includeBF: true)
            for historyGame in history.games {
                
                bodyText = bodyText + "\"\(historyGame.gameUUID)\""
                bodyText = bodyText + ", \(Utility.dateString(historyGame.datePlayed))"
                bodyText = bodyText + ", \"\(historyGame.deviceUUID)\""
                bodyText = bodyText + ", \"\(historyGame.gameLocation.description!)\""
                bodyText = bodyText + ", \(historyGame.gameLocation.latitude ?? 0)"
                bodyText = bodyText + ", \(historyGame.gameLocation.longitude ?? 0)"
                bodyText = bodyText + ", \"\(historyGame.deviceName!)\""
                bodyText = bodyText + ", \(Utility.dateString(historyGame.localDateCreated))"
                bodyText = bodyText + ", \((historyGame.gameMO.excludeStats ? "true" : "false"))"
                
                for historyParticipant in historyGame.participant {
                    bodyText = bodyText + ", \(historyParticipant.playerNumber)"
                    bodyText = bodyText + ", \"\(historyParticipant.name)\""
                    bodyText = bodyText + ", \"\(historyParticipant.participantMO.email!)\""
                    bodyText = bodyText + ", \(historyParticipant.participantMO.gamesPlayed)"
                    bodyText = bodyText + ", \(historyParticipant.participantMO.gamesWon)"
                    bodyText = bodyText + ", \(historyParticipant.totalScore)"
                    bodyText = bodyText + ", \(historyParticipant.handsPlayed)"
                    bodyText = bodyText + ", \(historyParticipant.handsMade)"
                    bodyText = bodyText + ", \(historyParticipant.twosMade)"
                    bodyText = bodyText + ", \(Utility.dateString(historyParticipant.localDateCreated))"
                }
                
                bodyText = bodyText + "\n"
                
            }
            
            mail.setMessageBody(bodyText, isHTML: false)
            
            from.present(mail, animated: true)
        } else {
            // show failure alert
            from.alertMessage("Unable to send email from this device")
        }
    }

}
