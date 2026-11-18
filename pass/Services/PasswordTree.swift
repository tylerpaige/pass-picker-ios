//
//  PasswordTree.swift
//  pass
//
//  Collapsible folder tree in the style of Pass Picker's sidebar: folders expand
//  in place instead of pushing a new screen. Shared by the app and the AutoFill extension.
//

import passKit
import UIKit

struct PasswordTreeRow {
    let entry: PasswordTableEntry
    let depth: Int
    let parentPath: String?
}

class PasswordTree {
    private let roots: [PasswordTableEntry]
    private(set) var rows = [PasswordTreeRow]()
    private(set) var expandedPaths: Set<String>

    init(parent: PasswordEntity?, expandedPaths: Set<String> = []) {
        self.roots = Self.sortedChildren(of: parent)
        self.expandedPaths = expandedPaths
        rebuildRows()
    }

    func isExpanded(_ row: PasswordTreeRow) -> Bool {
        expandedPaths.contains(row.entry.passwordEntity.path)
    }

    func toggle(at index: Int) {
        let path = rows[index].entry.passwordEntity.path
        if expandedPaths.contains(path) {
            expandedPaths.remove(path)
        } else {
            expandedPaths.insert(path)
        }
        rebuildRows()
    }

    func expandAll() {
        expandedPaths.formUnion(Self.folderPaths(in: roots))
        rebuildRows()
    }

    func collapseAll() {
        expandedPaths.removeAll()
        rebuildRows()
    }

    /// ⇧→: expands the row's level and everything below it, within its parent folder.
    func expandLevel(at index: Int) {
        let parent = rows[index].parentPath.flatMap { PasswordStore.shared.fetchPasswordEntity(with: $0) }
        expandedPaths.formUnion(Self.folderPaths(in: parent == nil ? roots : Self.sortedChildren(of: parent)))
        rebuildRows()
    }

    /// ⇧←: collapses the row's level and everything below it, within its parent folder.
    func collapseLevel(at index: Int) {
        if let parentPath = rows[index].parentPath {
            expandedPaths = expandedPaths.filter { !$0.hasPrefix(parentPath + "/") }
        } else {
            expandedPaths.removeAll()
        }
        rebuildRows()
    }

    /// Expands the folders above `path` (and `path` itself when it is a folder) so its row is shown.
    func reveal(path: String) {
        var ancestor = ""
        for component in path.split(separator: "/").dropLast() {
            ancestor = ancestor.isEmpty ? String(component) : "\(ancestor)/\(component)"
            expandedPaths.insert(ancestor)
        }
        if PasswordStore.shared.fetchPasswordEntity(with: path)?.isDir == true {
            expandedPaths.insert(path)
        }
        rebuildRows()
    }

    func index(ofPath path: String) -> Int? {
        rows.firstIndex { $0.entry.passwordEntity.path == path }
    }

    private func rebuildRows() {
        rows = []
        appendRows(for: roots, depth: 0, parentPath: nil)
    }

    private func appendRows(for entries: [PasswordTableEntry], depth: Int, parentPath: String?) {
        for entry in entries {
            rows.append(PasswordTreeRow(entry: entry, depth: depth, parentPath: parentPath))
            if entry.isDir, expandedPaths.contains(entry.passwordEntity.path) {
                appendRows(for: Self.sortedChildren(of: entry.passwordEntity), depth: depth + 1, parentPath: entry.passwordEntity.path)
            }
        }
    }

    private static func folderPaths(in entries: [PasswordTableEntry]) -> [String] {
        entries.filter(\.isDir).flatMap { [$0.passwordEntity.path] + folderPaths(in: sortedChildren(of: $0.passwordEntity)) }
    }

    // Folders first, then alphabetical, matching Pass Picker.
    private static func sortedChildren(of parent: PasswordEntity?) -> [PasswordTableEntry] {
        PasswordStore.shared.fetchPasswordEntityCoreData(parent: parent)
            .map { PasswordTableEntry($0) }
            .sorted { lhs, rhs in
                if lhs.isDir != rhs.isDir {
                    return lhs.isDir
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }
}

extension PasswordTableViewCell {
    func configure(treeRow row: PasswordTreeRow, in tree: PasswordTree, isAlternate: Bool, isOpen: Bool = false) {
        // The tree itself shows where an entry lives, so no category detail.
        configure(with: row.entry, depth: row.depth, isExpanded: tree.isExpanded(row), isAlternate: isAlternate, showsDetail: false, isOpen: isOpen)
    }
}
