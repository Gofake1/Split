//
//  Split.swift
//  Split
//
//  Created by David Wu on 1/25/17.
//  Copyright © 2017 Gofake1. All rights reserved.
//

import Foundation

public struct PlistDocument {

    enum RootKind {
        case array
        case dictionary
    }

    var root: PlistCollection?

    init(_ contents: [PlistEncodable]) throws {
        self.root = Array(contents)
        throw PlistError.dataError
    }

    init(_ contents: [String:PlistEncodable]) throws {
        throw PlistError.dataError
    }

    init(rootKind: RootKind) {
        switch rootKind {
        case .array:
            self.root = Array()
        case .dictionary:
            self.root = Dictionary()
        }
    }

    init(data: Data) throws {
        guard let document = String(data: data, encoding: .utf8) else {
            throw PlistError.dataError
        }
        self.root = try parse(document)
    }

    func write(to path: String) throws {
        if let root = self.root as? PlistEncodable {
            try root.plistEncoding.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            throw PlistError.internalError(description: "Failed to write to file")
        }
    }
}

extension PlistDocument: ExpressibleByStringLiteral,
                         ExpressibleByUnicodeScalarLiteral,
                         ExpressibleByExtendedGraphemeClusterLiteral {

    public init(stringLiteral value: String) {
        do {
            self.root = try parse(value)
        } catch {
            fatalError()
        }
    }

    public init(unicodeScalarLiteral value: String) {
        do {
            self.root = try parse(value)
        } catch {
            fatalError()
        }
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        do {
            self.root = try parse(value)
        } catch {
            fatalError()
        }
    }
}

enum PlistError: Error {
    case dataError
    case lexError(description: String)
    case parseError(description: String)
    case internalError(description: String)
}

/// Type that can be represented in a Property List as plain text
protocol PlistEncodable {
    var plistEncoding: String { get }
}

/// Type that represents a collection of `PlistEncodable`
protocol PlistCollection {
    var contents: Any { get set }
    func append(_ element: PlistEncodable)
}

extension String: PlistEncodable {
    var plistEncoding: String { return "<string>" + self + "</string>\n" }
}

extension Int: PlistEncodable {
    var plistEncoding: String { return "<integer>" + String(self) + "</integer>\n" }
}

extension UInt: PlistEncodable {
    var plistEncoding: String { return "<integer>" + String(self) + "</integer>\n" }
}

extension Float: PlistEncodable {
    var plistEncoding: String { return "<real>" + String(self) + "</real>\n" }
}

extension Double: PlistEncodable {
    var plistEncoding: String { return "<real>" + String(self) + "</real>\n" }
}

extension Bool: PlistEncodable {
    var plistEncoding: String { return self ? "<true/>\n" : "<false/>\n" }
}

var iso8601: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return df
}()

extension Date: PlistEncodable {
    var plistEncoding: String { return "<date>" + iso8601.string(from: self) + "</date>\n" }
}

extension Data: PlistEncodable {
    var plistEncoding: String { return "<data>" + self.base64EncodedString() + "</data>\n" }
}

extension Data {
    init?(plist: PlistDocument) {
        self.init(base64Encoded: "")
    }
}

public class Array: PlistEncodable, PlistCollection {

    var plistEncoding: String {
        var str = "<array>\n"
        for value in contents as! [PlistEncodable] {
            str += value.plistEncoding
        }
        str += "</array>\n"
        return str
    }

    var contents: Any

    init() {
        self.contents = [PlistEncodable]()
    }

    init(_ contents: [PlistEncodable]) {
        self.contents = contents
    }

    func append(_ element: PlistEncodable) {
        if var contents = contents as? [PlistEncodable] {
            contents.append(element)
            self.contents = contents
        }
    }
}

public class Dictionary: PlistEncodable, PlistCollection {

    var plistEncoding: String {
        var str = "<dict>\n"
        for (key, value) in contents as! [String:PlistEncodable] {
            str += "<key>" + key + "</key>"
            str += value.plistEncoding
        }
        str += "</dict>\n"
        return str
    }

    var contents: Any
    private var expectKey = true
    private var keyThatNeedsValue: String?

    init() {
        self.contents = [String:PlistEncodable]()
    }

    init(_ contents: [String:PlistEncodable]) {
        self.contents = contents
    }

    func append(_ element: PlistEncodable) {
        if expectKey {
            self.keyThatNeedsValue = element as? String
            expectKey = false
        } else {
            if var contents = contents as? [String:PlistEncodable] {
                if let key = self.keyThatNeedsValue {
                    contents[key] = element
                    self.contents = contents
                }
            }
            expectKey = true
        }
    }

    func append(key: String, value: PlistEncodable) {
        if var contents = contents as? [String:PlistEncodable] {
            contents[key] = value
        }
    }
}

protocol PlistTokenType {}

struct TagToken: PlistTokenType, CustomStringConvertible {

    enum Kind: String {
        case key
        case string
        case integer
        case boolean
        case date
        case data
        case array
        case dictionary = "dict"
    }

    enum Flag: String {
        case open
        case close
    }

    var description: String {
        switch flag {
        case .open:
            if kind == .boolean {
                return "<"
            }
            return "<\(kind)>"
        case .close:
            if kind == .boolean {
                return "/>"
            }
            return "</\(kind)>"
        }
    }

    var kind: Kind
    var flag: Flag

    init(flag: Flag, tagKind kindString: String) throws {
        guard let type = Kind(rawValue: kindString) else {
            throw PlistError.lexError(description: "Unknown type '\(kindString)'")
        }
        self.flag = flag
        self.kind = type
    }
}

struct DataToken: PlistTokenType, CustomStringConvertible {

    var description: String {
        return value
    }

    var value: String
}

enum LexState {
    case done
    case tag
    case openTag
    case closeTag
    case openCloseTag
    case value
}

func lex(_ sentence: String) throws -> [PlistTokenType] {
    var tokens      = [PlistTokenType]()
    var state       = LexState.done
    var tagString   = ""
    var valueString = ""
    for character in sentence.characters {
        switch character {
        case "<":
            switch state {
            case .done:
                state = .tag
            case .value:
                state = .tag
                tokens.append(DataToken(value: valueString))
                valueString = ""
            default:
                throw PlistError.lexError(description: "Unexpected '<'")
            }
        case ">":
            switch state {
            case .openTag:
                state = .done
                tokens.append(try TagToken(flag: .open, tagKind: tagString))
                tagString = ""
            case .closeTag:
                state = .done
                tokens.append(try TagToken(flag: .close, tagKind: tagString))
                tagString = ""
            case .openCloseTag:
                state = .done
                tokens.append(try TagToken(flag: .open, tagKind: "boolean"))
                tokens.append(DataToken(value: tagString))
                tokens.append(try TagToken(flag: .close, tagKind: "boolean"))
                tagString = ""
            default:
                throw PlistError.lexError(description: "Unexpected '>'")
            }
        case "/":
            switch state {
            case .tag:
                state = .closeTag
            case .openTag:
                state = .openCloseTag
            default:
                throw PlistError.lexError(description: "Unexpected '/'")
            }
        case "\n": fallthrough
        case "\t": fallthrough
        case " ":
            switch state {
            case .value:
                valueString += String(character)
            default:
                break
            }
        default:
            switch state {
            case .done:
                state = .value
                valueString += String(character)
            case .tag:
                state = .openTag
                tagString += String(character)
            case .openTag:  fallthrough
            case .closeTag:
                tagString += String(character)
            case .openCloseTag:
                throw PlistError.lexError(description: "Expected '>'")
            case .value:
                valueString += String(character)
            }
        }
    }
    if state != .done {
        throw PlistError.lexError(description: "Document must end with a valid tag")
    }
    return tokens
}

enum ParseState {
    case done
    case expectOpenTag
    case expectValue
    case expectCloseTag
    case expectOpenOrCloseTag
}

func parse(_ document: String) throws -> PlistCollection? {
    let tokens = try lex(document)
    var root: PlistCollection?

    guard
        let firstToken = tokens[0] as? TagToken,
        firstToken.flag == .open
    else {
        throw PlistError.parseError(description: "Document must begin with a valid tag")
    }
    switch firstToken.kind {
    case .array: fallthrough
    case .dictionary:
        break
    default:
        throw PlistError.parseError(description: "Root object must be an array or a dictionary")
    }

    // Scratch variables
    var state = ParseState.expectOpenTag
    var collectionStack = [PlistCollection]()
    var expectedValueKind: TagToken.Kind?

    for token in tokens {
        switch token {
        case let tag as TagToken:
            switch tag.flag {
            case .open:
                switch state {
                case .expectOpenTag: fallthrough
                case .expectOpenOrCloseTag:
                    switch tag.kind {
                    case .key:     fallthrough
                    case .string:  fallthrough
                    case .integer: fallthrough
                    case .boolean: fallthrough
                    case .date:    fallthrough
                    case .data:
                        state = .expectValue
                        expectedValueKind = tag.kind
                    case .array: fallthrough
                    case .dictionary:
                        state = .expectOpenTag
                        collectionStack.append((tag.kind == .array) ? Array() : Dictionary())
                    }
                case .done:
                    throw PlistError.parseError(description: "Unexpected opening tag")
                case .expectValue:
                    throw PlistError.parseError(description: "Unexpected opening tag, expected value")
                case .expectCloseTag:
                    throw PlistError.parseError(description: "Unexpected opening tag, expected closing tag")
                }
            case .close:
                switch state {
                case .expectCloseTag: fallthrough
                case .expectOpenOrCloseTag:
                    switch tag.kind {
                    case .key:     fallthrough
                    case .string:  fallthrough
                    case .integer: fallthrough
                    case .boolean: fallthrough
                    case .date:    fallthrough
                    case .data:
                        state = .expectOpenOrCloseTag
                    case .array: fallthrough
                    case .dictionary:
                        let currentCollection = collectionStack.popLast()
                        if let parentCollection = collectionStack.last {
                            parentCollection.append(currentCollection as! PlistEncodable)
                            state = .expectOpenOrCloseTag
                        } else {
                            state = .done
                            root = currentCollection
                        }
                    }
                case .done:
                    throw PlistError.parseError(description: "Unexpected closing tag")
                case .expectOpenTag:
                    throw PlistError.parseError(description: "Unexpected closing tag, expected opening tag")
                case .expectValue:
                    throw PlistError.parseError(description: "Unexpected closing tag, expected value")
                }
            }

        case let token as DataToken:
            switch state {
            case .expectValue:
                guard
                    let valueKind = expectedValueKind,
                    let currentCollection = collectionStack.last
                else {
                    throw PlistError.internalError(description: "Parser failed on data token")
                }
                switch valueKind {
                case .key: fallthrough
                case .string:
                    currentCollection.append(token.value)
                case .integer:
                    guard let int = Int(token.value) else {
                        throw PlistError.parseError(description: "Couldn't parse Int")
                    }
                    currentCollection.append(int)
                case .boolean:
                    guard let bool = Bool(token.value) else {
                        throw PlistError.parseError(description: "Couldn't parse Bool")
                    }
                    currentCollection.append(bool)
                case .date:
                    guard let date = iso8601.date(from: token.value) else {
                        throw PlistError.parseError(description: "Couldn't parse Date")
                    }
                    currentCollection.append(date)
                case .data:
                    guard let data = Data(base64Encoded: token.value) else {
                        throw PlistError.parseError(description: "Couldn't parse Data")
                    }
                    currentCollection.append(data)
                default:
                    throw PlistError.parseError(description: "Illegal value type '\(valueKind)'")
                }
                state = .expectCloseTag
            case .done: fallthrough
            case .expectOpenOrCloseTag:
                throw PlistError.parseError(description: "Unexpected value '\(token.value)'")
            case .expectOpenTag:
                throw PlistError.parseError(description:
                    "Unexpected value '\(token.value)'; expected opening tag")
            case .expectCloseTag:
                throw PlistError.parseError(description:
                    "Unexpected value '\(token.value)'; expected closing tag")
            }

        default:
            throw PlistError.parseError(description: "Unknown token '\(token)'")
        }
    }
    if state != .done {
        throw PlistError.parseError(description: "Document must end with a closing tag")
    }
    return root
}
