//
//  Custom Transitions.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 20/08/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class FadeAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    let duration = 0.5
    var presenting = true
    var originFrame = CGRect.zero
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let containerView = transitionContext.containerView
        if let toView = transitionContext.view(forKey: .to) ?? transitionContext.viewController(forKey:.from)?.view {
        
            // Avoid layout bug if rotated since last shown
            let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
            toView.frame = transitionContext.finalFrame(for: toViewController)
            
            containerView.addSubview(toView)
            toView.alpha = 0.0
            UIView.animate(
                withDuration: duration,
                animations: {
                    toView.alpha = 1.0
            },
                completion: { _ in
                    transitionContext.completeTransition(true)
            })
        }
    }
}

