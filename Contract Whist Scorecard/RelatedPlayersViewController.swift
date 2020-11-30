//
//  RelatedPlayers.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 30/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class RelatedPlayersViewController : ScorecardViewController, RelatedPlayersDelegate {

    private var email: String!
    private var completion: (()->())?
    private var descriptionMode: DescriptionMode = .opponents
    private var previousScreen: String?

    private weak var delegate: RelatedPlayersDelegate?
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var relatedPlayersContainerView: UIView!
    @IBOutlet private weak var relatedPlayersView: RelatedPlayersView!
    
    // MARK: - View Overrides ========================================================================== -

    internal override func viewDidLoad() {
        super.viewDidLoad()
        
        self.defaultViewColors()
        
        self.relatedPlayersView.set(email: self.email, descriptionMode: self.descriptionMode)
        
        // Setup banner
        self.setupBanner()
        
        // Setup help
        self.setupHelpView()
    }
        
    internal override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.relatedPlayersContainerView.layoutIfNeeded()
        self.relatedPlayersContainerView.roundCorners(cornerRadius: 8.0)
    }
    
    // MARK: - Related Players View delegates =========================================================== -
    
    func didDownloadPlayers(playerDetailList: [PlayerDetail], emailPlayerUUID: String?) {
        self.dismiss(animated: true, completion: {
            self.delegate?.didDownloadPlayers(playerDetailList: playerDetailList, emailPlayerUUID: emailPlayerUUID)
        })
    }
    
    func didCancel() {
        self.dismiss(animated: true, completion: self.completion)
    }
    
    // MARK: - UI Setup routines ============================================== -
    
    private func setupBanner() {
        self.banner.set(
            title: "W H I S T",
            rightButtons:[
                BannerButton(action: {[weak self] in self?.helpPressed()}, type: .help)])
    }
    
    // MARK: - Default view colors ============================================================== -
    
    private func defaultViewColors() {
        self.view.backgroundColor = Palette.banner.background
        self.captionLabel.textColor = Palette.banner.text
        self.relatedPlayersContainerView.backgroundColor = Palette.buttonFace.background
    }
    
    // MARK: - Function to show this view ======================================================= -
    
    public class func show(from viewController: ScorecardViewController & RelatedPlayersDelegate, email: String, descriptionMode: DescriptionMode = .opponents, previousScreen: String? = nil, completion: (()->())? = nil) {
        let storyboard = UIStoryboard(name: "RelatedPlayersViewController", bundle: nil)
        let relatedPlayersViewController: RelatedPlayersViewController = storyboard.instantiateViewController(withIdentifier: "RelatedPlayersViewController") as! RelatedPlayersViewController
        
        relatedPlayersViewController.email = email
        relatedPlayersViewController.descriptionMode = descriptionMode
        relatedPlayersViewController.previousScreen = previousScreen
        relatedPlayersViewController.completion = completion
        relatedPlayersViewController.delegate = viewController
        
        let popoverSize = (ScorecardUI.phoneSize() ? nil : ScorecardUI.defaultSize)
        viewController.present(relatedPlayersViewController, popoverSize: popoverSize, animated: true, container: .none, completion: nil)
    }
}

extension RelatedPlayersViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
                
        self.relatedPlayersView.addHelp(to: self.helpView, previousScreen: previousScreen)
    }
}
