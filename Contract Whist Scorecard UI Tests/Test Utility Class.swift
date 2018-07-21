//
//  Test Utility Class.swift
//  Contract Whist Scorecard UI Tests
//
//  Created by Marc Shearer on 12/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import XCTest

extension Contract_Whist_Scorecard_UI_Tests {
    
    func tap(_ element: XCUIElement, timeout: TimeInterval = 10) {
        self.waitFor(element, timeout: timeout, predicate: existsPredicate)
        if element.isHittable {
            element.tap()
        } else {
            let coordinate: XCUICoordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.0))
            coordinate.tap()
        }
    }
    
    func typeText(_ element: XCUIElement, _ text: String, timeout: TimeInterval = 10) {
        self.waitFor(element, timeout: timeout)
        element.tap()
        element.typeText(text)
    }
    
    func swipeLeft(_ element: XCUIElement, timeout: TimeInterval = 10) {
        self.waitFor(element, timeout: timeout)
        element.swipeLeft()
    }
    
    func swipeRight(_ element: XCUIElement, timeout: TimeInterval = 10) {
        self.waitFor(element, timeout: timeout)
        element.swipeRight()
    }
    
    func swipeUp(_ element: XCUIElement, timeout: TimeInterval = 10) {
        self.waitFor(element, timeout: timeout)
        element.swipeUp()
    }
    
    func swipeDown(_ element: XCUIElement, timeout: TimeInterval = 10) {
        self.waitFor(element, timeout: timeout)
        element.swipeDown()
    }
    
    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10, message: String? = nil, predicate: NSPredicate? = nil) {
        let predicate = (predicate == nil ? hittablePredicate : predicate)
        self.expectation(for: predicate!, evaluatedWith: element, handler: nil)
        self.waitForExpectations(timeout: timeout, handler: { (error) in
            if error != nil {
                let message = (message == nil ? "Element is not hittable" : message!)
                XCTFail(message)
            }
        })
    }
    
    func assertEnabled(_ element: XCUIElement, timeout: TimeInterval = 10, message: String? = nil) {
        self.expectation(for: enabledPredicate, evaluatedWith: element, handler: nil)
        self.waitForExpectations(timeout: timeout, handler: { (error) in
            if error != nil {
                let message = (message == nil ? "Element is not enabled" : message!)
                XCTFail(message)
            }
        })
    }
    
    
    func assertNotEnabled(_ element: XCUIElement, timeout: TimeInterval = 10, message: String? = nil) {
        self.expectation(for: notEnabledPredicate, evaluatedWith: element, handler: nil)
        self.waitForExpectations(timeout: timeout, handler: { (error) in
            if error != nil {
                let message = (message == nil ? "Element is enabled" : message!)
                XCTFail(message)
            }
        })
    }
    
    func assertExists(_ element: XCUIElement, timeout: TimeInterval = 10, message: String? = nil) {
        self.expectation(for: existsPredicate, evaluatedWith: element, handler: nil)
        self.waitForExpectations(timeout: timeout, handler: { (error) in
            if error != nil {
                let message = (message == nil ? "Element does not exist)" : message!)
                XCTFail(message)
            }
        })
    }
    
    func assertSelected(_ element: XCUIElement, timeout: TimeInterval = 10, message: String? = nil) {
        self.expectation(for: selectedPredicate, evaluatedWith: element, handler: nil)
        self.waitForExpectations(timeout: timeout, handler: { (error) in
            if error != nil {
                let message = (message == nil ? "Element is not selected" : message!)
                XCTFail(message)
            }
        })
    }
    
    func assertNotExists(_ element: XCUIElement, timeout: TimeInterval = 10, message: String? = nil) {
        self.expectation(for: notExistsPredicate, evaluatedWith: element, handler: nil)
        self.waitForExpectations(timeout: timeout, handler: { (error) in
            if error != nil {
                let message = (message == nil ? "Element exists)" : message!)
                XCTFail(message)
            }
        })
    }
    
    func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 10) {
        if element.exists && element.isHittable {
            element.tap()
        }
    }
}
