//
//  NextHandViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 18/09/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class NextHandViewController: ScorecardViewController {
    
    private var round: Int?
    
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var roundLabel: UILabel!
 
    internal override func viewDidLoad() {
        super.viewDidLoad()
        
        let color = Palette.roomInterior
        self.banner.set(backgroundColor: color)
        self.roundLabel.attributedText = Scorecard.game.roundTitle(self.round ?? Scorecard.game.handState.round)
        self.view.backgroundColor = color.background
    }
    
    internal override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Utility.executeAfter(delay: 1.0) {
            self.controllerDelegate?.didProceed(context: ["sendAfter" : 4.0])
        }
    }
    
    public class func show(from viewController: ScorecardViewController, appController: ScorecardAppController, round: Int?) -> NextHandViewController {
       
        let storyboard = UIStoryboard(name: "NextHandViewController", bundle: nil)
        let nextHandViewController = storyboard.instantiateViewController(withIdentifier: "NextHandViewController") as! NextHandViewController
        
        nextHandViewController.controllerDelegate = appController
        nextHandViewController.round = round
        
        viewController.present(nextHandViewController, appController: appController, animated: true, completion: nil)
        
        return nextHandViewController
    }
    
}
