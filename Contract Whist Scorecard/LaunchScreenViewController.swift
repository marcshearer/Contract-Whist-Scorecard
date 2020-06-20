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
    private var termsUser: String?
    
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
        if let termsUser = self.termsUser {
            Scorecard.settings.termsDate = Date()
            Scorecard.settings.termsUser = termsUser
            Scorecard.settings.termsDevice = Scorecard.deviceName
            Scorecard.settings.save()
            self.enableControls()
            self.continueStartup()
        } else {
            fatalError("Shouldn't have got to this point if user not available")
        }
    }
    
    @IBAction func declinePressed(_ sender: UIButton) {
        self.message.text = "You cannot access the app without accepting the terms of use"
        self.termsUser = nil
        self.enableControls()
        Utility.executeAfter(delay: 10.0) {
            exit(0)
        }
    }
    
    // MARK: - View Overrides ========================================================================== -
 
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.setupControls()
        
        self.termsText.text = "Whist allows you to score or play Contract Whist.\n\nA record of the scores of your games and the players' names will be kept and synchronised with a central database.\n\nThis data will not be used for any marketing purposes.\nHowever it will be accessible to other users of the app who know your Unique ID.\n\nBy accepting these terms and conditions you agree to any data you enter being shared in this way."

        self.enableControls()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        checkICloud()
        
        // Note flow continues in checkICloud
    }
    
    private func checkICloud() {
        
        self.message.text = "Loading..."
        Scorecard.shared.getVersion(completion: {
            // Don't call this until any upgrade has taken place
            self.getCloudVersion()
        })

        // Note flow continues in continueStartup
    }
    
    private func continueStartup() {
        
        if Scorecard.settings.termsDate == nil {
            // Need to get terms approval - but only possible with network
            if !Scorecard.shared.isNetworkAvailable || !Scorecard.shared.isLoggedIn {
                self.failNoNetwork()
            } else {
                Sync.getUser { (userID) in
                    if userID == nil && Scorecard.settings.termsDate == nil {
                        self.failNoNetwork()
                    } else {
                        // Wait for acceptance - will return after button click
                        self.termsUser = userID
                        self.enableControls()
                    }
                }
            }
        } else {
            Utility.executeAfter(delay: 1.0) {
                self.continueStartupContinued()
            }
        }
    }
            
   private func continueStartupContinued() {

        if !Scorecard.settings.syncEnabled {
            // New device - try to load from iCloud
            self.newDevice = true
            self.message.text = "Loading..."
            Scorecard.settings.loadFromICloud() { (players) in
                Utility.mainThread {
                    if players != nil && !players!.isEmpty {
                        self.syncPlayerList = players
                    }
                    if Scorecard.settings.termsDate == nil {
                        // Need to wait for terms acceptance
                        self.enableControls()
                    } else {
                        self.linkToNext()
                    }
                }
            }
        } else if Scorecard.settings.termsDate == nil {
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
                    Scorecard.settings.save()
                    self.syncGetPlayers = true
                    self.sync.delegate = self
                    if !self.sync.synchronise(syncMode: .syncGetPlayerDetails, specificPlayerUUIDs: self.syncPlayerList!, waitFinish: true) {
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

    private func failNoNetwork() {
        self.message.text = "You must be online\nand logged in to iCloud\n to start up the app"
        Utility.executeAfter(delay: 10.0, completion: { exit(0) })
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
    
    private func enableControls() {
        let showTerms = self.termsUser != nil
        let termsAccepted = Scorecard.settings.termsDate != nil
        self.whistImage.isHidden = !termsAccepted && showTerms
        self.message.isHidden = !termsAccepted && showTerms
        self.termsTitle.isHidden = termsAccepted || !showTerms
        self.termsText.isHidden = termsAccepted || !showTerms
        self.termsAccept.isHidden = termsAccepted || !showTerms
        self.termsDecline.isHidden = termsAccepted || !showTerms
    }
    
    // MARK: - iCloud fetch and sync delegates ======================================================== -
    
    private func getCloudVersion(async: Bool = false) {
        self.syncGetVersion = true
        if Scorecard.shared.isNetworkAvailable {
            self.sync.delegate = self
            if self.sync.synchronise(syncMode: .syncGetVersion, timeout: nil, waitFinish: async) {
                // Running or queued (if async)
            } else {
                self.syncCompletion(0)
            }
        } else {
            self.syncCompletion(0)
        }
    }
    
    func syncReturnPlayers(_ playerList: [PlayerDetail]!, _ thisPlayerUUID: String?) {
       
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
                
                if !Scorecard.shared.upgradeToVersion(from: self) {
                    self.alertMessage("Error upgrading to current version", okHandler: {
                        exit(0)
                    })
                }
                
                if Scorecard.shared.playerList.count != 0 && !Scorecard.version.blockSync && Scorecard.shared.isNetworkAvailable && Scorecard.shared.isLoggedIn {
                    // Rebuild any players who have a sync in progress flag set
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
            self.message.text = "Rebuilding\nPlayer Data..."
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
                Scorecard.settings.receiveNotifications = false
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
