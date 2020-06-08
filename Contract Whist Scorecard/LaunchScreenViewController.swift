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
                self.syncGetPlayers = true
                self.sync.delegate = self
                if !self.sync.synchronise(syncMode: .syncGetPlayerDetails, specificEmail: players, waitFinish: true) {
                    self.dismiss()
                }
            }
        } else {
            self.dismiss()
        }
    }
    
    private func dismiss() {
        Utility.mainThread {
            self.message.text = "Loading..."
            Utility.executeAfter(delay: 2.0) {
                self.dismiss(animated: true, completion: self.completion)
            }
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
        self.dismiss()
       
    }
    
    internal func syncCompletion(_ errors: Int) {
        
        if !self.syncGetPlayers {
        
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
            // Create an alert controller
            self.message.text = "Reconciling player data..."

            // Set reconcile running
            reconcile = Reconcile()
            reconcile.delegate = self
            reconcile.reconcilePlayers(playerMOList: playerMOList)
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

    // MARK: - Routine to display this view ================================================================= -
    
    class public func show(from viewController: ScorecardViewController, completion: (()->())? = nil) {
        
        let storyboard = UIStoryboard(name: "LaunchScreenViewController", bundle: nil)
        let launchScreenViewController: LaunchScreenViewController = storyboard.instantiateViewController(withIdentifier: "LaunchScreenViewController") as! LaunchScreenViewController
        
        launchScreenViewController.preferredContentSize = CGSize(width: 400, height: 700)
        launchScreenViewController.modalPresentationStyle = .fullScreen
        launchScreenViewController.completion = completion
        
        viewController.present(launchScreenViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: false)
    }
}
