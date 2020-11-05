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

class SyncViewController: ScorecardViewController, UITableViewDelegate, UITableViewDataSource, SyncDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    private let sync = Sync()
    
    // Variables to pass state
    private var completion: (()->())?
    
    // Local class variables
    private var messageCount = 0
    private var output: [String] = []
    private var stageComplete: [SyncStage : Bool] = [:]
    private var errors: Int = 0
    private var currentStage: SyncStage = SyncStage(rawValue: 0)!
    private var lastStageFinish = Date(timeIntervalSinceReferenceDate: 0.0)
    private var stages = 0
    private var syncStarted = false
    
    // UI Constants
    private let stageTableView = 1
    private let messageTableView = 2
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var syncStageTableView: UITableView!
    @IBOutlet private weak var syncMessageTableView: UITableView!
    @IBOutlet private weak var finishButton: UIButton!
    @IBOutlet private var labels: [UILabel]!
    
    @IBAction func finishPressed(_ sender: UIButton) {
        returnToCaller()
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()
   }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        finishButton.isHidden = true
        
        for stage in SyncStage.allCases {
            if stage != .started {
                self.syncStageTableView.beginUpdates()
                self.stages += 1
                self.syncStageTableView.insertRows(at: [IndexPath(row: self.stages - 1, section: 0)], with: .none)
                self.syncStageTableView.endUpdates()
            }
        }
        
        Utility.executeAfter(delay: 1.0) {
            // Invoke the sync
            self.sync.delegate = self
            self.syncStarted = true
            _ = self.sync.synchronise(waitFinish: true, okToSyncWithTemporaryPlayerUUIDs: true)
        }
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
            
            if stage.rawValue >= 0 {
                
                // Mark as complete
                self.stageComplete[stage] = true
                
                self.reportAfter(delay: 1.0, completion: {
                    
                    // Update tick and stop activity indicator
                    if let completeCell = self.syncStageTableView.cellForRow(at: IndexPath(row: stage.rawValue, section: 0)) as? SyncStageTableCell {
                        completeCell.statusImage.image = UIImage(named: "box tick")?.asTemplate
                        completeCell.statusImage.tintColor = Palette.banner.text
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
                })
            }
        }
    }
    
    private func stopActivityIndicators() {
        for stage in SyncStage.allCases {
            if let completeCell = self.syncStageTableView.cellForRow(at: IndexPath(row: stage.rawValue, section: 0)) as? SyncStageTableCell {
                 completeCell.activityIndicator.stopAnimating()
            }
        }
    }
    
    internal func syncAlert(_ message: String, completion: @escaping ()->()) {
        Utility.mainThread {
            self.stopActivityIndicators()
        }
        self.alertMessage(message, title: "Whist Sync", okHandler: {
            completion()
        })
    }
    
    internal func syncCompletion(_ errors: Int) {
        Utility.mainThread {
            self.errors=errors
            if self.errors > 0 {
                // Warn user of errors
                self.alertMessage("Warning: Errors occurred during synchronisation", title: "Warning", okHandler: {
                    self.finishButton.isHidden = false
                })
            } else if self.errors == 0 {
                // All OK - return but run out any backed up time first and then wait for 2 secs
                self.reportAfter(delay: 0.0, completion: {
                    Utility.executeAfter(delay: 2.0, completion: {
                        self.returnToCaller()
                    })
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
            return stages
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
            // Setup default colors (previously done in StoryBoard)
            self.defaultCellColors(cell: stageCell)
            
            let stage = SyncStage(rawValue: indexPath.row)!
            
            stageCell.label.text = Sync.stageDescription(stage: stage)
            stageCell.statusImage.image = UIImage(named: ((stageComplete[stage] ?? false) ? "box tick" : "box"))?.asTemplate
            stageCell.statusImage.tintColor = Palette.banner.text

            cell = stageCell
            
        case messageTableView:
            
            let messageCell = tableView.dequeueReusableCell(withIdentifier: "Sync Message Table Cell", for: indexPath) as! SyncMessageTableCell
            // Setup default colors (previously done in StoryBoard)
            self.defaultCellColors(cell: messageCell)

            
            messageCell.label.text = output[indexPath.row]
            
            cell = messageCell
            
        default:
            cell = UITableViewCell()
        }
        
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.alpha = 0

        UIView.animate(
            withDuration: 0.5,
            delay: 0.15 * Double(indexPath.row),
            animations: {
                cell.alpha = 1
            })
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    func returnToCaller() {
        self.dismiss()
    }
    
    private func xspinAnimation() -> CABasicAnimation {
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue = CGFloat.pi * 2000.0
        rotationAnimation.duration = 2000.0
        rotationAnimation.isCumulative = true
        rotationAnimation.isRemovedOnCompletion = false
        return rotationAnimation
    }
    
    
    private func reportAfter(delay: TimeInterval, completion: @escaping ()->()) {
        let dateNow = Date()
        let timeSinceLast = dateNow.timeIntervalSince(self.lastStageFinish)
        let waitTime = max(0.0, delay - timeSinceLast)
        self.lastStageFinish = dateNow + waitTime
        Utility.executeAfter(delay: waitTime, completion: {
            completion()
        })
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: ScorecardViewController, completion: (()->())? = nil){
        
        let storyboard = UIStoryboard(name: "SyncViewController", bundle: nil)
        let SyncViewController: SyncViewController = storyboard.instantiateViewController(withIdentifier: "SyncViewController") as! SyncViewController
        
        SyncViewController.completion = completion
        
        let popoverSize = (ScorecardUI.phoneSize() ? nil : ScorecardUI.defaultSize)
       
        viewController.present(SyncViewController, popoverSize: popoverSize, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: { self.completion?() })
    }
    
    override internal func shouldDismiss() -> Bool {
        return false
    }
}

class SyncStageTableCell: UITableViewCell {
    @IBOutlet fileprivate weak var statusImage: UIImageView!
    @IBOutlet fileprivate weak var label: UILabel!
    @IBOutlet fileprivate weak var activityIndicator: UIActivityIndicatorView!
}

class SyncMessageTableCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
}

extension SyncViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.finishButton.setTitleColor(Palette.banner.text, for: .normal)
        self.labels.forEach{(label) in label.textColor = Palette.banner.text}
        self.view.backgroundColor = Palette.banner.background
    }

    private func defaultCellColors(cell: SyncMessageTableCell) {
        switch cell.reuseIdentifier {
        case "Sync Message Table Cell":
            cell.label.textColor = Palette.banner.text
        default:
            break
        }
    }

    private func defaultCellColors(cell: SyncStageTableCell) {
        switch cell.reuseIdentifier {
        case "Sync Stage Table Cell":
            cell.label.textColor = Palette.banner.text
        default:
            break
        }
    }

}
