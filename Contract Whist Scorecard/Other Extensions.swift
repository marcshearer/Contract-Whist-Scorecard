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

extension UIViewController {
    
    func hideNavigationBar() {
        self.navigationController?.isNavigationBarHidden = true
    }
    
    public func showNavigationBar() {
        self.navigationController?.isNavigationBarHidden = false
    }
    
}

class CustomViewController : UIViewController {
    
    /*
    override func viewDidLoad() {
        Utility.mainThread {
            super.viewDidLoad()
            Utility.debugMessage(self.className(), "didLoad =========================================")
        }
        self.isModalInPopover = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Utility.mainThread {
            super.viewDidAppear(animated)
            Utility.debugMessage(self.className(), "didAppear ---------------------------------------")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        Utility.mainThread {
            super.viewWillAppear(animated)
            Utility.debugMessage(self.className(), "willAppear ---------------------------------------")
        }
    }

    override func viewDidLayoutSubviews() {
        Utility.mainThread {
            super.viewDidLayoutSubviews()
            Utility.debugMessage(self.className(), "didLayoutSubviews -------------------------------")
        }
    }
    
    override func viewWillLayoutSubviews() {
        Utility.mainThread {
            super.viewWillLayoutSubviews()
            Utility.debugMessage(self.className(), "willLayoutSubviews ------------------------------")
        }
    }
    */
    
    func present(_ viewControllerToPresent: UIViewController, sourceView: UIView? = nil, animated flag: Bool, completion: (() -> Void)? = nil) {
        // Avoid silly popups on max sized phones
       
        if !ScorecardUI.phoneSize() && sourceView != nil {
            viewControllerToPresent.modalPresentationStyle = UIModalPresentationStyle.popover
            viewControllerToPresent.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            viewControllerToPresent.popoverPresentationController?.sourceView = sourceView
            viewControllerToPresent.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0 ,height: 0)
            viewControllerToPresent.isModalInPopover = true
            if let delegate = self as? UIPopoverPresentationControllerDelegate {
                viewControllerToPresent.popoverPresentationController?.delegate = delegate
            }
        }
        
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    override var prefersStatusBarHidden: Bool {
        get {
            return AppDelegate.applicationPrefersStatusBarHidden ?? true
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    private func className() -> String {
        let fullName = NSStringFromClass(self.classForCoder)
        var tail = fullName.split(at: ".").last!
        if let viewControllerPos = tail.position("viewController", caseless: true) {
            tail = tail.left(viewControllerPos)
        }
        return tail
    }
}

extension CGPoint {
    
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow((self.x - point.x), 2) + pow((self.y - point.y), 2))
    }
}

extension CGRect {
    
    var center: CGPoint {
        get {
            return CGPoint(x: self.midX, y: self.midY)
        }
    }
}
