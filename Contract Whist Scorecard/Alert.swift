//
//  Alert.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 21/04/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import AudioToolbox

extension UIViewController {
    
    public enum AlertSound: Int {
        case shake = 1109
        case descent = 1024
        case photeShutter = 1108
        case alarm = 1304
        case lock = 1305
    }

    public func alertMessage(_ message: String, title: String = "Warning", buttonText: String = "OK", okHandler: (() -> ())? = nil) {
        
        func alertMessageCompletion(alertAction: UIAlertAction) {
            if okHandler != nil {
                okHandler!()
            }
        }
        
        Utility.mainThread {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: buttonText, style: UIAlertAction.Style.default, handler: alertMessageCompletion))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    public func alertMessage(if condition: Bool, _ message: String!, title: String = "Warning", buttonText: String! = "OK", okHandler: @escaping () -> ()) {
        // Pop up alert message if condition is true and execute handler on exit - else execute handler without alert
        if condition {
            self.alertMessage(message, title: title, buttonText: buttonText, okHandler: okHandler)
        } else {
            okHandler()
        }
    }

    public func alertDecision(_ message: String, title: String = "Warning", okButtonText: String = "OK", okHandler: (() -> ())? = nil, otherButtonText: String? = nil, otherHandler: (() -> ())? = nil, cancelButtonText: String = "Cancel", cancelHandler: (() -> ())? = nil) {
  
        func alertDecisionOkCompletion(alertAction: UIAlertAction) {
            okHandler?()
        }
        
        func alertDecisionOtherCompletion(alertAction: UIAlertAction) {
            otherHandler?()
        }
        
        func alertDecisionCancelCompletion(alertAction: UIAlertAction) {
            cancelHandler?()
        }
        
        Utility.mainThread {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: okButtonText, style: UIAlertAction.Style.default, handler: alertDecisionOkCompletion))
            if otherButtonText != nil {
                 alertController.addAction(UIAlertAction(title: otherButtonText, style: UIAlertAction.Style.default, handler: alertDecisionOtherCompletion))
            }
            alertController.addAction(UIAlertAction(title: cancelButtonText, style: UIAlertAction.Style.cancel, handler: alertDecisionCancelCompletion))
            self.present(alertController, animated: true, completion: nil)
        }
    }

    public func alertDecision(if condition: Bool,_ message: String, title: String = "Warning", okButtonText: String = "OK", okHandler: (() -> ())? = nil, otherButtonText: String? = nil, otherHandler: (() -> ())? = nil, cancelButtonText: String = "Cancel", cancelHandler: (() -> ())? = nil) {
        // Pop up alert decision if condition is true and execute handler on exit - else execute ok handler without alert
        if condition {
            self.alertDecision(message, title: title, okButtonText: okButtonText, okHandler: okHandler, otherButtonText: otherButtonText, otherHandler: otherHandler, cancelButtonText: cancelButtonText, cancelHandler: cancelHandler)
        } else {
            okHandler?()
        }
    }
    
    public func alertVibrate() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    public func alertSound(sound: AlertSound = .shake) {
        AudioServicesPlayAlertSound(SystemSoundID(sound.rawValue))
    }
    
    public func alertWait(_ message: String, title: String = "", completion: (()->())? = nil) -> UIAlertController {
        let alertController = UIAlertController(title: title, message: message + "\n\n\n\n\n", preferredStyle: .alert)
    
        // Add the activity indicator as a subview of the alert controller's view
        let indicatorView =
            UIActivityIndicatorView(frame: CGRect(x: 0, y: 100,
                                                  width: alertController.view.frame.width,
                                                  height: 100))
        indicatorView.style = .whiteLarge
        indicatorView.color = UIColor.black
        indicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alertController.view.addSubview(indicatorView)
        indicatorView.isUserInteractionEnabled = true
        indicatorView.startAnimating()
        
        // Present the view controller
        self.present(alertController, animated: true, completion: completion)
        
        return alertController
    }
}

extension UIAlertController {
    
    public func setAlertWaitMessage(_ message: String) {
        self.message = message + "\n\n\n\n"
    }

}

extension UIView {

    public func alertFlash(duration: TimeInterval = 0.2, after: Double = 0.0, repeatCount: Int = 1, backgroundColor: UIColor? = nil) {
        let oldAlpha = self.alpha
        let oldBackgroundColor = self.backgroundColor
        
        let animation = UIViewPropertyAnimator(duration: duration / 2.0, curve: .easeIn) {
            if backgroundColor != nil {
                self.backgroundColor = backgroundColor
            } else {
                self.alpha = 0.0
            }
        }
        animation.addCompletion { (_) in
            let animation = UIViewPropertyAnimator(duration: duration / 2.0, curve: .easeIn) {
                if backgroundColor != nil {
                    self.backgroundColor = oldBackgroundColor
                } else {
                    self.alpha = oldAlpha
                }
            }
            animation.addCompletion { (_) in
                if repeatCount > 1 {
                    self.alertFlash(duration: duration, after: duration / 2.0, repeatCount: repeatCount - 1, backgroundColor: backgroundColor)
                }
            }
            animation.startAnimation()
        }
        
        animation.startAnimation()
    }
}

class ActionSheet : NSObject, UIPopoverPresentationControllerDelegate {
    
    public var alertController: UIAlertController
    private var dark: Bool
    
    init(_ title: String! = nil, message: String! = nil, dark: Bool = false, view: UIView! = nil, direction: UIPopoverArrowDirection! = nil, x: CGFloat! = nil, y: CGFloat! = nil) {
        var view: UIView! = view
        if view == nil {
            view = Utility.getActiveViewController()!.view
        }
        self.dark = dark

        let optionBackgroundColor = Palette.background
        var titleBackgroundColor: UIColor
        var titleTextColor: UIColor
        if dark {
            titleBackgroundColor = Palette.darkHighlight
            titleTextColor = Palette.darkHighlightText
        } else {
            titleBackgroundColor = Palette.emphasis
            titleTextColor = Palette.emphasisText
        }
        
        self.alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        if let title = title {
            // Set attributed title
            let attributes = [NSAttributedString.Key.foregroundColor : titleTextColor,
                              NSAttributedString.Key.font : UIFont.boldSystemFont(ofSize: 22.0)]
            let titleString = NSMutableAttributedString(string: title, attributes: attributes)

            alertController.setValue(titleString, forKey: "attributedTitle")
        }
        if let message = message {
            // Set attributed message
            let attributes = [NSAttributedString.Key.foregroundColor : titleTextColor]
            let messageString = NSMutableAttributedString(string: message, attributes: attributes)
            alertController.setValue(messageString, forKey: "attributedMessage")
        }
        super.init()
        if let popover = alertController.popoverPresentationController {
            popover.delegate = self
            if direction == nil {
                popover.permittedArrowDirections = UIPopoverArrowDirection()
                if x == nil || y == nil {
                    popover.sourceRect = CGRect(x: view.frame.width / 2, y: view.frame.height / 2, width: 0, height: 0)
                }
            } else {
                popover.permittedArrowDirections = [direction]
                if x == nil || y == nil {
                    switch direction! {
                    case .left:
                        popover.sourceRect = CGRect(x: view.frame.width, y: view.frame.height / 2, width: 0, height: 0)
                    case .right:
                        popover.sourceRect = CGRect(x: 0, y: view.frame.height / 2, width: 0, height: 0)
                    case .up:
                        popover.sourceRect = CGRect(x: view.frame.width / 2, y: view.frame.height, width: 0, height: 0)
                    case .down:
                        popover.sourceRect = CGRect(x: view.frame.width / 2, y: 0, width: 0, height: 0)
                    default:
                        break
                    }
                }
            }
            popover.sourceView = (view == nil ? Utility.getActiveViewController()!.view : view)
            if x != nil && y != nil {
                popover.sourceRect = CGRect(x: x, y: y, width: 0, height: 0)
            }
            if dark {
                popover.backgroundColor = optionBackgroundColor
            }
        } else {
            alertController.view.subviews.first?.subviews.first?.subviews.first?.backgroundColor = optionBackgroundColor
            alertController.view.subviews.first?.subviews.first?.subviews.first?.subviews.first?.backgroundColor = titleBackgroundColor
            alertController.view.subviews.first?.subviews.first?.subviews.first?.subviews.last?.backgroundColor = optionBackgroundColor
        }
    }
    
    public func add(_ title: String, style: UIAlertAction.Style = UIAlertAction.Style.default, handler: (()->())! = nil) {
        let action = UIAlertAction(title: title, style: style, handler: { (UIAlertAction)->() in
            handler?()
        })
        alertController.addAction(action)
        if self.dark && style == .cancel {
            action.setValue(UIColor.black, forKey: "titleTextColor")
        } else {
            action.setValue(Palette.highlightText, forKey: "titleTextColor")
        }
    }
    
    public func present() {
        Utility.getActiveViewController()?.present(alertController, animated: true, completion: nil)
    }
}
