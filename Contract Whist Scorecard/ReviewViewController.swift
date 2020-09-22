//
//  ReviewViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 06/08/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import UIKit

class ReviewViewController: ScorecardViewController, ScorecardAlertDelegate, BannerDelegate {
    
    // Properties passed
    public var round: Int!
    public var thisPlayer: Int!
        
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var dealView: DealView!
    
    @IBAction func finishPressed() {
        self.dismiss()
    }
   
    @IBAction func tapGesture(recognizer:UITapGestureRecognizer) {
        self.finishPressed()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()
        
        self.setupBanner()
        self.dealView.show(round: self.round, thisPlayer: self.thisPlayer)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Scorecard.shared.reCenterPopup(self)
        view.setNeedsLayout()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Scorecard.shared.alertDelegate = nil
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        Scorecard.shared.motionBegan(motion, with: event)
    }
    
    // MARK: - Alert delegate handlers =================================================== -
    
    internal func alertUser(reminder: Bool) {
        self.banner.alertFlash(Banner.finishButton, duration: 0.3, repeatCount: 3)
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func setupBanner() {
        let roundTitle = Scorecard.game.roundTitle(round, rankColor: Palette.banner.text)
        let overUnder = Scorecard.game.overUnder(round: round)
        let overUnderWidth = overUnder.labelWidth(font: Banner.defaultFont)
        
        self.banner.set(
            attributedTitle: roundTitle, menuTitle: "Review Hand",
            rightButtons: [BannerButton(attributedTitle: overUnder, width: overUnderWidth, action: finishPressed, font: Banner.defaultFont)])
    }
    
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, round: Int, thisPlayer: Int) -> ReviewViewController?{
        
        let storyboard = UIStoryboard(name: "ReviewViewController", bundle: nil)
        let reviewViewController = storyboard.instantiateViewController(withIdentifier: "ReviewViewController") as! ReviewViewController
        
        reviewViewController.round = round
        reviewViewController.thisPlayer = thisPlayer
        
        viewController.present(reviewViewController, appController: appController, animated: true, completion: nil)
     
        return reviewViewController
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }

    private func defaultViewColors() {
        self.view.backgroundColor = Palette.normal.background
    }
}

