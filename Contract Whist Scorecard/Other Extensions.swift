//
//  Other Extensions.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class SearchBar : UISearchBar {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.layer.borderWidth = 1
        self.layer.borderColor = self.barTintColor?.cgColor
    }
}

class Stepper: UIStepper {
    private let _textField: UITextField!
    public var textField: UITextField {
        get {
            return _textField
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        _textField = nil
        super.init(coder: aDecoder)!
    }
    
    init(frame: CGRect, textField: UITextField) {
        self._textField = textField
        super.init(frame: frame)
    }
}
