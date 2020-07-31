//
//  DashboardViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 21/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

@objc public enum DashboardDetailType: Int {
    case history = 1
    case statistics = 2
    case highScores = 3
}

public enum Orientation: String, CaseIterable {
    case portrait = "Portrait"
    case landscape = "Landscape"
}

@objc protocol DashboardActionDelegate : class {
    
    func action(view: DashboardDetailType)
    
    @objc optional func reloadData()

}

@objc protocol DashboardTileDelegate : class {
    
    @objc optional func reloadData()
    
    @objc optional func didRotate()
    
}

class DashboardViewController: ScorecardViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, CustomCollectionViewLayoutDelegate, DashboardActionDelegate {
 
    struct DashboardViewInfo {
        var title: String
        var imageName: String?
        var nibNames: [Orientation:String]
        var views: [Orientation:DashboardView]
    }
    
    private enum DashboardCollectionViews: Int {
        case carousel = 1
        case scroll = 2
    }
    
    private var currentPage = -1
    
    private var dashboardViewInfo: [Int:DashboardViewInfo] = [:]
    private var dashboardInfo: [(title: String, fileName: String, imageName: String?)] = []
    private var currentOrientation: Orientation!
    
    private var backImage: String!
    private var backText: String!
    private var bannerColor: UIColor!
    private var bannerShadowColor: UIColor!
    private var bannerTextColor: UIColor!
    private var backgroundColor: UIColor!
    private var completion: (()->())?
    private var allowSync = true
    
    private var firstTime = true
    private var rotated = false
    
    private var observer: NSObjectProtocol?
    
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private var topSectionHeightConstraint: [NSLayoutConstraint]!
    @IBOutlet private var topSectionProportionalHeightConstraint: [NSLayoutConstraint]!
    @IBOutlet private var titleEqualHeightConstraint: [NSLayoutConstraint]!
    @IBOutlet private var titleProportionalHeightConstraint: [NSLayoutConstraint]!
    @IBOutlet private weak var bannerView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var carouselCollectionView: UICollectionView!
    @IBOutlet private weak var carouselCollectionViewFlowLayout: CustomCollectionViewLayout!
    @IBOutlet private weak var scrollCollectionView: UICollectionView!
    @IBOutlet private weak var finishButton: ClearButton!
    @IBOutlet private weak var dashboardContainerView: UIView!
    @IBOutlet private weak var syncButton: ShadowButton!
    @IBOutlet private weak var smallSyncButton: ClearButton!
    
    @IBAction func finishButtonPressed(_ sender: UIButton) {
        self.dismiss()
    }
    
    @IBAction func syncButtonPressed(_ sender: UIButton) {
        self.showSync()
    }
    
    @IBAction func swipeGestureRecognizer(_ recognizer: UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            switch recognizer.direction {
            case .left:
                if self.currentPage < self.dashboardViewInfo.count - 1 {
                    self.changed(self.carouselCollectionView, itemAtCenter: self.currentPage + 1, forceScroll: true)
                }
            case .right:
                if self.currentPage > 0 {
                    self.changed(self.carouselCollectionView, itemAtCenter: self.currentPage - 1, forceScroll: true)
                }
            default:
                self.finishButtonPressed(self.finishButton)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup form
        self.defaultViewColors()
        self.finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        self.finishButton.setTitle(self.backText)
        self.networkEnableSyncButton()

        // Add in dashboards
        self.addDashboardViews()
        
        // Configure flow and set initial value
        self.carouselCollectionViewFlowLayout.delegate = self
        
        self.carouselCollectionView.decelerationRate = UIScrollView.DecelerationRate.fast
        
        self.currentPage = Int(self.dashboardViewInfo.count / 2)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        Utility.mainThread {
            super.viewWillLayoutSubviews()
            self.currentOrientation = ScorecardUI.landscapePhone() ? .landscape : .portrait
            if self.rotated {
                self.hideOrientationViews(not: self.currentOrientation)
            }
            self.carouselCollectionView.layoutIfNeeded()
            let width: CGFloat = self.carouselCollectionView.frame.width / 4
            self.carouselCollectionView.contentInset = UIEdgeInsets(top: 0.0, left: width, bottom: 0.0, right: width)
            self.carouselCollectionView.reloadData()
            self.carouselCollectionView.layoutIfNeeded()
            if self.firstTime || self.rotated {
                self.carouselCollectionView.layoutIfNeeded()
                self.carouselCollectionView.contentOffset = CGPoint(x: self.carouselCollectionView.bounds.width / 4.0, y: 0.0)
                let selectedPage = (self.firstTime ? Int(self.dashboardViewInfo.count / 2) : self.currentPage)
                self.changed(self.carouselCollectionView, itemAtCenter: selectedPage, forceScroll: true)
                self.carouselCollectionView.reloadData()
                if self.rotated {
                    self.didRotate()
                    self.reloadData()
                }
                self.firstTime = false
                self.rotated = false
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // self.carouselCollectionView.reloadData()
    }
    
    internal func reloadData() {
        Utility.mainThread {
            for (_, orientationViews) in self.dashboardViewInfo {
                for (orientation, dashboardView) in orientationViews.views {
                    if orientation == self.currentOrientation {
                        self.reloadData(for: dashboardView)
                    }
                }
            }
        }
    }
    
    private func reloadData(for view: UIView) {
        if let view = view as? DashboardTileDelegate {
            view.reloadData?()
        } else {
            for view in view.subviews {
                self.reloadData(for: view)
            }
        }
    }
    
    private func didRotate() {
        for (_, orientationViews) in self.dashboardViewInfo {
            for (orientation, dashboardView) in orientationViews.views {
                if orientation == self.currentOrientation {
                    self.didRotate(for: dashboardView)
                }
            }
        }
    }
    
    private func didRotate(for view: UIView) {
        if let view = view as? DashboardTileDelegate {
            view.didRotate?()
        } else {
            for view in view.subviews {
                self.didRotate(for: view)
            }
        }
    }
    
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    internal func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        switch DashboardCollectionViews(rawValue: collectionView.tag) {
        case .carousel:
            return self.dashboardViewInfo.count
        case .scroll:
            return self.dashboardViewInfo.count
        default:
            return 0
        }
    }
    
    internal func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        switch DashboardCollectionViews(rawValue: collectionView.tag) {
        case .carousel:
            let height: CGFloat = collectionView.bounds.size.height
            let width: CGFloat = collectionView.bounds.size.width / 2.0
            return CGSize(width: width, height: height)
            
        case .scroll:
            return CGSize(width: 10.0, height: 10.0)
            
        default:
            return CGSize()
        }
        
    }
    
    internal func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        switch DashboardCollectionViews(rawValue: collectionView.tag) {
        case .carousel:
            let carouselCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Carousel Cell", for: indexPath) as! DashboardCarouselCell
            self.defaultCellColors(carouselCell)
            carouselCell.containerView.roundCorners(cornerRadius: 8.0)
            carouselCell.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
            carouselCell.titleLabel.alpha = (indexPath.row != self.currentPage ? 0.0 : 1.0)
            carouselCell.containerView.backgroundColor = (indexPath.row == self.currentPage ? self.bannerShadowColor : self.backgroundColor)
            carouselCell.backgroundImageView.tintColor = (indexPath.row == self.currentPage ? Palette.textTitle : Palette.disabledText)
            
            let dashboardInfo = dashboardViewInfo[indexPath.item]!
            carouselCell.titleLabel.text = dashboardInfo.title
            if let imageName = dashboardInfo.imageName {
                carouselCell.backgroundImageView.image = UIImage(named: imageName)!.asTemplate()
            }
            return carouselCell
            
        case .scroll:
            let scrollCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Scroll Cell", for: indexPath) as! DashboardScrollCell
                self.defaultCellColors(scrollCell)
            
            scrollCell.indicator.image = UIImage(systemName: (indexPath.row == self.currentPage ? "circle.fill" : "circle"))
            scrollCell.indicator.tintColor = self.bannerColor

            return scrollCell
            
        default:
            return UICollectionViewCell()
        }
    }
        
    internal func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch DashboardCollectionViews(rawValue: collectionView.tag) {
        case .carousel:
            self.changed(collectionView, itemAtCenter: indexPath.item, forceScroll: true)
        default:
            break
        }
    }
        
    internal func changed(_ collectionView: UICollectionView, itemAtCenter: Int, forceScroll: Bool) {
        Utility.mainThread {
            let changed = self.currentPage != itemAtCenter
            if changed || forceScroll == true {
                let oldView = self.getView(page: self.currentPage)
                let newView = self.getView(page: itemAtCenter)
                newView.isHidden = false
                Utility.animate(duration: self.firstTime ? 0.0 : 0.5,
                    completion: {
                        if changed {
                            oldView.isHidden = true
                        }
                    },
                    animations: {
                        // Unhighlight the cell leaving the center
                        if let cell = self.carouselCollectionView.cellForItem(at: IndexPath(item: self.currentPage, section: 0)) as? DashboardCarouselCell {
                            if self.currentPage != itemAtCenter {
                                cell.containerView.backgroundColor = self.backgroundColor
                                cell.backgroundImageView.tintColor = Palette.disabledText
                                cell.titleLabel.alpha = 0.0
                            }
                        }
                        
                        // Select cell
                        self.currentPage = itemAtCenter
                     
                        if forceScroll {
                            collectionView.scrollToItem(at: IndexPath(item: itemAtCenter, section: 0), at: .centeredHorizontally, animated: !self.firstTime)
                        }
                        
                        // Highlight new cell at center
                        if let cell = self.carouselCollectionView.cellForItem(at: IndexPath(item: self.currentPage, section: 0)) as? DashboardCarouselCell {
                            cell.containerView.backgroundColor = self.bannerShadowColor
                            cell.backgroundImageView.tintColor = Palette.textTitle
                            cell.titleLabel.alpha = 1.0
                        }
                        self.scrollCollectionView.reloadData()
                        if changed {
                            oldView.alpha = 0.0
                        }
                        newView.alpha = 1.0
                    })
                        
            }
        }
    }

    // MARK: - Add dashboard views ================================================================== -
    
    private func addDashboardViews() {
        
        for (page, dashboardInfo) in self.dashboardInfo.enumerated() {
            var nibNames: [Orientation:String] = [:]
            for orientation in Orientation.allCases {
                nibNames[orientation] = "\(dashboardInfo.fileName)\(orientation.rawValue)View"
            }
            self.dashboardViewInfo[page] = DashboardViewInfo(
                title: dashboardInfo.title,
                imageName: dashboardInfo.imageName,
                nibNames: nibNames,
                views: [:])
        }
        
        if self.dashboardViewInfo.count == 1 {
            // No carousel required
            self.titleLabel.text = self.dashboardViewInfo[0]?.title
            self.carouselCollectionView.isHidden = true
            self.scrollCollectionView.isHidden = true
            self.topSectionProportionalHeightConstraint.forEach{$0.priority = UILayoutPriority(rawValue: 1)}
            self.topSectionHeightConstraint.forEach{$0.priority = .required}
            self.titleProportionalHeightConstraint.forEach{$0.priority = UILayoutPriority(rawValue: 1)}
            self.titleEqualHeightConstraint.forEach{$0.priority = .required}
        }
    }
    
    private func hideOrientationViews(not notOrientation: Orientation) {
        for (page, viewInfo) in self.dashboardViewInfo {
            for (orientation, view) in viewInfo.views {
                if orientation != notOrientation {
                    view.alpha = 0.0
                    view.isHidden = true
                    view.removeFromSuperview()
                    self.dashboardViewInfo[page]!.views[orientation] = nil
                }
            }
        }
    }
    
    private func getView(page: Int) -> DashboardView {
        var view: DashboardView?
        if let viewInfo = self.dashboardViewInfo[page] {
            view = viewInfo.views[self.currentOrientation]
            if view == nil {
                if let nibName = viewInfo.nibNames[self.currentOrientation] {
                    view = DashboardView(withNibName: nibName, frame: self.dashboardContainerView.frame)
                    view!.alpha = 0.0
                    view!.delegate = self
                    view!.parentViewController = self
                    self.dashboardViewInfo[page]!.views[self.currentOrientation] = view
                    self.dashboardContainerView.addSubview(view!)
                    Constraint.anchor(view: self.dashboardContainerView, control: view!, attributes: .leading, .trailing, .top, .bottom)
                }
            }
        }
        return view!
    }
    
    // MARK: - Dashboard Action Delegate =============================================================== -
    
    func action(view: DashboardDetailType) {
        // Should already have been actioned in the individual dashboard - this is just to let us
        // refresh other views
        
        self.reloadData()
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func networkEnableSyncButton() {
        if !self.allowSync {
            self.syncButtons(hidden: true)
        } else {
            Scorecard.shared.checkNetworkConnection {
                self.syncButtons(hidden: !(Scorecard.shared.isNetworkAvailable && Scorecard.shared.isLoggedIn))
            }
            self.observer = Scorecard.reachability.startMonitor { (available) in
                self.syncButtons(hidden: !available)
            }
        }
    }
    
    private func syncButtons(hidden: Bool) {
        if ScorecardUI.smallPhoneSize() {
            self.syncButton.isHidden = true
            self.smallSyncButton.isHidden = hidden
        } else {
            self.smallSyncButton.isHidden = true
            self.syncButton.isHidden = hidden
        }
    }

    // MARK: - Functions to present other views ========================================================== -
    
    private func showSync() {
        SyncViewController.show(from: self, completion: {
            // Refresh screen
            self.reloadData()
        })
    }
    
    // MARK: - Function to present and dismiss this view ================================================= -
    
    @discardableResult class public func show(from viewController: ScorecardViewController, dashboardNames: [(title: String, fileName: String, imageName: String?)], allowSync: Bool = true, backImage: String = "home", backText: String = "", bannerColor: UIColor = Palette.banner, bannerShadowColor: UIColor = Palette.bannerShadow, bannerTextColor: UIColor = Palette.bannerText, backgroundColor: UIColor = Palette.background, completion: (()->())? = nil) -> ScorecardViewController {
        
        let storyboard = UIStoryboard(name: "DashboardViewController", bundle: nil)
        let dashboardViewController: DashboardViewController = storyboard.instantiateViewController(withIdentifier: "DashboardViewController") as! DashboardViewController
        
        dashboardViewController.preferredContentSize = CGSize(width: 400, height: 700)
        dashboardViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        dashboardViewController.dashboardInfo = dashboardNames
        dashboardViewController.allowSync = allowSync
        dashboardViewController.backText = backText
        dashboardViewController.backImage = backImage
        dashboardViewController.bannerColor = bannerColor
        dashboardViewController.bannerShadowColor = bannerShadowColor
        dashboardViewController.bannerTextColor = bannerTextColor
        dashboardViewController.backgroundColor = backgroundColor
        dashboardViewController.completion = completion
        
        viewController.present(dashboardViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
        return dashboardViewController
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: {
            self.didDismiss()
            self.completion?()
        })
    }
    
    override internal func didDismiss() {
        if self.observer != nil {
            NotificationCenter.default.removeObserver(self.observer!)
            self.observer = nil
        }
    }
}

extension DashboardViewController {
    
    private func defaultViewColors() {
        self.view.backgroundColor = self.backgroundColor
        self.bannerPaddingView.bannerColor = self.bannerColor
        self.bannerView.backgroundColor = self.bannerColor
        self.titleLabel.textColor = self.bannerTextColor
        if ScorecardUI.smallPhoneSize() {
            // Switch to cloud image rather than Sync text on shadowed button
            self.smallSyncButton.tintColor = self.bannerTextColor
        } else {
            self.syncButton.setTitleColor(self.bannerTextColor, for: .normal)
            self.syncButton.setBackgroundColor(self.bannerShadowColor)
        }
    }

    private func defaultCellColors(_ cell: DashboardCarouselCell) {
        cell.titleLabel.textColor = self.bannerTextColor
        cell.backgroundImageView.tintColor = Palette.textTitle
    }
    
    private func defaultCellColors(_ cell: DashboardScrollCell) {
        cell.indicator.tintColor = self.bannerColor
    }

}

class DashboardCarouselCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var containerView: UIView!
    @IBOutlet fileprivate weak var backgroundImageView: UIImageView!
    @IBOutlet fileprivate weak var titleLabel: UILabel!
}

class DashboardScrollCell: UICollectionViewCell {
   @IBOutlet fileprivate weak var indicator: UIImageView!
}

class Dashboard {
    
    public class func color(detailView: DashboardDetailType) -> UIColor {
        switch detailView {
        case .history:
            return Palette.history
        case .statistics:
            return Palette.stats
        case .highScores:
            return Palette.highScores
        }
    }
    
    public class func formatTypeButton(detailView: DashboardDetailType, button: RoundedButton) {
        button.setImage(Dashboard.typeImage(detailView: detailView).asTemplate(), for: .normal)
        button.backgroundColor = Dashboard.color(detailView: detailView)
        button.tintColor = Palette.buttonFace
        button.toCircle()
    }
    
    public class func typeImage(detailView: DashboardDetailType) -> UIImage {
        switch detailView {
        case .history:
            return UIImage(named: "history")!
        case .statistics:
            return UIImage(named: "stats")!
        case .highScores:
            return UIImage(named: "high score")!
        }
    }
    
    public class func typeColor(detailView: DashboardDetailType) -> UIColor {
        switch detailView {
        case .history:
            return Palette.history
        case .statistics:
            return Palette.stats
        case .highScores:
            return Palette.highScores
        }
    }
}
