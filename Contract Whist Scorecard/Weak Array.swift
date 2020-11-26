//
//  Weak Array.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 23/11/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation

class Weak<T: AnyObject> {
    weak var value: T?
    init(_ value: T) {
        self.value = value
    }
}

struct WeakArrayIterator<T: AnyObject>: IteratorProtocol {
    private var elements: [Weak<T>]
    
    init(elements: [Weak<T>]) {
        self.elements = elements
    }
    
    mutating func next() -> T? {
        var result: T?
        while !elements.isEmpty && result == nil {
            // Skip over any nil elements
            result = elements.first?.value
            elements.remove(at: 0)
        }
        return result
    }
}

class WeakArray<T: AnyObject>: Sequence {
    private var values: [Weak<T>]

    init() {
        self.values = Array<Weak<T>>([])
    }
    
    init?(_ array: [T]?) {
        if let array = array {
            self.values = array.map{Weak<T>($0)}
        } else {
            return nil
        }
    }
    
    init(_ array: [T]) {
        self.values = array.map{Weak<T>($0)}
    }
    
    func makeIterator() -> WeakArrayIterator<T> {
        return WeakArrayIterator(elements: self.values)
    }
    
    public func clear() {
        self.values = []
    }
    
    public var count: Int {
        return self.values.count
    }
    
    public var isEmpty: Bool {
        return self.values.isEmpty
    }
    
    public func value(_ element: Int) -> T {
        return self.values[element].value!
    }

    public var first: T? {
        return self.values.first?.value
    }
    
    public var last: T? {
        return self.values.last?.value
    }

    public func append(_ value: T) {
         values.append(Weak(value))
    }
    
    public func remove(at index: Int) {
        values.remove(at: index)
    }
    
    public func append(contentsOf array: [T]) {
        for element in array {
            self.append(element)
        }
    }
    
    public func append(contentsOf array: WeakArray<T>) {
        for element in array {
            self.append(element)
        }
    }
    
    public var asArray: [T] {
        return values.filter({$0.value != nil}).map{$0.value!}
    }
}
