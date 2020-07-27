//
//  Awards.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 16/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

fileprivate enum Source {
    case player
    case current
    case round(_ sourceRound: SourceRound)
    case awards
}

fileprivate enum SourceRound {
    case maximum
    case last
    case specific(_ round: Int)
}

fileprivate protocol Datasource {
    func value(forKey: String) -> Any?
}

fileprivate enum Comparison {
    case less
    case lessOrEqual
    case equal
    case greaterOrEqual
    case greater
}

fileprivate enum WinLose {
    case win
    case lose
    case any
}

fileprivate enum AwardNameItem {
    case name
    case shortName
    case title
    case description
}

fileprivate struct AwardNameConfig {
    private let name: String?
    private let shortName: String?
    private let title: String?
    private let description: String?
    
    init(name: String? = nil, shortName: String? = nil, title: String? = nil, description: String? = nil) {
        self.name = name
        self.shortName = shortName
        self.title = title
        self.description = description
    }
    
    fileprivate func value(for item: AwardNameItem) -> String? {
        switch item {
            case .name:          return self.name
            case .shortName:     return self.shortName
            case .title:         return self.title
            case .description:   return self.description ?? self.title
        }
    }
}

fileprivate struct AwardConfig {
    fileprivate let code: String
    private let nameConfig: AwardNameConfig
    private let levelNameConfig: [Int: AwardNameConfig]
    fileprivate let awardLevels: [Int]
    fileprivate let repeatable: Bool
    fileprivate let compare: Comparison?
    fileprivate let source: Source?
    fileprivate let key: String?
    fileprivate let custom: (([ParticipantMO])->Int)?
    fileprivate let winLose: WinLose
    fileprivate let imageName: String
    fileprivate let backgroundColor: UIColor
    fileprivate let backgroundImageName: String?
    fileprivate let condition: (()->Bool)?
    
    fileprivate init(code: String, name: String, shortName: String, title: String, description: String? = nil, awardLevels: [Int], repeatable: Bool = true, compare: Comparison? = nil, source: Source? = nil, key: String? = nil, custom: (([ParticipantMO])->Int)? = nil, winLose: WinLose = .any, imageName: String, backgroundColor: UIColor = Palette.darkHighlight, backgroundImageName: String? = nil, condition: (()->Bool)? = nil, overrides: [Int : AwardNameConfig]? = nil) {
        self.code = code
        self.nameConfig = AwardNameConfig(name: name, shortName: shortName, title: title, description: description)
        self.awardLevels = awardLevels
        self.repeatable = repeatable
        self.compare = compare
        self.source = source
        self.key = key
        self.custom = custom
        self.winLose = winLose
        self.imageName = imageName
        self.backgroundColor = backgroundColor
        self.backgroundImageName = backgroundImageName
        self.condition = condition
        self.levelNameConfig = overrides ?? [:]
    }
    
    private func value(for item: AwardNameItem, level: Int? = nil) -> String {
        var result = self.nameConfig.value(for: item)!
        if let level = level {
            if let levelValue = self.levelNameConfig[level]?.value(for: item) {
                result = self.substitute(levelValue, level)
            } else {
                result = self.substitute(result, level)
            }
        }
        return result
    }
    
    fileprivate func name(level: Int? = nil) -> String {
        return value(for: .name, level: level)
    }
    
    fileprivate func shortName(level: Int? = nil) -> String {
        return value(for: .shortName, level: level)
    }
    
    fileprivate func title(level: Int? = nil) -> String {
        return value(for: .title, level: level)
    }
    
    fileprivate func description(level: Int? = nil) -> String {
        return value(for: .description, level: level)
    }
    
    fileprivate func imageName(level: Int) -> String {
        return self.substitute(self.imageName, level)
    }

    private func substitute(_ stringValue: String, _ level: Int) -> String {
        if stringValue.contains("%d") {
            return stringValue.replacingOccurrences(of: "%d", with: "\(level)")
        } else {
            return stringValue
        }
    }
    
}

public struct Award {
    let code: String
    let awardLevel: Int
    let name: String
    let shortName: String
    let title: String
    let description: String
    let imageName: String
    let backgroundColor: UIColor
    let backgroundImageName: String?
    let gameUUID: String?
    let dateAwarded: Date?
    let count: Int
    
    fileprivate init(from awardMO: AwardMO, config: [AwardConfig]) {
        let config = config.first(where: {$0.code == awardMO.code})!
        self.init(from: config, awardLevel: Int(awardMO.awardLevel), gameUUID: awardMO.gameUUID!, dateAwarded: awardMO.dateAwarded!, count: Int(awardMO.count))
    }
    
    fileprivate init(from config: AwardConfig, awardLevel: Int, gameUUID: String? = nil, dateAwarded: Date? = nil, count: Int = 0) {
        self.code = config.code
        self.awardLevel = awardLevel
        self.name = config.name(level: awardLevel)
        self.shortName = config.shortName(level: awardLevel)
        self.title = config.title(level: awardLevel)
        self.description = config.description(level: awardLevel)
        self.imageName = config.imageName(level: awardLevel)
        self.backgroundColor = config.backgroundColor
        self.backgroundImageName = config.backgroundImageName ?? "awards background"
        self.gameUUID = gameUUID
        self.dateAwarded = dateAwarded
        self.count = count
    }
}

public class Awards {
    
    private var config: [AwardConfig] = []
    private var current: ParticipantMO?
    private var playerUUID: String?
    private var achieved: [AwardMO]?
    
    init() {
        self.setupConfig()
    }
    
    /// Get a players achieved and as yet unachieved awards
    /// - Parameter playerUUID: Player UUID
    /// - Returns: a tuple containing an array of achieved awards and an array of awards still to achieve
    public func get(playerUUID: String) -> (achieved: [Award], toAchieve: [Award], totalAwards: Int) {
        let playerAchieved = self.getAchieved(playerUUID: playerUUID)
        var toAchieve: [Award] = []
        for config in self.config {
            for awardLevel in config.awardLevels {
                if self.hasAchieved(playerAchieved, code: config.code, awardLevel: awardLevel) == nil {
                    toAchieve.append(Award(from: config, awardLevel: awardLevel))
                    break
                }
            }
        }
        let achieved = playerAchieved.map{Award(from: $0, config: self.config)}
        let totalAwards = self.config.reduce(0, {$0 + $1.awardLevels.count})
        
        return (achieved, toAchieve, totalAwards)
    }
    
    /// Get achieved awards for a player
    /// - Parameter playerUUID: Player UUID
    /// - Returns: Array of managed objects for awards
    public func getAchieved(playerUUID: String) -> [AwardMO] {
        if playerUUID != self.playerUUID || self.achieved == nil {
            self.achieved = CoreData.fetch(from: "Award", filter: NSPredicate(format: "playerUUID = %@", playerUUID), sort: ("dateAwarded", .descending)) as? [AwardMO]
            if self.achieved?.isEmpty ?? true {
                let achieved = self.defaultAchieved(playerUUID: playerUUID)
                self.save(playerUUID: playerUUID, achieved: achieved.map{Award(from: $0, config: self.config)})
                self.achieved = achieved
            }
            self.playerUUID = playerUUID
        }
        return self.achieved!
    }
    
    /// Get a specific achieved award
    /// - Parameters:
    ///   - playerUUID: Player UUID
    ///   - code: Award code
    ///   - AwardLevel: Award level
    /// - Returns: Award managed object
    public static func get(playerUUID: String, code: String, awardLevel: Int) -> AwardMO? {
        let awards = CoreData.fetch(from: "Award", filter: NSPredicate(format: "playerUUID = %@ and code = %@ and awardLevel = %@", playerUUID, code, awardLevel)) as? [AwardMO]
        return awards?.first
    }
    
    /// Returns an array of award levels still to be achieved for an award code for a given player
    /// - Parameters:
    ///   - playerUUID: Player UUID
    ///   - code: Award code
    /// - Returns: An array of award levels
    public func toAchieve(playerUUID: String, code: String) -> [Int] {
        var result: [Int] = []
        let achieved = self.getAchieved(playerUUID: playerUUID)
        if let config = self.config.first(where: {$0.code == code}) {
            for awardLevel in config.awardLevels {
                if self.hasAchieved(achieved, code: code, awardLevel: awardLevel) == nil {
                    result.append(awardLevel)
                }
            }
        }
        return result
    }
    
    /// Returns an array of awards that have been achieved in the current game and recent history for a player
    /// - Parameter playerUUID: Player UUID
    /// - Returns: Array of awards just achieved
    public func calculate(playerUUID: String) -> [Award] {
        var results: [Award] = []
        let achieved = self.getAchieved(playerUUID: playerUUID)
        var justAwarded = 0
        
        if let player = Scorecard.game.player(playerUUID: playerUUID),
           let current = player.participantMO {
            
            // Get history
            let history = self.getHistory(current: current)
            
            // Scan the available awards
            for config in self.config {
                
                // Check win/ lose
                if (config.winLose == .win && current.place != 1) || (config.winLose == .lose && current.place == 1) {
                    self.debugMessage(config: config, message: "Not a \(config.winLose)")
                    continue
                }
                
                // Get comparison value
                if let value = self.getValue(config: config, current: current, player: player, history: history, awarded: achieved.count + justAwarded) {
                
                    // Check against threshold awardLevels
                    if let awardLevel = self.checkAwardLevels(config: config, value: value) {
                        
                        let awardMO = achieved.first(where: {$0.code == config.code && $0.awardLevel == awardLevel})
                        
                        if !config.repeatable && awardMO != nil && awardMO!.gameUUID != Scorecard.game.gameUUID {
                            // Don't re-award if not repeatable (unless it was for this game)
                            self.debugMessage(config: config, message: "Repeat award for value \(value)")
                            continue
                        }
                        
                        var increment = 1
                        if awardMO?.gameUUID == Scorecard.game.gameUUID {
                            // Already awarded for this game
                            increment = 0
                        }
                        justAwarded += increment
                        
                        results.append(Award(from: config, awardLevel: awardLevel, gameUUID: current.gameUUID!, dateAwarded: current.datePlayed!, count: Int(awardMO?.count ?? 0) + increment))
                        self.debugMessage(config: config, message: "Awarded for value \(value)")
                    } else {
                        self.debugMessage(config: config, message: "No match for value \(value)")
                    }
                } else {
                    self.debugMessage(config: config, message: "No value")
                }
            }
        }
        
        return results
    }
        
    /// Create the core data for the list of awards achieved
    /// - Parameter achieved: List of awards
    public func save(playerUUID: String, achieved: [Award]) {
        let existing = self.getAchieved(playerUUID: playerUUID)
        for award in achieved {
            var awardMO = self.hasAchieved(existing, code: award.code, awardLevel: award.awardLevel)
            if awardMO != nil {
                // Already achieved - update
                CoreData.update {
                    awardMO!.gameUUID = award.gameUUID
                    awardMO!.dateAwarded = award.dateAwarded
                    awardMO!.count = Int64(award.count)
                    awardMO!.syncDate = nil
                }
            } else {
                awardMO = self.createAwardMO(playerUUID: playerUUID, code: award.code, awardLevel: award.awardLevel, gameUUID: award.gameUUID!, dateAwarded: award.dateAwarded!)
            }
            if self.playerUUID == playerUUID && self.achieved != nil {
                self.achieved!.append(awardMO!)
            }
        }
    }
    
    private func debugMessage(config: AwardConfig, message: String) {
        Utility.debugMessage("Awards", "\(config.name()) - \(message)", mainThread: false)
    }
    
    private func hasAchieved(_ achieved: [AwardMO], code: String, awardLevel: Int) -> AwardMO? {
        return achieved.first(where: {$0.code == code && $0.awardLevel == awardLevel})
    }
    
    private func getHistory(current: ParticipantMO) -> [ParticipantMO] {
        // Get last week's (and at least 21) participant records
        
        let lastWeekPredicate = NSPredicate(format: "datePlayed > %@ and playerUUID = %@", (current.datePlayed?.addingTimeInterval(-8 * 24 * 60 * 60))! as NSDate, current.playerUUID!)
        var history = CoreData.fetch(from: "Participant", filter: lastWeekPredicate, sort: ("datePlayed", .descending)) as! [ParticipantMO]
        
        if history.count < 21 {
            // Need at least ten
            history = CoreData.fetch(from: "Participant", limit: 21, sort: ("datePlayed", .descending)) as! [ParticipantMO]
        }
        
        if history.firstIndex(where: {$0.gameUUID == current.gameUUID}) == nil {
            // Add current game to list
            history.insert(current, at: 0)
        }
        
        return history
    }

    private func getValue(config: AwardConfig, current: ParticipantMO, player: Player, history: [ParticipantMO], awarded: Int) -> Int? {
        var value: Int?
        
        if let custom = config.custom {
            // Custom getter
            value = custom(history)
            
        } else if let key = config.key,
           let source = config.source,
           let playerMO = player.playerMO {
            
            // Standard getter
            switch source {
            case .current:
                value = current.value(forKey: key) as? Int
            case .player:
                value = playerMO.value(forKey: key) as? Int
            case .round(let round):
                switch round {
                case .last:
                    value = Scorecard.game.scores.get(round: Scorecard.game.rounds, playerNumber: player.playerNumber).value(forKey: key) as? Int
                case .maximum:
                    value = nil
                    for round in 1...Scorecard.game.rounds {
                        if let roundValue = Scorecard.game.scores.get(round: round, playerNumber: player.playerNumber).value(forKey: key) as? Int {
                            value = max(value ?? 0, roundValue)
                        }
                    }
                case .specific(let round):
                    value = Scorecard.game.scores.get(round: round, playerNumber: player.playerNumber).value(forKey: key) as? Int
                }
            case .awards:
                value = awarded
            }
        }
        return value
    }
    
    private func checkAwardLevels(config: AwardConfig, value: Int) -> Int? {
        var result: Int?
        for awardLevel in config.awardLevels {
            if let compare = config.compare {
                if comparison(value1: value, op: compare, value2: awardLevel) {
                    result = awardLevel
                }
            }
        }
        return result
    }
    
    private func comparison(value1: Int, op: Comparison, value2: Int) -> Bool {
        switch op {
        case .less:
            return (value1 < value2)
        case .lessOrEqual:
            return (value1 <= value2)
        case .equal:
            return (value1 == value2)
        case .greaterOrEqual:
            return (value1 >= value2)
        case .greater:
            return (value1 > value2)
        }
    }
     
    private func defaultAchieved(playerUUID: String) -> [AwardMO] {
        // Default in the initial list of achieved awards based on player record
        var results: [AwardMO] = []
        if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(playerUUID) {
            for config in self.config.reversed() {
                switch config.source {
                case .player:
                    if !config.repeatable && config.key != nil {
                        // Get comparison value
                        if let value = playerMO.value(forKey: config.key!) as? Int {
                            for awardLevel in config.awardLevels {
                                if value >= awardLevel {
                                    if let awardMO = self.createAwardMO(playerUUID: playerUUID, code: config.code, awardLevel: awardLevel, gameUUID: "", dateAwarded: Date(timeInterval: Double(results.count), since: Date.startOfDay()!)) {
                                        results.append(awardMO)
                                    }
                                }
                            }
                        }
                    }
                default:
                    break
                }
            }
        }
        return results
    }
    
    @discardableResult private func createAwardMO(playerUUID: String, code: String, awardLevel: Int, gameUUID: String, dateAwarded: Date) -> AwardMO? {
        var awardMO: AwardMO!
        _ = CoreData.update() {
            awardMO = CoreData.create(from: "Award") as? AwardMO
            if awardMO != nil {
                awardMO.playerUUID = playerUUID
                awardMO.code = code
                awardMO.awardLevel = Int64(awardLevel)
                awardMO.gameUUID = gameUUID
                awardMO.dateAwarded = dateAwarded
                awardMO.count = 1
            }
        }
        return awardMO
    }
    
    // MARK: - Custom value routines ==================================================================== -
    
    private func gamesInDay(history: [ParticipantMO]) -> Int {
        return gamesInPeriod(days: 0, history: history)
    }
    
    private func gamesInWeek(history: [ParticipantMO]) -> Int {
        return gamesInPeriod(days: -6, history: history)
    }
    
    private func gamesInPeriod(days: Int, history: [ParticipantMO]) -> Int {
        var result = 0
        
        for participantMO in history {
            if Date.startOfDay(days: days, from: Date())! <= participantMO.datePlayed! {
                result += 1
            } else {
                break
            }
        }
        return result
    }
    
    private func daysInARow(history: [ParticipantMO]) -> Int {
        var result = 0
        var cutoff = Date(timeIntervalSinceReferenceDate: 0)
        var lastDate = cutoff

        for participantMO in history {
            let gameDate = Date.startOfDay(from: participantMO.datePlayed!)!
            if gameDate >= cutoff {
                if gameDate != lastDate {
                    result += 1
                    lastDate = gameDate
                }
                cutoff = Date.startOfDay(days: -1, from: participantMO.datePlayed!)!
            } else {
                break
            }
        }
        return result
    }
    
    private func maxBehind(history: [ParticipantMO]) -> Int {
        return self.maxDifference(sign: 1, history: history)
    }
    
    private func maxAhead(history: [ParticipantMO]) -> Int {
        return self.maxDifference(sign: -1, history: history)
    }
    
    private func maxDifference(sign: Int, history: [ParticipantMO]) -> Int {
        var result = 0
        if let player = Scorecard.game.player(playerUUID: history.first!.playerUUID!) {
            for round in 1...Scorecard.game.rounds {
                var others: [Int] = []
                var thisPlayer: Int = 0
                for playerNumber in 1...Scorecard.game.currentPlayers {
                    if let score = Scorecard.game.scores.score(round: round, playerNumber: playerNumber) {
                        if playerNumber == player.playerNumber {
                            thisPlayer = score
                        } else {
                            others.append(score)
                        }
                    }
                }
                result = max(result, (thisPlayer - others.reduce(0, {max($0, $1)})) * sign)
            }
        }
        return result
    }
    
    private func aboveAverage(history: [ParticipantMO]) -> Int {
        return toAverage(sign: 1, history: history)
    }
    
    private func belowAverage(history: [ParticipantMO]) -> Int {
        return toAverage(sign: -1, history: history)
    }
    
    private func toAverage(sign: Int, history: [ParticipantMO]) -> Int {
        var result = 0
        if let player = Scorecard.game.player(playerUUID: history.first!.playerUUID!),
            let playerMO = player.playerMO {
            let average: Float = Float(playerMO.totalScore) / Float(max(1,playerMO.gamesPlayed))
            for participantMO in history {
                if (Float(participantMO.totalScore) - average) * Float(sign) > 0.0 {
                    result += 1
                } else {
                    break
                }
            }
                
        }
        return result
    }
    
    // MARK: - Conditions ================================================================== -
    
    /// Checks if there is a 9NT round at round 5
    /// - Returns: true/false
    private func hand9NT() -> Bool {
        var result = false
        let cards = Scorecard.activeSettings.cards
        let sequence = Scorecard.activeSettings.trumpSequence
        if let ntIndex = sequence.firstIndex(where: {$0 == "NT"}) {
            if ntIndex == 4 {
                if cards[0] <= 9 && cards[1] >= 9 && (cards[0] == 5) {
                    result = true
                } else if cards[0] >= 9 && cards[1] <= 9 && (cards[0] == 13) {
                    result = true
                }
            }
        }
        return result
    }
    
    // MARK: - Configuration ============================================================================= -

    private func setupConfig() {
        self.config = [
            AwardConfig(code: "gamesPlayed", name: "%d Games", shortName: "%d Games", title: "Play %d games of Whist",
                   awardLevels: [10, 25, 50, 100, 250, 500], repeatable: false,
                   compare: .equal, source: .player, key: "gamesPlayed",
                   imageName: "award games played %d"),
            AwardConfig(code: "gamesWon", name: "%d Wins", shortName: "%d Wins", title: "Win %d games of Whist",
                   awardLevels: [10, 25, 50, 75, 100, 200], repeatable: false,
                   compare: .equal, source: .player, key: "gamesWon",
                   imageName: "award games won %d"),
            AwardConfig(code: "handsMade", name: "%d Contracts", shortName: "%d Contracts", title: "Make %d contracts",
                   awardLevels: [50, 100, 250, 500, 750, 1000], repeatable: false,
                   compare: .equal, source: .player, key: "handsMade",
                   imageName: "award hands made %d"),
            AwardConfig(code: "twosMade", name: "%d Twos", shortName: "%d Twos", title: "Win %d tricks with a two",
                   awardLevels: [10, 25, 50, 100, 250, 500], repeatable: false,
                   compare: .equal, source: .player, key: "twosMade",
                   imageName: "award twos made %d",
                   condition: { Scorecard.activeSettings.bonus2 }),
            AwardConfig(code: "madeGame", name: "Contract Killer", shortName: "Contract Killer", title: "Make %d contracts in one game",
                   awardLevels: [11, 12, 13],
                   compare: .greaterOrEqual, source: .current, key: "handsMade",
                   imageName: "award game made %d"),
            AwardConfig(code: "winStreak", name: "Don't Stop Me Now", shortName: "Don't Stop Me", title: "I'm having such a good time.\nWin %d games in a row",
                   awardLevels: [3, 4, 5],
                   compare: .greaterOrEqual, source: .player, key: "winStreak",
                   imageName: "award win streak %d"),
            AwardConfig(code: "weekGames", name: "Enthusiast", shortName: "Enthusiast", title: "Play %d games in a week",
                   awardLevels: [10, 15, 20],
                   compare: .equal, custom: gamesInWeek,
                   imageName: "award week games %d",
                   overrides: [15 : AwardNameConfig(name: "Fanatic", shortName: "Fanatic"),
                               20 : AwardNameConfig(name: "Obsessed", shortName: "Obsessed")]),
            AwardConfig(code: "dayGames", name: "Keen Bean", shortName: "Keen Bean", title: "Play %d games in a day",
                   awardLevels: [3, 4, 5],
                   compare: .equal, custom: gamesInDay,
                   imageName: "award day games %d",
                   overrides: [4 : AwardNameConfig(name: "Fore!", shortName: "Fore!"),
                               5 : AwardNameConfig(name: "Get your 5 a Day", shortName: "5 a Day")]),
            AwardConfig(code: "dayStreak", name: "Loyalty Card", shortName: "Loyalty Card", title: "Play a game %d days in a row",
                   awardLevels: [3, 5, 7],
                   compare: .equal, custom: daysInARow,
                   imageName: "award day streak %d"),
            AwardConfig(code: "totalScore", name: "Flying High", shortName: "Flying High", title: "Score higher than %d in a game",
                   awardLevels: [130, 140, 150],
                   compare: .greaterOrEqual, source: .current, key: "totalScore",
                   imageName: "award total score %d"),
            AwardConfig(code: "allNoTrumps", name: "Clean Sweep", shortName: "Clean Sweep", title: "Win all nine tricks in the 9 NT hand",
                   awardLevels: [9],
                   compare: .equal, source: .round(.specific(5)), key: "made",
                   imageName: "award all no trumps",
                   condition: self.hand9NT),
            AwardConfig(code: "maxTricks", name: "Abracadabra", shortName: "Abracadabra", title: "Win %d or more tricks in a hand",
                   awardLevels: [10],
                   compare: .greaterOrEqual, source: .round(.maximum), key: "made",
                   imageName: "award max tricks %d"),
            AwardConfig(code: "twoLastRound", name: "Lucky Duck", shortName: "Lucky Duck", title: "Win with a 2 in last round",
                   awardLevels: [1],
                   compare: .greaterOrEqual, source: .round(.last), key: "twos",
                   imageName: "award two last round",
                   condition: { Scorecard.activeSettings.bonus2 }),
            AwardConfig(code: "winBehind", name: "Comeback King", shortName: "Comeback King", title: "Win the game after being %d points behind",
                   awardLevels: [30],
                   compare: .greaterOrEqual, custom: maxBehind, winLose: .win,
                   imageName: "win behind %d"),
            AwardConfig(code: "loseAhead", name: "Crimble Crumble", shortName: "Crumble", title: "Hard luck bambino! Lose the game after being %d points ahead",
                   awardLevels: [30],
                   compare: .greaterOrEqual, custom: maxAhead, winLose: .lose,
                   imageName: "lose ahead %d"),
            AwardConfig(code: "highLoss", name: "Hard Cheese", shortName: "Hard Cheese", title: "Better luck next time. Score more than %d points but still lose the game",
                   awardLevels: [130],
                   compare: .greaterOrEqual, source: .current, key: "totalScore", winLose: .lose,
                   imageName: "award high loss %d"),
            AwardConfig(code: "lowWin", name: "Down To The Wire", shortName: "To The Wire", title: "Win the game while scoring %d points or less",
                   awardLevels: [100, 90, 80],
                   compare: .lessOrEqual, source: .current, key: "totalScore", winLose: .win,
                   imageName: "award low win %d"),
            AwardConfig(code: "aboveAverage", name: "Little Miss Consistent", shortName: "Miss Consistent", title: "Score above your average for %d games in a row",
                   awardLevels: [5, 10],
                   compare: .equal, custom: aboveAverage,
                   imageName: "above average %d",
                   overrides: [10 : AwardNameConfig(name: "Little Miss Shine", shortName: "Mis Shine")]),
            AwardConfig(code: "belowAverage", name: "Mr Flop", shortName: "Mr Flop", title: "Score below your average for %d games in a row",
                   awardLevels: [5],
                   compare: .equal, custom: belowAverage,
                   imageName: "below average %d"),
            AwardConfig(code: "twosGame", name: "Two's Company", shortName: "Two's Company", title: "Make %d twos in one game",
                   awardLevels: [3, 4, 5],
                   compare: .greaterOrEqual, source: .current, key: "twosMade",
                   imageName: "award game twos %d",
                   condition: { Scorecard.activeSettings.bonus2 }),
            AwardConfig(code: "twosHand", name: "It Takes Two To Tango", shortName: "Two to Tango", title: "Make %d twos in one hand",
                   awardLevels: [2, 3],
                   compare: .greaterOrEqual, source: .round(.maximum), key: "twos",
                   imageName: "award hand twos %d",
                   condition: { Scorecard.activeSettings.bonus2 }),
            AwardConfig(code: "awards", name: "VIP", shortName: "VIP", title: "This award is for being awarded %d awards",
                   awardLevels: [25, 50], repeatable: false,
                   compare: .greaterOrEqual, source: .awards, key: "",
                   imageName: "awards %d"),
        ]
    }
}

extension AwardMO {
    
    public func from(cloudObject: CKRecord) {
        self.playerUUID = Utility.objectString(cloudObject: cloudObject, forKey: "playerUUID")
        self.code = Utility.objectString(cloudObject: cloudObject, forKey: "code")
        self.awardLevel = Utility.objectInt(cloudObject: cloudObject, forKey:"awardLevel")
        self.dateAwarded = Utility.objectDate(cloudObject: cloudObject, forKey: "dateAwarded")
        self.gameUUID = Utility.objectString(cloudObject: cloudObject, forKey: "gameUUID")
        self.count = Utility.objectInt(cloudObject: cloudObject, forKey: "count")
        self.syncDate = Utility.objectDate(cloudObject: cloudObject, forKey: "syncDate")
        self.syncRecordID = cloudObject.recordID.recordName
    }
    
    public func to(cloudObject: CKRecord) {
        cloudObject.setValue(self.playerUUID, forKey: "playerUUID")
        cloudObject.setValue(self.code, forKey: "code")
        cloudObject.setValue(self.awardLevel, forKey: "awardLevel")
        cloudObject.setValue(self.dateAwarded, forKey: "dateAwarded")
        cloudObject.setValue(self.gameUUID, forKey: "gameUUID")
        cloudObject.setValue(self.count, forKey: "count")
        cloudObject.setValue(self.syncDate, forKey: "syncDate")
    }
    
}
