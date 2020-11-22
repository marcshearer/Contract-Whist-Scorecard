//
//  Custom View Animations.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 20/11/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

enum ViewAnimation {
    case fade
    case slideRight
    case slideLeft
    case slideDown
    case slideUp
    case coverFromRight
    case coverFromLeft
    case coverFromTop
    case coverFromBottom
    case uncoverToRight
    case uncoverToLeft
    case uncoverToTop
    case uncoverToBottom
    case none
    
    func offset(by size: CGSize = CGSize(width: 1.0,height: 1.0), multiplier: CGFloat = 1.0) -> CGPoint {
        switch self {
        case .fade, .none:
            return .zero
        case .slideRight, .coverFromRight, .uncoverToLeft:
            return CGPoint(x: size.width * multiplier, y: 0)
        case .slideLeft, .coverFromLeft, .uncoverToRight:
            return CGPoint(x: -size.width * multiplier, y: 0)
        case .slideUp, .coverFromBottom, .uncoverToTop:
            return CGPoint(x: 0, y: size.height * multiplier)
        case .slideDown, .coverFromTop, .uncoverToBottom:
            return CGPoint(x: 0, y: -size.height * multiplier)
        }
    }
    
    var newEnters: Bool {
        switch self {
        case .slideUp, .slideDown, .slideLeft, .slideRight,
             .coverFromTop, .coverFromBottom, .coverFromLeft, .coverFromRight:
            return true
        default:
            return false
        }
    }
    
    var oldLeaves: Bool {
        switch self {
        case .slideUp, .slideDown, .slideLeft, .slideRight, .uncoverToTop, .uncoverToBottom, .uncoverToLeft, .uncoverToRight:
            return true
        default:
            return false
        }
    }
    
    var fades: Bool {
        return self == .fade
    }
    
    var rightMovement: Bool {
        switch self {
        case .slideRight, .coverFromLeft, .uncoverToRight:
            return true
        default:
            return false
        }
    }
    
    var leftMovement: Bool {
        switch self {
        case .slideLeft, .coverFromRight, .uncoverToLeft:
            return true
        default:
            return false
        }
    }
    
    var upMovement: Bool {
        switch self {
        case .slideUp, .coverFromBottom, .uncoverToTop:
            return true
        default:
            return false
        }
    }
    
    var downMovement: Bool {
        switch self {
        case .slideDown, .coverFromTop, .uncoverToBottom:
            return true
        default:
            return false
        }
    }
}

class ViewAnimator {
    
    static public func animate(rootView: UIView, clippingView: UIView? = nil, oldViews: [UIView] = [], newViews: [UIView] = [], animation: ViewAnimation, duration: TimeInterval = 0.5, layout: Bool = false, additionalAnimations: (()->())? = nil, completion: (()->())? = nil) {
        let clippingView = clippingView ?? rootView
        var newFrame: [CGRect] = []
        var oldFrame: [CGRect] = []
        let clipToBounds = clippingView.clipsToBounds
        clippingView.clipsToBounds = true
        
        for newView in newViews {
            newView.isHidden = false
            newView.alpha = 1.0
            if animation.newEnters {
                // Save existing frames
                newFrame.append(newView.frame)
                // Move views offscreen or hide
                newView.frame = newView.frame.offsetBy(offset: animation.offset(by: clippingView.frame.size))
            }
            if animation.fades {
                newView.alpha = 0.0
            }
        }
        for oldView in oldViews {
            if animation.oldLeaves {
                // Save existing frames
                oldFrame.append(oldView.frame)
                // Bring to front
                rootView.bringSubviewToFront(oldView)
            }
        }
        Utility.executeAfter(delay: 0.01) {
            // Allowing 10ms for view to be created properly and not interfere with animation
            Utility.animate(if: animation != .none, view: rootView, duration: duration, layout: layout,
                completion: {
                    clippingView.clipsToBounds = clipToBounds
                    for (index, oldView) in oldViews.enumerated() {
                        // Reposition old views back to where they were - assume caller removes or hides them
                        if animation.oldLeaves {
                            oldView.frame = oldFrame[index]
                        }
                        oldView.isHidden = true
                    }
                    completion?()
                },
                animations: {
                    additionalAnimations?()
                    for (index, newView) in newViews.enumerated() {
                        if animation.newEnters {
                            // Restore frames
                            newView.frame = newFrame[index]
                        }
                        if animation.fades {
                            newView.alpha = 1.0
                        }
                    }
                    for oldView in oldViews {
                        if animation.oldLeaves {
                            // Move old off screen
                            oldView.frame = oldView.frame.offsetBy(offset: animation.offset(by: clippingView.frame.size, multiplier: -1))
                        }
                    }
                }
            )
        }
    }
}
