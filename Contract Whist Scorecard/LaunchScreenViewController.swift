//
//  LaunchScreenViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class LaunchScreenViewController: ScorecardViewController, SyncDelegate, ReconcileDelegate {

   
    // Sync
    internal let sync = Sync()
    private var syncGetPlayers = false
    private var syncGetVersion = false
    private weak var callingViewController: ScorecardViewController!
    private var syncPlayerList: [String]?
    private var newDevice = false
    
    // Reconcile
    internal var reconcile: Reconcile!
    
    private var completion: (()->())?

    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var message: UILabel!
    @IBOutlet private weak var whistTitle: UILabel!
    @IBOutlet private weak var whistImage: UIImageView!
    @IBOutlet private weak var termsTitle: UILabel!
    @IBOutlet private weak var termsText: UILabel!
    @IBOutlet private weak var termsAccept: RoundedButton!
    @IBOutlet private weak var termsDecline: RoundedButton!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func acceptPressed(_ sender: UIButton) {
        Scorecard.shared.settings.termsDate = Date()
        Scorecard.shared.settings.termsDevice = Scorecard.deviceName
        Scorecard.shared.settings.save()
        self.enableControls()
        self.linkToNext()
    }
    
    @IBAction func declinePressed(_ sender: UIButton) {
        exit(0)
    }
    
    // MARK: - View Overrides ========================================================================== -
 
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupControls()
        
        self.termsText.text = "Whist allows you to score or play Contract Whist.\n\nA record of the scores of your games and the players' names will be kept and synchronised with a central database.\n\nThis data will not be used for any marketing purposes.\nHowever it will be accessible to other users of the app who know your Unique ID.\n\nBy accepting these terms and conditions you agree to any data you enter being shared in this way."

        self.enableControls(showTerms: false)
        
        checkICloud()
        
        // Note flow continues in checkICloud
    }
    
    private func checkICloud() {
        
        self.message.text = "Loading..."
        
        Utility.executeAfter(delay: 1.0) {
            Scorecard.shared.getVersion(completion: {
                // Don't call this until any upgrade has taken place
                self.getCloudVersion()
            })
        }
        // Note flow continues in continueStartup
    }
    
    private func continueStartup() {

        // self.showGetStarted() // TODO remove
        // return                // TODO remove
        
        if !Scorecard.shared.settings.syncEnabled {
            // New device - try to load from iCloud
            self.newDevice = true
            self.message.text = "Loading..."
            Scorecard.shared.settings.loadFromICloud() { (players) in
                Utility.mainThread {
                    if players != nil && !players!.isEmpty {
                        self.syncPlayerList = players
                    }
                    if Scorecard.shared.settings.termsDate == nil {
                        // Need to wait for terms acceptance
                        self.enableControls()
                    } else {
                        self.linkToNext()
                    }
                }
            }
        } else if Scorecard.shared.settings.termsDate == nil {
            // Need to wait for terms acceptance
            self.enableControls()
        } else {
            self.linkToNext()
        }
    }
    
    private func linkToNext() {
        if self.newDevice {
            // New device check notifications and link to get started
            if self.syncPlayerList != nil {
                self.checkReceiveNotifications() {
                    Scorecard.shared.settings.save()
                    self.syncGetPlayers = true
                    self.sync.delegate = self
                    if !self.sync.synchronise(syncMode: .syncGetPlayerDetails, specificEmail: self.syncPlayerList!, waitFinish: true) {
                        self.showGetStarted()
                    }
                }
            } else {
                // New device / iCloud user
                self.showGetStarted()
            }
        } else {
            self.dismiss()
        }
    }
    
    private func dismiss(showMessage: Bool = true) {
        Utility.mainThread {
            if showMessage {
                self.message.text = "Loading..."
            }
            self.callingViewController.dismissWithScreenshot(viewController: self, completion: self.completion)
        }
    }
    
    private func setupControls() {
        self.view.backgroundColor = Palette.banner
        self.whistTitle.textColor = Palette.bannerEmbossed
        self.message.textColor = Palette.bannerText
        self.termsTitle.textColor = Palette.bannerText
        self.termsText.backgroundColor = Palette.background
        self.termsText.textColor = Palette.text
        self.termsText.roundCorners(cornerRadius: 8.0)
        self.termsDecline.backgroundColor = Palette.buttonFace
        self.termsDecline.setTitleColor(Palette.buttonFaceText, for: .normal)
        self.termsDecline.toCircle()
        self.termsAccept.backgroundColor = Palette.darkHighlight
        self.termsAccept.setTitleColor(Palette.darkHighlightText, for: .normal)
        self.termsAccept.toCircle()
    }
    
    private func enableControls(showTerms: Bool = true) {
        let termsAccepted = Scorecard.shared.settings.termsDate != nil
        self.whistImage.isHidden = !termsAccepted && showTerms
        self.message.isHidden = !termsAccepted && showTerms
        self.termsTitle.isHidden = termsAccepted || !showTerms
        self.termsText.isHidden = termsAccepted || !showTerms
        self.termsAccept.isHidden = termsAccepted || !showTerms
        self.termsDecline.isHidden = termsAccepted || !showTerms
    }
    
    // MARK: - iCloud fetch and sync delegates ======================================================== -
    
    private func getCloudVersion(async: Bool = false) {
        if Scorecard.shared.isNetworkAvailable {
            self.sync.delegate = self
            self.syncGetVersion = true
            if self.sync.synchronise(syncMode: .syncGetVersion, timeout: nil, waitFinish: async) {
                // Running or queued (if async)
            } else {
                self.syncCompletion(0)
            }
        } else {
            self.syncCompletion(0)
        }
    }
    
    func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
       
        Utility.mainThread {
            self.syncGetPlayers = false
            
            for player in playerList {
                _ = player.createMO(saveToICloud: false)
            }
            self.sync.fetchPlayerImagesFromCloud(playerList.map{$0.playerMO})
            self.dismiss()
        }
       
    }
    
    internal func syncCompletion(_ errors: Int) {
        Utility.mainThread {
            if self.syncGetVersion {
                
                self.syncGetVersion = false
                
                Utility.debugMessage("launch", "Version returned")
                
                self.message.text = "Upgrading to\nCurrent Version..."
                if !Scorecard.shared.upgradeToVersion(from: self) {
                    self.alertMessage("Error upgrading to current version", okHandler: {
                        exit(0)
                    })
                }
                
                if Scorecard.shared.playerList.count != 0 && !Scorecard.version.blockSync && Scorecard.shared.isNetworkAvailable && Scorecard.shared.isLoggedIn {
                    // Rebuild any players who have a sync in progress flag set
                    self.message.text = "Rebuilding\nPlayer Data..."
                    self.reconcilePlayers()
                } else {
                    self.continueStartup()
                }
            }
        }
    }
    
    internal func syncAlert(_ message: String, completion: @escaping ()->()) {
        self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
            if Scorecard.version.blockAccess {
                exit(0)
            } else {
                completion()
                self.continueStartup()
            }
        })
    }
    
    // MARK: - Call reconcile and reconcile delegate methods =========================================================== -
    
    private func reconcilePlayers() {
        
        var playerMOList: [PlayerMO] = []
        for playerMO in Scorecard.shared.playerList {
            if playerMO.syncInProgress {
                playerMOList.append(playerMO)
            }
        }

        if playerMOList.count != 0 {
            // Set reconcile running
            reconcile = Reconcile()
            reconcile.delegate = self
            reconcile.reconcilePlayers(playerMOList: playerMOList)
        } else {
            self.continueStartup()
        }
    }
    
    public func reconcileAlertMessage(_ message: String) {
        Utility.mainThread {
            self.message.text = "Reconciling player data...\n\n\(message)"
        }
    }
    
    public func reconcileMessage(_ message: String) {
        Utility.mainThread {
             self.message.text = "Reconciling player data...\n\n\(message)"
        }
    }
    
    public func reconcileCompletion(_ errors: Bool) {
        Utility.mainThread {
            self.continueStartup()
        }
    }
    
    // MARK: - Notification and location permissions ================================================= -
    
    private func checkReceiveNotifications(completion: @escaping ()->()) {
        
        Notifications.checkNotifications(
            refused: { (requested) in
                if !requested {
                    self.alertMessage("You have previously refused permission for this app to send you notifications. \nThis will mean that you will not receive game invitation or completion notifications.\nTo change this, please authorise notifications in the Whist section of the main Settings App")
                }
                Scorecard.shared.settings.receiveNotifications = false
                completion()
            },
            accepted: {
                completion()
            },
            request: true)
    }
    
    // MARK: - Show get started ============================================================================= -
    
    private func showGetStarted() {
        GetStartedViewController.show(from: self) {
            self.dismiss()
        }
    }

    // MARK: - Routine to display this view ================================================================= -
    
    class public func show(from viewController: ScorecardViewController, completion: (()->())? = nil) {
        
        let storyboard = UIStoryboard(name: "LaunchScreenViewController", bundle: nil)
        let launchScreenViewController: LaunchScreenViewController = storyboard.instantiateViewController(withIdentifier: "LaunchScreenViewController") as! LaunchScreenViewController
        
        launchScreenViewController.preferredContentSize = CGSize(width: 400, height: 700)
        launchScreenViewController.modalPresentationStyle = .fullScreen
        launchScreenViewController.completion = completion
        launchScreenViewController.callingViewController = viewController
        
        viewController.present(launchScreenViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: false)
    }
}
