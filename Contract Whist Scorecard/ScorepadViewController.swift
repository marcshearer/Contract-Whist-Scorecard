//
//  ScorepadViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 25/11/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import Combine
 
class ScorepadViewController: ScorecardViewController,
                              UITableViewDataSource, UITableViewDelegate,
                              UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
                              ScorecardAlertDelegate, BannerDelegate, GameDetailPanelInvokeDelegate {
 
    
    // MARK: - Class Properties ======================================================================== -
    
    // Properties to pass state
    public var parentView: UIView!
    
    // Cell dimensions
    private let minCellHeight: CGFloat = 30
    private var cellHeight: CGFloat = 0
    private var roundWidth: CGFloat = 0.0
    private var cellWidth: CGFloat = 0.0
    private var singleColumn = false
    private var narrow = false
    private var imageRowHeight: CGFloat = 0.0
    private var headerHeight: CGFloat = 0.0
    private var bannerContinuationHeight: CGFloat = 10.0
    private let combinedTriggerWidth: CGFloat = 80.0
    private var scoresHeight: CGFloat = 0.0
    
    // Gradients
    let imageGradient: [(alpha: CGFloat, location: CGFloat)] =  [(0.0, 0.0), (0.0, 0.5), (0.8, 1.0)]
    let playerGradient: [(alpha: CGFloat, location: CGFloat)] = [(0.8, 0.0), (1.0, 0.5), (1.0, 1.0)]
    let footerGradient: [(alpha: CGFloat, location: CGFloat)] = [(1.0, 0.0), (1.0, 0.3), (0.0, 0.9), (0.0, 1.0)]
    
    // Header description variables
    private let showThumbnail = true
    private var headerRows = 0
    private var imageRow = -1
    private var playerRow = -1
    
    // Body description variables
    private var bodyColumns = 0

    // Cell outline weights
    private let thickLineWeight: CGFloat = 3.0
    private let thinLineWeight: CGFloat = 1.0
    
    // Local class variables
    private var lastBannerHeight:CGFloat = 0.0
    private var lastViewHeight:CGFloat = 0.0
    private var lastViewWidth: CGFloat = 0.0
    private var rotated = false
    private var firstTime = true
    private var observer: NSObjectProtocol?
    private var paddingGradientLayer: [CAGradientLayer] = []
    private var scoresSubscription: AnyCancellable?
    private let finishButton = Banner.finishButton
    private let scoreEntryButton = 1

    // UI component pointers
    private var imageCollectionView: UICollectionView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var bannerContinuationHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bannerContinuation: UIView!
    @IBOutlet private weak var bannerLogoView: BannerLogoView!
    @IBOutlet private weak var headerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var footerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var headerTableView: UITableView!
    @IBOutlet private weak var bodyTableView: UITableView!
    @IBOutlet private weak var footerTableView: UITableView!
    @IBOutlet private weak var tapGestureRecognizer: UITapGestureRecognizer!
    @IBOutlet private var paddingViewLines: [UIView]!
    @IBOutlet private weak var leftPaddingView: InsetPaddingView!
    @IBOutlet private weak var rightPaddingView: InsetPaddingView!
    @IBOutlet private var paddingViewLineWidth: [NSLayoutConstraint]!

    // MARK: - IB Actions ============================================================================== -
    
    internal func scorePressed() {
        self.willDismiss()
        Scorecard.game.selectedRound = Scorecard.game.maxEnteredRound
        self.controllerDelegate?.didProceed()
    }
    
    internal func finishPressed() {
        Scorecard.shared.warnExitGame(from: self) {
            self.willDismiss()
            self.controllerDelegate?.didCancel()
        }
    }
    
    @IBAction private func tapGesture(recognizer: UITapGestureRecognizer) {
        self.controllerDelegate?.didProceed()
    }
    
    @IBAction private func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        if self.gameMode == .scoring {
            let isHidden = banner.getButtonIsHidden(scoreEntryButton)
            let isEnabled = banner.getButtonIsEnabled(scoreEntryButton)
            if recognizer.state == .ended && !isHidden && isEnabled {
                finishPressed()
            }
        }
    }
    
    @IBAction private func leftSwipe(recognizer:UISwipeGestureRecognizer) {
        if self.gameMode == .scoring {
            if recognizer.state == .ended {
                self.scorePressed()
            }
        }
    }
    
    // MARK: - View Overrides ========================================================================== -
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        // Set default colors formerly in storyboard
        self.defaultViewColors()
        
        // Set nofification for image download
        observer = setImageDownloadNotification()
        
        // Don't sleep
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Subscribe to score changes
        self.setupScoresSubscription()
        
        // Setup help
        self.setupHelpView()
    }
    
    override internal func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.gameMode == .viewing {
            headerTableView.isUserInteractionEnabled = true
            footerTableView.isUserInteractionEnabled = true
            tapGestureRecognizer.isEnabled = true
        } else {
            tapGestureRecognizer.isEnabled = false
        }
        formatButtons()
        
        self.view.setNeedsLayout()
        
        Scorecard.shared.alertDelegate = self
        
        // Setup invoke delegate
        let gameDetailDelegate = self.gameDetailDelegate
        gameDetailDelegate?.invokeDelegate = self

    }
    
    override internal func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
        self.rotated = true
    }
    
    override internal func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if self.firstTime || self.rotated || self.lastBannerHeight != self.banner.height ||
            self.lastViewHeight != self.view.frame.height ||
            self.lastViewWidth != self.view.frame.width {

            self.setupBanner()
            self.setupSize(to: self.view.safeAreaLayoutGuide.layoutFrame.size)
            self.headerTableView.layoutIfNeeded()
            self.paddingViewLineWidth.forEach { $0.constant = (ScorecardUI.landscapePhone() ? 3 : 0)}
            self.paddingViewLines.forEach { $0.layoutIfNeeded() }
            self.headerTableView.reloadData()
            self.bodyTableView.reloadData()
            self.footerTableView.reloadData()
            self.lastBannerHeight = self.banner.height
            self.lastViewHeight = self.view.frame.height
            self.lastViewWidth = self.view.frame.width
            self.firstTime = false
            self.rotated = false
            self.setupBorders()
        }
    }
    
    override internal func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Scorecard.shared.alertDelegate = nil
    }
    
    override internal func willDismiss() {
        // Tidy up before exiting
        self.cancelScoresSubscription()
        if observer != nil {
            Notifications.removeObserver(self.observer)
            observer = nil
        }
        UIApplication.shared.isIdleTimerDisabled = false

        let gameDetailDelegate = self.gameDetailDelegate
        gameDetailDelegate?.invokeDelegate = nil
    }
    
    // MARK: - Game Detail Invoke Delegate Handlers ============================================== -
    
    internal func invoke(_ view: ScorecardView) {
        self.controllerDelegate?.didInvoke(view)
    }

    // MARK: - TableView Overrides ===================================================================== -

    internal func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0.0
        
        switch tableView.tag {
        case 1:
            // Header
            switch indexPath.row {
            case imageRow:
                height = imageRowHeight
            default:
                height = headerHeight - imageRowHeight - bannerContinuationHeight
            }
        case 2:
            // Body
            height = CGFloat(cellHeight)
        default:
            // Footer
            height = CGFloat(cellHeight + self.view.safeAreaInsets.bottom)
        }
        return height
    }
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var rows = 0
        
        switch tableView.tag {
        case 1:
            // Header
            rows = headerRows
        case 2:
            // Body contains a row for each round
            rows = Scorecard.game.rounds
        default:
            // Footer
            rows = 1
        }
        return rows
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell
        
        switch tableView.tag {
        case 1:
            // Header
            cell = tableView.dequeueReusableCell(withIdentifier: "Header Table Cell", for: indexPath)
        case 2:
            // Body
            cell = tableView.dequeueReusableCell(withIdentifier: "Body Table Cell", for: indexPath)
        default:
            // Footer
            cell = tableView.dequeueReusableCell(withIdentifier: "Footer Table Cell", for: indexPath)
        }
        
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        
        switch tableView.tag {
        case 1:
            // Header
            guard let tableViewCell = cell as? ScorepadTableViewCell else { return }
            tableViewCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row + 1000000)
            if indexPath.row == imageRow {
                imageCollectionView = tableViewCell.scorepadCollectionView
            }
        case 2:
            // Body
            guard let tableViewCell = cell as? ScorepadTableViewCell else { return }
            tableViewCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
        default:
            // Footer
            guard let tableViewCell = cell as? ScorepadTableViewCell else { return }
            tableViewCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row + 2000000)
        }
    }
    
    // MARK: - Alert delegate handlers =================================================== -
    
    internal func alertUser(reminder: Bool) {
        self.banner.alertFlash(scoreEntryButton, duration: 0.3, repeatCount: 3)
    }
    
    // MARK: - Image download handlers =================================================== -
    
    private func setImageDownloadNotification() -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = Notifications.addObserver(forName: .playerImageDownloaded) { [weak self]
            (notification) in
            self?.updateImage(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }
    
    private func updateImage(objectID: NSManagedObjectID) {
        // Find any cells containing an image which has just been downloaded asynchronously
        Utility.mainThread {
            let index = Scorecard.game?.scorecardIndex(objectID)
            if index != nil {
                // Found it - reload the cell
                self.imageCollectionView.reloadItems(at: [IndexPath(row: index!+1, section: 0)])
            }
        }
    }
    
    // MARK: - Scores publisher subscription =========================================================== -
    
    private func setupScoresSubscription() {
        self.scoresSubscription = Scorecard.game?.scores.subscribe { (round, enteredPlayerNumber) in
            Utility.mainThread {
                self.updatePlayerCells(round: round, playerNumber: Scorecard.game.scorecardPlayerNumber(enteredPlayerNumber: enteredPlayerNumber))
            }
        }
    }
    
    private func cancelScoresSubscription() {
        self.scoresSubscription?.cancel()
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    private func setupSize(to size: CGSize) {
        
        // Calculate columns
        
        // Set cell widths
        roundWidth = round(size.width > CGFloat(600) ? size.width / CGFloat(10) : 60)
        cellWidth = CGFloat(Int(round((size.width - roundWidth) / (CGFloat(2.0) * CGFloat(Scorecard.game.currentPlayers)))))
        
        if cellWidth <= combinedTriggerWidth {
            cellWidth *= 2
            bodyColumns = 1
            narrow = true
            imageRowHeight = 50.0
        } else {
            bodyColumns = 2
            narrow = false
            imageRowHeight = 50.0
        }
        
        roundWidth = size.width - (CGFloat(bodyColumns * Scorecard.game.currentPlayers) * cellWidth)
        
        // work out what appears in which header row
        imageRow = -1
        playerRow = -1
        headerRows = 0
        headerHeight =  0.0
        bannerContinuationHeight = 0.0
        
        if showThumbnail {
            headerHeight += imageRowHeight
            imageRow = headerRows
            headerRows += 1
        }
        
       
        playerRow = headerRows
        headerRows += 1
        
        // Note headerHeight does not include the player name row since we haven't
        // worked this out yet
        
        var floatCellHeight: CGFloat = (size.height - imageRowHeight - self.banner.height) / CGFloat(Scorecard.game.rounds + 2) // Adding 2 for name row in header and total row
        floatCellHeight.round()
        
        cellHeight = CGFloat(Int(floatCellHeight))
        
        if cellHeight < minCellHeight {
            cellHeight = minCellHeight
            headerHeight += CGFloat(cellHeight)
            bannerContinuationHeight = 0.0
        } else {
            headerHeight = size.height - (CGFloat(Scorecard.game.rounds + 1) * cellHeight) - self.banner.height
            imageRowHeight = min(headerHeight - minCellHeight, 50.0)
            bannerContinuationHeight = headerHeight - imageRowHeight - minCellHeight
        }
        
        var containerAdjustment: CGFloat = 0
        if self.containerBanner {
            containerAdjustment = Banner.containerHeight - headerHeight - Banner.normalHeight
        }
        bannerContinuationHeightConstraint.constant = bannerContinuationHeight + containerAdjustment
        headerViewHeightConstraint.constant = headerHeight - bannerContinuationHeight
        footerViewHeightConstraint.constant = CGFloat(cellHeight) + self.view.safeAreaInsets.bottom - containerAdjustment

        scoresHeight = min(ScorecardUI.screenHeight, CGFloat(Scorecard.game.rounds) * cellHeight, 600)
    }
    
    private func setupBorders() {
        
        let line = self.paddingViewLines![0]
        let height: CGFloat = line.frame.height
        var gradient: [(alpha: CGFloat, location: CGFloat)] = []
        let tableViewTop: CGFloat = self.headerTableView.frame.minY
        for element in self.imageGradient {
            gradient.append((element.alpha, (tableViewTop + bannerContinuationHeight + (element.location * imageRowHeight)) / height))
        }
        for element in self.playerGradient {
            gradient.append((element.alpha, (tableViewTop + bannerContinuationHeight + imageRowHeight + (element.location * minCellHeight)) / height))
        }
        
        let footerTop = tableViewTop + bannerContinuationHeight + imageRowHeight + minCellHeight + bodyTableView.frame.height
        let footerHeight = height - footerTop
        for element in self.footerGradient {
            gradient.append((element.alpha, (footerTop + (element.location * footerHeight)) / height))
        }
        
        self.paddingGradientLayer.forEach {
            $0.removeFromSuperlayer()
        }
        self.paddingGradientLayer = []
        self.paddingViewLines?.forEach {
            paddingGradientLayer.append(ScorecardUI.gradient($0, color: Palette.grid.background, gradients: gradient))
        }
    }
    
    private func returnFromEntry(editedRound: Int? = nil) {
        if rotated {
            headerTableView.reloadData()
            bodyTableView.reloadData()
            footerTableView.reloadData()
        }
        formatButtons()
    }
    
    public func highlightCurrentDealer(_ highlight: Bool) {
        if headerRows > 0 {
            for row in 0...headerRows-1 {
                let headerCell = self.headerCell(playerNumber: Scorecard.game.isScorecardDealer(), row: row)
                highlightDealer(headerCell: headerCell, playerNumber: Scorecard.game.isScorecardDealer(), row: row, forceClear: !highlight)
            }
        }
    }
    
    private func headerCell(playerNumber: Int, row: Int) -> ScorepadCollectionViewCell {
        let tableViewCell = headerTableView.cellForRow(at: IndexPath(row: row, section: 0)) as! ScorepadTableViewCell
        let collectionView = tableViewCell.scorepadCollectionView
        return collectionView?.cellForItem(at: IndexPath(item: playerNumber, section: 0)) as! ScorepadCollectionViewCell
    }
    
    private func highlightDealer(headerCell: ScorepadCollectionViewCell, playerNumber: Int, row: Int, forceClear: Bool = false) {
        if playerNumber >= 0 {
            headerCell.scorepadCellGradientLayer?.removeFromSuperlayer()
            if Scorecard.game.isScorecardDealer() == playerNumber && !forceClear {
                if row == playerRow {
                    headerCell.scorepadCellLabel?.textColor = Palette.banner.text
                    headerCell.scorepadCellGradientLayer = ScorecardUI.gradient(headerCell, color: Palette.total.background, gradients: playerGradient)
                } else if row == imageRow {
                    headerCell.scorepadCellGradientLayer = ScorecardUI.gradient(headerCell, color: Palette.total.background, gradients: imageGradient)
                }
            } else {
                Palette.bannerStyle(view: headerCell)
                
            }
        }
    }
    
    public func reloadScorepad() {
        self.headerTableView.reloadData()
        self.bodyTableView.reloadData()
        self.footerTableView.reloadData()
    }
    
    private func setupBanner() {
        let scoreEntryButtonTitle = (Scorecard.game.gameComplete() ? "Scores" :
                                        (self.gameMode.isHosting  || self.gameMode == .joining ? "Play" :
                                     "Score"))
        let scoreEntryButtonWidth = max(scoreEntryButtonTitle.labelWidth(font: BannerButton.defaultFont) + 16, 80)
        let menuText = (Scorecard.game.gameComplete() ? "Return to Game Summary" :
                            (self.gameMode.isHosting  || self.gameMode == .joining ? "Play Hand" :
                        "Enter Score"))
        self.banner.set(
            menuTitle: "Scorepad",
            leftButtons: [
                BannerButton(image: UIImage(named: "home"), width: 22, action: {[weak self] in self?.finishPressed()}, menuHide: true, menuText: "Abandon game", menuSpaceBefore: 20, id: Banner.finishButton),
                BannerButton(action: {[weak self] in self?.helpPressed()}, type: .help)],
            leftSpacing: 16,
            rightButtons: [
                BannerButton(title: scoreEntryButtonTitle, width: scoreEntryButtonWidth, action: {[weak self] in self?.scorePressed()}, type: .shadow, menuHide: true, menuText: menuText, id: scoreEntryButton)],
            backgroundColor: Palette.banner,
            containerOverrideHeight: Banner.normalHeight)
    }

    private func formatButtons() {
        self.banner.setButton(scoreEntryButton, isHidden: !(self.controllerDelegate?.canProceed ?? true))
        self.banner.setButton(finishButton, isHidden: !(self.controllerDelegate?.canCancel ?? true))
    }
    
    // MARK: - Utility methods to find or update specific cells ========================================== -
    
    private func cellForItemAt(_ tableView: UITableView, row: Int, playerNumber: Int, mode: Mode, bodyColumns:Int) -> ScorepadCollectionViewCell? {
        var cell: ScorepadCollectionViewCell?
        if let tableViewCell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? ScorepadTableViewCell {
            if let collectionView = tableViewCell.scorepadCollectionView {
                var item: Int?
                switch mode {
                case Mode.bid:
                    if bodyColumns > 1 {
                        item = (playerNumber * bodyColumns) - 1
                    }
                case Mode.made:
                    item = (playerNumber * bodyColumns)
                default:
                    break
                }
                if let item = item {
                    cell = collectionView.cellForItem(at: IndexPath(item: item, section: 0)) as? ScorepadCollectionViewCell
                }
            }
        }
        return cell
    }
    
    private func headerCell(row: Int, playerNumber: Int) -> ScorepadCollectionViewCell? {
        return cellForItemAt(headerTableView, row: row, playerNumber: playerNumber, mode: .made, bodyColumns: 1)
    }
    
    private func bodyCell(round: Int, playerNumber: Int, mode: Mode) -> ScorepadCollectionViewCell? {
        return cellForItemAt(bodyTableView, row: round - 1, playerNumber: playerNumber, mode: mode, bodyColumns: self.bodyColumns)
    }

    private func footerCell(playerNumber: Int) -> ScorepadCollectionViewCell? {
        return cellForItemAt(footerTableView, row: 0, playerNumber: playerNumber, mode: .made, bodyColumns: 1)
    }
    
    public func updateBodyCell(round: Int, playerNumber: Int, mode: Mode) {

        if let cell = self.bodyCell(round: round, playerNumber: playerNumber, mode: mode) {
            self.updateBodyCell(cell: cell, round: round, playerNumber: playerNumber, mode: mode)
        }
        self.updateTotalCell(playerNumber: playerNumber)
    }
    
    public func updateBodyCell(cell: ScorepadCollectionViewCell, round: Int, playerNumber: Int, mode: Mode) {

        let playerScore = Scorecard.game.scores.get(round: round, playerNumber: playerNumber, sequence: .scorecard)
    
        switch mode {
        case Mode.bid:
            if Scorecard.game.scores.error(round: round) {
                Palette.inverseErrorStyle(cell.scorepadCellLabel, errorCondtion: true)
            } else {
                Palette.alternateStyle(cell.scorepadCellLabel, setFont: false)
            }
            cell.scorepadCellLabel.text = (playerScore.bid  == nil ? "" : "\(playerScore.bid!)")
            
        case Mode.made:
            if Scorecard.game.scores.error(round: round) {
                Palette.inverseErrorStyle(cell.scorepadCellLabel, errorCondtion: true)
            } else {
                if playerScore.bid != nil && playerScore.bid == playerScore.made {
                    Palette.madeContractStyle(cell.scorepadCellLabel, setFont: false)
                } else {
                    if bodyColumns <= 1 {
                        // No bid label so don't need to differentiate
                        Palette.normalStyle(cell.scorepadCellLabel, setFont: false)
                    } else {
                        Palette.normalStyle(cell.scorepadCellLabel, setFont: false)
                    }
                }
                let imageView = cell.scorepadImage!
                if (playerScore.twos ?? 0) != 0 {
                    if playerScore.twos == 1 {
                        imageView.image = UIImage(named: "two")!
                    } else {
                        imageView.image = UIImage(named: "twos")!
                    }
                } else {
                    imageView.image = nil
                }
                imageView.superview!.bringSubviewToFront(imageView)
            }
            let playerTotal = Scorecard.game.scores.score(round: round, playerNumber: playerNumber, sequence: .scorecard)
            cell.scorepadCellLabel.text = (playerTotal  == nil ? "" : "\(playerTotal!)")
        default:
            break
        }
    }
    
    private func updatePlayerCells(round: Int, playerNumber: Int) {
            self.updateBodyCell(round: round, playerNumber: playerNumber, mode: Mode.bid)
            self.updateBodyCell(round: round, playerNumber: playerNumber, mode: Mode.made)
            self.updateBodyCell(round: round, playerNumber: playerNumber, mode: Mode.twos)
    }
    
    private func updateRoundCells(_ round: Int) {
        for playerLoop in 1...Scorecard.game.currentPlayers {
            self.updatePlayerCells(round: round, playerNumber: playerLoop)
        }
    }
    
    public func updateTotalCell(playerNumber: Int) {

        if let cell = self.footerCell(playerNumber: playerNumber) {
            self.updateTotalCell(cell: cell, playerNumber: playerNumber)
        }
    }
    
    private func updateTotalCell(cell: ScorepadCollectionViewCell, playerNumber: Int) {
        let playerTotal = Scorecard.game.scores.totalScore(playerNumber: playerNumber, sequence: .scorecard)
        cell.scorepadCellLabel.text = "\(playerTotal)"
    }
        
    // MARK: - Function to present this view ==============================================================
    
    class func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, existing scorepadViewController: ScorepadViewController? = nil) -> ScorepadViewController {
        var scorepadViewController: ScorepadViewController! = scorepadViewController
        
        if scorepadViewController == nil {
            let storyboard = UIStoryboard(name: "ScorepadViewController", bundle: nil)
            scorepadViewController = storyboard.instantiateViewController(withIdentifier: "ScorepadViewController") as? ScorepadViewController
        } else {
            scorepadViewController.firstTime = true
            scorepadViewController.view.setNeedsLayout()
        }
        
        scorepadViewController.parentView = viewController.view
        scorepadViewController.controllerDelegate = appController
        
        viewController.present(scorepadViewController, appController: appController, animated: true)
        
        return scorepadViewController
    }
    
    // MARK: - CollectionView Overrides ================================================================ -

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag >= 1000000 {
            return Scorecard.game.currentPlayers + 1
        } else {
            return (Scorecard.game.currentPlayers * bodyColumns) + 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let totalHeight: CGFloat = collectionView.bounds.size.height
        var width: CGFloat = 0.0
        let column = indexPath.row
        var headerCollection =  false
        var footerCollection = false
        
        if collectionView.tag >= 2000000 {
            footerCollection = true
        } else if collectionView.tag >= 1000000 {
            headerCollection = true
        }
        
        if headerCollection || footerCollection
        {
            if column == 0
            {
                width = roundWidth
            }
            else
            {
                width = cellWidth * CGFloat(bodyColumns)
            }
        }
        else
        {
            if column == 0
            {
                width = roundWidth
            }
            else
            {
                width = CGFloat(cellWidth)
            }
        }
        return CGSize(width: width, height: totalHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell = UICollectionViewCell()
        Palette.forcingGameBanners {
            var headerCell: ScorepadCollectionViewCell
            var footerCell: ScorepadCollectionViewCell
            var bodyCell: ScorepadCollectionViewCell
            
            let row = collectionView.tag % 1000000
            let round = row + 1
            var headerCollection =  false
            var footerCollection = false
            var player = 0
            var reuseIdentifier = ""
            let column = indexPath.row
            
            if collectionView.tag >= 2000000 {
                footerCollection = true
            } else if collectionView.tag >= 1000000 {
                headerCollection = true
            }
            
            if headerCollection {
                
                // Header
                
                if column != 0 {
                    // Thumbnail and/or name
                    player = column
                    
                    let playerDetail = Scorecard.game.player(scorecardPlayerNumber: player).playerMO
                    
                    if row == imageRow {
                        // Thumbnail cell
                        reuseIdentifier = "Header Collection Image Cell"
                    } else {
                        reuseIdentifier = "Header Collection Cell"
                    }
                    
                    headerCell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,for: indexPath)   as! ScorepadCollectionViewCell
                    self.defaultCellColors(cell: headerCell)
                    
                    headerCell.scorepadLeftLineGradientLayer?.removeFromSuperlayer()
                    Palette.bannerStyle(view: headerCell)
                    headerCell.scorepadLeftLineWeight.constant = thickLineWeight
                    headerCell.layoutIfNeeded()
                    
                    if row == playerRow {
                        // Setup label
                        headerCell.scorepadCellLabel.textColor = Palette.banner.text
                        headerCell.scorepadCellLabel.text = Scorecard.game.player(scorecardPlayerNumber: player).playerMO!.name!
                        if column != 0 {
                            headerCell.scorepadLeftLineGradientLayer = ScorecardUI.gradient(headerCell.scorepadLeftLine, color: Palette.grid.background, gradients: playerGradient, overrideWidth: thickLineWeight, overrideHeight: self.minCellHeight)
                        }
                        
                    } else {
                        // Setup the thumbnail picture / disc
                        if playerDetail != nil {
                            Utility.setThumbnail(data: playerDetail!.thumbnail,
                                                 imageView: headerCell.scorepadImage,
                                                 initials: playerDetail!.name!,
                                                 label: headerCell.scorepadDisc)
                            ScorecardUI.veryRoundCorners(headerCell.scorepadImage, radius: (imageRowHeight-9)/2)
                            ScorecardUI.veryRoundCorners(headerCell.scorepadDisc, radius: (imageRowHeight-9)/2)
                        }
                        if column != 0 {
                            headerCell.scorepadLeftLineGradientLayer = ScorecardUI.gradient(headerCell.scorepadLeftLine, color: Palette.grid.background, gradients: imageGradient, overrideWidth: thickLineWeight, overrideHeight: self.imageRowHeight)
                        }
                    }
                    
                } else {
                    // Title column
                    headerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Header Collection Cell",for: indexPath) as! ScorepadCollectionViewCell
                    self.defaultCellColors(cell: headerCell)
                    
                    headerCell.scorepadLeftLineGradientLayer?.removeFromSuperlayer()
                    Palette.bannerStyle(view: headerCell)
                    headerCell.scorepadCellLabel?.textColor = Palette.banner.contrastText
                    
                    // Row titles
                    switch row {
                    case imageRow:
                        headerCell.scorepadCellLabel.text=""
                    case playerRow:
                        headerCell.scorepadCellLabel.text=""
                    default:
                        break
                    }
                    headerCell.scorepadLeftLineWeight.constant = 0
                    headerCell.scorepadCellLabel.numberOfLines = 1
                }
                
                if row == playerRow {
                    // Setup the name font
                    if narrow {
                        headerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 20.0)
                    } else {
                        headerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 24.0)
                    }
                }
                
                // Setup top line
                headerCell.scorepadTopLineWeight.constant = (row == 0 ? 0 /* was thickLineWeight*/ : 0)
                
                // Highlight current dealer
                highlightDealer(headerCell: headerCell, playerNumber: column, row: row)
                
                cell=headerCell
                
            } else if footerCollection {
                
                // Footer
                
                footerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Footer Collection Cell",for: indexPath) as! ScorepadCollectionViewCell
                self.defaultCellColors(cell: footerCell)
                
                footerCell.scorepadLeftLineGradientLayer?.removeFromSuperlayer()
                footerCell.scorepadLeftLineGradientLayer = nil
                footerCell.scorepadCellLabel.textColor = Palette.total.text
                footerCell.scorepadCellLabelHeight.constant = cellHeight - thickLineWeight + (ScorecardUI.landscapePhone() ? self.view.safeAreaInsets.bottom / 2.0 : 0.0)
                footerCell.layoutIfNeeded()
                
                if column == 0 {
                    // Row titles
                    footerCell.scorepadCellLabel.text="Total"
                    footerCell.scorepadLeftLineWeight.constant = 0
                    footerCell.scorepadCellLabel.numberOfLines = 1
                    footerCell.scorepadCellLabel.accessibilityIdentifier = ""
                    if narrow {
                        footerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 20.0)
                    } else {
                        footerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 24.0)
                    }
                } else {
                    // Row values
                    player = column
                    self.updateTotalCell(cell: footerCell, playerNumber: player)
                    footerCell.scorepadLeftLineWeight.constant = thickLineWeight
                    footerCell.scorepadCellLabel.accessibilityIdentifier = "player\(indexPath.row)total"
                    footerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 26.0)
                }
                if column != 0 {
                    footerCell.scorepadLeftLine.backgroundColor = Palette.grid.background
                }
                
                // Fade out at bottom if there is a safe area inset at the side
                footerCell.scorepadCellGradientLayer?.removeFromSuperlayer()
                footerCell.backgroundColor = Palette.total.background
                
                footerCell.scorepadTopLineWeight.constant = thinLineWeight
                
                cell=footerCell
                
            } else {
                
                // Body
                
                if column == 0 || (column % 2 == 1 && bodyColumns == 2) {
                    reuseIdentifier = "Body Collection Text Cell"
                } else {
                    reuseIdentifier = "Body Collection Image Cell"
                }
                
                bodyCell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ScorepadCollectionViewCell
                self.defaultCellColors(cell: bodyCell)
                
                if narrow {
                    bodyCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 20.0)
                } else {
                    bodyCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 24.0)
                }
                
                if column == 0 {
                    Palette.bannerStyle(bodyCell.scorepadCellLabel)
                    
                    bodyCell.scorepadRankLabel.text = "\(Scorecard.game.roundCards(round))"
                    let suit = Scorecard.game.roundSuit(round)
                    bodyCell.scorepadSuitLabel.attributedText = suit.toAttributedString(font: bodyCell.scorepadCellLabel.font, noTrumpScale: 0.8)
                    bodyCell.scorepadCellLabel.text = ""
                    bodyCell.scorepadLeftLineWeight.constant = 0
                    bodyCell.scorepadCellLabel.accessibilityIdentifier = ""
                } else {
                    player = ((column - 1) / bodyColumns) + 1
                    if column % 2 == 1 && bodyColumns == 2 {
                        // Bid
                        bodyCell.scorepadLeftLineWeight.constant = thickLineWeight
                        self.updateBodyCell(cell: bodyCell, round: round, playerNumber: player, mode: Mode.bid)
                        bodyCell.scorepadCellLabel.accessibilityIdentifier = ""
                    } else {
                        // Score
                        bodyCell.scorepadLeftLineWeight.constant = (bodyColumns == 2 ? thinLineWeight : thickLineWeight)
                        self.updateBodyCell(cell: bodyCell, round: round, playerNumber: player, mode: Mode.made)
                        bodyCell.scorepadCellLabel.accessibilityIdentifier = "player\(player)round\(round)"
                    }
                    bodyCell.scorepadRankLabel?.text = ""
                    bodyCell.scorepadSuitLabel?.text = ""
                }
                
                bodyCell.scorepadTopLineWeight.constant = thinLineWeight
                
                cell=bodyCell
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if self.gameMode == .scoring {
            return true
        } else {
            if collectionView.tag < 1000000 {
                let round = collectionView.tag + 1
                if (self.gameMode.isHosting || self.gameMode == .joining) && Scorecard.game!.dealHistory[round] != nil && (round < Scorecard.game!.handState.round || (round == Scorecard.game!.handState.round && Scorecard.game!.gameComplete())) {
                    return true
                } else if self.gameMode == .scoring {
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.tag >= 1000000 {
            // Header row tapped - edit last row
            Scorecard.game.selectedRound = Scorecard.game.maxEnteredRound
        } else {
            // Body row tapped
            let round = collectionView.tag+1
            if self.gameMode == .scoring {
                if round >= Scorecard.game.maxEnteredRound {
                    // Row which is not yet entered tapped - edit last row
                    Scorecard.game.selectedRound = Scorecard.game.maxEnteredRound
                  } else {
                    Scorecard.game.selectedRound = round
                }
            } else if self.gameMode.isHosting || self.gameMode == .joining {
                if self.gameDetailDelegate?.isVisible ?? false {
                    self.gameDetailDelegate?.refresh(activeView: .scorepad, round: round)
                } else {
                    self.controllerDelegate?.didInvoke(.review, context: ["round" : round])
                }
            }
        }
        if self.gameMode == .scoring {
            self.controllerDelegate?.didProceed(context: ["reeditMode" : Scorecard.game.roundComplete(Scorecard.game.selectedRound)])
            rotated = false
        }
    }
}
    
// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class ScorepadTableViewCell: UITableViewCell {
    
    @IBOutlet weak var scorepadCollectionView: UICollectionView!
    @IBOutlet private weak var scorepadLeftLine: UIView!
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        scorepadCollectionView.delegate = dataSourceDelegate
        scorepadCollectionView.dataSource = dataSourceDelegate
        scorepadCollectionView.tag = row
        if row < 1000000 {
            scorepadCollectionView.accessibilityIdentifier = "round\(row+1)"
        } else if row < 2000000 {
            scorepadCollectionView.accessibilityIdentifier = "header\(row+1)"
        } else {
            scorepadCollectionView.accessibilityIdentifier = "total"
        }
        scorepadCollectionView.reloadData()
    }
}

class ScorepadCollectionViewCell: UICollectionViewCell {

    var scorepadCellGradientLayer: CAGradientLayer!
    var scorepadCellPaddingGradientLayer: CAGradientLayer!
    var scorepadLeftLineGradientLayer: CAGradientLayer!
        
    @IBOutlet fileprivate weak var scorepadCellLabel: UILabel!
    @IBOutlet fileprivate weak var scorepadRankLabel: UILabel!
    @IBOutlet fileprivate weak var scorepadSuitLabel: UILabel!
    @IBOutlet fileprivate weak var scorepadFooterPadding: UIView!
    @IBOutlet fileprivate weak var scorepadLeftLineWeight: NSLayoutConstraint!
    @IBOutlet fileprivate weak var scorepadTopLineWeight: NSLayoutConstraint!
    @IBOutlet fileprivate weak var scorepadCellLabelHeight: NSLayoutConstraint!
    @IBOutlet fileprivate weak var scorepadImage: UIImageView!
    @IBOutlet fileprivate weak var scorepadDisc: UILabel!
    @IBOutlet fileprivate weak var scorepadLeftLine: UIView!
    @IBOutlet fileprivate weak var scorepadTopLine: UIView!
}


// MARK: - Enumerations ============================================================================ -

enum CellType {
    case bid
    case score
}

extension ScorepadViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.bannerLogoView.fillColor = Palette.bannerShadow.background
        self.bannerLogoView.strokeColor = Palette.banner.text
        self.bannerContinuation.backgroundColor = Palette.banner.background
        self.footerTableView.backgroundColor = Palette.total.background
        self.leftPaddingView.bannerColor = Palette.banner.background
        self.paddingViewLines.forEach { $0.backgroundColor = Palette.banner.background }
        self.paddingViewLines.forEach { $0.backgroundColor = Palette.banner.background }
        self.rightPaddingView.bannerColor = Palette.banner.background
        self.view.backgroundColor = Palette.normal.background
    }

    private func defaultCellColors(cell: ScorepadCollectionViewCell) {
        switch cell.reuseIdentifier {
        case "Body Collection Image Cell":
            cell.scorepadLeftLine.backgroundColor = Palette.grid.background
            cell.scorepadTopLine.backgroundColor = Palette.grid.background
        case "Body Collection Text Cell":
            cell.scorepadLeftLine.backgroundColor = Palette.grid.background
            cell.scorepadTopLine.backgroundColor = Palette.grid.background
            cell.scorepadRankLabel.textColor = Palette.banner.text
        case "Footer Collection Cell":
            cell.scorepadFooterPadding.backgroundColor = Palette.total.background
            cell.scorepadLeftLine.backgroundColor = Palette.total.background
            cell.scorepadTopLine.backgroundColor = Palette.grid.background
        case "Header Collection Cell":
            cell.scorepadCellLabel.textColor = Palette.emphasis.text
            cell.scorepadLeftLine.backgroundColor = Palette.banner.background
            cell.scorepadTopLine.backgroundColor = Palette.grid.background
        case "Header Collection Image Cell":
            cell.scorepadLeftLine.backgroundColor = Palette.banner.background
            cell.scorepadTopLine.backgroundColor = Palette.grid.background
        default:
            break
        }
    }

}

extension ScorepadViewController {
    
    internal func setupHelpView() {
        weak var weakSelf = self
        
        self.helpView.reset()
                
        self.helpView.add("This screen shows you a summary of the current score in the game.\n\nYou can tap on a row of the grid to \(weakSelf?.gameMode == .scoring ? "see details of that round" : "review the hands for that round").")
        
        self.helpView.add("The players are shown at the top of the grid. The current dealer is highlighted with a darker background", views: [self.headerTableView], verticalBorder: -0.5, radius: 0)
        
        let trickWith2 = (Scorecard.activeSettings.bonus2 ? "\nThe " + NSAttributedString(imageName: "two") + " image is shown beside the score if a trick was won with a 2." : NSAttributedString())
        self.helpView.add("\(weakSelf?.bodyColumns == 2 ? "The left hand column under each player shows the bid made by the player in each round. The right hand column" : "The value under each player") shows the score achieved for each round. The cell is shaded if the contract was made." + trickWith2, views: [self.bodyTableView], radius: 0, shrink: true, direction: .up)
        
        self.helpView.add("Totals for each player are shown at the bottom of the grid", views: [self.footerTableView], radius: 0)

        self.helpView.add("The {} takes you to the \(Scorecard.game.gameComplete() ? "@*/Game Summary@*/" : (weakSelf?.gameMode == .scoring || weakSelf?.gameMode == .viewing ? "@*/Score Entry@*/" : "@*/Hand Playing@*/")) screen", bannerId: self.scoreEntryButton)

        self.helpView.add("The {} abandons the game and takes you back to the @*/Home@*/ screen", bannerId: Banner.finishButton, horizontalBorder: 8, verticalBorder: 4)
        
    }
}
