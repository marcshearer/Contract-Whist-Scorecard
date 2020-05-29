//
//  LaunchScreenViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class LaunchScreenViewController: UIViewController {

    @IBOutlet private weak var syncLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var leftBanner: UIView!
    @IBOutlet private weak var rightBanner: UIView!
    @IBOutlet private weak var walkThroughButton: ClearButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

       // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()
    }

}

extension LaunchScreenViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.leftBanner.backgroundColor = Palette.banner
        self.rightBanner.backgroundColor = Palette.banner
        self.syncLabel.textColor = Palette.textMessage
        self.titleLabel.textColor = Palette.textEmphasised
        self.walkThroughButton.tintColor = Palette.bannerText
        self.view.backgroundColor = Palette.background
    }

}


