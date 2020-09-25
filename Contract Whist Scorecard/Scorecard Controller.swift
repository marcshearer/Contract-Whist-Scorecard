//
//  Scorecard Controller.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation
import UIKit

enum ScorecardView {
    // Main views
    case selection
    case gamePreview
    case scorepad
    case gameSummary
    case location
    case hand
    case nextHand

    // Sub views which are invoked from main views
    case confirmPlayed
    case selectPlayers
    case overrideSettings
    case roundSummary
    case review
    case entry
    case highScores

    // Special views
    case exit
    case dismiss
    case processing
    case none
}

enum DismissAction {
    case none
    case proceed
    case cancel
}

enum ControllerType {
    case host
    case client
    case scoring
}

protocol ScorecardAppControllerDelegate : class {
    
    var controllerType: ControllerType { get }
    
    var canProceed: Bool { get }
    var canCancel: Bool { get }
    
    func didLoad()
    
    func didAppear()
    
    func didCancel(context: [String: Any]?)
    
    func didInvoke(_ invokedView: ScorecardView, context: [String:Any?]?, completion: (([String:Any?]?)->())?)
    
    func didProceed(context: [String: Any]?)
        
    func lock(_ active: Bool)
    
    func robotAction(playerNumber: Int!, action: RobotAction)
    
    func set(noHideDismissImageView: Bool)
}

extension ScorecardAppControllerDelegate {
    
    func robotAction(action: RobotAction) {
        robotAction(playerNumber: nil, action: action)
    }
    
    func didCancel() {
        didCancel(context: nil)
    }
}

extension ScorecardAppControllerDelegate {
    
    func didProceed() {
        didProceed(context: nil)
    }
    
    func didInvoke(_ invokedView: ScorecardView) {
        didInvoke(invokedView, context: nil, completion: nil)
    }
    
    func didInvoke(_ invokedView: ScorecardView, context: [String:Any?]?) {
        didInvoke(invokedView, context: context, completion: nil)
    }
    
    func didInvoke(_ invokedView: ScorecardView, completion: (([String:Any?]?)->())?) {
         didInvoke(invokedView, context: nil, completion: completion)
    }

}

public protocol ScorecardAppPlayerDelegate {
    
    // Can be implemented by server controllers to allow them to override the players to be sent to remotes
    
    func currentPlayers() -> [(playerUUID: String, name: String, connected: Bool)]?
    
}

public struct ScorecardAppQueue {
    let descriptor: String
    let data: [String : Any?]?
    var peer: CommsPeer?
}

class ScorecardAppController : CommsDataDelegate, ScorecardAppControllerDelegate {

    internal var activeViewController: ScorecardViewController?
    internal weak var parentViewController: ScorecardViewController!
    internal var _controllerType: ControllerType
    private static var references: [ControllerType:Int] = [:]
    private static var totalReferences = 0
    internal var activeView: ScorecardView = .none
    internal var lastView: ScorecardView = .none
    internal var viewLocked: Bool = false
    internal var queue: [ScorecardAppQueue] = []
    private var clientHandlerObserver: NSObjectProtocol?
    internal var uuid: String
    fileprivate var noHideDismissImageView: Bool = false
    fileprivate var invokedViews: [(view: ScorecardView, viewController: ScorecardViewController?, uuid: String)] = []
    private var whisper: [String : Whisper] = [:]
    private var gameDetailPanelViewController: GameDetailPanelViewController!
    internal var gameDetailDelegate: GameDetailDelegate?
    
    // Properties for shared methods (client and server)
    internal weak var scorepadViewController: ScorepadViewController!
    internal weak var roundSummaryViewController: RoundSummaryViewController!
    
    public var controllerType: ControllerType { self._controllerType }
    
    init(from parentViewController: ScorecardViewController, type: ControllerType) {
        
        if Utility.isDevelopment {
            if (ScorecardAppController.references[type] ?? 0) != 0 {
                Utility.debugMessage("Controller", "Multiple instances of \(type) controllers")
                parentViewController.alertSound(sound: .alarm)
            }
        }
        
        self.parentViewController = parentViewController
        self._controllerType = type
        self.uuid=UUID().uuidString.right(4)
        ScorecardAppController.references[self.controllerType] = (ScorecardAppController.references[self.controllerType] ?? 0) + 1
        ScorecardAppController.totalReferences += 1
        Utility.debugMessage("appController \(self.uuid)", "Init \(debugReference)")
    }
    
    internal func start() {
        Utility.debugMessage("appController \(self.uuid)", "Start \(debugReference)")
    }
    
    internal func stop() {
        Utility.debugMessage("appController \(self.uuid)", "Stop \(debugReference)")
        clearViewPresentingCompleteNotification(observer: clientHandlerObserver)
        if !noHideDismissImageView {
            self.parentViewController.hideDismissImageView(animated: false)
        }
        clientHandlerObserver = nil
    }
    
    deinit {
        Utility.debugMessage("appController \(self.uuid)", "Deinit \(debugReference)")
        ScorecardAppController.references[self.controllerType] = (ScorecardAppController.references[self.controllerType] ?? 0) - 1
        ScorecardAppController.totalReferences -= 1
    }
    
    private var debugReference: String {
        get {
            return "\(controllerType)(\(ScorecardAppController.references[controllerType]!)/\(ScorecardAppController.totalReferences)) \(self.uuid)"
        }
    }
    
    internal func present(nextView: ScorecardView, willDismiss: Bool = true, context: [String:Any?]? = nil) {
    
        Scorecard.shared.useGameColor = (nextView != .none && nextView != .exit)
        Scorecard.shared.trueUseGameColor = Scorecard.shared.useGameColor
        
        if nextView == self.activeView {
            // Already displaying - just refresh
            Utility.debugMessage("appController \(self.uuid)", "Refreshing view \(self.activeView)")
             
            if self.activeViewController == nil {
                self.activeView = .none
            } else {
                self.refreshView(view: nextView)
            }
            
            if Scorecard.shared.viewPresenting == .processing {
                Scorecard.shared.viewPresenting = .none
            }
            self.appControllerCompletion()
            
        } else {
            // New view - dismiss previous view controller
            if let activeViewController = activeViewController {
                Utility.debugMessage("appController \(self.uuid)", "Dismissing view \(self.activeView)")
                Scorecard.shared.viewPresenting = .dismiss
                
                var animated = true
                if nextView != .exit && nextView != .none {
                    // Dismissing this view to present another but want it to look like new view is presenting (animated) on top of this one
                    // Put up a screenshot of this view behind it on the parent, dismiss this one without animation, and then when next view is visible
                    // remove the screenshot from behind it
                    self.parentViewController.createDismissImageView()
                    self.parentViewController.dismissView = self.activeView
                    animated = false
                }
                if willDismiss {
                    self.activeViewController?.willDismiss()
                }
                activeViewController.dismiss(animated: animated) {
                    self.didDismissView(view: self.activeView, viewController: self.activeViewController)
                    activeViewController.controllerDelegate = nil
                    self.activeViewController = nil
                    Scorecard.shared.viewPresenting = .processing
                    
                    if nextView == .exit && self.gameDetailPanelViewController != nil {
                        // Remove game detail as exiting
                        self.gameDetailPanelViewController.dismiss(animated: animated) {
                            self.gameDetailPanelViewController = nil
                            self.gameDetailDelegate = nil
                            self.nextView(view: nextView, context: context)
                        }
                    } else {
                        self.nextView(view: nextView, context: context)
                    }
                }
            } else {
                self.nextView(view: nextView, context: context)
            }
        }
    }
    
    internal func presentControllerView(view: ScorecardView, context: [String:Any?]? = nil, completion: (([String:Any?]?)->())? = nil) -> ScorecardViewController? {
        // Wrapper for controllers present view
        
        // Call any generic actions before present
        
        // Now call controller present view
        let viewController = self.presentView(view: view, context: context) { (completionContext) in
            // Call any generic actions before completion
            
            // Completion after view presented - note not always called
            completion?(completionContext)
        }
        
        // Call any generic actions after present initiated

        // Refesh game detail if present
        self.gameDetailDelegate?.refresh(activeView: view)
        
        return viewController
    }
    
    internal func didInvoke(_ invokedView: ScorecardView, context: [String:Any?]? = nil, completion: (([String:Any?]?)->())? = nil) {
        // Lock network and other views
        self.lock(true)
        Scorecard.shared.viewPresenting = invokedView
        self.invokedViews.append((view: invokedView, viewController: nil, uuid: UUID().uuidString))
        let invokedViewController = self.presentControllerView(view: invokedView, context: context, completion: completion)
        invokedViews[invokedViews.count - 1].viewController = invokedViewController
    }
    
    internal func set(noHideDismissImageView: Bool) {
        self.noHideDismissImageView = noHideDismissImageView
    }

    private func nextView(view nextView: ScorecardView, context: [String:Any?]? = nil) {
        
        // Wait for any popup or lock to disappear
        if parentViewController.presentedViewController != nil  || self.viewLocked ||
            (Scorecard.shared.viewPresenting != .none  && Scorecard.shared.viewPresenting != .processing) {
            Utility.executeAfter(delay: 1.0) { [weak self] in
                self?.nextView(view: nextView)
            }
        } else {
            Utility.debugMessage("appController \(self.uuid)", "Presenting view \(nextView)")
            
            self.lastView = self.activeView
            self.activeView = nextView
            Scorecard.shared.viewPresenting = nextView
            
            if self.activeView != .none {
                self.activeViewController = self.presentControllerView(view: self.activeView, context: context)
            }
            
            if self.activeView == .exit || self.activeView == .none || self.activeViewController == nil {
                Scorecard.shared.viewPresenting = .none
                self.activeView = .none
            }
                           
            self.appControllerCompletion()
        }
    }
    
    internal func appControllerCompletion() {
        self.processQueue()
    }
    
    public func lock(_ active: Bool) {
        self.viewLocked = active
        if !self.viewLocked {
            // Catch up on anything that happened whilst locked
            self.appControllerCompletion()
        }
    }

    internal func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        Utility.mainThread {
            self.queue.append(ScorecardAppQueue(descriptor: descriptor, data: data, peer: peer))
            let alertShowing = self.activeViewController?.presentedViewController
            if alertShowing != nil || self.viewLocked || Scorecard.shared.viewPresenting != .none {
                Utility.debugMessage("appController \(self.uuid)", "View presenting causing queueing (\(alertShowing != nil ? "Alert" : "NoAlert")-\(self.viewLocked ? "locked" : "notLocked")-\(Scorecard.shared.viewPresenting))")
            }
            self.processQueue()
        }
    }
    
    internal func processQueue() {
        
        Utility.mainThread {
            var queueText = ""
            for element in self.queue {
                queueText = queueText + " " + element.descriptor
            }
            
            while self.queue.count > 0 && self.activeViewController?.presentedViewController == nil && !self.viewLocked &&
            Scorecard.shared.viewPresenting == .none {
                
                Scorecard.shared.viewPresenting = .processing
                
                // Pop top element off the queue
                let descriptor = self.queue.first!.descriptor
                let data = self.queue.first!.data
                let peer = self.queue.first!.peer!
                self.queue.removeFirst()
                
                Utility.debugMessage("appController \(self.uuid)", "Processing \(descriptor)")
                
                let stopProcessing = self.processQueue(descriptor: descriptor, data: data, peer: peer)
                
                if stopProcessing {
                    break
                }
                
                Scorecard.shared.viewPresenting = .none
                
            }
        }
    }
    
    internal func addQueue(descriptor: String, data: [String:Any?]?, peer: CommsPeer?) {
        self.queue.insert(ScorecardAppQueue(descriptor: descriptor, data: data, peer: peer), at: 0)
    }
    
    // MARK: - Default shared methods (for client & server)========================================== -
    
    internal func showLocation() -> LocationViewController? {
        var locationViewController: LocationViewController?
        
        if let parentViewController = self.fromViewController() {
            locationViewController = LocationViewController.show(from: parentViewController, appController: self, gameLocation: Scorecard.game.location, useCurrentLocation: true, mustChange: false, bannerColor: Palette.banner)
        }
        return locationViewController
    }
    
    internal func showScorepad(scorepadMode: ScorepadMode) -> ScorecardViewController? {
        let existingViewController = self.scorepadViewController != nil
        
        if let parentViewController = self.fromViewController() {
            self.scorepadViewController = ScorepadViewController.show(from: parentViewController, appController: self, existing: self.scorepadViewController, scorepadMode: scorepadMode)
            if existingViewController {
                self.scorepadViewController.reloadScorepad()
            }
        }
        return self.scorepadViewController
    }
    
    internal func showRoundSummary() -> ScorecardViewController? {
        
        if let parentViewController = self.fromViewController() {
            self.roundSummaryViewController = RoundSummaryViewController.show(from: parentViewController, appController: self, existing: roundSummaryViewController)
        }
        return self.roundSummaryViewController
    }
    
    internal func showGameSummary(mode: ScorepadMode) -> ScorecardViewController? {
        var gameSummaryViewController: GameSummaryViewController?
        
        // Avoid resuming once game summary shown
        Scorecard.game.setGameInProgress(false)
        Scorecard.recovery = Recovery(load: false)
        
        if let parentViewController = self.fromViewController() {
            gameSummaryViewController = GameSummaryViewController.show(from: parentViewController, appController: self, gameSummaryMode: mode)
        }
        return gameSummaryViewController
    }
    
    internal func showSelectPlayers(completion: (([String:Any?]?)->())?) -> SelectPlayersViewController? {
        var selectPlayerViewController: SelectPlayersViewController?
        
        if let parentViewController = self.fromViewController() {
            selectPlayerViewController = SelectPlayersViewController.show(from: parentViewController, appController: self, completion: { (playerList) in
                    completion?(["playerList" : playerList])
                })
        }
        return selectPlayerViewController
    }
    
    internal func showNextHand(round: Int?) -> NextHandViewController {
        return NextHandViewController.show(from: parentViewController, appController: self, round: round)
    }
    
    internal func showConfirmPlayed(context: [String:Any?]?, completion: (([String:Any?]?)->())?) -> ConfirmPlayedViewController? {
        var confirmPlayedViewController: ConfirmPlayedViewController?
        
        if let parentViewController = self.fromViewController() {
            if let title = context?["title"] as? String,
                let label = context?["label"] as? UIView,
                let sourceView = context?["sourceView"] as? UIView,
                let confirmText = context?["confirmText"] as? String,
                let cancelText = context?["cancelText"] as? String,
                let backgroundColor = context?["backgroundColor"] as? UIColor,
                let bannerColor = context?["bannerColor"] as? UIColor,
                let bannerTextColor = context?["bannerTextColor"] as? UIColor,
                let buttonColor = context?["buttonColor"] as? UIColor,
                let buttonTextColor = context?["buttonTextColor"] as? UIColor,
                let offsets = context?["offsets"] as? (CGFloat?, CGFloat?),
                let titleOffset = context?["titleOffset"] as? CGFloat,
                let contentOffset = context?["contentOffset"] as? CGPoint? {
                
                confirmPlayedViewController = ConfirmPlayedViewController.show(from: parentViewController, appController: self, title: title, content: label, sourceView: sourceView, confirmText: confirmText, cancelText: cancelText, offsets: offsets, titleOffset: titleOffset, contentOffset: contentOffset, backgroundColor: backgroundColor, bannerColor: bannerColor, bannerTextColor: bannerTextColor, buttonColor: buttonColor, buttonTextColor: buttonTextColor,
                    confirmHandler: {
                        completion?(["confirm" : true])
                    },
                    cancelHandler: {
                        completion?(["confirm" : false])
                    })
                    
                    
            }
        }
        return confirmPlayedViewController
    }
    
    internal func showHighScores() -> ScorecardViewController? {
        var highScoresViewController: ScorecardViewController?
        
        if let parentViewController = self.fromViewController() {
            highScoresViewController = DashboardViewController.show(from: parentViewController,
                                                                    dashboardNames: [(title: "High Scores",  fileName: "HighScoresDashboard",  imageName: nil)], allowSync: false, backImage: "cross white", backgroundColor: Palette.banner)
        }
        return highScoresViewController
    }
    
    internal func showReview(round: Int, playerNumber: Int) -> ReviewViewController? {
        var reviewViewController: ReviewViewController?
        
        if let parentViewController = self.fromViewController() {
            reviewViewController = ReviewViewController.show(from: parentViewController, appController: self, round: round, thisPlayer: playerNumber)
        }
        return reviewViewController
    }
    
    internal func showOverrideSettings() -> OverrideViewController? {
        var overrideViewController: OverrideViewController?
        
        if let parentViewController = self.fromViewController() {
            overrideViewController = OverrideViewController.show(from: parentViewController, appController: self)
        }
        return overrideViewController
    }
    
    internal func showGameDetailPanel() {
        if self.gameDetailPanelViewController == nil {
            self.gameDetailPanelViewController = GameDetailPanelViewController.create()
            self.gameDetailPanelViewController.appController = self
            self.parentViewController?.rootViewController.presentInContainers([PanelContainerItem(viewController: gameDetailPanelViewController, container: .right)], animated: true, completion: nil)
            self.gameDetailDelegate = self.gameDetailPanelViewController
        }
    }
    
    internal func hideGameDetailPanel() {
        self.gameDetailPanelViewController.didDismiss()
        self.gameDetailPanelViewController.dismiss(animated: true) {
            self.gameDetailPanelViewController = nil
            self.gameDetailDelegate = nil
        }
    }
    
    // MARK: - Presenting view complete ================================================================== -
    
    fileprivate func setViewPresentingComplete() {
        // Set a notification for handler complete
        // Flag not waiting and then process next entry in the queue
        Scorecard.shared.viewPresenting = .none
        self.appControllerCompletion()
    }
    
    private func clearViewPresentingCompleteNotification(observer: NSObjectProtocol?) {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Properties and Methods to be overridden in sub-classes ================================= -
    
    internal var canProceed: Bool { get { fatalError("Must be overridden") } }
      
    internal var canCancel: Bool { get { fatalError("Must be overridden") } }
      
    internal func refreshView(view: ScorecardView) {
        fatalError("Must be overridden")
    }
    
    internal func presentView(view: ScorecardView, context: [String:Any?]? = nil, completion: (([String:Any?]?)->())? = nil) -> ScorecardViewController? {
        fatalError("Must be overridden")
    }
    
    internal func didDismissView(view: ScorecardView, viewController: ScorecardViewController?) {
        fatalError("Must be overridden")
    }
        
    internal func processQueue(descriptor: String, data: [String:Any?]?, peer: CommsPeer) -> Bool {
        fatalError("Must be overridden")
    }
    
      internal func didLoad() {
        fatalError("Must be overridden")
    }
    
    internal func didAppear() {
        fatalError("Must be overridden")
    }
    
    internal func didCancel(context: [String: Any]?) {
        fatalError("Must be overridden")
    }
    
    internal func didProceed(context: [String : Any]?) {
        fatalError("Must be overridden")
    }
    
    internal func robotAction(playerNumber: Int! = nil, action: RobotAction) {
        // No action in base class
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    internal func showWhisper(_ message: String, hideAfter: TimeInterval? = nil, for context: String = "") {
        if self.whisper[context] == nil {
            self.whisper[context] = Whisper()
        }
        if let from = self.fromViewController(fullScreen: true) {
            self.whisper[context]!.show(message, from: from.view, hideAfter: hideAfter)
        }
    }
    
    internal func hideWhisper(_ message: String? = nil, for context: String = "") {
        self.whisper[context]?.hide(message, afterDelay: 0.5)
    }
    
    internal func fromViewController(fullScreen: Bool = false) -> ScorecardViewController? {
        if self.activeViewController == nil {
            // No active views - show from parent
            return self.parentViewController
        } else if self.invokedViews.last?.viewController == nil {
            // No invoked views - show from active view
            return self.activeViewController
        } else {
            // Already invoked a view - show on last one (which meets size requirements)
            var viewController: ScorecardViewController?
            for invokedView in self.invokedViews {
                if !fullScreen || invokedView.viewController?.view.frame.height == UIScreen.main.bounds.height {
                    viewController = invokedView.viewController
                    break
                }
            }
            return viewController ?? self.activeViewController
        }
    }
}


public enum Container {
    case left
    case main
    case right
    case rightInset
    case mainRight
}

class ScorecardViewController : UIViewController, UIAdaptivePresentationControllerDelegate, UIViewControllerTransitioningDelegate  {
    
    typealias RootViewController = ScorecardViewController & PanelContainer
    
    fileprivate var dismissView = ScorecardView.none
    internal weak var controllerDelegate: ScorecardAppControllerDelegate?
    internal weak var appController: ScorecardAppController?
    private var scorecardView: ScorecardView?
    private var invokedUUID: String?
    internal var launchScreenView: LaunchScreenView?
    internal var container: Container? = .none
    internal var rootViewController: RootViewController!
    internal var menuController: MenuController!
    internal var rightTitleLabel: UILabel!
    internal var rightCaptionLabel: UILabel!
    
    internal var uniqueID: String!
    internal weak var bannerClass: Banner!
    internal var gameDetailDelegate: GameDetailDelegate? { return self.appController?.gameDetailDelegate }

    override func viewDidLoad() {
        super.viewDidLoad()
                        
        self.presentationController?.delegate = self
        self.uniqueID = self.uniqueID ?? UUID().uuidString

        
        Utility.debugMessage(self.className, "didLoad")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !(self.appController?.invokedViews.isEmpty ?? true) && Scorecard.shared.viewPresenting == (self.appController?.invokedViews.last?.view ?? .none) {
            // Invoked view - notify app controller that view display complete
            self.invokedUUID = self.appController?.invokedViews.last?.uuid
            self.appController?.setViewPresentingComplete()
            
        } else if (self.appController?.activeView ?? .none) != .none && Scorecard.shared.viewPresenting == self.appController?.activeView {
            // New active view - notify app controller that view display complete
            self.appController?.setViewPresentingComplete()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        var useGameColor = Scorecard.shared.trueUseGameColor
        if self is RootViewController {
            useGameColor = false
        }
        Palette.forcingGameBanners(to: useGameColor) {
            self.bannerClass?.layoutSubviews()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        Scorecard.shared.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return self.shouldDismiss()
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        self.didDismiss()
    }
    
    internal func shouldDismiss() -> Bool {
        return true
    }
    
    internal func willDismiss() {
        
    }
    
    internal func didDismiss(){
        
    }
        
    // MARK: - View tweaks ========================================================================== -
    
    internal func present(_ viewControllerToPresent: ScorecardViewController, appController: ScorecardAppController? = nil, popoverSize: CGSize? = nil, sourceView: UIView? = nil, sourceRect: CGRect? = nil, popoverDelegate: UIPopoverPresentationControllerDelegate? = nil, animated: Bool, container: Container? = .main, completion: (() -> Void)? = nil) {

        func hideAndComplete() {
            completion?()
        }
        
        // Fill in controller information
        viewControllerToPresent.controllerDelegate = appController
        viewControllerToPresent.appController = appController
        viewControllerToPresent.scorecardView = Scorecard.shared.viewPresenting
        viewControllerToPresent.container = container
        viewControllerToPresent.rootViewController = self.rootViewController
        viewControllerToPresent.menuController = self.rootViewController?.menuController
        viewControllerToPresent.uniqueID = viewControllerToPresent.uniqueID ?? UUID().uuidString
        
        if self.rootViewController?.containers ?? false && (self.container == .main || self.container == .mainRight || self == self.rootViewController) && popoverSize == nil {
            // Working in containers
            self.rootViewController?.presentInContainers([PanelContainerItem(viewController: viewControllerToPresent, container: container!)], animated: true, completion: completion)
            
        } else {
            
            // No luck with container - go ahead and present
            viewControllerToPresent.container = .none
            
            // Add to view stack
            self.rootViewController?.viewControllerStack.append((viewControllerToPresent.uniqueID, viewControllerToPresent))
            
            // Use custom animation
            viewControllerToPresent.transitioningDelegate = self
            
            if popoverSize != nil {
                // Show as popup
                viewControllerToPresent.modalPresentationStyle = UIModalPresentationStyle.popover
                viewControllerToPresent.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
                viewControllerToPresent.preferredContentSize = popoverSize!
                viewControllerToPresent.popoverPresentationController?.sourceView = sourceView
                viewControllerToPresent.popoverPresentationController?.sourceRect = sourceRect ?? CGRect()
                viewControllerToPresent.popoverPresentationController?.delegate = popoverDelegate
                viewControllerToPresent.isModalInPopover = true
                if let delegate = self as? UIPopoverPresentationControllerDelegate {
                    viewControllerToPresent.popoverPresentationController?.delegate = delegate
                }
            } else {
                // Make full screen
                viewControllerToPresent.modalPresentationStyle = .fullScreen
            }
            
            super.present(viewControllerToPresent, animated: animated) {
                // Clean up any screenshot that was used to tidy up the dismiss animation of the previous view presented on this view controller
                self.hideDismissImageView()
                completion?()
            }
        }
    }
    
    internal func createDismissImageView() {
        if var rootViewController = self.rootViewController {
            Utility.debugMessage("Scorecard", "Creating dismiss image view on \(self.className)")
            let dismissImageView = UIImageView(frame: UIScreen.main.bounds)
            rootViewController.view.addSubview(dismissImageView)
            dismissImageView.accessibilityIdentifier = "dismissImageView"
            dismissImageView.image = Utility.screenshot()
            dismissImageView.frame = rootViewController.view.convert(rootViewController.view.frame, to: nil)
            rootViewController.view.bringSubviewToFront(dismissImageView)
            rootViewController.dismissImageViewStack.append(dismissImageView)
            
        }
    }
    
    internal func hideDismissImageView(animated: Bool = false, completion: (()->())? = nil) {
        
        let dismissImageView = self.rootViewController.dismissImageViewStack.last
        
        func hide() {
            if dismissImageView != nil {
                dismissImageView?.removeFromSuperview()
                self.rootViewController?.dismissImageViewStack.removeLast()
            }
            self.rootViewController?.dismissView = .none
            completion?()
        }
        
        if dismissImageView != nil {
            Utility.debugMessage("Scorecard", "Removing dismiss image view")
            if animated {
                dismissImageView?.alpha = 1.0
                Utility.animate(duration: 0.5, completion: {
                    dismissImageView?.alpha = 1.0
                    hide()
                }, animations: {
                    dismissImageView?.alpha = 0.0
                })
            } else {
                hide()
            }
        } else {
            completion?()
        }
    }
    
    override internal func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        self.dismiss(animated: animated, hideDismissImageView: false, completion: completion)
    }
    
    internal func dismiss(animated flag: Bool, hideDismissImageView: Bool, removeSuboptions: Bool = true, completion: (() -> Void)? = nil) {
        // Check if this is an invoked view dismissing and if so pop it and unlock
        
        func popAndComplete() {
            // Look for invoked apps
            if self.invokedUUID != nil && self.appController?.invokedViews.last?.uuid == self.invokedUUID {
                self.appController?.invokedViews.removeLast()
                if self.appController?.invokedViews.isEmpty ?? true {
                    self.appController?.lock(false)
                }
            }
            
            // Look in main view controller stack
            if let stack = self.rootViewController?.viewControllerStack {
                if let thisIndex = stack.firstIndex(where: {$0.uniqueID == self.uniqueID}) {
                    for index in (thisIndex..<stack.count).reversed() {
                        self.rootViewController?.viewControllerStack.remove(at: index)
                    }
                }
                if let viewController = self.rootViewController?.viewControllerStack.last?.viewController {
                    viewController.bannerClass?.restored()
                }
            }
            
            completion?()
        }
        
        Utility.debugMessage("ViewController", "Dismiss \(self.className)")
        if self.container != .none {
            self.willMove(toParent: nil)
            if removeSuboptions {
                self.menuController?.removeSuboptions(for: self.container)
            }
            self.container = .none
            self.view.removeFromSuperview()
            self.removeFromParent()
            if hideDismissImageView {
                self.hideDismissImageView() {
                    popAndComplete()
                }
            } else {
                popAndComplete()
            }
        } else {
            super.dismiss(animated: flag) {
                popAndComplete()
            }
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        get {
            return AppDelegate.applicationPrefersStatusBarHidden ?? true
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
        
    public var className: String {
        let fullName = NSStringFromClass(self.classForCoder)
        var tail = fullName.split(at: ".").last!
        if let viewControllerPos = tail.position("viewController", caseless: true) {
            tail = tail.left(viewControllerPos)
        }
        return tail
    }
    
    // MARK: - Animations ============================================================================== -
    
    internal func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        var duration = 0.25
        var animation: ScorecardAnimation? = nil
        
        if self.dismissView != .none {
            if presented is ScorepadViewController || self.dismissView == .roundSummary || self.dismissView == .gameSummary {
                animation = .fromLeft
                
            } else if self.dismissView == .scorepad || presented is RoundSummaryViewController || presented is GameSummaryViewController {
                animation = .fromRight
                                                
            } else if (presented is SelectionViewController && self.dismissView == .gamePreview) ||
                (presented is GamePreviewViewController && self.dismissView == .selection) {
                duration = 0.5
                animation = .fade
                
            } else {
                return nil
            }
        } else if (presented is SyncViewController) {
            duration = 0.5
            animation = .fromTop
            
        }
        
        if let animation = animation {
            return ScorecardAnimator(duration: duration, animation: animation, presenting: true)
        } else {
            return nil
        }
    }
    
    internal func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
       
        if dismissed is SyncViewController {
            return ScorecardAnimator(duration: 0.5, animation: .toTop, presenting: false)
            
        } else {
            return nil
        }
        
    }
    
    // MARK: - Launch screen ============================================================================ -
    
    internal func showLaunchScreenView(completion: (()->())? = nil) {
        if self.launchScreenView == nil {
            self.launchScreenView = LaunchScreenView(frame: UIScreen.main.bounds)
            self.launchScreenView!.parentViewController = self
            self.view.addSubview(self.launchScreenView!)
            Constraint.anchor(view: self.view, control: self.launchScreenView!)
        }
        self.launchScreenView!.completion = completion
        self.view.alpha = 1
        self.view.bringSubviewToFront(launchScreenView!)
    }
    
    internal func hideLaunchScreen(completion: (()->())? = nil) {
        Utility.animate(duration: 1.0, completion: {
            completion?()
            self.launchScreenView?.removeFromSuperview()
        }, animations: {
            self.launchScreenView?.alpha = 0
        })
    }
    
    // Methods that should be overridden (if called) in sub-classes =============================================== -
    
    internal func backButtonPressed() {
        fatalError("Must be overridden")
    }
    
    // MARK: - Utility routines ======================================================================== -
    
    public func setRightPanel(title: String, caption: String) {
        self.rootViewController?.rightTitleLabel?.text = title
        self.rootViewController?.rightCaptionLabel.text = caption
    }
    
    public func showLastGame() {
        let title = "Last Game\nPlayed"
        var caption = ""
        if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID),
            let datePlayed = playerMO.datePlayed {
            var format: String
            if Date.startOfYear(from: datePlayed) != Date.startOfYear() {
                format = "dd MMM YYYY"
            } else {
                format = "dd MMM"
            }
            caption = Utility.dateString(datePlayed, format: format, localized: false)
        }
        self.setRightPanel(title: title, caption: caption)
    }
    
    public var containerBanner: Bool {
        return self.menuController?.isVisible ?? false && (self.container == .main || self.container == .mainRight)
    }
    
    public var defaultBannerColor: PaletteColor {
        if self.containerBanner  {
            return Palette.normal
        } else {
            return Palette.banner
        }
    }
    
    public func defaultBannerTextColor(_ textType: ThemeTextType? = nil) -> UIColor {
        if self.containerBanner {
            return Palette.normal.textColor(textType ?? .theme)
        } else {
            return Palette.banner.textColor(textType ?? .normal)
        }
    }
    
    public var defaultBannerHeight: CGFloat {
        if self.containerBanner {
            return Banner.containerHeight
        } else {
            return Banner.normalHeight
        }
    }
    
    public var defaultBannerAlignment: NSTextAlignment {
        if self.containerBanner {
            return .left
        } else {
            return .center
        }
    }
}
