//
//  Weak Dictionary.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 26/11/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation

struct WeakDictionaryIterator<T: AnyObject>: IteratorProtocol {
    private var elements: [(key: AnyHashable, value: Weak<T>)] = []
    
    init(elements: [AnyHashable:Weak<T>]) {
        for (key, value) in elements {
            self.elements.append((key: key, value: value))
        }
    }
    
    mutating func next() -> (AnyHashable, T)? {
        var result: (AnyHashable, T)?
        while !elements.isEmpty && result == nil {
            // Skip over any nil elements
            if let value = elements.first?.value.value {
                result = (key: elements.first!.key, value)
            }
            elements.remove(at: 0)
        }
        return result
    }
}

class WeakDictionary<T: AnyObject>: Sequence {
    private var values: [AnyHashable:Weak<T>]

    init() {
        self.values = [:]
    }
    
    init?(_ dictionary: [AnyHashable:T]?) {
        if let dictionary = dictionary {
            self.values = Dictionary(uniqueKeysWithValues: dictionary.map { key, value in (key, Weak(value))})
        } else {
            return nil
        }
    }
    
    init(_ dictionary: [AnyHashable:T]) {
        self.values = Dictionary(uniqueKeysWithValues: dictionary.map { key, value in (key, Weak(value))})
    }
    
    func makeIterator() -> WeakDictionaryIterator<T> {
        return WeakDictionaryIterator(elements: self.values)
    }
    
    public func clear() {
        self.values = [:]
    }
    
    public var count: Int {
        return self.values.count
    }
    
    public var isEmpty: Bool {
        return self.values.isEmpty
    }
    
    public func value(_ key: AnyHashable) -> T? {
        return self.values[key]?.value
    }
    
    public func first(where condition: ((key: AnyHashable, value: T)) -> Bool) -> (key: AnyHashable, value: T)? {
        return self.asDictionary.first(where: {condition($0)})
    }
    
    public func set(key: AnyHashable, value: T) {
         values[key] = Weak(value)
    }
    
    public func remove(key: AnyHashable) {
        values[key] = nil
    }
        
    public var asDictionary: [AnyHashable:T] {
        var result: [AnyHashable:T] = [:]
        for (key, value) in self {
            result[key] = value
        }
        return result
    }
}
