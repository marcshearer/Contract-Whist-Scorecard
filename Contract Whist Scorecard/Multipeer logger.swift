//
//  Multipeer logger.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 07/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit
import MessageUI

class MultipeerLogger : CommsBrowserDelegate, CommsStateDelegate, CommsDataDelegate {
    
    static let logger = MultipeerLogger()
    private var service: CommsClientServiceDelegate?
    private var loggerList: [String : MultipeerLoggerEntry] = [:]
    private var logHistory: [LogEntry] = []
    private var historyElement = 0
    private var logUUID: String?
    static private var mailComposeDelegate = MailComposeDelegate()
    
    public  var connected: Bool {
        // Check if any connections open
        get {
            var result = false
            for (_, logger) in self.loggerList {
                if logger.peer.state == .connected {
                    result = true
                    break
                }
            }
            return result
        }
    }
    static public var logEntries: Bool {
        get {
            return !self.logger.logHistory.isEmpty
        }
    }
    
    init() {
        Utility.sendingMessage = true
        self.service = CommsHandler.client(proximity: .nearby, mode: .broadcast, serviceID: MultipeerLoggerConfig.logService, deviceName: Scorecard.deviceName)
        self.service?.browserDelegate = self
        self.service?.stateDelegate = self
        self.service?.dataDelegate = self
        self.service?.start()
        self.logUUID = UUID().uuidString
        Utility.sendingMessage = false
    }
    
    public func reset() {
        self.service?.stop()
        self.service?.start()
    }
    
    func peerFound(peer: CommsPeer, reconnect: Bool = true) {
        
        var logger = self.loggerList[peer.deviceName]
        var new = false
        var connect = false
        
        if logger == nil {
            // New peer - add to list
            logger = MultipeerLoggerEntry(peer: peer)
            self.loggerList[peer.deviceName] = logger
            new = true
            connect = true
            
        } else if logger?.peer.state == .notConnected {
            connect = true
            
        }
        
        logger!.peer = peer
        
        if connect {
            Utility.getActiveViewController()?.alertDecision(if: new, "A nearby device (\(peer.deviceName)) is logging Contract Whist. Would you like to connect?\n\nNote: this could expose otherwise hidden information to the logging device.", title: "Logging", okButtonText: "Connect", okHandler: {
                logger!.accepted = true
                _ = self.service?.connect(to: peer, playerUUID: nil, playerName: nil, reconnect: true)
            }, cancelButtonText: "Ignore")
        }
    }
    
    func peerLost(peer: CommsPeer) {
        self.loggerList[peer.deviceName]?.peer = peer
    }
    
    func error(_ message: String) {
    }
    
    func write(timestamp: String, source: String, message: String) {
        logHistory.append(LogEntry(timestamp: timestamp, source: source, message: message))
        if loggerList.count > 0 {
            let data: [String : [String : String]] =
                ["\(historyElement)" : [ "uuid"      : self.logUUID!,
                                         "timestamp" : timestamp,
                                         "source"    : source   ,
                                         "message"   : message   ]]
            historyElement += 1
            for (_, logger) in loggerList {
                if logger.peer.state == .connected && logger.accepted {
                    self.service?.send("log", data, to: logger.peer)
                }
            }
        }
    }
    
    func stateChange(for peer: CommsPeer, reason: String?) {
        // Update peer
        self.loggerList[peer.deviceName]?.peer = peer
    }

    func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        if descriptor == "lastSequence" {
            if let lastSequence = data?["sequence"] as! Int?, let logUUID = data?["uuid"] as! String? {
                if let logger = self.loggerList[peer.deviceName] {
                    if peer.state == .connected && logger.accepted {
                        var data : [String : [String : String]] = [:]
                        for entry in logHistory {
                            if historyElement > lastSequence || logUUID != self.logUUID {
                                data["\(historyElement)"] =
                                    [ "uuid" : self.logUUID!,
                                      "timestamp" : (entry.timestamp ?? ""),
                                      "source"    : (entry.source    ?? ""),
                                      "message"   : (entry.message   ?? "")]
                            }
                            historyElement += 1
                        }
                        self.service?.send("log", data, to: peer)
                    }
                }
            }
        }
    }
    
    static func sendPlayerEmail(from: ScorecardViewController) {
        var bodyText = ""
        
        if MFMailComposeViewController.canSendMail() {
            if !self.logger.logHistory.isEmpty {
                let mail = MFMailComposeViewController()
                mail.mailComposeDelegate = MultipeerLogger.mailComposeDelegate
                mail.setSubject("Whist Log")
                mail.setToRecipients(["marc@sheareronline.com"])
                
                for history in self.logger.logHistory {
                    bodyText = bodyText + "\"" + "\(history.source ?? "")" + "\""
                    bodyText = bodyText + ",\"" + "\(history.timestamp ?? "")" + "\""
                    bodyText = bodyText + ",\"" + "\(history.message ?? "")" + "\""
                    bodyText = bodyText + "\n"
                }
                
                mail.setMessageBody(bodyText, isHTML: false)
                
                from.present(mail, animated: true)
                
            }
        } else {
            // show failure alert
            from.alertMessage("Unable to send email from this device")
        }
    }
}

fileprivate class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
    
    internal func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
    
}

fileprivate class MultipeerLoggerEntry {
    public var peer: CommsPeer
    public var accepted = false
    
    init(peer: CommsPeer) {
        self.peer = peer
    }
}

fileprivate class LogEntry {
    public var timestamp: String?
    public var source: String?
    public var message: String?
    
    init(timestamp: String?, source: String?, message:String?) {
        self.timestamp = timestamp
        self.source = source
        self.message = message
    }
}

class MultipeerLoggerConfig {
    
    // Service for log messages - blank to disable
    public static let logService = "whist-logger"
    
}
