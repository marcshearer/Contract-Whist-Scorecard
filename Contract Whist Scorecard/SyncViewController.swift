//
//  SyncViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 06/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CloudKit
import QuartzCore

class SyncViewController: CustomViewController, UITableViewDelegate, UITableViewDataSource, SyncDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    private let scorecard = Scorecard.shared
    private let sync = Sync()
    
    // Variables to pass state
    private var completion: (()->())?
    
    // Local class variables
    private var messageCount = 0
    private var output: [String] = []
    private var stageComplete: [SyncStage : Bool] = [:]
    private var errors: Int = 0
    private var currentStage: SyncStage = SyncStage(rawValue: 0)!
    
    // UI Constants
    private let stageTableView = 1
    private let messageTableView = 2
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var syncStageTableView: UITableView!
    @IBOutlet weak var syncMessageTableView: UITableView!
    @IBOutlet weak var navigationBar: NavigationBar!
    @IBOutlet weak var finishButton: UIButton!
    @IBOutlet weak var syncImage: UIImageView!
    
    @IBAction func finishPressed(_ sender: UIButton) {
        returnToCaller()
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationBar.setTitle("Syncing with iCloud")
   }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimations()
        finishButton.isHidden = true
        
        // Invoke the sync
        self.sync.delegate = self
        _ = self.sync.synchronise(waitFinish: true)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    // MARK: - Sync class delegate methods ===================================================================== -
    
    internal func syncMessage(_ message: String) {
        Utility.mainThread {
            self.output.append(message)
            self.messageCount += 1
            self.syncMessageTableView.insertRows(at: [IndexPath(row: self.messageCount-1, section: 0)], with: .automatic)
            self.syncMessageTableView.scrollToRow(at: IndexPath(row: self.messageCount-1, section: 0), at: .bottom, animated: true)
        }
    }
    
    internal func syncStageComplete(_ stage: SyncStage) {
        Utility.mainThread {
            // Mark as complete
            self.stageComplete[stage] = true
            
            // Update tick and stop activity indicator
            if let completeCell = self.syncStageTableView.cellForRow(at: IndexPath(row: stage.rawValue, section: 0)) as? SyncStageTableCell {
                completeCell.statusImage.image = UIImage(named: "boxtick")
                completeCell.activityIndicator.stopAnimating()
            }
            
            // Start next activity indicator
            if let nextStage = SyncStage(rawValue: stage.rawValue + 1) {
                let indexPath = IndexPath(row: nextStage.rawValue, section: 0)
                if let nextCell = self.syncStageTableView.cellForRow(at: indexPath) as? SyncStageTableCell {
                    nextCell.activityIndicator.startAnimating()
                }
                // Make sure we can see it (in landscape)
                self.syncStageTableView.scrollToRow(at: indexPath, at: .none, animated: true)
            }
            self.view.layoutIfNeeded()
        }
    }
    
    internal func syncAlert(_ message: String, completion: @escaping ()->()) {
        Utility.mainThread {
            self.stopAnimations(false)
        }
        self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
            completion()
        })
        sleep(10)
    }
    
    internal func syncCompletion(_ errors: Int) {
        Utility.mainThread {
            self.errors=errors
            self.stopAnimations(self.errors == 0)
            if self.errors > 0 {
                // Warn user of errors
                let alertController = UIAlertController(title: "Warning", message: "Warning: Errors occurred during synchronisation", preferredStyle: UIAlertController.Style.alert)
                alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler:  {
                    (action:UIAlertAction!) -> Void in
                    self.finishButton.isHidden = false
                }))
                self.present(alertController, animated: true)
            } else if self.errors == 0 {
                // All OK - return
                Utility.executeAfter(delay: 3, completion: {
                    self.returnToCaller()
               })
            } else {
                // Error already notified
                self.returnToCaller()
            }
        }
    }
    
    // MARK: - TableView Overrides ===================================================================== -

     func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView.tag {
        case stageTableView:
            return SyncStage.allCases.count - 1 // No row for 'started'
        case messageTableView:
            return messageCount
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell:UITableViewCell
        
        switch tableView.tag {
        case stageTableView:
            
            let stageCell = tableView.dequeueReusableCell(withIdentifier: "Sync Stage Table Cell", for: indexPath) as! SyncStageTableCell
            
            let stage = SyncStage(rawValue: indexPath.row)!
            
            stageCell.label.text = Sync.stageDescription(stage: stage)
            stageCell.statusImage.image = UIImage(named: ((stageComplete[stage] ?? false) ? "boxtick" : "box"))
            
            cell = stageCell
            
        case messageTableView:
            
            let messageCell = tableView.dequeueReusableCell(withIdentifier: "Sync Message Table Cell", for: indexPath) as! SyncMessageTableCell
            
            messageCell.label.text = output[indexPath.row]
            
            cell = messageCell
            
        default:
            cell = UITableViewCell()
        }
        
        return cell
    }
    
    
    // MARK: - Utility Routines ======================================================================== -
    
    func returnToCaller() {
        self.dismiss()
    }
    
    func startAnimations() {
        syncImage.layer.add(spinAnimation(), forKey: "Rotate")
    }

    private func spinAnimation() -> CABasicAnimation {
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue = CGFloat.pi * 2000.0
        rotationAnimation.duration = 2000.0
        rotationAnimation.isCumulative = true
        rotationAnimation.isRemovedOnCompletion = false
        return rotationAnimation
    }
    
    func stopAnimations(_ success: Bool) {
        self.syncImage.layer.removeAllAnimations()
        if success {
            self.syncImage.image = UIImage(named: "big tick")
            self.navigationBar.setTitle("Sync Complete")
        } else {
            self.syncImage.image = UIImage(named: "big cross")
            self.navigationBar.setTitle("Sync Failed")
        }
        
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: UIViewController, completion: (()->())? = nil){
        
        let storyboard = UIStoryboard(name: "SyncViewController", bundle: nil)
        let SyncViewController: SyncViewController = storyboard.instantiateViewController(withIdentifier: "SyncViewController") as! SyncViewController
        
        SyncViewController.modalPresentationStyle = UIModalPresentationStyle.popover
        SyncViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        SyncViewController.popoverPresentationController?.sourceView = viewController.popoverPresentationController?.sourceView ?? viewController.view
        SyncViewController.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0 ,height: 0)
        SyncViewController.preferredContentSize = CGSize(width: 400, height: 700)
        SyncViewController.popoverPresentationController?.delegate = viewController as? UIPopoverPresentationControllerDelegate
        
        SyncViewController.completion = completion
        
        viewController.present(SyncViewController, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: { self.completion?() })
    }
}

class SyncStageTableCell: UITableViewCell {
    @IBOutlet weak var statusImage: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
}

class SyncMessageTableCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
}
