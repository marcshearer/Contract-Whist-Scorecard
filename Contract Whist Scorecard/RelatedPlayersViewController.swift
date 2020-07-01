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

    private weak var delegate: RelatedPlayersDelegate?
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var finishButton: ClearButton!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var relatedPlayersContainerView: UIView!
    @IBOutlet private weak var relatedPlayersView: RelatedPlayersView!
    
    // MARK: - View Overrides ========================================================================== -

    internal override func viewDidLoad() {
        self.defaultViewColors()
        self.relatedPlayersView.set(email: self.email, descriptionMode: self.descriptionMode)
    }
    
    internal override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.relatedPlayersContainerView.layoutIfNeeded()
        self.relatedPlayersContainerView.roundCorners(cornerRadius: 8.0)
    }
    
    // MARK: - Related Players View delegates =========================================================== -
    
    func didDownloadPlayers(playerDetailList: [PlayerDetail], emailPlayerUUID: String?) {
        delegate?.didDownloadPlayers(playerDetailList: playerDetailList, emailPlayerUUID: emailPlayerUUID)
        self.dismiss(animated: true)
    }
    
    func didCancel() {
        self.dismiss(animated: true, completion: self.completion)
    }
    
    // MARK: - Default view colors ============================================================== -
    
    private func defaultViewColors() {
        self.view.backgroundColor = Palette.banner
        self.titleLabel.textColor = Palette.bannerEmbossed
        self.captionLabel.textColor = Palette.bannerText
        self.relatedPlayersContainerView.backgroundColor = Palette.buttonFace
    }
    
    // MARK: - Function to show this view ======================================================= -
    
    public class func show(from viewController: ScorecardViewController & RelatedPlayersDelegate, email: String, descriptionMode: DescriptionMode = .opponents, completion: (()->())? = nil) {
        let storyboard = UIStoryboard(name: "RelatedPlayersViewController", bundle: nil)
        let relatedPlayersViewController: RelatedPlayersViewController = storyboard.instantiateViewController(withIdentifier: "RelatedPlayersViewController") as! RelatedPlayersViewController
        
        relatedPlayersViewController.preferredContentSize = CGSize(width: 400, height: 700)
        relatedPlayersViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        relatedPlayersViewController.email = email
        relatedPlayersViewController.descriptionMode = descriptionMode
        relatedPlayersViewController.completion = completion
        relatedPlayersViewController.delegate = viewController
        
        viewController.present(relatedPlayersViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
    }
}
