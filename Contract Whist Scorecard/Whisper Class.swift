//
//  Whisper Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 30/03/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class Whisper {
        
    private let height: CGFloat = 50.0
    private let sideIndent: CGFloat = 40.0
    private let bottomIndent: CGFloat = 10.0

    private var containerView = UIView()
    private var label = UILabel()
    private var parentView: UIView!
    private var tapGesture: WhisperTapGesture!
    private var frame: CGRect!
    private var hiddenFrame: CGRect!
    private var isShown = false
    private var timer: Timer!
    
    init(backgroundColor: UIColor? = nil, textColor: UIColor? = nil) {
        self.containerView.isHidden = true
        self.containerView.backgroundColor = UIColor.clear
        self.containerView.addSubview(self.label)
        self.label.backgroundColor = backgroundColor ?? Palette.whisper.background
        self.label.textColor = textColor ?? Palette.whisper.text
        self.label.adjustsFontSizeToFitWidth = true
        self.label.numberOfLines = 0
        self.label.font = UIFont.systemFont(ofSize: 16)
        self.label.textAlignment = .center
        self.label.isUserInteractionEnabled = true
        self.label.adjustsFontSizeToFitWidth = true
        self.tapGesture = WhisperTapGesture { self.hide() }
        self.label.addGestureRecognizer(self.tapGesture)
    }
    
    public func show(_ message: String, from parentView: UIView, hideAfter: TimeInterval! = nil) {
        Utility.mainThread {
            self.stopTimer()
            
            Utility.debugMessage("whisper", "Show '\(message)' - hide after \(hideAfter ?? 0)")
            
            var newLabel = true
            if self.isShown {
                if self.parentView == parentView {
                    // Existing whisper on this view - just change label
                    self.setupFrames()
                    newLabel = false
                    self.label.text = message
                    self.containerView.frame = self.frame
                    if hideAfter != nil {
                        self.hide(afterDelay: hideAfter)
                    }
                } else {
                    self.hide()
                }
            }
            
            if newLabel {
                self.isShown = true
                
                // Move to this view if necessary
                if self.parentView != parentView {
                    self.parentView = parentView
                    self.containerView.removeFromSuperview()
                    self.parentView.addSubview(self.containerView)
                }

                // Set up label
                self.setupFrames()
                self.containerView.frame = self.hiddenFrame
                self.label.frame = CGRect(origin: CGPoint(), size: self.containerView.frame.size)
                self.label.text = message
                self.label.roundCorners(cornerRadius: 10.0)
                self.containerView.addShadow()
               
                // Show label
                self.containerView.isHidden = false
                self.parentView.bringSubviewToFront(self.containerView)

                Utility.animate(duration: 0.5, animations: {
                    self.containerView.frame = self.frame
                    if hideAfter != nil {
                        // Hide if requested
                        self.hide(afterDelay: hideAfter)
                    }
                })
            }
        }
    }
    
    private func setupFrames() {
        self.frame = CGRect(x: self.parentView.safeAreaInsets.left + self.sideIndent, y: self.parentView.frame.height - self.height - self.bottomIndent, width: self.parentView.safeAreaLayoutGuide.layoutFrame.width - (2.0 * self.sideIndent), height: self.height)
        self.hiddenFrame = CGRect(x: self.frame.minX, y: self.parentView.frame.maxY + self.height, width: self.frame.width, height: self.frame.height)
    }
    
    public func hide(_ message: String! = nil, afterDelay: TimeInterval? = nil) {
        self.stopTimer()
        Utility.debugMessage("whisper", "Hide  - \(self.isShown ? (self.label.text ?? "") : "")")
        
        if self.isShown {
            if afterDelay != nil {
                self.startTimer(afterDelay!) { self.hide(message) }
            } else {
                if message != nil {
                    self.label.text = message
                }
                Utility.animate(duration: 0.5, completion: {
                    self.isShown = false
                    self.containerView.isHidden = true
                    
                }, animations: {
                    self.containerView.frame = self.hiddenFrame
                })
            }
        }
    }
    
    private func stopTimer() {
        if let timer = self.timer {
            timer.invalidate()
            self.timer = nil
        }
    }
    
    private func startTimer(_ timeInterval: TimeInterval, action: @escaping ()->()) {
        self.stopTimer()
        self.timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { (_) in
            action()
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
