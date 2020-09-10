//
//  Custom Transitions.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 20/08/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

enum ScorecardAnimation {
    case fade
    case fromLeft
    case fromRight
    case fromTop
    case toTop
}

class ScorecardAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    let duration: TimeInterval
    let animation: ScorecardAnimation
    let presenting: Bool
    var originFrame = CGRect.zero
    
    init(duration: TimeInterval, animation: ScorecardAnimation, presenting: Bool) {
        self.duration = duration
        self.animation = animation
        self.presenting = presenting
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let containerView = transitionContext.containerView
        if let toViewController = transitionContext.viewController(forKey:.to),
            let fromViewController = transitionContext.viewController(forKey:.from) {
            if let toView = transitionContext.view(forKey: .to) ?? toViewController.view,
                var fromView = transitionContext.view(forKey: .from) ?? fromViewController.view {
                
                if let rootViewController = fromViewController as? PanelContainer {
                    if let dismissImageView = rootViewController.dismissImageView {
                        fromView = dismissImageView
                    }
                }
                
                // Avoid layout bug if rotated since last shown
                let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
                toView.frame = transitionContext.finalFrame(for: toViewController)
                
                containerView.addSubview(toView)
                
                switch self.animation {
                case .fade:
                    toView.alpha = 0.0
                    UIView.animate(
                        withDuration: duration,
                        animations: {
                            toView.alpha = 1.0
                    },
                        completion: { _ in
                            transitionContext.completeTransition(true)
                    })
                    
                case .fromLeft:
                    let frame = fromView.frame
                    toView.frame = CGRect(x: -frame.width, y: 0.0, width: frame.width, height: frame.height)
                    toView.clipsToBounds = true
                    UIView.animate(
                        withDuration: duration,
                        animations: {
                            toView.frame = frame
                            fromView.frame = CGRect(x: frame.width, y: 0.0, width: frame.width, height: frame.height)
                    },
                        completion: { _ in
                            transitionContext.completeTransition(true)
                    })
                    
                case .fromRight:
                    let frame = fromView.frame
                    toView.frame = CGRect(x: frame.width, y: 0.0, width: frame.width, height: frame.height)
                    UIView.animate(
                        withDuration: duration,
                        animations: {
                            toView.frame = frame
                            fromView.frame = CGRect(x: -frame.width, y: 0.0, width: frame.width, height: frame.height)
                    },
                        completion: { _ in
                            transitionContext.completeTransition(true)
                    })
                case .fromTop:
                    let frame = fromView.frame
                    toView.frame = CGRect(x: 0.0, y: -frame.height, width: frame.width, height: frame.height)
                    UIView.animate(
                        withDuration: duration,
                        animations: {
                            toView.frame = frame
                    },
                        completion: { _ in
                            transitionContext.completeTransition(true)
                    })
                case .toTop:
                    let frame = fromView.frame
                    toView.frame = frame
                    fromView.superview?.bringSubviewToFront(fromView)
                    UIView.animate(
                        withDuration: duration,
                        animations: {
                            fromView.frame = CGRect(x: 0.0, y: -frame.height, width: frame.width, height: frame.height)
                    },
                        completion: { _ in
                            transitionContext.completeTransition(true)
                    })
                }
            }
        }
    }
}

