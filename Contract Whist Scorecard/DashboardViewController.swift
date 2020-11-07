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
    
    var description: String {
        switch self {
        case .history:
            return "Recent Game History"
        case .statistics:
            return "Key Stats"
        case .highScores:
            return "High Scores"
        }
    }
    
    var context: String {
        switch self {
        case .statistics:
            return "players with the highest win%"
        default:
            return "players"
        }
    }
}

public enum Orientation: String, CaseIterable {
    case portrait = "Portrait"
    case landscape = "Landscape"
    case container = "Container"
}

@objc protocol DashboardActionDelegate : class {
    
    func action(view: DashboardDetailType, personal: Bool)
    
    @objc optional func reloadData()

}

struct DashboardName {
    let title: String
    let fileName: String
    let imageName: String?
    let helpId: AnyHashable?
    let returnTo: String
    
    init(title: String, returnTo: String? = nil, fileName: String, imageName: String? = nil, helpId: AnyHashable? = nil) {
        self.title = title
        self.fileName = fileName
        self.imageName = imageName
        self.helpId = helpId
        self.returnTo = returnTo ?? title
    }
}

class DashboardViewController: ScorecardViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, CustomCollectionViewLayoutDelegate, DashboardActionDelegate, BannerDelegate {
 
    struct DashboardViewInfo {
        var title: String
        var returnTo: String
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
    private var dashboardInfo: [DashboardName] = []
    private var currentOrientation: Orientation!
    
    private var backImage: String!
    private var backText: String!
    private var backgroundColor: PaletteColor!
    private var completion: (()->())?
    private var allowSync = true
    private var overrideTitle: String?
    internal var awardDetail: AwardDetail?
    private var bottomInset: CGFloat?
    private var menuFinishText: String?
    
    private var firstTime = true
    private var rotated = false
    
    private var observer: NSObjectProtocol?

    @IBOutlet private weak var banner: Banner!
    @IBOutlet private var topSectionProportionalHeightConstraint: [NSLayoutConstraint]!
    @IBOutlet private var topSectionHeightConstraint: [NSLayoutConstraint]!
    @IBOutlet private weak var carouselCollectionView: UICollectionView!
    @IBOutlet private weak var carouselCollectionViewFlowLayout: CustomCollectionViewLayout!
    @IBOutlet private weak var scrollCollectionView: UICollectionView!
    @IBOutlet private weak var dashboardContainerView: UIView!
    @IBOutlet private weak var dashboardContainerBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var subtitleView: UIView!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var subtitleViewHeightConstraint: NSLayoutConstraint!
    
    internal func finishPressed() {
        self.dismiss()
    }
    
    internal func syncPressed() {
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
                self.finishPressed()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup form
        self.defaultViewColors()
        self.setupButtons()
        self.networkEnableSyncButton()

        // Add in dashboards
        self.addDashboardViews()
        
        // Configure flow and set initial value
        self.carouselCollectionViewFlowLayout.delegate = self
        self.carouselCollectionView.decelerationRate = UIScrollView.DecelerationRate.fast
        self.currentPage = Int(self.dashboardViewInfo.count / 2)
        
        self.setupSubtitle()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        if let collectionViewLayout = self.carouselCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            collectionViewLayout.invalidateLayout()
        }
        
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.currentOrientation = (self.container == .mainRight && self.rootViewController.isVisible(container: .mainRight) ? .container : (ScorecardUI.landscapePhone() ? .landscape : .portrait))
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
                self.reloadData()
                self.didRotate()
            }
            self.firstTime = false
            self.rotated = false
        }
        self.setupSubtitle()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Configure bottom
        let bottomSafeArea = self.view.safeAreaInsets.bottom
        self.dashboardContainerBottomConstraint.constant = self.bottomInset ?? (bottomSafeArea == 0 ? 16 : bottomSafeArea)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // self.carouselCollectionView.reloadData()
    }
    
    override func rightPanelDidDisappear() {
        self.awardDetail = nil
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
        Utility.mainThread {
            for (_, orientationViews) in self.dashboardViewInfo {
                for (orientation, dashboardView) in orientationViews.views {
                    if orientation == self.currentOrientation {
                        self.didRotate(for: dashboardView)
                    }
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
            carouselCell.containerView.layoutIfNeeded()
            carouselCell.containerView.roundCorners(cornerRadius: 8.0)
            carouselCell.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
            carouselCell.titleLabel.alpha = (indexPath.row != self.currentPage ? 0.0 : 1.0)
            carouselCell.containerView.backgroundColor = (indexPath.row == self.currentPage ? Palette.carouselSelected.background : Palette.carouselUnselected.background)
            carouselCell.backgroundImageView.tintColor = (indexPath.row == self.currentPage ? Palette.carouselSelected.contrastText : Palette.carouselUnselected.faintText)
            carouselCell.titleLabel.textColor = (indexPath.row == self.currentPage ? Palette.carouselSelected.text : Palette.carouselUnselected.text)
            
            let dashboardInfo = dashboardViewInfo[indexPath.item]!
            carouselCell.titleLabel.text = dashboardInfo.title
            if let imageName = dashboardInfo.imageName {
                carouselCell.backgroundImageView.image = UIImage(named: imageName)!.asTemplate
            }
            return carouselCell
            
        case .scroll:
            let scrollCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Scroll Cell", for: indexPath) as! DashboardScrollCell
                self.defaultCellColors(scrollCell)
            
            scrollCell.indicator.image = UIImage(systemName: (indexPath.row == self.currentPage ? "circle.fill" : "circle"))
            scrollCell.indicator.tintColor = Palette.normal.themeText

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
                self.setupHelpView(view: newView)
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
                                cell.containerView.backgroundColor = Palette.carouselUnselected.background
                                cell.backgroundImageView.tintColor = Palette.carouselUnselected.faintText
                                cell.titleLabel.textColor = Palette.carouselUnselected.text
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
                            cell.containerView.backgroundColor = Palette.carouselSelected.background
                            cell.backgroundImageView.tintColor = Palette.carouselSelected.contrastText
                            cell.titleLabel.textColor = Palette.carouselSelected.text
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
                returnTo: dashboardInfo.returnTo,
                imageName: dashboardInfo.imageName,
                nibNames: nibNames,
                views: [:])
        }
        
        if self.dashboardViewInfo.count == 1 {
            // No carousel required
            self.carouselCollectionView.isHidden = true
            self.scrollCollectionView.isHidden = true
            Constraint.setActive(self.topSectionProportionalHeightConstraint, to: false)
            Constraint.setActive(self.topSectionHeightConstraint, to: true)
        }
    }
    
    private func hideOrientationViews(not notOrientation: Orientation) {
        for (page, viewInfo) in self.dashboardViewInfo {
            for (orientation, view) in viewInfo.views {
                if orientation != notOrientation {
                    view.alpha = 0.0
                    view.isHidden = true
                    self.willDisappear(for: view)
                    view.removeFromSuperview()
                    self.dashboardViewInfo[page]!.views[orientation] = nil
                }
            }
        }
    }
    
    private func willDisappear(for view: UIView) {
        if let view = view as? DashboardTileDelegate {
            view.willDisappear?()
        } else {
            for view in view.subviews {
                self.willDisappear(for: view)
            }
        }
    }
    
    
    private func getView(page: Int) -> DashboardView {
        var view: DashboardView?
        if let viewInfo = self.dashboardViewInfo[page] {
            view = viewInfo.views[self.currentOrientation]
            if view == nil {
                if let nibName = viewInfo.nibNames[self.currentOrientation] {
                    view = DashboardView(withNibName: nibName, frame: self.dashboardContainerView.frame, parent: self, title: viewInfo.title, returnTo: viewInfo.returnTo, delegate: self)
                    view!.alpha = 0.0
                    self.dashboardViewInfo[page]!.views[self.currentOrientation] = view
                    self.dashboardContainerView.addSubview(view!)
                    Constraint.anchor(view: self.dashboardContainerView, control: view!, attributes: .leading, .trailing, .top, .bottom)
                }
            }
        }
        return view!
    }
    
    // MARK: - Dashboard Action Delegate =============================================================== -
    
    func action(view: DashboardDetailType, personal: Bool) {
        // Should already have been actioned in the individual dashboard - this is just to let us
        // refresh other views
        
        self.reloadData()
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func setupSubtitle() {
        if let title = self.overrideTitle {
            self.banner.set(title: title)
        } else if self.dashboardViewInfo.count == 1 {
            let subTitle = self.dashboardInfo.first!.title
            if self.container == .main || self.container == .mainRight {
                self.subtitleLabel.text = subTitle
                self.subtitleViewHeightConstraint.constant = 30
                self.subtitleView.backgroundColor = self.defaultBannerColor.background
                self.subtitleLabel.textAlignment = self.defaultBannerAlignment
                self.subtitleLabel.textColor = self.defaultBannerTextColor()
            } else {
                self.banner.set(title: subTitle)
            }
        }
    }
    
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
        self.banner.setButton("sync", isHidden: hidden)
    }
    
    private func setupButtons() {
        var type: BannerButtonType
        var title: String?
        var image: UIImage?
        var width: CGFloat
        if ScorecardUI.smallPhoneSize() {
            image = UIImage(named: "cloud")
            type = .clear
            width = 30
        } else {
            title = "Sync"
            type = .shadow
            width = 60
        }
        
        var leftButtons: [BannerButton]?
        if let menuFinishText = self.menuFinishText {
            leftButtons = [
                BannerButton(title: self.backText, image: UIImage(named: self.backImage ?? "back"), action: finishPressed, menuHide: true, menuText: menuFinishText, id: Banner.finishButton)]
        }
        
        self.banner.set(
            leftButtons: leftButtons,
            rightButtons: [
                BannerButton(action: self.helpPressed, type: .help),
                BannerButton(title: title, image: image, width: width, action: self.syncPressed, type: type, menuHide: false, font: UIFont.systemFont(ofSize: 14), id: "sync")],
            disableOptions: (leftButtons != nil))
    }

    // MARK: - Functions to present other views ========================================================== -
    
    private func showSync() {
        SyncViewController.show(from: self, completion: {
            // Refresh screen
            self.reloadData()
        })
    }
    
    // MARK: - Function to present and dismiss this view ================================================= -
    
    @discardableResult class public func show(from viewController: ScorecardViewController, title: String? = nil, dashboardNames: [DashboardName], allowSync: Bool = true, backImage: String = "home", backText: String? = nil, backgroundColor: PaletteColor = Palette.dark, container: Container? = .main, bottomInset: CGFloat? = nil, menuFinishText: String? = nil, completion: (()->())? = nil) -> ScorecardViewController {
        
        let dashboardViewController = DashboardViewController.create(title: title, dashboardNames: dashboardNames, allowSync: allowSync, backImage: backImage, backText: backText, backgroundColor: backgroundColor, bottomInset: bottomInset, menuFinishText: menuFinishText, completion: completion)
        
        viewController.present(dashboardViewController, animated: true, container: container, completion: nil)
        
        return dashboardViewController
    }
    
    class public func create(title: String? = nil, dashboardNames: [DashboardName], allowSync: Bool = true, backImage: String = "home", backText: String? = nil, backgroundColor: PaletteColor = Palette.dark, bottomInset: CGFloat? = nil, menuFinishText: String? = nil, completion: (()->())? = nil) -> DashboardViewController {
        
        let storyboard = UIStoryboard(name: "DashboardViewController", bundle: nil)
        let dashboardViewController: DashboardViewController = storyboard.instantiateViewController(withIdentifier: "DashboardViewController") as! DashboardViewController
        
        dashboardViewController.overrideTitle = title
        dashboardViewController.dashboardInfo = dashboardNames
        dashboardViewController.allowSync = allowSync
        dashboardViewController.backText = backText
        dashboardViewController.backImage = backImage
        dashboardViewController.backgroundColor = backgroundColor
        dashboardViewController.completion = completion
        dashboardViewController.bottomInset = bottomInset
        dashboardViewController.menuFinishText = menuFinishText
        
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
        self.view.backgroundColor = self.backgroundColor.background
    }

    private func defaultCellColors(_ cell: DashboardScrollCell) {
        cell.indicator.tintColor = Palette.normal.themeText
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
        button.setImage(Dashboard.typeImage(detailView: detailView).asTemplate, for: .normal)
        button.backgroundColor = Dashboard.color(detailView: detailView)
        button.tintColor = Palette.buttonFace.background
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
}

extension DashboardViewController {
    
    internal func setupHelpView(view: DashboardView) {
        
        self.helpView.reset()
        
        var text = ""
        if self.dashboardInfo.count > 1 {
            text = "The @*/\(self.banner.title ?? "Dashboard")@*/ screen contains \(self.dashboardInfo.count) dashboards.\n\nYou can switch between them using the carousel at the top of the screen or by swiping left or right.\n\n"
        }
        self.helpView.add("\(text)\(self.dashboardHelp())")
        
        self.helpView.add("The @*/Carousel@*/ allows you to switch between the different dashboard views. Either swipe it or tap on one of the tiles to navigate.", views: [self.carouselCollectionView, self.scrollCollectionView], verticalBorder: 4, radius: 0)
        
        self.helpView.add("The {} is used to synchronise the local database with the iCloud database", bannerId: "sync")
        
        self.helpView.add("The {} will take you back to the previous view.", bannerId: Banner.finishButton, horizontalBorder: 8, verticalBorder: 4)
        
        self.helpView.add(dashboardView: view)
    }
    
    private func dashboardHelp() -> String {
        if let id = self.dashboardInfo[currentPage].helpId as? String {
            switch id {
            case "personalResults":
                return "The @*/Personal@*/ dashboard shows you your own personal results and statistics.\n\nYou can tap on a tile to see more details."
            case "everyoneResults":
                return "The @*/Everyone@*/ dashboard shows you the aggregated results and statistics for all players on this device.\n\nYou can tap on a tile to see more details."
            case "awards":
                return "The @*/Awards@*/ dashboard shows you the Awards that you have achieved so far plus the Awards that are still available to be achieved in the future.\n\nYou can tap on an award tile to see details."
            case "highScores":
                return "The @*/High Scores@*/ dashboard shows you the highest scores for each category.\n\nTap on a high score to see the detail."
            default:
                return ""
            }
        } else {
            return ""
        }
    }
}
