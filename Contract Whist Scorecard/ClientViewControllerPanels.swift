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
    
    func visible(container: Container) -> Bool
    
    func panelLayoutSubviews()
    
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
    
    internal func panelLayoutSubviews() {
        let menuVisible = self.menuController?.isVisible ?? false
        self.topSection.isHidden = menuVisible
        self.bottomSection.isHidden = menuVisible
        
        // Set all menu-dependent constraints to inactive
        Constraint.setActive(self.menuHeightConstraints, to: false)
        Constraint.setActive(self.noMenuHeightConstraints, to: false)
        
        // Now activate dependent on manu visisble
        if menuVisible {
            Constraint.setActive(self.menuHeightConstraints, to: true)
        } else {
            Constraint.setActive(self.noMenuHeightConstraints, to: !ScorecardUI.landscapePhone())
        }
        
        // Set variable constraints
        self.topSectionTopConstraint.constant = (menuVisible ? 40 : 0)
        self.hostCollectionContainerInsets.forEach{(constraint) in constraint.constant = (menuVisible ? 40 : 20)}
        self.peerTitleBarTopConstraint.constant = (menuVisible ? 20 : 8)
        
        // Set colors
        self.banner.set(backgroundColor: (menuVisible ? Palette.dark : self.defaultBannerColor))
        self.hostCollectionView.backgroundColor = (menuVisible ? UIColor.clear : Palette.buttonFace.background)
        
        // Set shadows and flow layouts
        if menuVisible {
            self.hostCollectionContainerView.removeShadow()
            self.hostCollectionView.setCollectionViewLayout(self.centeredFlowLayout, animated: false)
            self.centeredFlowLayout.invalidateLayout()
        } else {
            self.hostCollectionContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0), shadowOpacity: 0.1, shadowRadius: 2.0)
            self.hostCollectionView.setCollectionViewLayout(self.hostCollectionViewLayout, animated: false)
            self.hostCollectionViewLayout.invalidateLayout()
        }
        
        // Show / hide controls
        self.hostTitleBar.set(transparent: menuVisible, alignment: .center)
        self.peerTitleBar.set(transparent: menuVisible, alignment: .center)
        self.infoButton.isHidden = menuVisible
        
        // Setup behaviour for hosts collection view
        self.hostsAcross = (menuVisible ? 2 : 3)
        self.hostsDown = (menuVisible ? 2 : 1)
        self.hostVerticalSpacing = (menuVisible ? 20 : 0)
        self.hostHorizontalSpacing = (menuVisible ? 12 : 0) // Allows for spacing in cell around button
        self.hostRoundedContainer = !menuVisible
    }
    
    internal func allocateContainerSizes() {
        // Idea is to have all 3 containers available, but sometimes offscreen if on an iPad
        repeat {
            self.containers = true
            if !ScorecardUI.phoneSize() && self.leftPanelWidthConstraint != nil && self.rightPanelWidthConstraint != nil {
                if self.view.frame.width >= 1000 {
                    // Room for all 3
                    let leftWidth = self.view.frame.width * 0.29
                    let rightWidth = self.view.frame.width * 0.32
                    self.leftPanelTrailingConstraint.constant = leftWidth
                    self.leftPanelWidthConstraint.constant = leftWidth
                    self.rightPanelLeadingConstraint.constant = -rightWidth
                    self.rightPanelWidthConstraint.constant =  rightWidth
                    break
                }
                if self.view.frame.width >= 750 {
                    // Room for 2
                    let leftWidth = self.view.frame.width * 0.4
                    let rightWidth = UIScreen.main.bounds.width * 0.32
                    self.leftPanelTrailingConstraint.constant = leftWidth
                    self.leftPanelWidthConstraint.constant = leftWidth
                    self.rightPanelLeadingConstraint.constant = 0
                    self.rightPanelWidthConstraint.constant =  rightWidth
                    break
                }
            }
            // Just 1
            if self.menuController?.isVisible ?? false {
                // Losing menu - close it cleanly
                self.menuController?.didDisappear()
            }
            
            let leftWidth = self.view.frame.width * 1
            let rightWidth = self.view.frame.width * 1
            self.leftPanelTrailingConstraint.constant = 0
            self.leftPanelWidthConstraint.constant = leftWidth
            self.rightPanelLeadingConstraint.constant = 0
            self.rightPanelWidthConstraint.constant =  rightWidth
            if ScorecardUI.phoneSize() {
                // Looks like we're on a phone - no containers
                self.containers = false
            }
        } while false
        
        self.container = (self.containers ? .main : .none)
        
        self.leftContainer?.setNeedsLayout()
        self.rightContainer?.setNeedsLayout()
        self.rightInsetContainer?.setNeedsLayout()
    }
    
    internal func visible(container: Container) -> Bool {
        if !self.containers {
            return false
        } else {
            switch container {
            case .left:
                return self.leftPanelTrailingConstraint.constant > 0
            case .main:
                return true
            case .right, .rightInset, .mainRight:
                return self.rightPanelLeadingConstraint.constant < 0
            }
        }
    }
    
    internal func rightPanelDefaultScreenColors() {
        self.rightContainer.backgroundColor = Palette.banner.background
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
                case .rightInset:
                    containerView = self.rightInsetContainer
                case .mainRight:
                    containerView = self.mainRightContainer
                default:
                    containerView = self.mainContainer
                }
                if let containerView = containerView {
                    // Got a container - add view controller / view to container
                    rootViewController.addChild(viewController)
                    view.frame = rootView.convert(containerView.frame, to: rootView)
                    rootView.addSubview(view)
                    viewController.didMove(toParent: rootViewController)
                    rootView.bringSubviewToFront(view)
                    
                    // Add layout constraints
                    view.translatesAutoresizingMaskIntoConstraints = false
                    Constraint.anchor(view: rootView, control: containerView, to: view)
                    if container == .rightInset {
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
                Utility.animate(duration: 0.25,
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
