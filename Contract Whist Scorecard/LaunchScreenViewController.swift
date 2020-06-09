//
//  LaunchScreenViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class LaunchScreenViewController: ScorecardViewController, SyncDelegate, ReconcileDelegate {

    @IBOutlet private weak var message: UILabel!
    @IBOutlet private weak var whistTitle: UILabel!
    
    // Sync
    internal let sync = Sync()
    private var syncGetPlayers = false
    private weak var callingViewController: ScorecardViewController!
    
    // Reconcile
    internal var reconcile: Reconcile!
    
    private var completion: (()->())?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = Palette.banner
        self.whistTitle.textColor = Palette.bannerEmbossed
        self.message.textColor = Palette.bannerText
        
        self.message.text = "Checking Network\nand iCloud Login ..."
        
        Utility.executeAfter(delay: 1.0) {
            Scorecard.shared.getVersion(completion: {
                // Don't call this until any upgrade has taken place
                self.getCloudVersion()
            })
        }
        // Note flow continues in viewDidContinue
    }
    
    private func viewDidContinue() {
        if !Scorecard.shared.settings.syncEnabled {
            // New device - try to load from iCloud
            self.message.text = "New Installation\n\nTrying to load\nsettings from iCloud..."
            Scorecard.shared.settings.loadFromICloud() { (players) in
                if let players = players {
                    self.checkReceiveNotifications() {
                        Scorecard.shared.settings.save()
                        self.syncGetPlayers = true
                        self.sync.delegate = self
                        if !self.sync.synchronise(syncMode: .syncGetPlayerDetails, specificEmail: players, waitFinish: true) {
                            self.dismiss(showMessage: false)
                        }
                    }
                } else {
                    // New device / iCloud user
                }
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
    
    // MARK: - iCloud fetch and sync delegates ======================================================== -
    
    private func getCloudVersion(async: Bool = false) {
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
    
    func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
       
        for player in playerList {
            _ = player.createMO()
        }
        self.sync.fetchPlayerImagesFromCloud(playerList.map{$0.playerMO})
        self.dismiss()
       
    }
    
    internal func syncCompletion(_ errors: Int) {
        
        if !self.syncGetPlayers {
        
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
                self.viewDidContinue()
            }
        }
    }
    
    internal func syncAlert(_ message: String, completion: @escaping ()->()) {
        self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
            if Scorecard.version.blockAccess {
                exit(0)
            } else {
                completion()
                self.viewDidContinue()
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
            self.viewDidContinue()
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
            self.viewDidContinue()
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
