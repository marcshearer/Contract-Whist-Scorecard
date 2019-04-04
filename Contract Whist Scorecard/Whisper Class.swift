//
//  Whisper Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 30/03/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class Whisper {
    
    private let height:CGFloat = 50.0
    private let sideIndent:CGFloat = 40.0
    private let bottomIndent: CGFloat = 4.0

    private var label: UILabel
    private var view: UIView!
    private var tapGesture: WhisperTapGesture!
    private var frame: CGRect!
    private var hiddenFrame: CGRect!
    private var isShown = false
    
    init() {
        self.label = UILabel()
        self.label.isUserInteractionEnabled = true
    }
    
     public func show(_ message: String, hideAfter: TimeInterval! = nil) {
        var newLabel = true
        Utility.mainThread {
            if self.isShown {
                if self.view == Utility.getActiveViewController(fullScreenOnly: true)!.view {
                    // Existing whisper on this view - just change label
                    newLabel = false
                    self.label.text = message
                    if hideAfter != nil {
                        self.hide(after: hideAfter)
                    }
                } else {
                    self.hide()
                }
            }
            
            if newLabel {
                // Setup view
                let viewController = Utility.getActiveViewController(fullScreenOnly: true)!
                self.view = viewController.view
                self.setupFrames()
                
                // Set up tab gesture
                self.tapGesture = WhisperTapGesture { self.hide() }
                self.tapGesture.numberOfTapsRequired = 1
                self.tapGesture.numberOfTouchesRequired = 1
                
                // Set up label
                self.label.frame = self.hiddenFrame
                self.label.adjustsFontSizeToFitWidth = true
                self.label.numberOfLines = 0
                self.label.text = message
                self.label.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1.0)
                self.label.layer.borderColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0).cgColor
                self.label.layer.borderWidth = 1.0
                self.label.font = UIFont.systemFont(ofSize: 16)
                self.label.textAlignment = .center
                ScorecardUI.roundCorners(self.label, percent: 20)
                
                // Show label
                self.view.addSubview(self.label)
                self.view.bringSubviewToFront(self.label)
                self.label.addGestureRecognizer(self.tapGesture)
                
                self.isShown = true
                
                Utility.animate(duration: 0.5, animations: {
                    self.label.frame = self.frame
                    if hideAfter != nil {
                        // Hide if requested
                        self.hide(after: max(0.0, hideAfter - 0.5))
                    }
                })
            }
        }
    }
    
    private func setupFrames() {
        self.frame = CGRect(x: self.view.safeAreaInsets.left + self.sideIndent, y: self.view.safeAreaInsets.top + self.view.safeAreaLayoutGuide.layoutFrame.height - self.height - self.bottomIndent, width: self.view.safeAreaLayoutGuide.layoutFrame.width - (2.0 * self.sideIndent), height: self.height)
        self.hiddenFrame = CGRect(x: self.frame.minX, y: self.view.frame.maxY + self.height, width: self.frame.width, height: self.frame.height)
    }
    
    public func hide(_ message: String! = nil, after: TimeInterval! = nil) {
        if self.isShown {
            if message != nil {
                self.label.text = message
            }
            Utility.animate(duration: 0.2, afterDelay: after, animations: {
                self.label.frame = self.hiddenFrame
            })
             self.isShown = false
        }
    }
}

fileprivate class WhisperTapGesture: UITapGestureRecognizer {
    
    private var action: ()->()
    
    init(action: @escaping ()->()) {
        self.action = action
        super.init(target: nil, action: nil)
    }
    
    override internal func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        self.action()
    }
    
}
