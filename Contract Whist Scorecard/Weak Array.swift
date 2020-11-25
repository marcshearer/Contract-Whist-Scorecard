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


class WeakArray<T: AnyObject> {
    var values: Array<Weak<T>>

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
    
    public func clear() {
        self.values = []
    }
    
    public var count: Int {
        return self.values.count
    }
    
    public var isEmpty: Bool {
        return self.values.isEmpty
    }
    
    public var first: T? {
        return values.first?.value
    }

    public var last: T? {
        return values.last?.value
    }

    public func append(_ value: T) {
        // TODO values.append(Weak(value))
    }
    
    public func append(contentsOf: [T]) {
        for element in contentsOf {
            self.append(element)
        }
    }
    
    public var asArray: [T] {
        return values.filter({$0.value != nil}).map{$0.value!}
    }
}
