//
//  PlayerDetailViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 13/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

enum DetailMode {
    case create
    case amend
    case display
    case download
    case downloaded
    case none
}

class PlayerDetailViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SyncDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Lines in view
    private enum Sections: Int, CaseIterable {
        case uniqueID = 0
        case lastPlayed = 1
        case records = 2
        case stats = 3
    }
    
    private enum UniqueIdOptions: Int, CaseIterable {
        case uniqueID = 0
        case deletePlayer = 1
    }
    
    private enum LastPlayedOptions: Int, CaseIterable {
        case lastPlayed = 0
    }
    
    private enum RecordsOptions: Int, CaseIterable {
        case totalScore = 0
        case bidsMade = 1
        case winStreak = 2
        case twosMade = 3
    }
    
    private enum StatsOptions: Int, CaseIterable {
        case played = 0
        case win = 1
        case winPercent = 2
        case total = 3
        case average = 4
    }
    
    // Main state properties
    private let scorecard = Scorecard.shared
    private var reconcile: Reconcile!
    private let sync = Sync()
    
    // Text field tags
    private let nameFieldTag = 0
    private let emailFieldTag = 1
    private let deleteButtonTag = 2

    // Properties to control how view works
    private var playerDetail: PlayerDetail!
    private var mode: DetailMode!
    private var sourceView: UIView!
    private var callerCompletion: ((PlayerDetail?, Bool)->())?
    
    // Local class variables
    private var emailOnEntry = ""
    private var actionSheet: ActionSheet!
    private var changed = false

    // Alert controller while waiting for cloud download
    private var cloudAlertController: UIAlertController!
    private var cloudIndicatorView: UIActivityIndicatorView!
    private var emailErrorLabel: UILabel? = nil
    private var emailCell: PlayerDetailCell!

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var footerPaddingView: UIView!
    @IBOutlet private weak var finishButton: UIButton!
    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var playerNameField: UITextField!
    @IBOutlet private weak var playerImageView: UIImageView!
    @IBOutlet private weak var playerErrorLabel: UILabel!
    @IBOutlet private weak var addImageLabel: UILabel!

    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func continueButtonPressed(_ sender: Any) {
        switch mode! {
        case .amend:
            // Update core data with any changes
            self.warnEmailChanged(completion: {
                if !CoreData.update(updateLogic: {
                    let playerMO = self.playerDetail.playerMO!
                    if playerMO.email != self.playerDetail.email {
                        // Need to rebuild as email changed
                        self.playerDetail.toManagedObject(playerMO: playerMO)
                        if Reconcile.rebuildLocalPlayer(playerMO: self.playerDetail.playerMO) {
                            self.playerDetail.fromManagedObject(playerMO: playerMO)
                        }
                    } else {
                        self.playerDetail.toManagedObject(playerMO: playerMO)
                    }
                }) {
                    self.alertMessage("Error saving player")
                }
            })
        case .create:
            // Player will be created in calling controller (selectPlayers)
            self.dismiss(playerDetail: self.playerDetail)
        case .download:
            self.getCloudPlayerDetails()
        case .downloaded:
            // No further action required
            self.dismiss(playerDetail: self.playerDetail)
        default:
            break
        }
    }
    
    @IBAction func backButtonPressed(_ sender: Any) {

        // Taking cancel option
        if self.mode != .display {
            playerDetail.name = ""
        }
        self.dismiss()

    }

    @IBAction func allSwipe(recognizer:UISwipeGestureRecognizer) {
        backButtonPressed(finishButton!)
    }
    
    @IBAction private func tapGesture(recognizer: UITapGestureRecognizer) {
        self.imageTapped()
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Store email on entry
        emailOnEntry = playerDetail.email
        
        // Setup player header fields
        self.setupHeaderFields()
               
        tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 0.0)
        
        enableButtons()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        switch self.mode! {
        case .download:
            // Set footer color
            footerPaddingView.backgroundColor = Palette.disabled
            
        default:
            break
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.updateHeaderFields()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        scorecard.reCenterPopup(self)
        if actionSheet != nil {
            scorecard.reCenterPopup(actionSheet.alertController)
        }
        self.view.setNeedsLayout()
    }

    // MARK: - TableView Overrides ===================================================================== -

    func numberOfSections(in tableView: UITableView) -> Int {
        if mode != .create {
            return Sections.allCases.count
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rows: Int
        
        switch Sections(rawValue: section)! {
        case .uniqueID:
            rows = UniqueIdOptions.allCases.count
        case .lastPlayed:
            rows = LastPlayedOptions.allCases.count
        case .records:
            rows = RecordsOptions.allCases.count
        case .stats:
            rows = StatsOptions.allCases.count
        }
        return rows
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        var height: CGFloat
        
        switch Sections(rawValue: section)! {
        case .uniqueID:
            height = 20.0
        default:
            height = 50.0
        }
        return height
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var header: PlayerDetailHeaderFooterView?
        
        if let section = Sections(rawValue: section) {
            var reuseIdentifier = "Header"
            var text: String
            
            switch section {
            case .uniqueID:
                reuseIdentifier = "Header Error"
                switch mode! {
                case .download:
                   text = "Unique ID of player to download"
                default:
                    text = "Unique ID - E.g. email"
                }
            case .lastPlayed:
                text = "Last played:"
            case .records:
                text = "Personal records:"
            case .stats:
                text = "Personal statistics:"
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as! PlayerDetailCell
            cell.headerLabel.text = text
            cell.headerErrorLabel?.text = ""
            header = PlayerDetailHeaderFooterView(cell)
                        
            if section == .uniqueID {
                self.emailErrorLabel = cell.headerErrorLabel
            }
        }
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat
        
        switch Sections(rawValue: indexPath.section)! {
        case .uniqueID:
            switch UniqueIdOptions(rawValue: indexPath.row)! {
            case .deletePlayer:
                height = 40.0
            default:
                height = 20.0
            }
        case .stats:
            switch StatsOptions(rawValue: indexPath.row)! {
            case .total:
                height = 40.0
            default:
                height = 20.0
            }
        default:
            height = 20.0
        }
        
        return height
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: PlayerDetailCell!
        
        switch Sections(rawValue: indexPath.section)! {
        case .uniqueID:
            switch UniqueIdOptions(rawValue: indexPath.row)! {
            case .uniqueID:
                cell = tableView.dequeueReusableCell(withIdentifier: "Unique ID", for: indexPath) as? PlayerDetailCell
                cell.uniqueIdField.text = playerDetail.email
                cell.uniqueIdField.tag = self.emailFieldTag
                cell.uniqueIdField.isSecureTextEntry = (self.mode != .create && self.mode != .download && self.mode != .downloaded)
                cell.uniqueIdField.attributedPlaceholder = NSAttributedString(string: "Unique identifier - must not be blank", attributes:[NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15.0, weight: .thin)])
                if self.mode == .display {
                    cell.uniqueIdField.isEnabled = false
                }
                self.addTargets(cell.uniqueIdField)
                self.emailCell = cell
                if mode == .download {
                    cell.uniqueIdField.becomeFirstResponder()
                }
                
            case .deletePlayer:
                cell = tableView.dequeueReusableCell(withIdentifier: "Action Button", for: indexPath) as? PlayerDetailCell
                if mode == .amend {
                    cell.actionButton.setTitle("Delete Player", for: .normal)
                    cell.actionButton.tag = self.deleteButtonTag
                    cell.actionButton.addTarget(self, action: #selector(PlayerDetailViewController.actionButtonPressed(_:)), for: .touchUpInside)
                }
            }
            
        case .lastPlayed:
            switch LastPlayedOptions(rawValue: indexPath.row)! {
            case .lastPlayed:
                cell = tableView.dequeueReusableCell(withIdentifier: "Single", for: indexPath) as? PlayerDetailCell
                if playerDetail.datePlayed != nil {
                    let formatter = DateFormatter()
                    formatter.dateStyle = DateFormatter.Style.full
                    cell.singleLabel.text = formatter.string(from: playerDetail.datePlayed)
                } else {
                    cell.singleLabel.text="Not played"
                }
            }
            
        case .records:
            cell = tableView.dequeueReusableCell(withIdentifier: "Record", for: indexPath) as? PlayerDetailCell
            
            switch RecordsOptions(rawValue: indexPath.row)! {
            case .totalScore:
                cell.recordDescLabel.text = "High score"
                cell!.recordValueLabel.text = "\(playerDetail.maxScore)"
                if playerDetail.maxScoreDate != nil {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd MMM yyyy"
                    cell!.recordDateLabel.text = formatter.string(from: playerDetail.maxScoreDate)
                } else {
                    cell!.recordDateLabel.text=""
                }
                
            case .bidsMade:
                cell.recordDescLabel.text = "Bids made"
                cell!.recordValueLabel.text = "\(playerDetail.maxMade)"
                if playerDetail.maxMadeDate != nil {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd MMM yyyy"
                    cell!.recordDateLabel.text = formatter.string(from: playerDetail.maxMadeDate)
                } else {
                    cell!.recordDateLabel.text=""
                }
                
            case .winStreak:
                cell.recordDescLabel.text = "Win streak"
                if let playerMO = playerDetail.playerMO, let email = playerMO.email {
                    let streaks = History.getWinStreaks(playerEmailList: [email])
                    if streaks.first?.streak ?? 0 == 0 {
                        cell?.recordValueLabel.text = "0"
                        cell?.recordDateLabel.text = ""
                    } else {
                        cell!.recordValueLabel.text = "\(streaks.first!.streak)"
                        if let participantMO = streaks.first?.participantMO {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "dd MMM yyyy"
                            cell!.recordDateLabel.text = formatter.string(from: participantMO.datePlayed!)
                        }
                    }
                } else {
                    cell?.recordValueLabel.text = "0"
                    cell?.recordDateLabel.text = ""
                }
                
            case .twosMade:
                cell.recordDescLabel.text = "Twos made"
                cell!.recordValueLabel.text = "\(playerDetail.maxTwos)"
                if playerDetail.maxTwosDate != nil {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd MMM yyyy"
                    cell!.recordDateLabel.text = formatter.string(from: playerDetail.maxTwosDate)
                } else {
                    cell!.recordDateLabel.text=""
                }
            }
            
        case .stats:
            cell = tableView.dequeueReusableCell(withIdentifier: "Stat", for: indexPath) as? PlayerDetailCell
            
            switch StatsOptions(rawValue: indexPath.row)! {
            case .played:
                cell.statDescLabel1.text = "Games played"
                cell.statValueLabel1.text = "\(playerDetail.gamesPlayed)"

                cell.statDescLabel2.text = "Hands played"
                cell.statValueLabel2.text = "\(playerDetail.handsPlayed)"

            case .win:
                cell.statDescLabel1.text = "Games won"
                cell.statValueLabel1.text = "\(playerDetail.gamesWon)"

                cell.statDescLabel2.text = "Hands made"
                cell.statValueLabel2.text = "\(playerDetail.handsMade)"

            case .winPercent:
                cell.statDescLabel1.text = "Win %"
                if CGFloat(playerDetail.gamesPlayed) == 0 {
                    cell.statValueLabel1.text = "0.0 %"
                } else {
                    let percent = (CGFloat(playerDetail.gamesWon) / CGFloat(playerDetail.gamesPlayed)) * 100
                    cell.statValueLabel1.text = "\(String(format: "%0.1f", percent)) %"
                }
                
                cell.statDescLabel2.text = "Made %"
                if playerDetail.handsPlayed == 0 {
                    cell.statValueLabel2.text = "0.0 %"
                } else {
                    let percent = (CGFloat(playerDetail.handsMade) / CGFloat(playerDetail.handsPlayed)) * 100
                    cell.statValueLabel2.text = "\(String(format: "%0.1f", percent)) %"
                }
                
            case .total:
                cell.statDescLabel1.text = "Total score"
                cell.statValueLabel1.text = "\(playerDetail.totalScore)"

                if self.scorecard.settingBonus2 {
                    cell.statDescLabel2.text = "Twos made"
                    cell.statValueLabel2.text = "\(playerDetail.twosMade)"
                } else {
                    cell.statDescLabel2.text = ""
                    cell.statValueLabel2.text = ""
                }
                
            case .average:
                cell.statDescLabel1.text = "Average score"
                if playerDetail.gamesPlayed == 0 {
                    cell.statValueLabel1.text = "0.0"
                } else {
                    let average = (CGFloat(playerDetail.totalScore) / CGFloat(playerDetail.gamesPlayed))
                    cell.statValueLabel1.text = "\(String(format: "%0.1f", average))"
                }

                if self.scorecard.settingBonus2 {
                    cell.statDescLabel2.text = "Twos made %"
                    if playerDetail.handsPlayed == 0 {
                        cell.statValueLabel2.text = "0.0 %"
                    } else {
                        let percent = (CGFloat(playerDetail.twosMade) / CGFloat(playerDetail.handsPlayed)) * 100
                        cell.statValueLabel2.text = "\(String(format: "%0.1f", percent)) %"
                    }
                } else {
                    cell.statDescLabel2.text = ""
                    cell.statValueLabel2.text = ""
                }
            }
        }
             
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.clear
        cell!.selectedBackgroundView = backgroundView
            
        return cell!
    }
       
    // MARK: - TextField and Button Control Overrides ======================================================== -
    
    private func addTargets(_ textField: UITextField) {
        textField.addTarget(self, action: #selector(PlayerDetailViewController.textFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        textField.addTarget(self, action: #selector(PlayerDetailViewController.textFieldShouldReturn(_:)), for: UIControl.Event.editingDidEndOnExit)
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        self.changed = true
        switch textField.tag {
        case self.nameFieldTag:
            // Name
            playerDetail.name = textField.text!
            playerDetail.nameDate = Date()
        case self.emailFieldTag:
            // Email
            playerDetail.email = textField.text!
            playerDetail.emailDate = Date()
        default:
            break
        }
        self.enableButtons()
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == self.nameFieldTag && textField.text == "" {
            // Don't allow blank name
            return false
        } else if mode == .download && textField.tag == self.emailFieldTag {
            if textField.text == "" {
                // Don't allow blank email in download mode
                return false
            } else {
                // Press the 'check' button
                self.getCloudPlayerDetails()
            }
        } else {
            // Try to move to next text field - resign if none found
            if textField.tag == self.nameFieldTag {
                emailCell.uniqueIdField.becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }
        return true
    }

    @objc func actionButtonPressed(_ button: UIButton) {
        switch button.tag {
        case self.deleteButtonTag:
            self.checkDeletePlayer()
        default:
            break
        }
    }

   // MARK: - Image Picker Routines / Overrides ============================================================ -

    private func imageTapped() {
        let actionSheet = ActionSheet("Thumbnail Image", message: "\(playerDetail.thumbnail == nil ? "Add a" : "Replace") thumbnail image for this player", view: sourceView)
        actionSheet.add("Take Photo", handler: {
                self.getPicture(from: .camera)
            })
        actionSheet.add("Use Photo Library",handler: {
                self.getPicture(from: .photoLibrary)
            })
        if playerDetail.thumbnail != nil {
            actionSheet.add("Remove Photo", handler: {
                self.removeImage()

            })
        }
        actionSheet.add("Cancel", style: .cancel, handler:nil)
        actionSheet.present()
    }
    
    private func getPicture(from: UIImagePickerController.SourceType) {
       if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.allowsEditing = false
            imagePicker.sourceType = from
            
            present(imagePicker, animated: true, completion: nil)
        }
    }
    
    internal func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        
        if let selectedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage {
            var rotatedImage:UIImage
            
            self.playerImageView!.image = selectedImage
            
            if let rawImage = self.playerImageView!.image {
                rotatedImage = rotateImage(image: rawImage)
                if let imageData = rotatedImage.pngData() {
                    playerDetail.thumbnail  = Data(imageData)
                    playerDetail.thumbnailDate = Date()
                }
                self.playerImageView!.image = rotatedImage
            }
            self.playerImageView!.contentMode = .scaleAspectFill
            self.playerImageView!.clipsToBounds = true
            self.playerImageView!.alpha = 1.0
            self.changed = true
            self.enableButtons()
            
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func rotateImage(image: UIImage) -> UIImage {
        
        if (image.imageOrientation == UIImage.Orientation.up ) {
            return image
        }
        
        UIGraphicsBeginImageContext(image.size)
        
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))
        let copy = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return copy!
    }
    
    func removeImage() {
        playerDetail.thumbnail = nil
        playerDetail.thumbnailDate = nil
        if mode == .create || mode == .amend {
            self.playerImageView!.image = UIImage(named: "camera")
        }
        self.playerImageView!.contentMode = .center
        self.playerImageView!.backgroundColor = Palette.disabled
        ScorecardUI.veryRoundCorners(self.playerImageView!)
        self.playerImageView!.clipsToBounds = false
        self.playerImageView!.alpha = 0.5
        self.view.bringSubviewToFront(self.addImageLabel)
        self.changed = true
        self.enableButtons()
    }
    
    // MARK: - Sync routines including the delegate methods ======================================== -
    
    func getCloudPlayerDetails() {
        
        self.cloudAlertController = UIAlertController(title: title, message: "Downloading player from Cloud\n\n\n\n", preferredStyle: .alert)
        
        self.sync.delegate = self
        if self.sync.synchronise(syncMode: .syncGetPlayerDetails, specificEmail: [playerDetail.email], waitFinish: false) {
            
            //add the activity indicator as a subview of the alert controller's view
            self.cloudIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 100,
                                                                width: self.cloudAlertController.view.frame.width,
                                                                height: 100))
            self.cloudIndicatorView.style = .whiteLarge
            self.cloudIndicatorView.color = UIColor.black
            self.cloudIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.cloudAlertController.view.addSubview(self.cloudIndicatorView)
            self.cloudIndicatorView.isUserInteractionEnabled = true
            self.cloudIndicatorView.startAnimating()
            
            self.present(self.cloudAlertController, animated: true, completion: nil)
            
        } else {
            self.alertMessage("Error getting player details from iCloud")
            self.actionButton.isHidden = true
        }
    }
    
    func getImages(_ imageFromCloud: [PlayerMO]) {
        self.sync.fetchPlayerImagesFromCloud(imageFromCloud)
    }
    
    internal func syncAlert(_ message: String, completion: @escaping ()->()) {
        Utility.mainThread {
            self.cloudAlertController.dismiss(animated: true, completion: {
                self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
                    self.actionButton.isHidden = true
                    completion()
                })
            })
        }
    }
    
    internal func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
        
        Utility.mainThread {
            self.cloudAlertController.dismiss(animated: true, completion: {
                if playerList != nil && playerList.count > 0 {
                    self.playerDetail = playerList[0]
                    self.mode = .downloaded
                    self.navigationBar.topItem?.title = self.playerDetail.name
                    self.footerPaddingView.backgroundColor = Palette.background
                    self.tableView.isUserInteractionEnabled = false
                    self.enableButtons()
                    self.updateHeaderFields()
                    self.tableView.reloadData()
                    
                } else {
                    self.alertMessage("Unable to download player from Cloud", buttonText: "Continue", okHandler:
                        {
                            self.actionButton.isHidden = true
                    })
                }
            })
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func enableButtons() {
        var finishTitle = ""
        var invalid: Bool
        
        let duplicateName = scorecard.isDuplicateName(playerDetail)
        let duplicateEmail = scorecard.isDuplicateEmail(playerDetail)
        
        switch mode! {
        case .amend, .create:
            invalid = duplicateName || duplicateEmail || playerDetail.name == "" || playerDetail.email == ""
        case .download:
            invalid = (playerDetail.email == "" || duplicateEmail)
        default:
            invalid = false
        }
        
        if invalid {
            finishTitle = "Cancel"
        } else if (mode == .amend && self.changed) || mode == .create {
            finishTitle = "Cancel"
        } else {
            finishTitle = ""
        }
        finishButton.setTitle(finishTitle, for: .normal)
        
        switch mode! {
        case .amend:
            actionButton.isHidden = (!self.changed || invalid)
            actionButton.setTitle("Save", for: .normal)
        case .create:
            actionButton.isHidden = invalid
            actionButton.setTitle("Create", for: .normal)
        case .download:
            actionButton.isHidden = invalid
            actionButton.setTitle("Check", for: .normal)
        case .downloaded:
            actionButton.isHidden = false
            actionButton.setTitle("Add", for: .normal)
        default:
            actionButton.isHidden = true
        }
        
        switch mode {
        case .create, .amend:
            self.addImageLabel.text = (self.playerDetail.thumbnail == nil ? "Tap camera to\nadd photo" : "Tap photo to\nchange")
        default:
            self.addImageLabel.isHidden = true
        }
        
        self.playerErrorLabel.text = (duplicateName ? "Duplicate not allowed" : "")
        
        self.emailErrorLabel?.text = (duplicateEmail ? (mode == .download ? "Already on device" : "Duplicate not allowed") : "")
    }
    
    // MARK: - Utility Routines ======================================================================== -

    func setupHeaderFields() {
        navigationBar.topItem?.title = playerDetail.name
        switch self.mode! {
        case .create:
            // Smaller input
            navigationBar.topItem?.title = "New Player"
            
        case .download:
            // Switch name and email
            navigationBar.topItem?.title = "Download"
        
        default:
            break
        }
        
        self.playerNameField.tag = nameFieldTag
        self.addTargets(self.playerNameField)
        var placeholder: String
        switch mode! {
        case .create, .amend:
            placeholder = "Player name - Must not be blank"
        default:
            placeholder = "Player name"
        }
        self.playerNameField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes:[NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20.0, weight: .thin)])
        self.playerNameField.isEnabled = (mode == .create || mode == .amend)
        if mode == .create {
            self.playerNameField.becomeFirstResponder()
        }
        
        if mode != .create && mode != .amend {
            self.playerImageView.isUserInteractionEnabled = false
        }
    }
    
    func updateHeaderFields() {
        self.playerNameField.text = playerDetail.name
        if let thumbnail = self.playerDetail.thumbnail {
            Utility.setThumbnail(data: thumbnail,imageView: self.playerImageView)
        } else {
            self.removeImage()
        }
    }
    
    func checkDeletePlayer() {
        var alertController: UIAlertController
        alertController = UIAlertController(title: "Warning", message: "This will remove the player \n'\(playerDetail.name)'\nfrom this device.\n\nIf you are synchronising with iCloud the player will still be available to download in future.\n Otherwise this will remove their details permanently.\n\n Are you sure you want to do this?", preferredStyle: UIAlertController.Style.alert)
        
        alertController.addAction(UIAlertAction(title: "Confirm", style: UIAlertAction.Style.default,
                                                handler: { (action:UIAlertAction!) -> Void in
            
            // Update core data with any changes
            self.playerDetail.deleteMO()

            // Remove this player from list of subscriptions
            Notifications.updateHighScoreSubscriptions()

            // Delete any detached games
            History.deleteDetachedGames()

            // Flag as deleted and return
            self.dismiss(playerDetail: self.playerDetail, deletePlayer: true)
                                                    
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler:nil))
        present(alertController, animated: true, completion: nil)
    }
    
    func warnEmailChanged(completion: (()->())? = nil) {
        if self.playerDetail.name != "" && self.emailOnEntry != "" && self.emailOnEntry != self.playerDetail.email {
            self.alertDecision("If you change a player's unique ID this will separate them from their game history. Essentially this is the same as deleting the player and creating a new one.\n\nAre you sure you want to do this?", title: "Warning",
            okHandler: {
                completion?()
                self.dismiss(playerDetail: self.playerDetail)
            },
            cancelHandler: {
            })
        } else {
            completion?()
            self.dismiss(playerDetail: self.playerDetail)
        }
    }
    
    // MARK: - method to show this view controller ============================================================================== -
    
    static public func show(from sourceViewController: CustomViewController, playerDetail: PlayerDetail, mode: DetailMode, sourceView: UIView, completion: ((PlayerDetail?,Bool)->())? = nil) {
        let storyboard = UIStoryboard(name: "PlayerDetailViewController", bundle: nil)
        let playerDetailViewController = storyboard.instantiateViewController(withIdentifier: "PlayerDetailViewController") as! PlayerDetailViewController

        playerDetailViewController.preferredContentSize = CGSize(width: 400, height: 600)

        playerDetailViewController.playerDetail = playerDetail
        playerDetailViewController.mode = mode
        playerDetailViewController.sourceView = sourceView
        playerDetailViewController.callerCompletion = completion
        
        sourceViewController.present(playerDetailViewController, sourceView: sourceView, animated: true, completion: nil)
    }
    
    private func dismiss(playerDetail: PlayerDetail? = nil, deletePlayer: Bool = false) {
        self.dismiss(animated: true, completion: {
            self.callerCompletion?(playerDetail, deletePlayer)
        })
    }
    

}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class PlayerDetailCell: UITableViewCell {
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var headerErrorLabel: UILabel!
    @IBOutlet weak var uniqueIdField: UITextField!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var singleLabel: UILabel!
    @IBOutlet weak var recordDescLabel: UILabel!
    @IBOutlet weak var recordValueLabel: UILabel!
    @IBOutlet weak var recordDateLabel: UILabel!
    @IBOutlet weak var statDescLabel1: UILabel!
    @IBOutlet weak var statValueLabel1: UILabel!
    @IBOutlet weak var statDescLabel2: UILabel!
    @IBOutlet weak var statValueLabel2: UILabel!
}

class PlayerDetailHeaderFooterView: UITableViewHeaderFooterView {
   
    public var cell: PlayerDetailCell!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    convenience init?(_ cell: PlayerDetailCell, reuseIdentifier: String? = nil) {
        let frame = CGRect(origin: CGPoint(), size: cell.frame.size)
        self.init(reuseIdentifier: reuseIdentifier)
        cell.frame = frame
        self.cell = cell
        self.addSubview(cell)
    }
    
    override func layoutSubviews() {
        let frame = CGRect(origin: CGPoint(), size: self.frame.size)
        cell.frame = frame
    }
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
