# Split

XML [Property List](https://en.wikipedia.org/wiki/Property_list) serializer written in Swift

## Limitations

* Does not handle XML in general
* Assumes UTF-8
* Assumes valid Property List semantics (e.g `<dict>` objects have pairs of `<key>`s and values)
* Split is *not* a wrapper around Foundation's `PropertyListSerialization`

## Usage

#### Serialize a Swift type

Encode an array of strings and write it to a file:

```swift
let fruits = ["Apple", "Banana", "Orange"]
let plist = PlistDocument(root: fruits)
try plist.write(to: "/some/path")
```

`PlistEncodable`s are types that can be serialized in a Property List:

```swift
let things: [PlistEncodable] = [Date(), "Foo", 42, true]
let things2: [String:PlistEncodable] = ["date": Date(), "bar": "Foo", "answer": 42, "boolean": true]
```

Not all data can be modeled as Swift collection types.
Build a heterogeneous object:

```swift
let plist = PlistDocument(rootKind: .array)
plist.root?.append(Split.Dictionary)
plist.root![0][Key("key")] = "value"
// <array>
//   <dict>
//     <key>key</key>
//     <string>value</string>
//   </dict>
// </array>
```

#### Deserialize a .plist file

Recreate the `fruits` array:

```swift
let fruitsData: Data = ... // Read from a UTF-8 encoded file
let plist = try PlistDocument(data: fruitsData)
let fruits = plist.root?.contents as! [PlistEncodable]
var newFruits = [String]()
for fruit in fruits {
    switch fruit {
    case let fruit as String:
        newFruits.append(fruit)
    default: break // In this case we know the array only contains Strings, but Property Lists can also contain
                   // numbers, dates, booleans, base64-encoded strings
    }
}
// newFruits: ["Apple", "Banana", "Orange"]
```

## Installation

Include `Split/Split.swift` in your project, or use [Carthage](https://github.com/Carthage/Carthage):

```
github "Gofake1/Split"
```

## TODO

Implement validation

*This project is available under the MIT License*
