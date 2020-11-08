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
        case photoShutter = 1108
        case alarm = 1304
        case lock = 1305
    }

    public func alertMessage(if condition: Bool = true, _ message: String? = nil, _ attributedMessage: NSAttributedString? = nil, title: String = "Warning", width: CGFloat? = nil, image: UIImage? = nil, imageWidth: CGFloat? = nil, imageTint: UIColor? = nil, sourceView: UIView? = nil, buttonText: String = "OK", okHandler: (() -> ())? = nil) {
        
        if condition {
            Utility.mainThread {
                AlertViewController.show(from: self, sourceView: sourceView, message: message, attributedMessage: attributedMessage, title: title, width: width, image: image, imageWidth: imageWidth, imageTint: imageTint, okButtonText: buttonText, okHandler: okHandler)
            }
        } else {
            okHandler?()
        }
    }

    public func alertDecision(if condition: Bool = true, _ message: String? = nil, _ attributedMessage: NSAttributedString? = nil, title: String = "Warning", width: CGFloat? = nil, image: UIImage? = nil, imageWidth: CGFloat? = nil, imageTint: UIColor? = nil, sourceView: UIView? = nil, okButtonText: String = "OK", okHandler: (() -> ())? = nil, otherButtonText: String? = nil, otherHandler: (() -> ())? = nil, cancelButtonText: String = "Cancel", cancelHandler: (() -> ())? = nil) {
        
        if condition {
            Utility.mainThread {
                AlertViewController.show(from: self, sourceView: sourceView, message: message, attributedMessage: attributedMessage, title: title, width: width, image: image, imageWidth: imageWidth, imageTint: imageTint, okButtonText: okButtonText, okHandler: okHandler, otherButtonText: otherButtonText, otherHandler: otherHandler, cancelButtonText: cancelButtonText, cancelHandler: cancelHandler)
            }
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
        indicatorView.style = UIActivityIndicatorView.Style.large
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
