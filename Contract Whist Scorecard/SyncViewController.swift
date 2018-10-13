//
//  SyncViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 06/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CloudKit

class SyncViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, SyncDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    var scorecard: Scorecard!
    private let sync = Sync()
    
    // Local class variables
    private var count = 0
    private var output: [String] = []
    private var errors: Int = 0
    
    // Properties to pass state to / from segues
    var returnSegue = ""
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var syncTableView: UITableView!
    @IBOutlet weak var syncView: UIView!
    @IBOutlet weak var actionLabel: UILabel!
    @IBOutlet weak var finishButton: UIButton!
    @IBOutlet weak var syncImage: UIImageView!
    
    @IBAction func finishPressed(_ sender: UIButton) {
        returnToCaller()
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sync.initialise(scorecard: scorecard)
        actionLabel.text = "Syncing with iCloud"
       
   }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimations()
        finishButton.isHidden = true
        
        // Invoke the sync
        if self.sync.connect() {
            self.sync.delegate = self
            self.sync.synchronise()
        } else {
            self.alertMessage("Error connecting to iCloud", okHandler: {
                self.returnToCaller()
            })
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        scorecard.reCenterPopup(self)
    }
    
    // MARK: - Sync class delegate methods ===================================================================== -
    
    func syncMessage(_ message: String) {
        Utility.mainThread {
            self.output.append(message)
            self.count += 1
            self.syncTableView.insertRows(at: [IndexPath(row: self.count-1, section: 0)], with: .automatic)
            self.syncTableView.scrollToRow(at: IndexPath(row: self.count-1, section: 0), at: .bottom, animated: true)
        }
    }
    
    func syncAlert(_ message: String, completion: @escaping ()->()) {
        Utility.mainThread {
            self.stopAnimations(false)
        }
        self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
            completion()
        })
        sleep(10)
    }
    
    func syncCompletion(_ errors: Int) {
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
                Utility.executeAfter(delay: 2, completion: {
                    self.returnToCaller()
               })
            } else {
                // Error already notified
                self.returnToCaller()
            }
        }
    }
    
    func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
    }
    
    // MARK: - TableView Overrides ===================================================================== -

     func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Sync Table Cell", for: indexPath) as! SyncTableCell
        
        cell.label.text = output[indexPath.row]
        
        return cell
    }
    
    
    // MARK: - Utility Routines ======================================================================== -
    
    func returnToCaller() {
        self.performSegue(withIdentifier: returnSegue, sender: self)
    }
    
    func startAnimations() {
        var imageList: [UIImage] = []
        imageList.append(UIImage(named: "sync 0")!)
        imageList.append(UIImage(named: "sync 45")!)
        imageList.append(UIImage(named: "sync 90")!)
        imageList.append(UIImage(named: "sync 135")!)
        
        syncImage.animationImages = imageList;
        syncImage.animationDuration = 1.0
        syncImage.startAnimating()
    }
    
    func stopAnimations(_ success: Bool) {
        self.syncImage.stopAnimating()
        if success {
            self.syncImage.image = UIImage(named: "big tick")
            self.actionLabel.text = "Sync Complete"
        } else {
            self.syncImage.image = UIImage(named: "big cross")
            self.actionLabel.text = "Sync Failed"
        }
        
    }
}

class SyncTableCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
}
