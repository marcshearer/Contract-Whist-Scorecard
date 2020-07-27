 //
//  Scoring Controller Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 07/06/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import Combine
 
class ScoringController: ScorecardAppController, ScorecardAppPlayerDelegate, GamePreviewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    private var selectedPlayers: [PlayerMO]!
        
    private weak var selectionViewController: SelectionViewController!
    private weak var gamePreviewViewController: GamePreviewViewController!
    private weak var entryViewController: EntryViewController?
    
    private var sharingService: CommsClientServiceDelegate?
    private var completion: ((Bool)->())?
    private var gameInProgress = false
    private var canStartGame: Bool = true
    private var lastMessage: String = ""
    private var recoveryMode: Bool = false    // Recovery mode as defined by where weve come from (largely ignored)
        
    // MARK: - Constructor ========================================================================== -
    
    init(from parentViewController: ScorecardViewController) {
        super.init(from: parentViewController, type: .scoring)
    }
    
    public func start(recoveryMode: Bool = false, completion: ((Bool)->())? = nil) {
    
        super.start()
        
        // Start sharing service
        Scorecard.shared.setupSharing()
        
        // Save completion handler and mode
        self.recoveryMode = recoveryMode
        self.completion = completion
        
        if self.recoveryMode {
            
            // Restore players
            self.resetResumedPlayers()
            
            // Just go straight to scoring without preview
            self.gameInProgress = true
            self.startGame()
        } else {
            // Show selection
            self.present(nextView: .selection)
        }
    }
    
    override public func stop() {
        
        Scorecard.shared.stopSharing()
        super.stop()
    }
    
    // MARK: - App Controller Overrides =========================================================== -
     
    override internal func refreshView(view: ScorecardView) {
        
    }
    
    override internal func presentView(view: ScorecardView, context: [String:Any?]?, completion: (([String:Any?]?)->())?) -> ScorecardViewController? {
        var viewController: ScorecardViewController?
        
        switch view {
        case .selection:
            viewController = self.showSelection()
            
        case .gamePreview:
            viewController = self.showGamePreview(selectedPlayers: self.selectedPlayers)
            
        case .location:
            viewController = self.showLocation()
            
        case .entry:
            let reeditMode = context?["reeditMode"] as? Bool ?? false
            viewController = self.showEntry(reeditMode: reeditMode)
            
        case .scorepad:
            viewController = self.showScorepad(scorepadMode: .scoring)
            
        case .roundSummary:
            viewController = self.showRoundSummary()
            
        case .gameSummary:
            viewController = self.showGameSummary(mode: .scoring)
            
        case .confirmPlayed:
            viewController = self.showConfirmPlayed(context: context, completion: completion)
                
        case .highScores:
            viewController = self.showHighScores()
            
        case .overrideSettings:
            viewController = self.showOverrideSettings()
            
        case .selectPlayers:
            viewController = self.showSelectPlayers(completion: completion)
        
        case .exit:
            self.exitScoring()
            
        default:
            break
        }
        return viewController
    }
    
    override internal func didDismissView(view: ScorecardView, viewController: ScorecardViewController?) {
        // Tidy up after view dismissed
        
        switch self.activeView {
        case .gamePreview:
            self.gamePreviewViewController.selectedPlayersView.delegate = nil
            self.gamePreviewViewController.controllerDelegate = nil
            self.gamePreviewViewController.delegate = nil
            self.gamePreviewViewController = nil
           
        default:
            break
        }
    }
     
     // MARK: - View Delegate Handlers  =================================================== -
     
     override internal var canProceed: Bool {
         get {
             var canProceed = true
             switch self.activeView {
             case .gamePreview:
                canProceed = self.canStartGame
                 
             case .scorepad:
                canProceed = true
                
             default:
                 break
             }
             return canProceed
                 
         }
     }
     
     override internal var canCancel: Bool {
         get {
             var canCancel = true
             switch self.activeView {
             case .scorepad:
                canCancel = !Scorecard.game.gameComplete()
                
             default:
                 break
             }
             return canCancel
                 
         }
     }
     
     override internal func didLoad() {
         switch self.activeView {
         default:
             break
         }
     }
     
     override internal func didAppear() {
         switch self.activeView {
         default:
             break
         }
     }
     
    override internal func didCancel() {
        switch self.activeView {
        case .selection:
            self.present(nextView: .exit)
            
        case .gamePreview:
            self.gameInProgress = false
            self.present(nextView: .selection)
            
        case .location:
            // Link back to game preview
            self.present(nextView: .exit)
            
        case .entry:
            // Link to scorepad
            self.present(nextView: .scorepad)
            
        case .roundSummary:
            // Link to scorepad
            self.present(nextView: .entry)
            
        case .scorepad:
            // Exit - game abandoned
            self.present(nextView: .exit)
            
        case .gameSummary:
            // Go back to scorepad
            self.present(nextView: .scorepad)
            
        default:
            break
        }
     }
     
    override internal func didProceed(context: [String:Any]?) {
        switch self.activeView {
        case .selection:
            // Set up comms connection and then send invitations
            self.lastMessage = ""
            _ = self.statusMessage()
            self.sendPlayers()
            self.present(nextView: .gamePreview)

        case .gamePreview:
            // Start the new game
            self.newGame()
            self.startGame()
            
        case .location:
        // Got location - show hand
            Scorecard.recovery.saveLocationAndDate()
            self.present(nextView: .entry)
            
        case .entry:
            // Link to the round summary or game summary
            self.entryComplete()
                    
        case .gameSummary:
            // Game complete
            self.gameComplete(context: context)
            
        case .scorepad:
            // Link to entry unless game is complete and pressed button
            let reeditMode = context?["reeditMode"] as? Bool ?? false
            if Scorecard.game.gameComplete() && !reeditMode {
                self.present(nextView: .gameSummary)
            } else {
                self.present(nextView: .entry, context: context)
            }
            
        default:
            break
        }
    }
     
    private func newGame() {
        Scorecard.game.resetValues()
        Scorecard.game.datePlayed = Date()
        Scorecard.game.gameUUID = UUID().uuidString
        Scorecard.recovery.saveLocationAndDate()
        Scorecard.recovery.saveOverride()
    }
    
    func startGame() {
        self.setupPlayers()
        Scorecard.shared.saveMaxScores()
        Scorecard.recovery.saveInitialValues()
        _ = self.statusMessage()
        
        // Link to entry or location
        if Scorecard.game.gameComplete() {
            self.present(nextView: .gameSummary)
        } else if Scorecard.activeSettings.saveLocation &&
             (Scorecard.game.location.description == nil || Scorecard.game.location.description == "" ||
                 !Scorecard.game.roundStarted(1)) {
            self.present(nextView: .location)
        } else {
            self.present(nextView: .entry)
        }
        
        Scorecard.shared.sendScoringState(from: self)
        
        // Do a background partial sync
        Scorecard.shared.syncBeforeGame(allPlayers: true)
    }
    
    private func sendPlayers() {
        // Send updated players to update the preview (prior to the game starting)
        if !self.gameInProgress {
            Scorecard.shared.sendPlayers(from: self)
            Scorecard.shared.sendDealer()
        }
        _ = self.statusMessage()
    }
    
    private func refreshPlayers() {
        self.gamePreviewViewController?.selectedPlayers = self.selectedPlayers
        self.gamePreviewViewController?.refreshPlayers()
        _ = self.statusMessage()
    }
    
    private func statusMessage() -> String {
        var message: String
        var remoteMessage: String?
        if self.canStartGame {
            message = "Ready to start game"
            remoteMessage = "Waiting for the scorer\nto start the game"
        } else {
            message = "Waiting for players\nto be selected"
        }
        remoteMessage = remoteMessage ?? message
        if remoteMessage != lastMessage {
            Scorecard.shared.sendStatus(message:remoteMessage!)
            lastMessage = remoteMessage!
        }
        
        return message
    }
    
    // MARK: - Controller player overrides =========================================================== -
    
    func currentPlayers() -> [(playerUUID: String, name: String, connected: Bool)]? {
        var players: [(playerUUID: String, name: String, connected: Bool)]?
        
        if !Scorecard.game.inProgress {
            players = self.selectedPlayers!.map { (playerUUID: $0.playerUUID!, name: $0.name!, connected: true ) }
        }
        
        return players
    }
 
    // MARK: - Enter scores ========================================================================== -
    
    private func showEntry(reeditMode: Bool = false) -> ScorecardViewController? {
           
        Scorecard.game.setGameInProgress(true)

        if let parentViewController = self.parentViewController {
            self.entryViewController = EntryViewController.show(from: parentViewController, appController: self, existing: self.entryViewController, reeditMode: reeditMode)
        }
        
        return self.entryViewController
    }
    
    private func entryComplete() {
        if Scorecard.game.gameComplete() {
            // Game complete
            _ = Scorecard.game.save()
            self.present(nextView: .gameSummary)
        } else {
            // Not complete - move to next round and go to scorepad
            let round = Scorecard.game!.selectedRound
            if Scorecard.game.roundComplete(round) && round != Scorecard.game.rounds && round >= Scorecard.game.maxEnteredRound {
                // Reset state and prepare for next round
                self.nextHand()
                self.present(nextView: .scorepad)
            } else {
                self.present(nextView: .roundSummary)
            }
        }
    }
    
    private func nextHand() {
        if Scorecard.game.selectedRound != Scorecard.game.rounds {
            Scorecard.game!.selectedRound += 1
            Scorecard.game.maxEnteredRound = Scorecard.game!.selectedRound
        }
    }
    
    private func gameComplete(context : [String:Any]!) {
        let mode = context["mode"] as? GameSummaryReturnMode ?? .returnHome
        let advanceDealer = context["advanceDealer"] as? Bool ?? true
        let resetOverrides = context["resetOverrides"] as? Bool ?? true
        
        Scorecard.shared.exitScorecard(advanceDealer: advanceDealer, resetOverrides: resetOverrides) {
            if mode == .newGame {
                self.newGame()
                self.startGame()
            } else {
                self.present(nextView: .exit)
            }
        }
    }

    // MARK: - Game Preview Delegate handlers ============================================================================== -
    
    internal let gamePreviewHosting: Bool = false
    
    internal var gamePreviewWaitMessage: NSAttributedString {
        get {
            return NSAttributedString(string: self.statusMessage())
        }
    }
    
    internal func gamePreview(isConnected playerMO: PlayerMO) -> Bool {
        return true
    }
    
    internal func gamePreview(disconnect playerMO: PlayerMO) {
    }
    
    internal func gamePreview(moved playerMO: PlayerMO, to slot: Int) {
        if let currentSlot = self.playerIndexFor(playerUUID: playerMO.playerUUID) {
            let keepPlayer = self.selectedPlayers[slot]
            self.selectedPlayers[slot] = self.selectedPlayers[currentSlot]
            self.selectedPlayers[currentSlot] = keepPlayer
        }
        self.sendPlayers()
    }
     
    // MARK: - Show / refresh / hide other views ==================================================== -
    
    private func showSelection() -> ScorecardViewController {
        if let viewController = self.fromViewController() {
            self.selectionViewController = SelectionViewController.show(from: viewController, appController: self, existing: self.selectionViewController, mode: .players, formTitle: "Choose Players", smallFormTitle: "Select", backText: "", backImage: "home",
                                                                        completion:
                { [weak self] (returnHome, selectedPlayers) in
                    // Returned values coming back from select players. Just store them - should get a didProceed immediately after
                    self?.selectedPlayers = selectedPlayers
            })
        }
        return self.selectionViewController
    }
    
    private func showGamePreview(selectedPlayers: [PlayerMO]) -> ScorecardViewController? {
        
        if let viewController = self.fromViewController() {
            self.gamePreviewViewController = GamePreviewViewController.show(from: viewController, appController: self, selectedPlayers: selectedPlayers, formTitle: "Score a Game", smallFormTitle: "Score", backText: "", readOnly: false, animated: !self.recoveryMode, delegate: self)
        }
        return self.gamePreviewViewController
    }
    
    // MARK: - Utility Routines ======================================================================== -
        
    private func playerIndexFor(playerUUID: String?) -> Int? {
         return self.selectedPlayers.firstIndex(where: {$0.playerUUID == playerUUID})
    }
    
    private func setupPlayers() {
        Scorecard.game.saveSelectedPlayers(self.selectedPlayers)
    }
    
    private func resetResumedPlayers() {
        // Run round player list trying to patch in players from last time
        selectedPlayers = []
        for playerNumber in 1...Scorecard.game.currentPlayers {
            let playerUri = Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO!.uri
            if playerUri != "" {
                if let playerMO = Scorecard.shared.playerList.first(where: { $0.uri == playerUri} ) {
                    selectedPlayers.append(playerMO)
                }
            }
        }
    }
    
    public func exitScoring() {
        let completion = self.completion
        self.completion = nil
        completion?(true)
    }
}
