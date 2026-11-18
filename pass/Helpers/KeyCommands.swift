//
//  KeyCommands.swift
//  pass
//
//  Hardware keyboard shortcuts, mirroring Pass Picker on macOS.
//

import UIKit

extension UIKeyCommand {
    /// A key command that wins over UIKit's own handling of the same keys (e.g. arrows scrolling a table).
    static func shortcut(_ input: String, action: Selector, modifiers: UIKeyModifierFlags = [], title: String = "") -> UIKeyCommand {
        let command = UIKeyCommand(title: title, action: action, input: input, modifierFlags: modifiers)
        if #available(iOS 15.0, *) {
            command.wantsPriorityOverSystemBehavior = true
        }
        return command
    }
}

extension UITableView {
    func indexPath(after indexPath: IndexPath?) -> IndexPath? {
        guard let indexPath else {
            return firstIndexPath(from: 0)
        }
        if indexPath.row + 1 < numberOfRows(inSection: indexPath.section) {
            return IndexPath(row: indexPath.row + 1, section: indexPath.section)
        }
        return firstIndexPath(from: indexPath.section + 1)
    }

    func indexPath(before indexPath: IndexPath?) -> IndexPath? {
        guard let indexPath else {
            return firstIndexPath(from: 0)
        }
        if indexPath.row > 0 {
            return IndexPath(row: indexPath.row - 1, section: indexPath.section)
        }
        var section = indexPath.section - 1
        while section >= 0 {
            let rows = numberOfRows(inSection: section)
            if rows > 0 {
                return IndexPath(row: rows - 1, section: section)
            }
            section -= 1
        }
        return nil
    }

    private func firstIndexPath(from section: Int) -> IndexPath? {
        var section = section
        while section < numberOfSections {
            if numberOfRows(inSection: section) > 0 {
                return IndexPath(row: 0, section: section)
            }
            section += 1
        }
        return nil
    }

    /// Moves the keyboard focus, shown as the table's selection, to `indexPath`.
    func focusRow(at indexPath: IndexPath?) {
        guard let indexPath else {
            return
        }
        selectRow(at: indexPath, animated: false, scrollPosition: .none)
        scrollToRow(at: indexPath, at: .none, animated: true)
    }
}
