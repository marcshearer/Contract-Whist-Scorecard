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
    
    var dismissSnapshotStack: [UIView] {get set}
    var viewControllerStack: [(uniqueID: String, viewController: ScorecardViewController)] {get set}
    var containers: Bool {get}
    var detailDelegate: DetailDelegate? {get set}
    
    func isVisible(container: Container) -> Bool
    
    func view(container: Container?) -> UIView
    
    func panelLayoutSubviews()
    
    func allocateContainerSizes()
    
    func presentInContainers(_ items: [PanelContainerItem], animation: ViewAnimation, duration: TimeInterval?, completion: (() -> ())?)
        
    @discardableResult func invokeOption(_ option: MenuOption, animation: ViewAnimation, completion: (()->())?) -> ScorecardViewController?
    
    func selectAvailableDevice(deviceName: String)
    
    func panelhelpPressed(alwaysNext: Bool, completion: ((Bool)->())?)
    
    func setNoSettingsRestart()
    
    func showLastGame()
}

extension PanelContainer {
    func presentInContainers(_ items: [PanelContainerItem], animation: ViewAnimation, completion: (() -> ())?) {
        presentInContainers(items, animation: animation, duration: nil, completion: completion)
    }
        
    func invokeOption(_ option: MenuOption, completion: (()->())?) -> ScorecardViewController? {
        invokeOption(option, animation: .none, completion: completion)
    }
}

protocol DetailDelegate {
    
    var isVisible: Bool {get}
    var detailView: UIView {get}
    var helpView: HelpView! {get}

    func helpPressed(alwaysNext: Bool, completion: ((Bool)->())?)

}

extension ClientViewController : PanelContainer {
    
    internal func panelLayoutSubviews() {
        
        self.rightPanelLayoutSubviews()
        
        let menuVisible = self.menuController?.isVisible ?? false
        self.topSection.isHidden = menuVisible
        self.thisPlayerThumbnail.isHidden = menuVisible
        self.bottomSection.isHidden = menuVisible
        self.actionButtons.forEach{ (button) in button.isHidden = menuVisible }
        
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
        self.helpButton.isHidden = menuVisible
        
        // Setup behaviour for hosts collection view
        self.hostsAcross = (menuVisible ? 2 : 3)
        self.hostsDown = (menuVisible ? 2 : 1)
        self.hostVerticalSpacing = (menuVisible ? 20 : 0)
        self.hostHorizontalSpacing = (menuVisible ? 12 : 0) // Allows for spacing in cell around button
        self.hostRoundedContainer = !menuVisible
    }
    
    internal func allocateContainerSizes() {
        // Idea is to have all 3 containers available, but sometimes offscreen if on an iPad
        self.containers = true
        let menuWasVisible = self.menuController?.isVisible ?? false
        let canAddMenu = (self.gameMode != .none || self.viewControllerStack.isEmpty || menuWasVisible)
        let rightPanelWasVisible = self.isVisible(container: .right)

        repeat {
            if canAddMenu && !ScorecardUI.phoneSize() && self.leftPanelWidthConstraint != nil && self.rightPanelWidthConstraint != nil {
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
        
        let menuIsVisible = self.menuController?.isVisible ?? false
        if menuIsVisible != menuWasVisible {
            if !menuIsVisible {
                // Losing menu - close it cleanly
                self.menuController?.menuDidDisappear()
            } else  {
                // Menu becoming visible - reset
                self.menuController?.reset()
            }
        }
        if rightPanelWasVisible && !self.isVisible(container: .right) {
            // Losing right panel - close it cleanly
            self.menuController?.rightPanelDidDisappear(completion: nil)
        }
        
        self.container = (self.containers ? .main : .none)
        
        self.leftContainer?.setNeedsLayout()
        self.rightContainer?.setNeedsLayout()
    }
    
    internal func isVisible(container: Container) -> Bool {
        if !self.containers {
            return false
        } else {
            switch container {
            case .left:
                return self.leftPanelTrailingConstraint.constant > 0
            case .main:
                return true
            case .right, .mainRight:
                return self.rightPanelLeadingConstraint.constant < 0
            }
        }
    }
    
    internal func view(container: Container?) -> UIView {
        var containerView: UIView
        switch container {
        case .left:
            containerView = self.leftContainer
        case .right:
            containerView = self.rightContainer
         case .mainRight:
            containerView = self.mainRightContainer
        case .main:
            containerView = self.mainContainer
        default:
            containerView = self.view
        }
        return containerView
    }
    
    internal func frame(container: Container) -> CGRect {
        let view = self.view(container: container)
        return view.frame
    }
    
    internal func rightPanelDefaultScreenColors() {
        self.rightContainer.backgroundColor = Palette.banner.background
        self.rightPanelTitleLabel.textColor = Palette.banner.text
        self.rightPanelCaptionLabel.textColor = Palette.banner.text
    }
        
    public func invokeOption(_ option: MenuOption, animation: ViewAnimation, completion: (()->())?) -> ScorecardViewController? {
        var viewController: ScorecardViewController?
        
        switch option {
        case .settings:
            viewController = self.showSettings(animation: animation, presentCompletion: completion)
            
        case .changePlayer:
            self.showPlayerSelection(completion: completion)
            
        case .cancelChangePlayer:
            self.hidePlayerSelection(completion: completion)
            
        default:
            break
        }
        
        return viewController
    }
    
    public func presentInContainers(_ items: [PanelContainerItem], animation: ViewAnimation = .fade, duration: TimeInterval? = nil, completion: (() -> ())?) {
        if let rootViewController = self.rootViewController, let rootView = self.view {
            let duration = duration ?? 0.5
            var animateViews: [(view: UIView, container: Container, frame: CGRect)] = []
            
            let animateRightPanel = (animation.leftMovement || animation.rightMovement) && animation.newEnters && self.isVisible(container: .right)
            for item in items {
                Utility.debugMessage("Client", "Show \(item.viewController.className)")
                let container = item.container
                let viewController = item.viewController
                viewController.rootViewController = self.rootViewController
                viewController.menuController = self.rootViewController.menuController
                viewController.container = container
                if let view = viewController.view {
                    let containerView = self.view(container: container)
                    // Got a container - add view controller / view to container
                    rootViewController.addChild(viewController)
                    view.frame = containerView.superview!.convert(containerView.frame, to: rootView)
                    rootView.addSubview(view)
                    viewController.didMove(toParent: rootViewController)
                    rootView.bringSubviewToFront(view)
                    
                    animateViews.append((view, container, view.frame))
                    if container == .main || container == .mainRight {
                        // Add to controller stack
                        self.rootViewController?.viewControllerStack.append((viewController.uniqueID, viewController))
                    }
                }
            }
            
            // Need to animate - position new views to right
            let rightPanelLeading = self.rightPanelLeadingConstraint.constant
            if animateRightPanel {
                self.rightPanelLeadingConstraint.constant += animation.offset(by: self.mainRightContainer.frame.size).x
            }
            
            var oldViews: [UIView] = []
            if let snapshot = self.rootViewController.dismissSnapshotStack.last {
                if let snapshotClippingView = snapshot.superview {
                    if snapshotClippingView != rootView {
                        // Bring clipping view to front if necessary
                        if animation.oldLeaves {
                            rootView.bringSubviewToFront(snapshotClippingView)
                        }
                    }
                }
                oldViews.append(snapshot)
            }
            
            rootView.bringSubviewToFront(self.menuPanelViewController.view)
            ViewAnimator.animate(rootView: rootView, clippingView: self.mainRightContainer, oldViews: oldViews, newViews: animateViews.map{$0.view}, animation: animation, duration: duration, layout: animateRightPanel,
                additionalAnimations: {
                    if animateRightPanel {
                        self.rightPanelLeadingConstraint.constant = rightPanelLeading
                    }
                },
                completion: {
                    self.presentInContainersCompletion(completion: completion)
                    animateViews.forEach { (viewElement) in
                        // Add constraints
                        let containerView = self.view(container: viewElement.container)
                        viewElement.view.translatesAutoresizingMaskIntoConstraints = false
                        Constraint.anchor(view: rootView, control: containerView, to: viewElement.view)
                    }
                }
            )
        }
    }
    
    private func presentInContainersCompletion(completion: (() -> ())?) {
        self.hideDismissSnapshot()
        completion?()
    }
    
    internal func selectAvailableDevice(deviceName: String) {
        // Connect to a particular device based on click-through of notification
        self.selectAvailable(deviceName: deviceName)
    }
    
    internal func setNoSettingsRestart() {
        self.noSettingsRestart = true
    }
    
    internal func panelhelpPressed(alwaysNext: Bool, completion: ((Bool)->())?) {
        let stack = self.viewControllerStack
        if stack.isEmpty {
            // Nothing displayed - call my own help function
            self.helpView.show(alwaysNext: alwaysNext, completion: completion)
        } else {
            // Work back up the view controller stack until you find something in the main window
            var mainViewController: ScorecardViewController?
            for element in stack.reversed() {
                if let container = element.viewController.container {
                    if container == .main || container == .mainRight {
                        mainViewController = element.viewController
                        break
                    }
                }
            }
            if let helpView = mainViewController?.helpView, let mainView = mainViewController?.view {
                
                let delegate = mainViewController?.rootViewController.detailDelegate
                let delegateHelp = (delegate?.detailView.superview != nil && !(delegate?.helpView?.isEmpty ?? true))
                
                // Show the main panel screen help
                mainView.superview!.bringSubviewToFront(mainView)
                helpView.show(alwaysNext: alwaysNext || delegateHelp) { (finishPressed) in
                   
                    if !finishPressed && delegateHelp {
                   
                        // Need to keep the previous helpView around to stop click throughs
                        helpView.isHidden = false
                        
                        // Now show any help for the detail panel
                        delegate!.detailView.superview!.bringSubviewToFront(delegate!.detailView)
                        delegate!.helpPressed(alwaysNext: alwaysNext) { (finishPressed) in
                            mainView.superview!.bringSubviewToFront(mainView)
                            helpView.isHidden = true
                            completion?(finishPressed)
                        }
                    } else {
                        completion?(finishPressed)
                    }
                }
            } else {
                completion?(false)
            }
        }
    }
}
