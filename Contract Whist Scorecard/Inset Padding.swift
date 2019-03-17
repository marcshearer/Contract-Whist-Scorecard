//
//  InsetPaddingView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 15/03/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

// Used as a padding view for devices such as iPhone X where there is some space around the safe area

import UIKit

class InsetPaddingViewNoColor: UIView {

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
}

class InsetPaddingView: InsetPaddingViewNoColor {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = ScorecardUI.bannerColor
    }

}


