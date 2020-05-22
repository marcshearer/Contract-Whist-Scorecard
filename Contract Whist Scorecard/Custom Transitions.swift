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
        if let toView = transitionContext.view(forKey: .to) ?? transitionContext.viewController(forKey:.to)?.view,
            let fromView = transitionContext.view(forKey: .from) ?? transitionContext.viewController(forKey:.from)?.view{
        
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
            }
        }
    }
}

