//
//  ClientViewControllerPanels.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 20/08/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

struct PanelContainerItem {
    let viewController: ScorecardViewController
    let container: Container
}

protocol PanelContainer {
    
    var dismissImageView: UIImageView! {get set}
    var viewControllerStack: [(uniqueID: String, viewController: ScorecardViewController)] {get set}

    var containers: Bool {get}
    
    func presentInContainers(_ items: [PanelContainerItem], rightPanelTitle: String?, animated: Bool, completion: (() -> ())?)
        
    @discardableResult func invokeOption(_ option: MenuOption, completion: (()->())?) -> ScorecardViewController?
    
    func rightPanelDefaultScreenColors()
    
    func selectAvailableDevice(deviceName: String)
}

extension PanelContainer {
    func presentInContainers(_ items: [PanelContainerItem], animated: Bool, completion: (() -> ())?) {
        presentInContainers(items, rightPanelTitle: nil, animated: animated, completion: completion)
    }
}

extension ClientViewController : PanelContainer {
    
    internal func allocateContainerSizes() {
        repeat {
            self.containers = true
            if !ScorecardUI.phoneSize() && self.leftPanelWidthConstraint != nil && self.rightPanelWidthConstraint != nil {
                if self.view.frame.width >= 1000 {
                    // Room for all 3
                    self.leftPanelWidthConstraint.constant = ScorecardUI.screenWidth * 0.32
                    self.rightPanelWidthConstraint.constant =  ScorecardUI.screenWidth * 0.3
                    break
                }
                if self.view.frame.width >= 750 {
                    // Room for 2
                    self.leftPanelWidthConstraint.constant =  ScorecardUI.screenWidth * 0.4
                    self.rightPanelWidthConstraint.constant = 0
                    break
                }
            }
            // Just 1
            self.containers = false
            self.leftPanelWidthConstraint?.constant = 0
            self.rightPanelWidthConstraint?.constant = 0
            
        } while false
        
        self.leftContainer?.setNeedsLayout()
        self.rightContainer?.setNeedsLayout()
    }
    
    internal func rightPanelDefaultScreenColors() {
        self.rightPanel.backgroundColor = Palette.banner.background
        self.rightPanelTitleLabel.textColor = Palette.banner.text
        self.rightPanelCaptionLabel.textColor = Palette.banner.text
    }
        
    public func invokeOption(_ option: MenuOption, completion: (()->())?) -> ScorecardViewController? {
        var viewController: ScorecardViewController?
        
        switch option {
        case .settings:
            viewController = self.showSettings(presentCompletion: completion)
            
        case .changePlayer:
            self.showPlayerSelection(completion: completion)
            
        case .cancelChangePlayer:
            self.hidePlayerSelection(completion: completion)
            
        default:
            break
        }
        
        return viewController
    }
    
    public func presentInContainers(_ items: [PanelContainerItem], rightPanelTitle: String? = nil, animated: Bool, completion: (() -> ())?) {
        if let rootViewController = self.rootViewController, let rootView = self.view {
            var containerView: UIView?
            var animateViews: [UIView] = []
            if let title = rightPanelTitle {
                self.setRightPanel(title: title, caption: "")
            }
            for item in items {
                Utility.debugMessage("Client", "Show \(item.viewController.className)")
                let container = item.container
                let viewController = item.viewController
                viewController.rootViewController = self.rootViewController
                viewController.menuController = self.rootViewController.menuController
                viewController.container = container
                let view = viewController.view!
                switch container {
                case .left:
                    containerView = self.leftContainer
                case .right:
                    containerView = self.rightContainer
                case .mainRight:
                    containerView = self.mainRightContainer
                default:
                    containerView = self.mainContainer
                }
                if let containerView = containerView {
                    // Got a container - add view controller / view to container
                    rootViewController.addChild(viewController)
                    viewController.didMove(toParent: rootViewController)
                    rootView.addSubview(view)
                    rootView.bringSubviewToFront(view)
                    
                    // Position view
                    view.frame = rootView.convert(containerView.frame, to: rootView)
                    view.translatesAutoresizingMaskIntoConstraints = false
                    Constraint.anchor(view: rootView, control: containerView, to: view)
                    if container == .right {
                        view.roundCorners(cornerRadius: 12.0)
                    }
                    if animated {
                        view.alpha = 0.0
                        animateViews.append(view)
                    }
                    if container == .main || container == .mainRight {
                        // Add to controller stack
                        self.rootViewController?.viewControllerStack.append((viewController.uniqueID, viewController))
                    }
                }
            }
            if animated {
                // Need to animate - just dissolve for now
                Utility.animate(duration: 0.5,
                    completion: {
                        self.presentInContainersCompletion(completion: completion)
                    },
                    animations: {
                        animateViews.forEach{ (view) in view.alpha = 1.0 }
                })
            } else {
                self.presentInContainersCompletion(completion: completion)
            }
        }
    }
    
    private func presentInContainersCompletion(completion: (() -> ())?) {
        self.hideDismissImageView()
        completion?()
    }
    
    internal func selectAvailableDevice(deviceName: String) {
        // Connect to a particular device based on click-through of notification
        self.selectAvailable(deviceName: deviceName)
    }
}
