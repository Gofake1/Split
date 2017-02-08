//
//  SplitTests.swift
//  SplitTests
//
//  Created by David Wu on 1/25/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import XCTest
@testable import Split

class SplitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testCatsValid() {
        guard let url = Bundle(for: type(of: self)).url(forResource: "Cats.plist.valid", withExtension: nil)
            else { return }
        do {
            let catsValid = try Data(contentsOf: url)
            let document = try PlistDocument(data: catsValid)
            let cats = document.root?.contents as! [PlistEncodable]
            let jaguar = (cats[2] as! Split.Dictionary).contents as! [String:PlistEncodable]
            XCTAssertEqual(jaguar["Name"] as! String, "Jaguar")
        } catch PlistError.lexError(let description) {
            XCTFail(description)
        } catch PlistError.parseError(let description) {
            XCTFail(description)
        } catch {
            XCTFail()
        }
    }

    func testNamesValid() {
        guard let url = Bundle(for: type(of: self)).url(forResource: "Names.plist.valid", withExtension: nil)
            else { return }
        do {
            let namesValid = try Data(contentsOf: url)
            let document = try PlistDocument(data: namesValid)
            let names = document.root?.contents as! [PlistEncodable]
            let first = names.first! as! String
            XCTAssertEqual(first, "SwiftPropertyList")
            let last = names.last! as! String
            XCTAssertEqual(last, "Spliff")
        } catch PlistError.lexError(let description) {
            XCTFail(description)
        } catch PlistError.parseError(let description) {
            XCTFail(description)
        } catch {
            XCTFail()
        }
    }

    func testRivalsInvalid() {
        guard let url = Bundle(for: type(of: self)).url(forResource: "Rivals.plist.invalid", withExtension: nil)
            else { return }
        do {
            let rivalsInvalid = try Data(contentsOf: url)
            _ = try PlistDocument(data: rivalsInvalid)
        } catch PlistError.lexError(let description) {
            XCTFail(description)
        } catch PlistError.parseError(let description) {
            XCTAssertEqual(description, "Document must end with a closing tag")
        } catch {
            XCTFail()
        }
    }
}
