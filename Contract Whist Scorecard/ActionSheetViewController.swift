//
//  ActionSheetViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 14/09/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class ActionSheetViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {
    
    private let titleHeight: CGFloat = 60
    private let messageHeight: CGFloat = 30
    private let actionHeight: CGFloat = 60
    private let spacing: CGFloat = 10
    private var titleText: String = ""
    private var messageText: String?
    private var actions: [ActionSheetAction] = []
    private var cancelActions: [ActionSheetAction] = []
    private var firstTime = true
    
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var tableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tapGesture: UITapGestureRecognizer!
    
    // MARK: - View Overrides ========================================================================== -

    @IBAction private func tapGesture(recognizer: UITapGestureRecognizer) {
        self.dismiss(completion: self.cancelActions.last?.action)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        self.tableView.separatorColor = Palette.separator.background
        
        self.tapGesture.delegate = self
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if self.firstTime {
            let height = self.tableViewHeight()
            self.tableViewHeightConstraint.constant = height
            self.tableViewBottomConstraint.constant = height + self.view.safeAreaInsets.bottom
            self.firstTime = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Utility.animate {
            self.tableViewBottomConstraint.constant = 0
        }
    }
    
    internal func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view == self.view {
            return true
         } else {
            return false
         }
    }
    
    // MARK: - TableView Overrides ===================================================================== -

    internal func numberOfSections(in tableView: UITableView) -> Int {
        return 1 + cancelActions.count
    }
    
    internal func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return self.headerHeight()
        default:
            return spacing
        }
    }
    
    internal func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Header") as! ActionSheetHeaderCell
            cell.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: self.headerHeight())
            let header = ActionSheetHeader(cell)!
            header.set(text: self.titleText, message: self.messageText)
            return header
        default:
            let header = UITableViewHeaderFooterView()
            header.backgroundView = UIView()
            header.backgroundView?.backgroundColor = UIColor.clear
            return header
        }
    }
    
    internal func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.actionHeight
    }
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return actions.count
        default:
            return 1
        }
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Action", for: indexPath) as! ActionSheetCell
        switch indexPath.section {
        case 0:
            cell.set(text: actions[indexPath.row].text, last: indexPath.row >= actions.count - 1)
        default:
            cell.set(text: cancelActions[indexPath.row].text, cancel: true)
        }
        cell.backgroundView = UIView()
        cell.backgroundView?.backgroundColor = UIColor.clear
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        var action: (()->())?
        switch indexPath.section {
        case 0:
            action = actions[indexPath.row].action
        default:
            action = cancelActions[indexPath.row].action
        }
        
        self.dismiss(completion: action)
        
        return nil
    }
    
    private func headerHeight() -> CGFloat {
        return self.titleHeight + (self.messageText == nil ? 0 : self.messageHeight)
    }
    
    private func tableViewHeight() -> CGFloat {
        var height: CGFloat = self.headerHeight()
        height += (CGFloat(actions.count) * self.actionHeight)
        height += (CGFloat(cancelActions.count) * (self.actionHeight + self.spacing))
        return height
    }
    
    // MARK: - Routine to present/dismiss this view controller ================================================= -
    
    public class func show(from parentViewController: UIViewController, title: String, message: String? = nil, actions: [ActionSheetAction], cancelActions: [ActionSheetAction], sourceView: UIView, sourceRect: CGRect, direction: UIPopoverArrowDirection) {
            
        let storyboard = UIStoryboard(name: "ActionSheetViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "ActionSheetViewController") as! ActionSheetViewController
                
        viewController.titleText = title
        viewController.messageText = message
        viewController.actions = actions
        viewController.cancelActions = cancelActions

        viewController.modalPresentationStyle = .overFullScreen
        
        parentViewController.present(viewController, animated: false)
    }
    
    private func dismiss(completion: (()->())?) {
        Utility.animate(duration: 0.25, completion: {
            self.dismiss(animated: true, completion: completion)
        }, animations: {
            let height = self.tableViewHeight()
            self.tableViewBottomConstraint.constant = height + self.view.safeAreaInsets.bottom
            self.view.backgroundColor = UIColor.clear
        })
    }
}

class ActionSheetHeader: UITableViewHeaderFooterView {
    
    public var cell: ActionSheetHeaderCell!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    convenience init?(_ cell: ActionSheetHeaderCell) {
        let frame = CGRect(origin: CGPoint(), size: cell.frame.size)
        self.init(reuseIdentifier: cell.reuseIdentifier)
        cell.frame = frame
        self.frame = frame
        cell.backgroundColor = UIColor.clear
        self.backgroundView = UIView()
        self.backgroundView!.backgroundColor = UIColor.clear
        self.cell = cell
        self.addSubview(cell)
    }
    
    internal func set(text: String, message: String? = nil) {
        self.cell.set(text: text, message: message)
    }
}

class ActionSheetHeaderCell: UITableViewCell {
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var messageLabelHeightConstraint: NSLayoutConstraint!
    
    internal func set(text: String, message: String?) {
        
        self.roundCorners(cornerRadius: 16, bottomRounded: false)
        let color = Palette.darkHighlight
        self.backgroundColor = color.background
        self.titleLabel?.textColor = color.text
        self.messageLabel?.textColor = color.text
        self.titleLabel?.text = text
        if let message = message {
            self.messageLabel?.text = message
            self.messageLabelHeightConstraint.constant = 30
        } else {
            self.messageLabelHeightConstraint.constant = 0
        }
    }
}

class ActionSheetCell: UITableViewCell {
    
    @IBOutlet private weak var actionLabel: UILabel!
    
    internal func set(text: String, cancel: Bool = false, last: Bool = false) {
        
        var color: PaletteColor
        if cancel {
            color = Palette.buttonFace
            self.roundCorners(cornerRadius: 16)
        } else {
            color = Palette.buttonFace
            if last {
                self.roundCorners(cornerRadius: 16, topRounded: false)
            }
        }
        self.backgroundColor = color.background
        self.actionLabel?.textColor = color.text
        self.actionLabel?.text = text
        
    }
}

struct ActionSheetAction {
    let text: String
    let action: (()->())?
}

class ActionSheet {
    
    private let titleText: String
    private let messageText: String?
    private let sourceView: UIView
    private let sourceRect: CGRect
    private let direction: UIPopoverArrowDirection
    
    private var actions: [ActionSheetAction] = []
    private var cancelActions: [ActionSheetAction] = []
    
    init(_ title: String! = nil, message: String? = nil, sourceView: UIView, sourceRect: CGRect? = nil, direction: UIPopoverArrowDirection = UIPopoverArrowDirection()) {
        self.titleText = title
        self.messageText = message
        self.sourceView = sourceView
        self.sourceRect = sourceRect ?? CGRect(origin: sourceView.center, size: CGSize())
        self.direction = direction
    }
    
    public func add(_ title: String, style: UIAlertAction.Style = UIAlertAction.Style.default, handler: (()->())? = nil) {
        if style == .cancel {
            self.cancelActions.append(ActionSheetAction(text: title, action: handler))
        } else {
            self.actions.append(ActionSheetAction(text: title, action: handler))
        }
    }
    
    public func present(from viewController: UIViewController) {
        ActionSheetViewController.show(from: viewController, title: self.titleText, actions: self.actions, cancelActions: self.cancelActions, sourceView: self.sourceView, sourceRect: self.sourceRect, direction: self.direction)
    }
}
