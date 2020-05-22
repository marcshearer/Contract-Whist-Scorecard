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
}

protocol ScorecardAppControllerDelegate : class {
    
    var canProceed: Bool { get }
    var canCancel: Bool { get }
    
    func didLoad()
    
    func didAppear()
    
    func didCancel()
    
    func didProceed(context: [String: Any]?)
    
    func didInvoke(_ view: ScorecardView)
    
    func lock(_ active: Bool)
}

extension ScorecardAppControllerDelegate {
    
    func didProceed() {
        didProceed(context: nil)
    }
}

public struct ScorecardAppQueue {
    let descriptor: String
    let data: [String : Any?]?
    var peer: CommsPeer?
}

class ScorecardAppControllerClass : CommsDataDelegate {

    internal var activeViewController: ScorecardAppViewController?
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
    
    init(from parentViewController: ScorecardViewController, type: ControllerType) {
        
        if Utility.isDevelopment {
            if (ScorecardAppControllerClass.references[type] ?? 0) != 0 {
                print("Multiple instances of \(type) controllers")
                parentViewController.alertSound(sound: .alarm)
            }
        }
        
        self.parentViewController = parentViewController
        self.controllerType = type
        self.uuid=UUID().uuidString.right(4)
        ScorecardAppControllerClass.references[self.controllerType] = (ScorecardAppControllerClass.references[self.controllerType] ?? 0) + 1
        ScorecardAppControllerClass.totalReferences += 1
        Utility.debugMessage("appController \(self.uuid)", "Init \(debugReference)")

        self.clientHandlerObserver = self.setViewPresentingCompleteNotification()
    }
    
    internal func start() {
        Utility.debugMessage("appController \(self.uuid)", "Start \(debugReference)")
    }
    
    internal func stop() {
        Utility.debugMessage("appController \(self.uuid)", "Stop \(debugReference)")
        clearViewPresentingCompleteNotification(observer: clientHandlerObserver)
        self.parentViewController.view.sendSubviewToBack(self.parentViewController.dismissImageView)
        self.parentViewController.dismissImageView.image = nil
        clientHandlerObserver = nil
    }
    
    deinit {
        Utility.debugMessage("appController \(self.uuid)", "Deinit \(debugReference)")
        ScorecardAppControllerClass.references[self.controllerType] = (ScorecardAppControllerClass.references[self.controllerType] ?? 0) - 1
        ScorecardAppControllerClass.totalReferences -= 1
    }
    
    private var debugReference: String {
        get {
            return "\(controllerType)(\(ScorecardAppControllerClass.references[controllerType]!)/\(ScorecardAppControllerClass.totalReferences)) \(self.uuid)"
        }
    }
    
    internal func appController(nextView: ScorecardView, willDismiss: Bool = true) {
    
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
                    self.parentViewController.dismissImageView.image = self.screenshot()
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
    
    private func nextView(view nextView: ScorecardView) {
        
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
            Scorecard.shared.viewPresenting = self.activeView
            
            if self.activeView != .none {
                self.activeViewController = self.presentView(view: self.activeView)
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
                
                self.processQueue(descriptor: descriptor, data: data, peer: peer)
                
                Scorecard.shared.viewPresenting = .none
            }
        }
    }
    
    internal func addQueue(descriptor: String, data: [String:Any?]?, peer: CommsPeer?) {
        self.queue.insert(ScorecardAppQueue(descriptor: descriptor, data: data, peer: peer), at: 0)
    }
    
    // MARK: - Notification handler ================================================================== -
    
    private func setViewPresentingCompleteNotification() -> NSObjectProtocol? {
        // Set a notification for handler complete
        let observer = NotificationCenter.default.addObserver(forName: .appControllerViewPresentingCompleted, object: nil, queue: nil) {
            (notification) in
            // Flag not waiting and then process next entry in the queue
            Scorecard.shared.viewPresenting = .none
            self.appControllerCompletion()
        }
        return observer
    }
    
    private func clearViewPresentingCompleteNotification(observer: NSObjectProtocol?) {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Methods to be overridden in sub-classes ============================================================== -
    
    internal func refreshView(view: ScorecardView) {
        fatalError("Must be overridden")
    }
    
    internal func presentView(view: ScorecardView) -> ScorecardAppViewController? {
        fatalError("Must be overridden")
    }
    
    internal func didDismissView(view: ScorecardView, viewController: ScorecardAppViewController?) {
        fatalError("Must be overridden")
    }
        
    internal func processQueue(descriptor: String, data: [String:Any?]?, peer: CommsPeer) {
        fatalError("Must be overridden")
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    func screenshot() -> UIImage? {
        let layer = self.activeViewController!.view.layer
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, scale);
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let screenshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return screenshot
    }
}

typealias ScorecardAppController = ScorecardAppControllerClass & ScorecardAppControllerDelegate

class ScorecardViewController : UIViewController, UIAdaptivePresentationControllerDelegate, UIViewControllerTransitioningDelegate  {
    
    internal var scorecardView: ScorecardView? { return nil }
    fileprivate var dismissImageView: UIImageView!
    fileprivate var dismissView = ScorecardView.none
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create an image view which will be used to hold a screenshot to tidy up dismiss animations
        self.dismissImageView = UIImageView(frame: UIScreen.main.bounds)
        self.view.addSubview(dismissImageView)
        self.view.sendSubviewToBack(self.dismissImageView)
        
        self.presentationController?.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.scorecardView != nil && Scorecard.shared.viewPresenting == scorecardView {
            // Notify app controller that view display complete
            Scorecard.shared.viewPresenting = .none
            NotificationCenter.default.post(name: .appControllerViewPresentingCompleted, object: self, userInfo: nil)
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
        
    internal func present(_ viewControllerToPresent: UIViewController, sourceView: UIView? = nil, animated flag: Bool, completion: (() -> Void)? = nil) {

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
        
        super.present(viewControllerToPresent, animated: flag) { [unowned self, completion] in
            // Clean up any screenshot that was used to tidy up the dismiss animation of the previous view presented on this view controller
            self.view.sendSubviewToBack(self.dismissImageView)
            self.dismissImageView.image = nil
            self.dismissView = .none
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
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        if self.dismissView != .none {
            if presented is ScorepadViewController {
                return ScorecardAnimator(duration: 0.25, animation: .fromLeft, presenting: true)
                
            } else if self.dismissView == .scorepad {
                return ScorecardAnimator(duration: 0.25, animation: .fromRight, presenting: true)
                
            } else if (presented is SelectionViewController && self.dismissView == .gamePreview) ||
                      (presented is GamePreviewViewController && self.dismissView == .selection) {
                return ScorecardAnimator(duration: 0.5, animation: .fade, presenting: true)
            
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if #available(iOS 13.0, *) {
            // TODO transitions don't work on IOS 13
            return nil
        } else {
            if dismissed is EntryViewController {
                return ScorecardAnimator(duration: 0.5, animation: .fade, presenting: false)
            } else {
                return nil
            }
        }
    }
}

protocol ScorecardAppViewControllerDelegate: ScorecardViewController {
    
    var scorecardView: ScorecardView? { get }
    var controllerDelegate: ScorecardAppControllerDelegate? { get set }
        
}

typealias ScorecardAppViewController = ScorecardViewController & ScorecardAppViewControllerDelegate
