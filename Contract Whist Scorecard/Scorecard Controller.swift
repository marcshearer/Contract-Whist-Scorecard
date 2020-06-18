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
    
    var canProceed: Bool { get }
    var canCancel: Bool { get }
    
    func didLoad()
    
    func didAppear()
    
    func didCancel()
    
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
    internal var controllerType: ControllerType
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
    
    // Properties for shared methods (client and server)
    internal weak var scorepadViewController: ScorepadViewController!
    internal weak var roundSummaryViewController: RoundSummaryViewController!
    
    init(from parentViewController: ScorecardViewController, type: ControllerType) {
        
        if Utility.isDevelopment {
            if (ScorecardAppController.references[type] ?? 0) != 0 {
                print("Multiple instances of \(type) controllers")
                parentViewController.alertSound(sound: .alarm)
            }
        }
        
        self.parentViewController = parentViewController
        self.controllerType = type
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
            self.parentViewController.view.sendSubviewToBack(self.parentViewController.dismissImageView)
            self.parentViewController.dismissImageView.image = nil
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
                    self.parentViewController.dismissImageView.image = Utility.screenshot()
                    if let view = self.activeViewController?.view {
                        self.parentViewController.dismissImageView.frame = view.superview!.convert(view.frame, to: nil)
                    }
                    self.parentViewController.dismissView = self.activeView
                    self.parentViewController.view.bringSubviewToFront(self.parentViewController.dismissImageView)
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
                    self.nextView(view: nextView)
                }
            } else {
                self.nextView(view: nextView)
            }
        }
    }
    
    internal func didInvoke(_ invokedView: ScorecardView, context: [String:Any?]? = nil, completion: (([String:Any?]?)->())? = nil) {
        // Lock network and other views
        self.lock(true)
        Scorecard.shared.viewPresenting = invokedView
        self.invokedViews.append((view: invokedView, viewController: nil, uuid: UUID().uuidString))
        let invokedViewController = self.presentView(view: invokedView, context: context, completion: completion)
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
                self.activeViewController = self.presentView(view: self.activeView, context: context)
            }
            
            if self.activeView == .exit || self.activeView == .none || self.activeViewController == nil {
                Scorecard.shared.viewPresenting = .none
                self.activeView = .none
            }
                           
            self.appControllerCompletion()
        }
    }
    
    internal func transitionViews() -> (from: ScorecardView, to: ScorecardView) {
        return (from: self.lastView, to: self.activeView)
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
            locationViewController = LocationViewController.show(from: parentViewController, appController: self, gameLocation: Scorecard.game.location, useCurrentLocation: true, mustChange: false, bannerColor: Palette.gameBanner)
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
            selectPlayerViewController = SelectPlayersViewController.show(from: parentViewController, appController: self, descriptionMode: .opponents, allowOtherPlayer: true, allowNewPlayer: true, completion: { (selected, playerList, selection, thisPlayerUUID) in
                
                    completion?(["selected" : selected,
                                 "playerList" : playerList,
                                 "selection" : selection])
                })
        }
        return selectPlayerViewController
    }
    
    internal func showConfirmPlayed(context: [String:Any?]?, completion: (([String:Any?]?)->())?) -> ConfirmPlayedViewController? {
        var confirmPlayedViewController: ConfirmPlayedViewController?
        
        if let parentViewController = self.fromViewController() {
            if let title = context?["title"] as? String,
                let label = context?["label"] as? UIView,
                let sourceView = context?["sourceView"] as? UIView,
                let confirmText = context?["confirmText"] as? String,
                let cancelText = context?["cancelText"] as? String,
                let backgroundColor = context?["backgroundColor"] as? UIColor {
                
                confirmPlayedViewController = ConfirmPlayedViewController.show(from: parentViewController, appController: self, title: title, content: label, sourceView: sourceView, confirmText: confirmText, cancelText: cancelText, offsets: (0.5, nil), backgroundColor: backgroundColor,
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
    
    internal func showHighScores() -> HighScoresViewController? {
        var highScoresViewController: HighScoresViewController?
        
        if let parentViewController = self.fromViewController() {
            highScoresViewController = HighScoresViewController.show(from: parentViewController, appController: self, backText: "", backImage: "cross white")
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
    
    // MARK: - Presenting view conplete ================================================================== -
    
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
    
    internal func didCancel() {
        fatalError("Must be overridden")
    }
    
    internal func didProceed(context: [String : Any]?) {
        fatalError("Must be overridden")
    }
    
    internal func robotAction(playerNumber: Int! = nil, action: RobotAction) {
        // No action in base class
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    internal func fromViewController() -> ScorecardViewController? {
        if self.activeViewController == nil {
            // No active views - show from parent
            return self.parentViewController
        } else if self.invokedViews.last?.viewController == nil {
            // No invoked views - show from active view
            return self.activeViewController
        } else {
            // Already invoked a view - show on last one
            return self.invokedViews.last?.viewController
        }
    }
}

class ScorecardViewController : UIViewController, UIAdaptivePresentationControllerDelegate, UIViewControllerTransitioningDelegate  {
    
    fileprivate var dismissImageView: UIImageView!
    fileprivate var dismissView = ScorecardView.none
    internal weak var controllerDelegate: ScorecardAppControllerDelegate?
    fileprivate weak var appController: ScorecardAppController?
    private var scorecardView: ScorecardView?
    private var invokedUUID: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create an image view which will be used to hold a screenshot to tidy up dismiss animations
        self.dismissImageView = UIImageView(frame: UIScreen.main.bounds)
        self.view.addSubview(dismissImageView)
        self.view.sendSubviewToBack(self.dismissImageView)
        
        self.presentationController?.delegate = self
        
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
        
    internal func present(_ viewControllerToPresent: ScorecardViewController, appController: ScorecardAppController? = nil, sourceView: UIView? = nil, animated flag: Bool, completion: (() -> Void)? = nil) {

        // Use custom animation
        viewControllerToPresent.transitioningDelegate = self
        
       // Avoid silly popups on max sized phones
        if !ScorecardUI.phoneSize() && sourceView != nil {
            viewControllerToPresent.modalPresentationStyle = UIModalPresentationStyle.popover
            viewControllerToPresent.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            viewControllerToPresent.popoverPresentationController?.sourceView = sourceView
            viewControllerToPresent.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0 ,height: 0)
            viewControllerToPresent.isModalInPopover = true
            if let delegate = self as? UIPopoverPresentationControllerDelegate {
                viewControllerToPresent.popoverPresentationController?.delegate = delegate
            }
        } else if !ScorecardUI.phoneSize() {
            // Make full screen on iPad
            viewControllerToPresent.modalPresentationStyle = .fullScreen
        }
        viewControllerToPresent.controllerDelegate = appController
        viewControllerToPresent.appController = appController
        viewControllerToPresent.scorecardView = Scorecard.shared.viewPresenting
        
        super.present(viewControllerToPresent, animated: flag) { [unowned self, completion] in
            // Clean up any screenshot that was used to tidy up the dismiss animation of the previous view presented on this view controller
            self.view.sendSubviewToBack(self.dismissImageView)
            self.dismissImageView.image = nil
            self.dismissView = .none
            completion?()
        }
    }
    
    override internal func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        // Check if this is an invoked view dismissing and if so pop it and unlock
        
        super.dismiss(animated: flag) {
            if self.invokedUUID != nil && self.appController?.invokedViews.last?.uuid == self.invokedUUID {
                self.appController?.invokedViews.removeLast()
                if self.appController?.invokedViews.isEmpty ?? true {
                    self.appController?.lock(false)
                }
            }
            completion?()
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
        }
        if let animation = animation {
            return ScorecardAnimator(duration: duration, animation: animation, presenting: true)
        } else {
            return nil
        }
    }
    
    internal func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
       
        if dismissed is LaunchScreenViewController {
            return ScorecardAnimator(duration: 2.0, animation: .fade, presenting: false)
        } else {
            return nil
        }
        
    }
    
    // MARK: - Dismiss view under cover of a screen shot ================================================ -
    
    public func dismissWithScreenshot(viewController: ScorecardViewController, completion: (()->())? = nil) {
        self.dismissImageView.image =  Utility.screenshot()
        self.view.bringSubviewToFront(self.dismissImageView)
        self.dismissImageView.alpha = 1.0
        self.dismissImageView.isHidden = false
        self.dismissImageView.frame = view.superview!.convert(view.frame, to: nil)
        viewController.dismiss(animated: false) {
            completion?()
            Utility.animate(duration: 0.5, afterDelay: 1.0, completion: {
                self.view.sendSubviewToBack(self.dismissImageView)
                self.dismissImageView.image = nil
                self.dismissImageView.alpha = 1.0
            }, animations: {
                self.dismissImageView.alpha = 0.0
            })
        }
    }
}
