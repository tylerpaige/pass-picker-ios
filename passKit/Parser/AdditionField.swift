//
//  AdditionField.swift
//  passKit
//
//  Created by Danny Moesch on 30.09.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

public struct AdditionField: Hashable {
    public let title: String, content: String
    /// One item of a bulleted list: a "key:" line followed by "- item" lines.
    public let isListItem: Bool

    public init(title: String = "", content: String = "", isListItem: Bool = false) {
        self.title = title
        self.content = content
        self.isListItem = isListItem
    }

    var asString: String {
        title.isEmpty ? content : title + ": " + content
    }

    var asTuple: (String, String) {
        (title, content)
    }
}

extension AdditionField {
    static func | (left: String, right: AdditionField) -> String {
        left | right.asString
    }

    static func | (left: AdditionField, right: String) -> String {
        left.asString | right
    }

    static func | (left: AdditionField, right: AdditionField) -> String {
        left.asString | right
    }
}

infix operator =>: MultiplicationPrecedence

public extension String {
    static func => (key: String, value: String) -> AdditionField {
        AdditionField(title: key, content: value)
    }
}
